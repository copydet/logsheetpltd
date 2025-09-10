import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/firebase_user_model.dart';

/// ============================================================================
/// USER MANAGEMENT SERVICE
/// ============================================================================
/// Service untuk manajemen user oleh admin
/// Menggunakan Firebase Auth dan Firestore
/// ============================================================================

class UserManagementService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'user_profile';

  // ========================================================================
  // USER CREATION
  // ========================================================================

  /// Buat user baru (Admin only)
  /// Menggunakan Firebase Auth untuk authentication dan Firestore untuk profile
  static Future<Map<String, dynamic>> createUser({
    required String username,
    required String displayName,
    required String password,
    required String role,
    required List<String> generatorAccess,
    Map<String, bool>? permissions,
  }) async {
    try {
      print('👤 USER_MGMT: Creating new user: $username');

      // Validasi input
      if (username.isEmpty || displayName.isEmpty || password.isEmpty) {
        return {
          'success': false,
          'message': 'Username, display name, dan password wajib diisi'
        };
      }

      if (password.length < 6) {
        return {
          'success': false,
          'message': 'Password minimal 6 karakter'
        };
      }

      // Konversi username ke email format
      final email = _convertUsernameToEmail(username);
      
      // Cek apakah user sudah ada
      final existingUser = await _checkUserExists(username, email);
      if (existingUser['exists'] == true) {
        return {
          'success': false,
          'message': existingUser['message']
        };
      }

      // Buat user di Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        return {
          'success': false,
          'message': 'Gagal membuat user di Firebase Auth'
        };
      }

      final uid = userCredential.user!.uid;

      // Update display name di Firebase Auth
      await userCredential.user!.updateDisplayName(displayName);

      // Buat user profile di Firestore
      final userProfile = {
        'uid': uid,
        'username': username.toLowerCase(),
        'displayName': displayName,
        'email': email,
        'role': role,
        'isActive': true,
        'generatorAccess': generatorAccess,
        'permissions': _createDefaultPermissions(role, permissions),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Simpan ke Firestore dengan UID sebagai document ID
      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .set(userProfile);

      print('✅ USER_MGMT: User $username berhasil dibuat dengan UID: $uid');
      
      return {
        'success': true,
        'message': 'User $displayName berhasil dibuat',
        'uid': uid,
        'email': email,
      };

    } on FirebaseAuthException catch (e) {
      print('❌ USER_MGMT: Firebase Auth error: ${e.code} - ${e.message}');
      
      String errorMessage = 'Gagal membuat user';
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Email sudah digunakan';
          break;
        case 'invalid-email':
          errorMessage = 'Format email tidak valid';
          break;
        case 'weak-password':
          errorMessage = 'Password terlalu lemah';
          break;
        default:
          errorMessage = 'Error: ${e.message}';
      }

      return {
        'success': false,
        'message': errorMessage
      };
    } catch (e) {
      print('❌ USER_MGMT: Unexpected error creating user: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan: $e'
      };
    }
  }

  // ========================================================================
  // USER RETRIEVAL
  // ========================================================================

  /// Ambil semua users dari Firestore
  static Future<List<FirebaseUserModel>> getAllUsers() async {
    try {
      print('👥 USER_MGMT: Fetching all users');

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .orderBy('displayName')
          .get();

      final users = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return FirebaseUserModel.fromFirestore(data, doc.id);
      }).toList();

      print('✅ USER_MGMT: Retrieved ${users.length} users');
      return users;

    } catch (e) {
      print('❌ USER_MGMT: Error getting users: $e');
      return [];
    }
  }

  /// Ambil user berdasarkan UID
  static Future<FirebaseUserModel?> getUserByUid(String uid) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(uid)
          .get();

      if (!doc.exists) return null;

      return FirebaseUserModel.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      print('❌ USER_MGMT: Error getting user by UID: $e');
      return null;
    }
  }

  /// Ambil user berdasarkan username
  static Future<FirebaseUserModel?> getUserByUsername(String username) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      final doc = querySnapshot.docs.first;
      return FirebaseUserModel.fromFirestore(doc.data(), doc.id);
    } catch (e) {
      print('❌ USER_MGMT: Error getting user by username: $e');
      return null;
    }
  }

  // ========================================================================
  // USER UPDATE
  // ========================================================================

  /// Update user profile
  static Future<Map<String, dynamic>> updateUser({
    required String uid,
    String? displayName,
    String? role,
    List<String>? generatorAccess,
    Map<String, bool>? permissions,
    bool? isActive,
  }) async {
    try {
      print('👤 USER_MGMT: Updating user: $uid');

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (displayName != null) updateData['displayName'] = displayName;
      if (role != null) {
        updateData['role'] = role;
        // Update permissions based on new role
        if (permissions == null) {
          updateData['permissions'] = _createDefaultPermissions(role, null);
        }
      }
      if (generatorAccess != null) updateData['generatorAccess'] = generatorAccess;
      if (permissions != null) updateData['permissions'] = permissions;
      if (isActive != null) updateData['isActive'] = isActive;

      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .update(updateData);

      // Update display name di Firebase Auth jika diperlukan
      if (displayName != null) {
        try {
          // Note: Untuk update Firebase Auth user, perlu special handling
          // Karena kita tidak punya akses ke user token
          print('📝 USER_MGMT: Display name updated in Firestore');
        } catch (e) {
          print('⚠️ USER_MGMT: Could not update Firebase Auth display name: $e');
        }
      }

      print('✅ USER_MGMT: User updated successfully');
      return {
        'success': true,
        'message': 'User berhasil diupdate'
      };

    } catch (e) {
      print('❌ USER_MGMT: Error updating user: $e');
      return {
        'success': false,
        'message': 'Gagal mengupdate user: $e'
      };
    }
  }

  // ========================================================================
  // USER DELETION
  // ========================================================================

  /// Hapus user (soft delete - set isActive = false)
  static Future<Map<String, dynamic>> deactivateUser(String uid) async {
    try {
      print('👤 USER_MGMT: Deactivating user: $uid');

      // Soft delete - set isActive = false
      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ USER_MGMT: User deactivated successfully');
      return {
        'success': true,
        'message': 'User berhasil dinonaktifkan'
      };

    } catch (e) {
      print('❌ USER_MGMT: Error deactivating user: $e');
      return {
        'success': false,
        'message': 'Gagal menonaktifkan user: $e'
      };
    }
  }

  /// Hapus user secara permanen (hard delete)
  static Future<Map<String, dynamic>> deleteUserPermanently(String uid) async {
    try {
      print('👤 USER_MGMT: Permanently deleting user from database: $uid');

      // Hapus dari Firestore
      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .delete();

      // Note: Untuk menghapus dari Firebase Auth diperlukan Firebase Admin SDK
      // yang biasanya dijalankan di server, bukan di client
      print('⚠️ USER_MGMT: User deleted from Firestore. Firebase Auth account still exists.');

      print('✅ USER_MGMT: User permanently deleted from Firestore database');
      return {
        'success': true,
        'message': 'User berhasil dihapus dari database.\n\nCATATAN: Akun Firebase Authentication masih ada dan perlu dihapus manual dari Firebase Console untuk keamanan penuh.'
      };

    } catch (e) {
      print('❌ USER_MGMT: Error permanently deleting user: $e');
      return {
        'success': false,
        'message': 'Gagal menghapus user secara permanen: $e'
      };
    }
  }

  /// Aktivasi ulang user
  static Future<Map<String, dynamic>> activateUser(String uid) async {
    try {
      print('👤 USER_MGMT: Activating user: $uid');

      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ USER_MGMT: User activated successfully');
      return {
        'success': true,
        'message': 'User berhasil diaktifkan'
      };

    } catch (e) {
      print('❌ USER_MGMT: Error activating user: $e');
      return {
        'success': false,
        'message': 'Gagal mengaktifkan user: $e'
      };
    }
  }

  // ========================================================================
  // PASSWORD MANAGEMENT
  // ========================================================================

  /// Reset password user
  static Future<Map<String, dynamic>> resetUserPassword(String email) async {
    try {
      print('🔐 USER_MGMT: Sending password reset email to: $email');

      await _auth.sendPasswordResetEmail(email: email);

      print('✅ USER_MGMT: Password reset email sent');
      return {
        'success': true,
        'message': 'Email reset password berhasil dikirim'
      };

    } catch (e) {
      print('❌ USER_MGMT: Error sending password reset: $e');
      return {
        'success': false,
        'message': 'Gagal mengirim email reset password: $e'
      };
    }
  }

  // ========================================================================
  // HELPER METHODS
  // ========================================================================

  /// Konversi username ke email format
  static String _convertUsernameToEmail(String username) {
    if (username.contains('@')) {
      return username; // Already email format
    }
    return '${username.toLowerCase()}@pltd.com';
  }

  /// Cek apakah user sudah ada
  static Future<Map<String, dynamic>> _checkUserExists(
    String username,
    String email,
  ) async {
    try {
      // Cek berdasarkan username di Firestore
      final usernameQuery = await _firestore
          .collection(_collectionName)
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        return {
          'exists': true,
          'message': 'Username sudah digunakan'
        };
      }

      // Cek berdasarkan email di Firestore
      final emailQuery = await _firestore
          .collection(_collectionName)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        return {
          'exists': true,
          'message': 'Email sudah digunakan'
        };
      }

      return {
        'exists': false,
        'message': 'User available'
      };

    } catch (e) {
      print('❌ USER_MGMT: Error checking user existence: $e');
      return {
        'exists': false,
        'message': 'Could not check user existence'
      };
    }
  }

  /// Buat default permissions berdasarkan role
  static Map<String, bool> _createDefaultPermissions(
    String role,
    Map<String, bool>? customPermissions,
  ) {
    final defaultPermissions = <String, bool>{
      'canViewReports': true,
      'canEditLogsheet': role != 'viewer',
      'canDeleteLogsheet': role == 'admin' || role == 'manager',
      'canManageUsers': role == 'admin',
      'canAccessAdminPanel': role == 'admin',
      'canExportData': role != 'viewer',
      'canViewAllGenerators': role == 'admin' || role == 'manager',
      'canManageGeneratorAccess': role == 'admin',
    };

    // Override dengan custom permissions jika ada
    if (customPermissions != null) {
      defaultPermissions.addAll(customPermissions);
    }

    return defaultPermissions;
  }

  // ========================================================================
  // VALIDATION METHODS
  // ========================================================================

  /// Validasi username
  static Map<String, dynamic> validateUsername(String username) {
    if (username.isEmpty) {
      return {'valid': false, 'message': 'Username tidak boleh kosong'};
    }

    if (username.length < 3) {
      return {'valid': false, 'message': 'Username minimal 3 karakter'};
    }

    if (username.length > 20) {
      return {'valid': false, 'message': 'Username maksimal 20 karakter'};
    }

    // Cek karakter yang diizinkan (alphanumeric dan underscore)
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return {
        'valid': false,
        'message': 'Username hanya boleh berisi huruf, angka, dan underscore'
      };
    }

    return {'valid': true, 'message': 'Username valid'};
  }

  /// Validasi display name
  static Map<String, dynamic> validateDisplayName(String displayName) {
    if (displayName.isEmpty) {
      return {'valid': false, 'message': 'Nama tampilan tidak boleh kosong'};
    }

    if (displayName.length < 2) {
      return {'valid': false, 'message': 'Nama tampilan minimal 2 karakter'};
    }

    if (displayName.length > 50) {
      return {'valid': false, 'message': 'Nama tampilan maksimal 50 karakter'};
    }

    return {'valid': true, 'message': 'Nama tampilan valid'};
  }

  /// Validasi password
  static Map<String, dynamic> validatePassword(String password) {
    if (password.isEmpty) {
      return {'valid': false, 'message': 'Password tidak boleh kosong'};
    }

    if (password.length < 6) {
      return {'valid': false, 'message': 'Password minimal 6 karakter'};
    }

    if (password.length > 128) {
      return {'valid': false, 'message': 'Password maksimal 128 karakter'};
    }

    return {'valid': true, 'message': 'Password valid'};
  }

  // ========================================================================
  // UTILITY METHODS
  // ========================================================================

  /// Ambil daftar role yang tersedia
  static List<String> getAvailableRoles() {
    return ['operator', 'admin'];
  }

  /// Ambil daftar generator yang tersedia
  static List<String> getAvailableGenerators() {
    return [
      'PLTD_MITSUBISHI_1',
      'PLTD_MITSUBISHI_2', 
      'PLTD_MITSUBISHI_3',
      'PLTD_MITSUBISHI_4'
    ];
  }

  /// Get role description
  static String getRoleDescription(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrator - Akses penuh ke semua fitur';
      case 'manager':
        return 'Manager - Dapat mengelola data dan melihat laporan';
      case 'leader':
        return 'Leader - Dapat mengedit logsheet dan melihat laporan';
      case 'operator':
        return 'Operator - Dapat mengedit logsheet';
      case 'viewer':
        return 'Viewer - Hanya dapat melihat data';
      default:
        return 'Role tidak dikenal';
    }
  }
}
