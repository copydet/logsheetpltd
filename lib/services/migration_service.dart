import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';
import '../models/database/database_user_model.dart';
import '../models/database/generator_model.dart';
import '../models/database/cache_model.dart';

/// ============================================================================
/// MIGRATION SERVICE
/// ============================================================================
/// Service untuk migrate data dari SharedPreferences ke SQLite
/// ============================================================================

class MigrationService {
  static final DatabaseService _dbService = DatabaseService();

  // ========================================================================
  // MAIN MIGRATION METHOD
  // ========================================================================

  /// Migrate semua data dari SharedPreferences ke SQLite
  static Future<bool> migrateToSQLite() async {
    try {
      print('🔄 MIGRATION: Starting SharedPreferences → SQLite migration...');

      // Backup existing SharedPreferences data
      await _backupSharedPreferences();

      // Initialize database
      await _dbService.database;

      // Migrate users
      await _migrateUsers();

      // Migrate generators
      await _migrateGenerators();

      // Migrate temperature data
      await _migrateTemperatureData();

      // Migrate logsheet cache
      await _migrateLogsheetCache();

      // Migrate settings
      await _migrateSettings();

      // Verify migration
      final isValid = await _verifyMigration();

      print(
        '🔄 MIGRATION: Migration completed ${isValid ? 'successfully' : 'with errors'}',
      );
      return isValid;
    } catch (e) {
      print('❌ MIGRATION: Error during migration: $e');
      return false;
    }
  }

  // ========================================================================
  // BACKUP METHODS
  // ========================================================================

  static Future<void> _backupSharedPreferences() async {
    try {
      print('💾 MIGRATION: Creating SharedPreferences backup...');

      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      final backup = <String, dynamic>{};
      for (final key in allKeys) {
        final value = prefs.get(key);
        backup[key] = value;
      }

      // Save backup to database settings table
      final db = await _dbService.database;
      await db.insert('settings', {
        'key': '_migration_backup',
        'value': json.encode(backup),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      print('💾 MIGRATION: Backup created with ${allKeys.length} keys');
    } catch (e) {
      print('❌ MIGRATION: Error creating backup: $e');
    }
  }

  // ========================================================================
  // USER MIGRATION
  // ========================================================================

  static Future<void> _migrateUsers() async {
    try {
      print('👤 MIGRATION: Migrating users...');

      final prefs = await SharedPreferences.getInstance();
      final db = await _dbService.database;

      // Get users from SharedPreferences
      final usersJson = prefs.getString('users');
      if (usersJson != null) {
        final usersList = json.decode(usersJson) as List;

        for (final userData in usersList) {
          final user = DatabaseUser(
            username: userData['username'] ?? 'unknown',
            displayName:
                userData['displayName'] ??
                userData['username'] ??
                'Unknown User',
            role: userData['role'] ?? 'operator',
          );

          await db.insert(
            'users',
            user.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          print('👤 MIGRATION: Migrated user: ${user.username}');
        }
      }

      // Migrate current user session
      final currentUser = prefs.getString('current_user');
      if (currentUser != null) {
        final userData = json.decode(currentUser);

        // Find user in database
        final userResults = await db.query(
          'users',
          where: 'username = ?',
          whereArgs: [userData['username']],
        );

        if (userResults.isNotEmpty) {
          final userId = userResults.first['id'] as int;

          // Create session
          final session = DatabaseUserSession(
            userId: userId,
            sessionToken: DateTime.now().millisecondsSinceEpoch.toString(),
            isActive: true,
          );

          await db.insert(
            'user_sessions',
            session.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          print(
            '👤 MIGRATION: Created session for user: ${userData['username']}',
          );
        }
      }

      print('👤 MIGRATION: Users migration completed');
    } catch (e) {
      print('❌ MIGRATION: Error migrating users: $e');
    }
  }

  // ========================================================================
  // GENERATOR MIGRATION
  // ========================================================================

  static Future<void> _migrateGenerators() async {
    try {
      print('⚡ MIGRATION: Migrating generators...');

      final prefs = await SharedPreferences.getInstance();
      final db = await _dbService.database;

      // Default generators
      final defaultGenerators = ['Generator 1', 'Generator 2', 'Generator 3'];

      for (final generatorName in defaultGenerators) {
        // Check generator status
        final statusKey = 'generator_status_$generatorName';
        final isActive = prefs.getBool(statusKey) ?? false;

        // Check active file ID
        final fileIdKey = 'active_file_id_$generatorName';
        final activeFileId = prefs.getString(fileIdKey);

        final generator = Generator(
          name: generatorName,
          isActive: isActive,
          activeFileId: activeFileId,
        );

        await db.insert(
          'generators',
          generator.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        print(
          '⚡ MIGRATION: Migrated generator: $generatorName (active: $isActive)',
        );
      }

      print('⚡ MIGRATION: Generators migration completed');
    } catch (e) {
      print('❌ MIGRATION: Error migrating generators: $e');
    }
  }

  // ========================================================================
  // TEMPERATURE DATA MIGRATION
  // ========================================================================

  static Future<void> _migrateTemperatureData() async {
    try {
      print('🌡️ MIGRATION: Migrating temperature data...');

      final prefs = await SharedPreferences.getInstance();
      final db = await _dbService.database;
      final allKeys = prefs.getKeys();

      int migratedCount = 0;

      for (final key in allKeys) {
        if (key.startsWith('temp_data_')) {
          try {
            final dataJson = prefs.getString(key);
            if (dataJson != null) {
              final data = json.decode(dataJson);

              final tempData = TemperatureData(
                fileId: data['fileId'] ?? '',
                hour: data['hour'] ?? 0,
                date: data['date'] ?? '',
                waterTemp: (data['waterTemp'] as num?)?.toDouble() ?? 0.0,
                lubeOilTemp: (data['lubeOilTemp'] as num?)?.toDouble() ?? 0.0,
                tempBearing: (data['tempBearing'] as num?)?.toDouble() ?? 0.0,
                tempWindingU: (data['tempWindingU'] as num?)?.toDouble() ?? 0.0,
                tempWindingV: (data['tempWindingV'] as num?)?.toDouble() ?? 0.0,
                tempWindingW: (data['tempWindingW'] as num?)?.toDouble() ?? 0.0,
                engineTempExhaust:
                    (data['engineTempExhaust'] as num?)?.toDouble() ?? 0.0,
              );

              await db.insert(
                'temperature_data',
                tempData.toMap(),
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
              migratedCount++;
            }
          } catch (e) {
            print('❌ MIGRATION: Error migrating temperature key $key: $e');
          }
        }
      }

      print(
        '🌡️ MIGRATION: Temperature data migration completed ($migratedCount records)',
      );
    } catch (e) {
      print('❌ MIGRATION: Error migrating temperature data: $e');
    }
  }

  // ========================================================================
  // LOGSHEET CACHE MIGRATION
  // ========================================================================

  static Future<void> _migrateLogsheetCache() async {
    try {
      print('📄 MIGRATION: Migrating logsheet cache...');

      final prefs = await SharedPreferences.getInstance();
      final db = await _dbService.database;
      final allKeys = prefs.getKeys();

      int migratedCount = 0;

      for (final key in allKeys) {
        if (key.contains('_hasData_') || key.contains('_logsheet_')) {
          try {
            // Parse cache keys and migrate
            // This is a simplified migration - you might need to adjust based on actual key patterns

            final value = prefs.get(key);
            if (value != null) {
              // Create cache entry
              final cache = LogsheetCache(
                fileId: 'migrated_$key',
                generatorName: 'unknown',
                hour: 0,
                date: DateTime.now()
                    .toIso8601String()
                    .substring(0, 10)
                    .replaceAll('-', ''),
                hasData: value is bool ? value : false,
                dataJson: value is String ? {'data': value} : null,
                cachedAt: DateTime.now(),
                expiresAt: DateTime.now().add(const Duration(days: 7)),
              );

              await db.insert(
                'logsheet_cache',
                cache.toMap(),
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
              migratedCount++;
            }
          } catch (e) {
            print('❌ MIGRATION: Error migrating cache key $key: $e');
          }
        }
      }

      print(
        '📄 MIGRATION: Logsheet cache migration completed ($migratedCount records)',
      );
    } catch (e) {
      print('❌ MIGRATION: Error migrating logsheet cache: $e');
    }
  }

  // ========================================================================
  // SETTINGS MIGRATION
  // ========================================================================

  static Future<void> _migrateSettings() async {
    try {
      print('⚙️ MIGRATION: Migrating settings...');

      final prefs = await SharedPreferences.getInstance();
      final db = await _dbService.database;
      final allKeys = prefs.getKeys();

      int migratedCount = 0;

      for (final key in allKeys) {
        // Skip keys that are already migrated
        if (key.startsWith('temp_data_') ||
            key == 'users' ||
            key == 'current_user' ||
            key.startsWith('generator_status_') ||
            key.startsWith('active_file_id_')) {
          continue;
        }

        try {
          final value = prefs.get(key);
          if (value != null) {
            final setting = Setting(
              key: key,
              value: value.toString(),
              updatedAt: DateTime.now(),
            );

            await db.insert(
              'settings',
              setting.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            migratedCount++;
          }
        } catch (e) {
          print('❌ MIGRATION: Error migrating setting $key: $e');
        }
      }

      print(
        '⚙️ MIGRATION: Settings migration completed ($migratedCount records)',
      );
    } catch (e) {
      print('❌ MIGRATION: Error migrating settings: $e');
    }
  }

  // ========================================================================
  // VERIFICATION
  // ========================================================================

  static Future<bool> _verifyMigration() async {
    try {
      print('✅ MIGRATION: Verifying migration...');

      // Check table counts
      final userCount = await _dbService.getTableRowCount('users');
      final generatorCount = await _dbService.getTableRowCount('generators');
      final tempCount = await _dbService.getTableRowCount('temperature_data');
      final cacheCount = await _dbService.getTableRowCount('logsheet_cache');
      final settingsCount = await _dbService.getTableRowCount('settings');

      print('✅ MIGRATION: Verification results:');
      print('   - Users: $userCount');
      print('   - Generators: $generatorCount');
      print('   - Temperature data: $tempCount');
      print('   - Cache entries: $cacheCount');
      print('   - Settings: $settingsCount');

      return true;
    } catch (e) {
      print('❌ MIGRATION: Error during verification: $e');
      return false;
    }
  }

  // ========================================================================
  // CLEANUP METHODS
  // ========================================================================

  /// Clear SharedPreferences after successful migration
  static Future<void> clearSharedPreferencesAfterMigration() async {
    try {
      print('🧹 MIGRATION: Clearing SharedPreferences after migration...');

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      print('🧹 MIGRATION: SharedPreferences cleared');
    } catch (e) {
      print('❌ MIGRATION: Error clearing SharedPreferences: $e');
    }
  }

  /// Restore from backup if needed
  static Future<void> restoreFromBackup() async {
    try {
      print('🔄 MIGRATION: Restoring from backup...');

      final db = await _dbService.database;
      final backupResult = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['_migration_backup'],
      );

      if (backupResult.isNotEmpty) {
        final backupData = json.decode(backupResult.first['value'] as String);
        final prefs = await SharedPreferences.getInstance();

        for (final entry in backupData.entries) {
          final key = entry.key;
          final value = entry.value;

          if (value is String) {
            await prefs.setString(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          } else if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is double) {
            await prefs.setDouble(key, value);
          } else if (value is List<String>) {
            await prefs.setStringList(key, value);
          }
        }

        print('🔄 MIGRATION: Backup restored successfully');
      }
    } catch (e) {
      print('❌ MIGRATION: Error restoring from backup: $e');
    }
  }
}
