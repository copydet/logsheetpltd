import 'database_service.dart';
import '../models/database/database_user_model.dart';

/// ============================================================================
/// DATABASE USER SERVICE
/// ============================================================================
/// Service untuk manage users menggunakan SQLite database
/// Menggantikan SharedPreferences dengan SQLite untuk better performance
/// ============================================================================

class DatabaseUserService {
  static final DatabaseService _dbService = DatabaseService();

  // ========================================================================
  // USER MANAGEMENT
  // ========================================================================

  /// Add user baru ke database
  static Future<bool> addUser(
    String username,
    String displayName,
    String role,
  ) async {
    try {
      // Cek apakah user sudah ada
      if (await userExists(username)) {
        print('❌ USER: User $username sudah ada');
        return false;
      }

      final user = DatabaseUser(
        username: username,
        displayName: displayName,
        role: role,
      );

      final db = await _dbService.database;
      final id = await db.insert('users', user.toMap());

      print('✅ USER: User $username berhasil ditambahkan dengan ID: $id');
      return true;
    } catch (e) {
      print('❌ USER: Error adding user $username: $e');
      return false;
    }
  }

  /// Get semua users dari database
  static Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final db = await _dbService.database;
      final result = await db.query('users', orderBy: 'display_name ASC');

      final users = result.map((row) {
        final user = DatabaseUser.fromMap(row);
        return {
          'username': user.username,
          'displayName': user.displayName,
          'role': user.role,
        };
      }).toList();

      print('✅ USER: Retrieved ${users.length} users');
      return users;
    } catch (e) {
      print('❌ USER: Error getting users: $e');
      return [];
    }
  }

  /// Cek apakah user exists
  static Future<bool> userExists(String username) async {
    try {
      final db = await _dbService.database;
      final result = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      print('❌ USER: Error checking user existence: $e');
      return false;
    }
  }

  /// Get user detail by username
  static Future<Map<String, dynamic>?> getUserByUsername(
    String username,
  ) async {
    try {
      final db = await _dbService.database;
      final result = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );

      if (result.isEmpty) return null;

      final user = DatabaseUser.fromMap(result.first);
      return {
        'username': user.username,
        'displayName': user.displayName,
        'role': user.role,
      };
    } catch (e) {
      print('❌ USER: Error getting user $username: $e');
      return null;
    }
  }

  /// Update user information
  static Future<bool> updateUser(
    String username, {
    String? displayName,
    String? role,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (displayName != null) updateData['display_name'] = displayName;
      if (role != null) updateData['role'] = role;

      final db = await _dbService.database;
      final updated = await db.update(
        'users',
        updateData,
        where: 'username = ?',
        whereArgs: [username],
      );

      if (updated > 0) {
        print('✅ USER: User $username berhasil diupdate');
        return true;
      } else {
        print('❌ USER: User $username tidak ditemukan untuk update');
        return false;
      }
    } catch (e) {
      print('❌ USER: Error updating user $username: $e');
      return false;
    }
  }

  /// Delete user
  static Future<bool> deleteUser(String username) async {
    try {
      final db = await _dbService.database;

      // Get user ID for cleanup
      final userResult = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );

      if (userResult.isEmpty) {
        print('❌ USER: User $username tidak ditemukan untuk delete');
        return false;
      }

      final userId = userResult.first['id'] as int;

      // Delete user sessions first (foreign key constraint)
      await db.delete(
        'user_sessions',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Delete user
      final deleted = await db.delete(
        'users',
        where: 'username = ?',
        whereArgs: [username],
      );

      if (deleted > 0) {
        print('✅ USER: User $username berhasil dihapus');
        return true;
      } else {
        print('❌ USER: Gagal menghapus user $username');
        return false;
      }
    } catch (e) {
      print('❌ USER: Error deleting user $username: $e');
      return false;
    }
  }

  // ========================================================================
  // SESSION MANAGEMENT
  // ========================================================================

  /// Login user dan create session
  static Future<bool> loginUser(String username) async {
    try {
      // Cek apakah user ada
      final userResult = await getUserByUsername(username);
      if (userResult == null) {
        print('❌ USER: User $username tidak ditemukan');
        return false;
      }

      // Get user ID
      final db = await _dbService.database;
      final users = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );

      if (users.isEmpty) return false;

      final userId = users.first['id'] as int;

      // Deactivate all existing sessions for this user
      await db.update(
        'user_sessions',
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Create new session
      final session = DatabaseUserSession(
        userId: userId,
        sessionToken: DateTime.now().millisecondsSinceEpoch.toString(),
        isActive: true,
      );

      await db.insert('user_sessions', session.toMap());

      print('✅ USER: User $username berhasil login');
      return true;
    } catch (e) {
      print('❌ USER: Error during login for $username: $e');
      return false;
    }
  }

  /// Logout user (deactivate session)
  static Future<bool> logoutUser() async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null) {
        print('❌ USER: Tidak ada user yang sedang login');
        return false;
      }

      // Get user ID
      final db = await _dbService.database;
      final users = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [currentUser['username']],
        limit: 1,
      );

      if (users.isEmpty) return false;

      final userId = users.first['id'] as int;

      // Deactivate all sessions for this user
      final updated = await db.update(
        'user_sessions',
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'user_id = ? AND is_active = 1',
        whereArgs: [userId],
      );

      if (updated > 0) {
        print('✅ USER: User ${currentUser['username']} berhasil logout');
        return true;
      } else {
        print('❌ USER: Tidak ada session aktif untuk logout');
        return false;
      }
    } catch (e) {
      print('❌ USER: Error during logout: $e');
      return false;
    }
  }

  /// Get current logged in user
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final db = await _dbService.database;

      // Get active session with user data
      final result = await db.rawQuery('''
        SELECT u.username, u.display_name, u.role, s.session_token
        FROM user_sessions s
        JOIN users u ON s.user_id = u.id
        WHERE s.is_active = 1
        ORDER BY s.created_at DESC
        LIMIT 1
      ''');

      if (result.isEmpty) return null;

      final row = result.first;
      return {
        'username': row['username'],
        'displayName': row['display_name'],
        'role': row['role'],
      };
    } catch (e) {
      print('❌ USER: Error getting current user: $e');
      return null;
    }
  }

  /// Check if user is logged in
  static Future<bool> isUserLoggedIn() async {
    try {
      final currentUser = await getCurrentUser();
      return currentUser != null;
    } catch (e) {
      print('❌ USER: Error checking login status: $e');
      return false;
    }
  }

  /// Get active sessions count
  static Future<int> getActiveSessionsCount() async {
    try {
      final db = await _dbService.database;
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM user_sessions
        WHERE is_active = 1
      ''');

      return result.first['count'] as int;
    } catch (e) {
      print('❌ USER: Error getting active sessions count: $e');
      return 0;
    }
  }

  // ========================================================================
  // UTILITY METHODS
  // ========================================================================

  /// Get user statistics
  static Future<Map<String, int>> getUserStats() async {
    try {
      final db = await _dbService.database;

      final totalUsersResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM users',
      );
      final activeSessionsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM user_sessions WHERE is_active = 1',
      );

      return {
        'totalUsers': totalUsersResult.first['count'] as int,
        'activeSessions': activeSessionsResult.first['count'] as int,
      };
    } catch (e) {
      print('❌ USER: Error getting user stats: $e');
      return {'totalUsers': 0, 'activeSessions': 0};
    }
  }

  /// Clear all user data (untuk testing)
  static Future<bool> clearAllUserData() async {
    try {
      final db = await _dbService.database;

      await db.delete('user_sessions');
      await db.delete('users');

      print('✅ USER: All user data cleared');
      return true;
    } catch (e) {
      print('❌ USER: Error clearing user data: $e');
      return false;
    }
  }

  /// Initialize dengan default users (jika diperlukan)
  static Future<void> initializeDefaultUsers() async {
    try {
      final userCount = await (await _dbService.database).rawQuery(
        'SELECT COUNT(*) as count FROM users',
      );
      final count = userCount.first['count'] as int;

      if (count == 0) {
        // Add default admin user
        await addUser('admin', 'Administrator', 'admin');
        print('✅ USER: Default admin user created');
      }
    } catch (e) {
      print('❌ USER: Error initializing default users: $e');
    }
  }
}
