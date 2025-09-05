import 'database_service.dart';
import '../models/database/cache_model.dart';
import '../models/database/generator_model.dart';

/// ============================================================================
/// DATABASE STORAGE SERVICE
/// ============================================================================
/// Service untuk general storage menggunakan SQLite database
/// Menggantikan SharedPreferences dengan SQLite untuk better performance
/// ============================================================================

class DatabaseStorageService {
  static final DatabaseService _dbService = DatabaseService();

  // ========================================================================
  // GENERATOR MANAGEMENT
  // ========================================================================

  /// Atur generator status (active/inactive)
  static Future<bool> setGeneratorStatus(
    String generatorName,
    bool isActive,
  ) async {
    try {
      final db = await _dbService.database;

      // Cek if generator exists
      final existing = await db.query(
        'generators',
        where: 'name = ?',
        whereArgs: [generatorName],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Update existing generator
        final updated = await db.update(
          'generators',
          {
            'is_active': isActive ? 1 : 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'name = ?',
          whereArgs: [generatorName],
        );

        print(
          '✅ STORAGE: Generator $generatorName status updated to ${isActive ? 'active' : 'inactive'}',
        );
        return updated > 0;
      } else {
        // Buat new generator
        final generator = Generator(name: generatorName, isActive: isActive);

        final id = await db.insert('generators', generator.toMap());
        print(
          '✅ STORAGE: Generator $generatorName created with status ${isActive ? 'active' : 'inactive'}',
        );
        return id > 0;
      }
    } catch (e) {
      print('❌ STORAGE:  setting generator status: $e');
      return false;
    }
  }

  /// Ambil generator status
  static Future<bool> getGeneratorStatus(String generatorName) async {
    try {
      final db = await _dbService.database;
      final result = await db.query(
        'generators',
        where: 'name = ?',
        whereArgs: [generatorName],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final generator = Generator.fromMap(result.first);
        return generator.isActive;
      }

      return false; // Default to inactive if not found
    } catch (e) {
      print('❌ STORAGE:  getting generator status: $e');
      return false;
    }
  }

  /// Atur active file ID untuk generator
  static Future<bool> setActiveFileId(
    String generatorName,
    String fileId,
  ) async {
    try {
      final db = await _dbService.database;

      // Cek if generator exists
      final existing = await db.query(
        'generators',
        where: 'name = ?',
        whereArgs: [generatorName],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Update existing generator
        final updated = await db.update(
          'generators',
          {
            'active_file_id': fileId,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'name = ?',
          whereArgs: [generatorName],
        );

        print('✅ STORAGE: Active file ID for $generatorName set to $fileId');
        return updated > 0;
      } else {
        // Buat new generator with file ID
        final generator = Generator(name: generatorName, activeFileId: fileId);

        final id = await db.insert('generators', generator.toMap());
        print(
          '✅ STORAGE: Generator $generatorName created with file ID $fileId',
        );
        return id > 0;
      }
    } catch (e) {
      print('❌ STORAGE:  setting active file ID: $e');
      return false;
    }
  }

  /// Ambil active file ID untuk generator
  static Future<String?> getActiveFileId(String generatorName) async {
    try {
      final db = await _dbService.database;
      final result = await db.query(
        'generators',
        where: 'name = ?',
        whereArgs: [generatorName],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final generator = Generator.fromMap(result.first);
        return generator.activeFileId;
      }

      return null;
    } catch (e) {
      print('❌ STORAGE:  getting active file ID: $e');
      return null;
    }
  }

  /// Ambil all generators
  static Future<List<Map<String, dynamic>>> getAllGenerators() async {
    try {
      final db = await _dbService.database;
      final result = await db.query('generators', orderBy: 'name ASC');

      return result.map((row) {
        final generator = Generator.fromMap(row);
        return {
          'name': generator.name,
          'isActive': generator.isActive,
          'activeFileId': generator.activeFileId,
        };
      }).toList();
    } catch (e) {
      print('❌ STORAGE:  getting all generators: $e');
      return [];
    }
  }

  // ========================================================================
  // LOGSHEET CACHE MANAGEMENT
  // ========================================================================

  /// Atur cache data untuk logsheet
  static Future<bool> setCacheData(
    String fileId,
    String generatorName,
    int hour,
    String date,
    bool hasData, {
    Map<String, dynamic>? dataJson,
    Duration? expirationDuration,
  }) async {
    try {
      final now = DateTime.now();
      final expiresAt = expirationDuration != null
          ? now.add(expirationDuration)
          : now.add(const Duration(days: 7)); // Default 7 days

      final cache = LogsheetCache(
        fileId: fileId,
        generatorName: generatorName,
        hour: hour,
        date: date,
        hasData: hasData,
        dataJson: dataJson,
        cachedAt: now,
        expiresAt: expiresAt,
      );

      final db = await _dbService.database;

      // Cek if cache already exists
      final existing = await db.query(
        'logsheet_cache',
        where: 'file_id = ? AND generator_name = ? AND hour = ? AND date = ?',
        whereArgs: [fileId, generatorName, hour, date],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Update existing cache
        final updated = await db.update(
          'logsheet_cache',
          cache.toMap(),
          where: 'file_id = ? AND generator_name = ? AND hour = ? AND date = ?',
          whereArgs: [fileId, generatorName, hour, date],
        );

        print('✅ STORAGE: Cache updated for $fileId $generatorName hour $hour');
        return updated > 0;
      } else {
        // Insert new cache
        final id = await db.insert('logsheet_cache', cache.toMap());
        print('✅ STORAGE: Cache created for $fileId $generatorName hour $hour');
        return id > 0;
      }
    } catch (e) {
      print('❌ STORAGE:  setting cache data: $e');
      return false;
    }
  }

  /// Ambil cache data untuk logsheet
  static Future<Map<String, dynamic>?> getCacheData(
    String fileId,
    String generatorName,
    int hour,
    String date,
  ) async {
    try {
      final db = await _dbService.database;
      final result = await db.query(
        'logsheet_cache',
        where: 'file_id = ? AND generator_name = ? AND hour = ? AND date = ?',
        whereArgs: [fileId, generatorName, hour, date],
        limit: 1,
      );

      if (result.isEmpty) return null;

      final cache = LogsheetCache.fromMap(result.first);

      // Cek if cache is expired
      if (cache.expiresAt != null &&
          cache.expiresAt!.isBefore(DateTime.now())) {
        // Hapus expired cache
        await db.delete(
          'logsheet_cache',
          where: 'file_id = ? AND generator_name = ? AND hour = ? AND date = ?',
          whereArgs: [fileId, generatorName, hour, date],
        );

        print(
          '🗑️ STORAGE: Expired cache deleted for $fileId $generatorName hour $hour',
        );
        return null;
      }

      return {
        'fileId': cache.fileId,
        'generatorName': cache.generatorName,
        'hour': cache.hour,
        'date': cache.date,
        'hasData': cache.hasData,
        'dataJson': cache.dataJson,
        'cachedAt': cache.cachedAt,
        'expiresAt': cache.expiresAt,
      };
    } catch (e) {
      print('❌ STORAGE:  getting cache data: $e');
      return null;
    }
  }

  /// Cek if logsheet has data (from cache)
  static Future<bool> hasLogsheetData(
    String fileId,
    String generatorName,
    int hour,
    String date,
  ) async {
    try {
      final cacheData = await getCacheData(fileId, generatorName, hour, date);
      return cacheData?['hasData'] ?? false;
    } catch (e) {
      print('❌ STORAGE: Error  logsheet data: $e');
      return false;
    }
  }

  /// Bersihkan expired cache entries
  static Future<int> clearExpiredCache() async {
    try {
      final db = await _dbService.database;
      final deleted = await db.delete(
        'logsheet_cache',
        where: 'expires_at < ?',
        whereArgs: [DateTime.now().toIso8601String()],
      );

      print('🗑️ STORAGE: Cleared $deleted expired cache entries');
      return deleted;
    } catch (e) {
      print('❌ STORAGE:  clearing expired cache: $e');
      return 0;
    }
  }

  /// Bersihkan all cache untuk fileId tertentu
  static Future<bool> clearCacheByFileId(String fileId) async {
    try {
      final db = await _dbService.database;
      final deleted = await db.delete(
        'logsheet_cache',
        where: 'file_id = ?',
        whereArgs: [fileId],
      );

      print('🗑️ STORAGE: Cleared $deleted cache entries for $fileId');
      return true;
    } catch (e) {
      print('❌ STORAGE:  clearing cache by fileId: $e');
      return false;
    }
  }

  // ========================================================================
  // AturTINGS MANAGEMENT
  // ========================================================================

  /// Atur setting value
  static Future<bool> setSetting(String key, String value) async {
    try {
      final db = await _dbService.database;

      // Cek if setting exists
      final existing = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Update existing setting
        final updated = await db.update(
          'settings',
          {'value': value, 'updated_at': DateTime.now().toIso8601String()},
          where: 'key = ?',
          whereArgs: [key],
        );

        return updated > 0;
      } else {
        // Insert new setting
        final id = await db.insert('settings', {
          'key': key,
          'value': value,
          'updated_at': DateTime.now().toIso8601String(),
        });

        return id > 0;
      }
    } catch (e) {
      print('❌ STORAGE:  setting value for $key: $e');
      return false;
    }
  }

  /// Ambil setting value
  static Future<String?> getSetting(String key, {String? defaultValue}) async {
    try {
      final db = await _dbService.database;
      final result = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return result.first['value'] as String;
      }

      return defaultValue;
    } catch (e) {
      print('❌ STORAGE:  getting value for $key: $e');
      return defaultValue;
    }
  }

  /// Ambil all settings
  static Future<Map<String, String>> getAllSettings() async {
    try {
      final db = await _dbService.database;
      final result = await db.query('settings');

      final settings = <String, String>{};
      for (final row in result) {
        settings[row['key'] as String] = row['value'] as String;
      }

      return settings;
    } catch (e) {
      print('❌ STORAGE:  getting all settings: $e');
      return {};
    }
  }

  /// Hapus setting
  static Future<bool> deleteSetting(String key) async {
    try {
      final db = await _dbService.database;
      final deleted = await db.delete(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
      );

      return deleted > 0;
    } catch (e) {
      print('❌ STORAGE:  deleting setting $key: $e');
      return false;
    }
  }

  // ========================================================================
  // STATISTICS & UTILITY METHODS
  // ========================================================================

  /// Ambil storage statistics
  static Future<Map<String, int>> getStorageStats() async {
    try {
      final db = await _dbService.database;

      final generatorCount = await _dbService.getTableRowCount('generators');
      final cacheCount = await _dbService.getTableRowCount('logsheet_cache');
      final settingsCount = await _dbService.getTableRowCount('settings');

      final expiredCacheResult = await db.rawQuery(
        '''
        SELECT COUNT(*) as count 
        FROM logsheet_cache 
        WHERE expires_at < ?
      ''',
        [DateTime.now().toIso8601String()],
      );

      final expiredCacheCount = expiredCacheResult.first['count'] as int;

      return {
        'generators': generatorCount,
        'cache': cacheCount,
        'settings': settingsCount,
        'expiredCache': expiredCacheCount,
      };
    } catch (e) {
      print('❌ STORAGE:  getting storage stats: $e');
      return {'generators': 0, 'cache': 0, 'settings': 0, 'expiredCache': 0};
    }
  }

  /// Bersihkan all storage data (untuk testing)
  static Future<bool> clearAllStorageData() async {
    try {
      final db = await _dbService.database;

      await db.delete('logsheet_cache');
      await db.delete('generators');
      await db.delete('settings');

      print('✅ STORAGE: All storage data cleared');
      return true;
    } catch (e) {
      print('❌ STORAGE:  clearing storage data: $e');
      return false;
    }
  }

  /// Inisialisasi default generators
  static Future<void> initializeDefaultGenerators() async {
    try {
      final generatorCount = await (await _dbService.database).rawQuery(
        'SELECT COUNT(*) as count FROM generators',
      );
      final count = generatorCount.first['count'] as int;

      if (count == 0) {
        // Tambah default generators
        final defaultGenerators = ['Generator 1', 'Generator 2', 'Generator 3'];

        for (final generatorName in defaultGenerators) {
          await setGeneratorStatus(generatorName, false);
        }

        print('✅ STORAGE: Default generators initialized');
      }
    } catch (e) {
      print('❌ STORAGE:  initializing default generators: $e');
    }
  }
}
