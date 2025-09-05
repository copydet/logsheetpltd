import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

/// ============================================================================
/// DATABASE SERVICE
/// ============================================================================
/// Core service untuk mengelola SQLite database
/// Tanganis: initialization, migrations, connections
/// ============================================================================

class DatabaseService {
  // ========================================================================
  // SINGLETON PATTERN
  // ========================================================================

  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // ========================================================================
  // PROPERTIES
  // ========================================================================

  static Database? _database;
  static const String _databaseName = 'logsheet_app.db';
  static const int _databaseVersion = 3;

  // ========================================================================
  // DATABASE GETTER
  // ========================================================================

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // ========================================================================
  // DATABASE INITIALIZATION
  // ========================================================================

  Future<Database> _initDatabase() async {
    try {
      // Ambil database path
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);

      print('🗄️ DATABASE: Initializing database at: $path');

      // Open database with version control
      final database = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
        onDowngrade: _downgradeDatabase,
      );

      print('🗄️ DATABASE: fully initialized');
      return database;
    } catch (e) {
      print('❌ DATABASE:  initializing database: $e');
      rethrow;
    }
  }

  // ========================================================================
  // DATABASE CREATION
  // ========================================================================

  Future<void> _createDatabase(Database db, int version) async {
    print('🗄️ DATABASE: Creating database tables...');

    // Buat Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        display_name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'operator',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Buat User Sessions table
    await db.execute('''
      CREATE TABLE user_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        session_token TEXT UNIQUE NOT NULL,
        is_active BOOLEAN DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        expires_at DATETIME,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // Buat Generators table
    await db.execute('''
      CREATE TABLE generators (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        is_active BOOLEAN DEFAULT 0,
        active_file_id TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Buat Temperature Data table
    await db.execute('''
      CREATE TABLE temperature_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_id TEXT NOT NULL,
        generator_id INTEGER,
        hour INTEGER NOT NULL,
        date TEXT NOT NULL,
        water_temp REAL DEFAULT 0.0,
        lube_oil_temp REAL DEFAULT 0.0,
        temp_bearing REAL DEFAULT 0.0,
        temp_winding_u REAL DEFAULT 0.0,
        temp_winding_v REAL DEFAULT 0.0,
        temp_winding_w REAL DEFAULT 0.0,
        engine_temp_exhaust REAL DEFAULT 0.0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (generator_id) REFERENCES generators(id) ON DELETE CASCADE,
        UNIQUE(file_id, date, hour)
      )
    ''');

    // Buat Logsheet Cache table
    await db.execute('''
      CREATE TABLE logsheet_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_id TEXT NOT NULL,
        generator_name TEXT NOT NULL,
        hour INTEGER NOT NULL,
        date TEXT NOT NULL,
        has_data BOOLEAN DEFAULT 0,
        data_json TEXT,
        cached_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        expires_at DATETIME,
        UNIQUE(file_id, date, hour)
      )
    ''');

    // Buat Settings table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Buat Logsheets Historical Data table
    await db.execute('''
      CREATE TABLE logsheets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_id TEXT NOT NULL,
        generator_name TEXT NOT NULL,
        timestamp DATETIME NOT NULL,
        date TEXT NOT NULL,
        hour INTEGER NOT NULL,
        
        -- Engine data
        rpm TEXT,
        jam_operasi TEXT,
        lube_oil_temp TEXT,
        oil_pressure TEXT,
        water_temp TEXT,
        tegangan_accu TEXT,
        beban TEXT,
        
        -- Electrical data
        voltage_r TEXT,
        voltage_s TEXT,
        voltage_t TEXT,
        ampere_r TEXT,
        ampere_s TEXT,
        ampere_t TEXT,
        frequency TEXT,
        cosinus TEXT,
        kvar TEXT,
        
        -- Temperature data
        temp_winding_u TEXT,
        temp_winding_v TEXT,
        temp_winding_w TEXT,
        temp_bearing TEXT,
        engine_pressure_crankcase TEXT,
        engine_temp_exhaust TEXT,
        
        -- Energy and Fuel data
        kwh_awal TEXT,
        kwh_akhir TEXT,
        total_kwh TEXT,
        bbm_awal TEXT,
        bbm_akhir TEXT,
        total_bbm TEXT,
        sfc TEXT,
        
        -- Metadata
        source TEXT DEFAULT 'spreadsheet',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        
        UNIQUE(file_id, date, hour)
      )
    ''');

    // Buat Indexes for better performance
    await _createIndexes(db);

    // Insert default data
    await _insertDefaultData(db);

    print('🗄️ DATABASE: All tables created fully');
  }

  // ========================================================================
  // DATABASE INDEXES
  // ========================================================================

  Future<void> _createIndexes(Database db) async {
    print('🗄️ DATABASE: Creating indexes...');

    // Temperature data indexes
    await db.execute(
      'CREATE INDEX idx_temp_file_date ON temperature_data(file_id, date)',
    );
    await db.execute(
      'CREATE INDEX idx_temp_date_hour ON temperature_data(date, hour)',
    );

    // Logsheet cache indexes
    await db.execute(
      'CREATE INDEX idx_cache_file_date ON logsheet_cache(file_id, date)',
    );
    await db.execute(
      'CREATE INDEX idx_cache_expires ON logsheet_cache(expires_at)',
    );

    // User session indexes
    await db.execute('CREATE INDEX idx_session_user ON user_sessions(user_id)');
    await db.execute(
      'CREATE INDEX idx_session_active ON user_sessions(is_active)',
    );

    // Logsheets historical data indexes
    await db.execute(
      'CREATE INDEX idx_logsheets_generator_date ON logsheets(generator_name, date)',
    );
    await db.execute(
      'CREATE INDEX idx_logsheets_timestamp ON logsheets(timestamp)',
    );
    await db.execute(
      'CREATE INDEX idx_logsheets_file_id ON logsheets(file_id)',
    );

    print('🗄️ DATABASE: Indexes created');
  }

  // ========================================================================
  // DEFAULT DATA
  // ========================================================================

  Future<void> _insertDefaultData(Database db) async {
    print('🗄️ DATABASE: Inserting default data...');

    // Insert default generators (based on existing app data)
    final generators = [
      {'name': 'Generator 1', 'is_active': 0},
      {'name': 'Generator 2', 'is_active': 0},
      {'name': 'Generator 3', 'is_active': 0},
    ];

    for (final generator in generators) {
      await db.insert('generators', generator);
    }

    // Insert default admin user
    await db.insert('users', {
      'username': 'admin',
      'display_name': 'Administrator',
      'role': 'admin',
    });

    print('🗄️ DATABASE: Default data inserted');
  }

  // ========================================================================
  // DATABASE MIGRATION
  // ========================================================================

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    print('🗄️ DATABASE: Upgrading from version $oldVersion to $newVersion');

    // Upgrade from version 1 to 2: Add logsheets table
    if (oldVersion < 2) {
      print('🗄️ DATABASE: Adding logsheets historical data table...');

      await db.execute('''
        CREATE TABLE logsheets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          file_id TEXT NOT NULL,
          generator_name TEXT NOT NULL,
          timestamp DATETIME NOT NULL,
          date TEXT NOT NULL,
          hour INTEGER NOT NULL,
          
          -- Engine data
          rpm TEXT,
          jam_operasi TEXT,
          lube_oil_temp TEXT,
          oil_pressure TEXT,
          water_temp TEXT,
          tegangan_accu TEXT,
          beban TEXT,
          
          -- Electrical data
          voltage_r TEXT,
          voltage_s TEXT,
          voltage_t TEXT,
          ampere_r TEXT,
          ampere_s TEXT,
          ampere_t TEXT,
          frequency TEXT,
          cosinus TEXT,
          kvar TEXT,
          
          -- Temperature data
          temp_winding_u TEXT,
          temp_winding_v TEXT,
          temp_winding_w TEXT,
          temp_bearing TEXT,
          engine_pressure_crankcase TEXT,
          engine_temp_exhaust TEXT,
          
          -- Energy and Fuel data
          kwh_awal TEXT,
          kwh_akhir TEXT,
          total_kwh TEXT,
          bbm_awal TEXT,
          bbm_akhir TEXT,
          total_bbm TEXT,
          sfc TEXT,
          
          -- Metadata
          source TEXT DEFAULT 'spreadsheet',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          
          UNIQUE(file_id, date, hour)
        )
      ''');

      // Tambah indexes for logsheets table
      await db.execute(
        'CREATE INDEX idx_logsheets_generator_date ON logsheets(generator_name, date)',
      );
      await db.execute(
        'CREATE INDEX idx_logsheets_timestamp ON logsheets(timestamp)',
      );
      await db.execute(
        'CREATE INDEX idx_logsheets_file_id ON logsheets(file_id)',
      );

      print('🗄️ DATABASE: Logsheets table and indexes created fully');
    }

    // Upgrade from version 2 to 3: Add energy and fuel tracking columns
    if (oldVersion < 3) {
      print('🗄️ DATABASE: Adding energy and fuel tracking columns...');

      await db.execute('ALTER TABLE logsheets ADD COLUMN kwh_awal TEXT');
      await db.execute('ALTER TABLE logsheets ADD COLUMN kwh_akhir TEXT');
      await db.execute('ALTER TABLE logsheets ADD COLUMN total_kwh TEXT');
      await db.execute('ALTER TABLE logsheets ADD COLUMN bbm_awal TEXT');
      await db.execute('ALTER TABLE logsheets ADD COLUMN bbm_akhir TEXT');
      await db.execute('ALTER TABLE logsheets ADD COLUMN total_bbm TEXT');
      await db.execute('ALTER TABLE logsheets ADD COLUMN sfc TEXT');

      print(
        '🗄️ DATABASE: Energy and fuel tracking columns added successfully',
      );
    }
  }

  Future<void> _downgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    print('🗄️ DATABASE: Downgrading from version $oldVersion to $newVersion');
    // Tangani version downgrades here (usually not recommended)
  }

  // ========================================================================
  // Method utilitasS
  // ========================================================================

  /// Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      print('🗄️ DATABASE: Connection closed');
    }
  }

  /// Ambil database info
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    final path = db.path;
    final version = await db.getVersion();

    return {'path': path, 'version': version, 'isOpen': db.isOpen};
  }

  /// Cek if table exists
  Future<bool> tableExists(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  /// Ambil table row count
  Future<int> getTableRowCount(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName',
    );
    return result.first['count'] as int;
  }

  /// Jalankan raw query with error handling
  Future<List<Map<String, dynamic>>> executeQuery(
    String query, [
    List<dynamic>? arguments,
  ]) async {
    try {
      final db = await database;
      return await db.rawQuery(query, arguments);
    } catch (e) {
      print('❌ DATABASE:  executing query: $e');
      print('❌ DATABASE: Query: $query');
      rethrow;
    }
  }

  /// Jalankan raw query with no result
  Future<void> executeNonQuery(String query, [List<dynamic>? arguments]) async {
    try {
      final db = await database;
      await db.rawQuery(query, arguments);
      print('🗄️ DATABASE: Query executed fully');
    } catch (e) {
      print('❌ DATABASE:  executing non-query: $e');
      print('❌ DATABASE: Query: $query');
      rethrow;
    }
  }

  // ========================================================================
  // TRANSACTION SUPPORT
  // ========================================================================

  /// Jalankan multiple operations in a transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  // ========================================================================
  // BersihkanUP METHODS
  // ========================================================================

  /// Bersihkan expired cache entries
  Future<int> cleanExpiredCache() async {
    final db = await database;
    final result = await db.delete(
      'logsheet_cache',
      where: 'expires_at < ?',
      whereArgs: [DateTime.now().toIso8601String()],
    );

    print('🗄️ DATABASE: Cleaned $result expired cache entries');
    return result;
  }

  /// Bersihkan old temperature data (older than 30 days)
  Future<int> cleanOldTemperatureData() async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    final cutoffDateStr = cutoffDate
        .toIso8601String()
        .substring(0, 10)
        .replaceAll('-', '');

    final result = await db.delete(
      'temperature_data',
      where: 'date < ?',
      whereArgs: [cutoffDateStr],
    );

    print('🗄️ DATABASE: Cleaned $result old temperature records');
    return result;
  }

  // ========================================================================
  // LOGSHEET HISTORICAL DATA METHODS
  // ========================================================================

  /// Simpan logsheet data to historical database
  Future<void> saveLogsheetToHistory(
    String fileId,
    String generatorName,
    Map<String, dynamic> logsheetData,
  ) async {
    try {
      final db = await database;
      final now = DateTime.now();

      // Extract date and hour from ORIGINAL FORM DATA, not savedDate
      String dateStr;
      int hour;
      String timestamp;

      // Use form date/time if available, otherwise use save time
      if (logsheetData['tanggal'] != null && logsheetData['jam'] != null) {
        // Use original form data
        dateStr = logsheetData['tanggal'].toString();
        hour = int.tryParse(logsheetData['jam'].toString()) ?? now.hour;

        // Buat proper timestamp from form data
        final formDate = DateTime.tryParse(dateStr);
        if (formDate != null) {
          final formDateTime = DateTime(
            formDate.year,
            formDate.month,
            formDate.day,
            hour,
          );
          timestamp = formDateTime.toIso8601String();
        } else {
          timestamp = now.toIso8601String();
        }
      } else {
        // Fallback to save time if form data not available
        final savedDate = logsheetData['savedDate'] ?? now.toIso8601String();
        final parsedDate = DateTime.tryParse(savedDate) ?? now;
        dateStr =
            '${parsedDate.year.toString().padLeft(4, '0')}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
        hour = parsedDate.hour;
        timestamp = savedDate;
      }

      await db.insert('logsheets', {
        'file_id': fileId,
        'generator_name': generatorName,
        'timestamp': timestamp,
        'date': dateStr,
        'hour': hour,

        // Engine data
        'rpm': logsheetData['rpm']?.toString(),
        'jam_operasi': logsheetData['jamOperasi']?.toString(),
        'lube_oil_temp': logsheetData['lubeOilTemp']?.toString(),
        'oil_pressure': logsheetData['oilPressure']?.toString(),
        'water_temp': logsheetData['waterTemp']?.toString(),
        'tegangan_accu': logsheetData['teganganAccu']?.toString(),
        'beban': logsheetData['beban']?.toString(),

        // Electrical data
        'voltage_r': logsheetData['voltageR']?.toString(),
        'voltage_s': logsheetData['voltageS']?.toString(),
        'voltage_t': logsheetData['voltageT']?.toString(),
        'ampere_r': logsheetData['ampereR']?.toString(),
        'ampere_s': logsheetData['ampereS']?.toString(),
        'ampere_t': logsheetData['ampereT']?.toString(),
        'frequency': logsheetData['hz']?.toString(),
        'cosinus': logsheetData['cosPhi']?.toString(),
        'kvar': logsheetData['kvar']?.toString(), // Temperature data
        'temp_winding_u': logsheetData['tempWindingU']?.toString(),
        'temp_winding_v': logsheetData['tempWindingV']?.toString(),
        'temp_winding_w': logsheetData['tempWindingW']?.toString(),
        'temp_bearing': logsheetData['tempBearing']?.toString(),
        'engine_pressure_crankcase': logsheetData['enginePressureCrankcase']
            ?.toString(),
        'engine_temp_exhaust': logsheetData['engineTempExhaust']?.toString(),

        // 🔧 FIX: Add kWh and BBM data to SQLite storage
        'kwh_awal': logsheetData['kwhAwal']?.toString(),
        'kwh_akhir': logsheetData['kwhAkhir']?.toString(),
        'total_kwh': logsheetData['totalKwh']?.toString(),
        'bbm_awal': logsheetData['bbmAwal']?.toString(),
        'bbm_akhir': logsheetData['bbmAkhir']?.toString(),
        'total_bbm': logsheetData['totalBbm']?.toString(),
        'sfc': logsheetData['sfc']?.toString(),

        'source': 'spreadsheet',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      print(
        '💾 DATABASE: Saved logsheet data for $generatorName at $dateStr $hour:00 (timestamp: $timestamp)',
      );
      print('💾 DATABASE: Logsheet data keys: ${logsheetData.keys.toList()}');
      print(
        '💾 DATABASE: Form date: ${logsheetData['tanggal']}, Form hour: ${logsheetData['jam']}',
      );
    } catch (e) {
      print('❌ DATABASE:  saving logsheet to history: $e');
    }
  }

  /// Update energy/BBM data for existing logsheet record
  Future<void> updateLogsheetEnergyData(
    String fileId,
    String generatorName,
    Map<String, dynamic> energyData,
  ) async {
    try {
      final db = await database;
      final now = DateTime.now();

      // Ambil current date and hour
      String dateStr;
      int hour;

      if (energyData['tanggal'] != null && energyData['jam'] != null) {
        dateStr = energyData['tanggal'].toString();
        hour = int.tryParse(energyData['jam'].toString()) ?? now.hour;
      } else {
        dateStr =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        hour = now.hour;
      }

      // Cek if record exists for this generator, date, and hour
      final existing = await db.query(
        'logsheets',
        where: 'file_id = ? AND generator_name = ? AND date = ? AND hour = ?',
        whereArgs: [fileId, generatorName, dateStr, hour],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Update existing record with energy data
        await db.update(
          'logsheets',
          {
            'kwh_awal': energyData['kwhAwal']?.toString(),
            'kwh_akhir': energyData['kwhAkhir']?.toString(),
            'total_kwh': energyData['totalKwh']?.toString(),
            'bbm_awal': energyData['bbmAwal']?.toString(),
            'bbm_akhir': energyData['bbmAkhir']?.toString(),
            'total_bbm': energyData['totalBbm']?.toString(),
            'sfc': energyData['sfc']?.toString(),
          },
          where: 'file_id = ? AND generator_name = ? AND date = ? AND hour = ?',
          whereArgs: [fileId, generatorName, dateStr, hour],
        );

        print(
          '✅ DATABASE: Updated energy data for $generatorName at $dateStr $hour:00',
        );
      } else {
        // If no existing record, create new one with energy data only
        // This should not happen if operational data was saved first
        print(
          '⚠️ DATABASE: No existing record found for $generatorName at $dateStr $hour:00, creating new record',
        );

        final timestamp = DateTime(
          DateTime.parse(dateStr).year,
          DateTime.parse(dateStr).month,
          DateTime.parse(dateStr).day,
          hour,
        ).toIso8601String();

        await db.insert('logsheets', {
          'file_id': fileId,
          'generator_name': generatorName,
          'timestamp': timestamp,
          'date': dateStr,
          'hour': hour,

          // Energy data only (operational data will be null)
          'kwh_awal': energyData['kwhAwal']?.toString(),
          'kwh_akhir': energyData['kwhAkhir']?.toString(),
          'total_kwh': energyData['totalKwh']?.toString(),
          'bbm_awal': energyData['bbmAwal']?.toString(),
          'bbm_akhir': energyData['bbmAkhir']?.toString(),
          'total_bbm': energyData['totalBbm']?.toString(),
          'sfc': energyData['sfc']?.toString(),

          'source': 'spreadsheet',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      print('❌ DATABASE:  updating energy data: $e');
      rethrow;
    }
  }

  /// Ambil historical logsheet data for a generator
  Future<List<Map<String, dynamic>>> getLogsheetHistory(
    String generatorName, {
    int daysBack = 7,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: daysBack));

      final results = await db.query(
        'logsheets',
        where: 'generator_name = ? AND timestamp >= ?',
        whereArgs: [generatorName, startDate.toIso8601String()],
        orderBy: 'timestamp DESC',
      );

      print(
        '🗄️ DATABASE: Retrieved ${results.length} historical logsheet records for $generatorName',
      );

      // Ubah raw database rows to logsheet data format
      return results.map((row) => _convertRowToLogsheetData(row)).toList();
    } catch (e) {
      print('❌ DATABASE:  getting logsheet history: $e');
      return [];
    }
  }

  /// Ambil logsheet data for a specific date
  Future<List<Map<String, dynamic>>> getLogsheetByDate(
    String generatorName,
    DateTime date,
  ) async {
    try {
      final db = await database;
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final results = await db.query(
        'logsheets',
        where: 'generator_name = ? AND date = ?',
        whereArgs: [generatorName, dateStr],
        orderBy: 'hour ASC',
      );

      print(
        '🗄️ DATABASE: Retrieved ${results.length} logsheet records for $generatorName on $dateStr',
      );
      return results;
    } catch (e) {
      print('❌ DATABASE:  getting logsheet by date: $e');
      return [];
    }
  }

  /// DEBUG: Get total count of all logsheet records
  Future<int> getTotalLogsheetCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM logsheets',
      );
      final count = result.first['count'] as int? ?? 0;
      print('🗄️ DATABASE: Total logsheet records in database: $count');
      return count;
    } catch (e) {
      print('❌ DATABASE:  getting total logsheet count: $e');
      return 0;
    }
  }

  /// DEBUG: Get logsheet count by generator
  Future<Map<String, int>> getLogsheetCountByGenerator() async {
    try {
      final db = await database;
      final results = await db.rawQuery('''
        SELECT generator_name, COUNT(*) as count 
        FROM logsheets 
        GROUP BY generator_name
      ''');

      final counts = <String, int>{};
      for (final row in results) {
        final name = row['generator_name'] as String;
        final count = row['count'] as int;
        counts[name] = count;
      }

      print('🗄️ DATABASE: Logsheet counts by generator: $counts');
      return counts;
    } catch (e) {
      print('❌ DATABASE:  getting logsheet count by generator: $e');
      return {};
    }
  }

  // ========================================================================
  // AturTINGS MANAGEMENT (untuk SyncManager)
  // ========================================================================

  /// Ambil all settings as a map
  Future<Map<String, String>> getSettings() async {
    try {
      final db = await database;
      final results = await db.query('settings');

      final settings = <String, String>{};
      for (final row in results) {
        settings[row['key'] as String] = row['value'] as String;
      }

      return settings;
    } catch (e) {
      print('❌ DATABASE:  getting settings: $e');
      return {};
    }
  }

  /// Atur a single setting
  Future<void> setSetting(String key, String value) async {
    try {
      final db = await database;
      await db.insert('settings', {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('❌ DATABASE:  setting $key: $e');
    }
  }

  /// Ambil logsheet history with limit and date filter (untuk SyncManager)
  Future<List<Map<String, dynamic>>> getLogsheetHistoryForSync({
    int limit = 1000,
    DateTime? since,
  }) async {
    try {
      final db = await database;
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (since != null) {
        whereClause = 'WHERE timestamp >= ?';
        whereArgs.add(since.toIso8601String());
      }

      final results = await db.rawQuery(
        'SELECT * FROM logsheets $whereClause ORDER BY timestamp DESC LIMIT ?',
        [...whereArgs, limit],
      );

      // Ubah to format compatible with Firestore
      final formattedResults = results.map((row) {
        return {
          'id': row['id'],
          'file_id': row['file_id'],
          'generator_name': row['generator_name'],
          'date': row['date'],
          'created_at': row['timestamp'],
          'data': _convertRowToLogsheetData(row),
        };
      }).toList();

      return formattedResults;
    } catch (e) {
      print('❌ DATABASE:  getting logsheet history for sync: $e');
      return [];
    }
  }

  /// Ubah database row to logsheet data format
  Map<String, dynamic> _convertRowToLogsheetData(Map<String, dynamic> row) {
    return {
      'jamOperasi': row['jam_operasi'],
      'rpm': row['rpm'],
      'lubeOilTemp': row['lube_oil_temp'],
      'oilPressure': row['oil_pressure'],
      'waterTemp': row['water_temp'],
      'teganganAccu': row['tegangan_accu'],
      'beban': row['beban'],
      'voltageR': row['voltage_r'],
      'voltageS': row['voltage_s'],
      'voltageT': row['voltage_t'],
      'ampereR': row['ampere_r'],
      'ampereS': row['ampere_s'],
      'ampereT': row['ampere_t'],
      'kvar': row['kvar'],
      'hz': row['frequency'],
      'cosPhi': row['cosinus'],
      'tempWindingU': row['temp_winding_u'],
      'tempWindingV': row['temp_winding_v'],
      'tempWindingW': row['temp_winding_w'],
      'tempBearing': row['temp_bearing'],
      'enginePressureCrankcase': row['engine_pressure_crankcase'],
      'engineTempExhaust': row['engine_temp_exhaust'],

      // 🔧 FIX: Add kWh and BBM data mapping for Firestore sync
      'kwhAwal': row['kwh_awal'],
      'kwhAkhir': row['kwh_akhir'],
      'totalKwh': row['total_kwh'],
      'bbmAwal': row['bbm_awal'],
      'bbmAkhir': row['bbm_akhir'],
      'totalBbm': row['total_bbm'],
      'sfc': row['sfc'],

      'savedDate': row['timestamp'],
      'fileId': row['file_id'],
    };
  }

  /// Bersihkanup old data (untuk SyncManager)
  Future<int> cleanupOldData(DateTime cutoffDate) async {
    try {
      final db = await database;

      // Hapus old logsheets
      final deletedLogsheets = await db.delete(
        'logsheets',
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );

      // Hapus old temperature data
      final deletedTemp = await db.delete(
        'temperature_data',
        where: 'date < ?',
        whereArgs: [
          '${cutoffDate.year.toString().padLeft(4, '0')}-${cutoffDate.month.toString().padLeft(2, '0')}-${cutoffDate.day.toString().padLeft(2, '0')}',
        ],
      );

      // Hapus expired cache
      final deletedCache = await db.delete(
        'logsheet_cache',
        where: 'expires_at < ?',
        whereArgs: [DateTime.now().toIso8601String()],
      );

      final totalDeleted = deletedLogsheets + deletedTemp + deletedCache;
      print(
        '🧹 DATABASE: Cleaned up $totalDeleted old records (logsheets: $deletedLogsheets, temp: $deletedTemp, cache: $deletedCache)',
      );

      return totalDeleted;
    } catch (e) {
      print('❌ DATABASE:  cleaning up old data: $e');
      return 0;
    }
  }

  /// Simpan logsheet from Firestore format (untuk restore)
  Future<void> saveLogsheetFromFirestore(
    String generatorName,
    String date,
    Map<String, dynamic> data,
  ) async {
    try {
      // Generate a file_id for Firestore data
      final fileId = 'firestore_${generatorName.replaceAll(' ', '_')}_$date';

      await saveLogsheetToHistory(fileId, generatorName, data);
      print('✅ DATABASE: Restored logsheet for $generatorName on $date');
    } catch (e) {
      print('❌ DATABASE:  saving logsheet from Firestore: $e');
    }
  }
}
