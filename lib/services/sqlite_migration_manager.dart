import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// Manager untuk mengelola migrasi SQLite database
class SQLiteMigrationManager {
  static const int _currentVersion = 1;

  /// Melakukan migrasi database jika diperlukan
  static Future<bool> performMigration() async {
    try {
      print('📊 MIGRASI: Memulai proses migrasi SQLite...');
      
      final dbService = DatabaseService();
      final db = await dbService.database;
      final version = await db.getVersion();
      
      print('📊 MIGRASI: Versi database saat ini: $version');
      print('📊 MIGRASI: Versi target: $_currentVersion');
      
      if (version < _currentVersion) {
        print('📊 MIGRASI: Memerlukan migrasi dari versi $version ke $_currentVersion');
        
        // Lakukan migrasi berdasarkan versi
        for (int v = version + 1; v <= _currentVersion; v++) {
          await _migrateToVersion(db, v);
        }
        
        await db.setVersion(_currentVersion);
        print('✅ MIGRASI: Berhasil diupgrade ke versi $_currentVersion');
      } else {
        print('✅ MIGRASI: Database sudah pada versi terbaru');
      }
      
      return true;
    } catch (e) {
      print('❌ MIGRASI: Gagal melakukan migrasi: $e');
      return false;
    }
  }

  /// Migrasi ke versi tertentu
  static Future<void> _migrateToVersion(Database db, int version) async {
    print('📊 MIGRASI: Melakukan migrasi ke versi $version...');
    
    switch (version) {
      case 1:
        await _migrateToV1(db);
        break;
      default:
        print('⚠️ MIGRASI: Versi $version tidak dikenal');
    }
  }

  /// Migrasi ke versi 1 - Setup tabel dasar
  static Future<void> _migrateToV1(Database db) async {
    try {
      // Buat tabel untuk menyimpan data temperature jika belum ada
      await db.execute('''
        CREATE TABLE IF NOT EXISTS temperature_data (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          generator_name TEXT NOT NULL,
          shift TEXT NOT NULL,
          date TEXT NOT NULL,
          time TEXT NOT NULL,
          temperature REAL NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0
        )
      ''');

      // Buat tabel untuk migration status
      await db.execute('''
        CREATE TABLE IF NOT EXISTS migration_status (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      // Buat tabel untuk sync status
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_status (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          last_sync TEXT,
          status TEXT DEFAULT 'pending'
        )
      ''');

      print('✅ MIGRASI: Tabel-tabel versi 1 berhasil dibuat');
    } catch (e) {
      print('❌ MIGRASI: Gagal membuat tabel versi 1: $e');
      rethrow;
    }
  }

  /// Simpan data temperature ke SQLite
  static Future<void> saveTemperatureData({
    required String generatorName,
    required String shift,
    required String date,
    required String time,
    required double temperature,
  }) async {
    try {
      final dbService = DatabaseService();
      final db = await dbService.database;
      final now = DateTime.now().toIso8601String();
      
      await db.insert('temperature_data', {
        'generator_name': generatorName,
        'shift': shift,
        'date': date,
        'time': time,
        'temperature': temperature,
        'created_at': now,
        'synced': 0,
      });
      
      print('✅ TEMP DATA: Data suhu berhasil disimpan ke SQLite');
    } catch (e) {
      print('❌ TEMP DATA: Gagal menyimpan data suhu: $e');
      rethrow;
    }
  }

  /// Dapatkan data temperature yang belum disync
  static Future<List<Map<String, dynamic>>> getUnsyncedTemperatureData() async {
    try {
      final dbService = DatabaseService();
      final db = await dbService.database;
      final result = await db.query(
        'temperature_data',
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'created_at ASC',
      );
      
      print('📊 TEMP DATA: Ditemukan ${.length} data yang belum disync');
      return result;
    } catch (e) {
      print('❌ TEMP DATA: Gagal mengambil data yang belum disync: $e');
      return [];
    }
  }

  /// Tandai data temperature sebagai sudah disync
  static Future<void> markTemperatureDataAsSynced(List<int> ids) async {
    try {
      final dbService = DatabaseService();
      final db = await dbService.database;
      final batch = db.batch();
      
      for (final id in ids) {
        batch.update(
          'temperature_data',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      
      await batch.commit();
      print('✅ TEMP DATA: ${ids.length} data berhasil ditandai sebagai tersync');
    } catch (e) {
      print('❌ TEMP DATA: Gagal menandai data sebagai tersync: $e');
      rethrow;
    }
  }

  /// Update status migrasi
  static Future<void> updateMigrationStatus(String key, String value) async {
    try {
      final dbService = DatabaseService();
      final db = await dbService.database;
      final now = DateTime.now().toIso8601String();
      
      await db.insert(
        'migration_status',
        {
          'key': key,
          'value': value,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('✅ MIGRASI: Status migrasi $key berhasil diupdate');
    } catch (e) {
      print('❌ MIGRASI: Gagal update status migrasi: $e');
    }
  }

  /// Dapatkan status migrasi
  static Future<String?> getMigrationStatus(String key) async {
    try {
      final dbService = DatabaseService();
      final db = await dbService.database;
      final result = await db.query(
        'migration_status',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        return result.first['value'] as String;
      }
      
      return null;
    } catch (e) {
      print('❌ MIGRASI: Gagal mengambil status migrasi: $e');
      return null;
    }
  }

  /// Bersihkan data lama
  static Future<void> cleanupOldData({int daysToKeep = 30}) async {
    try {
      final dbService = DatabaseService();
      final db = await dbService.database;
      final cutoffDate = DateTime.now()
          .subtract(Duration(days: daysToKeep))
          .toIso8601String();
      
      final deletedCount = await db.delete(
        'temperature_data',
        where: 'created_at < ? AND synced = ?',
        whereArgs: [cutoffDate, 1],
      );
      
      print('✅ CLEANUP: $deletedCount data lama berhasil dibersihkan');
    } catch (e) {
      print('❌ CLEANUP: Gagal membersihkan data lama: $e');
    }
  }
}
