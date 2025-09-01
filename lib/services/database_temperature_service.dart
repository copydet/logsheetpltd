import 'database_service.dart';
import '../models/database/temperature_model.dart';

/// ============================================================================
/// DATABASE TEMPERATURE SERVICE
/// ============================================================================
/// Service untuk manage temperature data menggunakan SQLite database
/// Menggantikan SharedPreferences dengan SQLite untuk better performance
/// ============================================================================

class DatabaseTemperatureService {
  static final DatabaseService _dbService = DatabaseService();

  // ========================================================================
  // TEMPERATURE DATA MANAGEMENT
  // ========================================================================

  /// Save temperature data ke database
  static Future<bool> saveTemperatureData({
    required String fileId,
    required int hour,
    required String date,
    required double waterTemp,
    required double lubeOilTemp,
    required double tempBearing,
    required double tempWindingU,
    required double tempWindingV,
    required double tempWindingW,
    required double engineTempExhaust,
  }) async {
    try {
      final tempData = TemperatureData(
        fileId: fileId,
        hour: hour,
        date: date,
        waterTemp: waterTemp,
        lubeOilTemp: lubeOilTemp,
        tempBearing: tempBearing,
        tempWindingU: tempWindingU,
        tempWindingV: tempWindingV,
        tempWindingW: tempWindingW,
        engineTempExhaust: engineTempExhaust,
      );

      final db = await _dbService.database;

      // Check if data already exists
      final existing = await db.query(
        'temperature_data',
        where: 'file_id = ? AND hour = ? AND date = ?',
        whereArgs: [fileId, hour, date],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Update existing data
        final updated = await db.update(
          'temperature_data',
          tempData.toMap(),
          where: 'file_id = ? AND hour = ? AND date = ?',
          whereArgs: [fileId, hour, date],
        );

        print('✅ TEMP: Temperature data updated for $fileId hour $hour');
        return updated > 0;
      } else {
        // Insert new data
        final id = await db.insert('temperature_data', tempData.toMap());
        print(
          '✅ TEMP: Temperature data saved for $fileId hour $hour with ID: $id',
        );
        return id > 0;
      }
    } catch (e) {
      print('❌ TEMP: Error saving temperature data: $e');
      return false;
    }
  }

  /// Get temperature data by fileId, hour, dan date
  static Future<Map<String, dynamic>?> getTemperatureData(
    String fileId,
    int hour,
    String date,
  ) async {
    try {
      final db = await _dbService.database;
      final result = await db.query(
        'temperature_data',
        where: 'file_id = ? AND hour = ? AND date = ?',
        whereArgs: [fileId, hour, date],
        limit: 1,
      );

      if (result.isEmpty) return null;

      final tempData = TemperatureData.fromMap(result.first);
      return {
        'fileId': tempData.fileId,
        'hour': tempData.hour,
        'date': tempData.date,
        'waterTemp': tempData.waterTemp,
        'lubeOilTemp': tempData.lubeOilTemp,
        'tempBearing': tempData.tempBearing,
        'tempWindingU': tempData.tempWindingU,
        'tempWindingV': tempData.tempWindingV,
        'tempWindingW': tempData.tempWindingW,
        'engineTempExhaust': tempData.engineTempExhaust,
      };
    } catch (e) {
      print('❌ TEMP: Error getting temperature data: $e');
      return null;
    }
  }

  /// Get all temperature data untuk fileId tertentu
  static Future<List<Map<String, dynamic>>> getTemperatureDataByFileId(
    String fileId,
  ) async {
    try {
      final db = await _dbService.database;
      final result = await db.query(
        'temperature_data',
        where: 'file_id = ?',
        whereArgs: [fileId],
        orderBy: 'hour ASC',
      );

      return result.map((row) {
        final tempData = TemperatureData.fromMap(row);
        return {
          'fileId': tempData.fileId,
          'hour': tempData.hour,
          'date': tempData.date,
          'waterTemp': tempData.waterTemp,
          'lubeOilTemp': tempData.lubeOilTemp,
          'tempBearing': tempData.tempBearing,
          'tempWindingU': tempData.tempWindingU,
          'tempWindingV': tempData.tempWindingV,
          'tempWindingW': tempData.tempWindingW,
          'engineTempExhaust': tempData.engineTempExhaust,
        };
      }).toList();
    } catch (e) {
      print('❌ TEMP: Error getting temperature data by fileId: $e');
      return [];
    }
  }

  /// Get temperature data by date range
  static Future<List<Map<String, dynamic>>> getTemperatureDataByDateRange(
    String startDate,
    String endDate,
  ) async {
    try {
      final db = await _dbService.database;
      final result = await db.query(
        'temperature_data',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startDate, endDate],
        orderBy: 'date ASC, hour ASC',
      );

      return result.map((row) {
        final tempData = TemperatureData.fromMap(row);
        return {
          'fileId': tempData.fileId,
          'hour': tempData.hour,
          'date': tempData.date,
          'waterTemp': tempData.waterTemp,
          'lubeOilTemp': tempData.lubeOilTemp,
          'tempBearing': tempData.tempBearing,
          'tempWindingU': tempData.tempWindingU,
          'tempWindingV': tempData.tempWindingV,
          'tempWindingW': tempData.tempWindingW,
          'engineTempExhaust': tempData.engineTempExhaust,
        };
      }).toList();
    } catch (e) {
      print('❌ TEMP: Error getting temperature data by date range: $e');
      return [];
    }
  }

  /// Get temperature data by generator name untuk semua logsheet files
  /// Method ini mengambil data dari semua file_id yang terkait dengan generator tertentu
  static Future<List<Map<String, dynamic>>> getTemperatureDataByGeneratorName(
    String generatorName, {
    int? limitDays,
  }) async {
    try {
      final db = await _dbService.database;

      // Build query untuk mencari temperature data berdasarkan generator name
      // Menggunakan JOIN dengan logsheets table untuk mendapatkan semua file_id
      String query = '''
        SELECT DISTINCT 
          t.file_id,
          t.hour,
          t.date,
          t.water_temp,
          t.lube_oil_temp,
          t.temp_bearing,
          t.temp_winding_u,
          t.temp_winding_v,
          t.temp_winding_w,
          t.engine_temp_exhaust
        FROM temperature_data t
        INNER JOIN logsheets l ON t.file_id = l.file_id
        WHERE l.generator_name = ?
      ''';

      List<dynamic> whereArgs = [generatorName];

      // Add date filter if limitDays is specified
      if (limitDays != null) {
        final cutoffDate = DateTime.now().subtract(Duration(days: limitDays));
        final dateStr =
            '${cutoffDate.year}${cutoffDate.month.toString().padLeft(2, '0')}${cutoffDate.day.toString().padLeft(2, '0')}';
        query += ' AND t.date >= ?';
        whereArgs.add(dateStr);
      }

      query += ' ORDER BY t.date DESC, t.hour DESC';

      print('🔍 TEMP: Querying temperature data for generator: $generatorName');
      if (limitDays != null) {
        print('🔍 TEMP: Limited to last $limitDays days');
      }

      final result = await db.rawQuery(query, whereArgs);

      print(
        '📊 TEMP: Found ${result.length} temperature records for $generatorName',
      );

      return result.map((row) {
        return {
          'fileId': row['file_id'] as String,
          'hour': row['hour'] as int,
          'date': row['date'] as String,
          'waterTemp': (row['water_temp'] as num).toDouble(),
          'lubeOilTemp': (row['lube_oil_temp'] as num).toDouble(),
          'tempBearing': (row['temp_bearing'] as num).toDouble(),
          'tempWindingU': (row['temp_winding_u'] as num).toDouble(),
          'tempWindingV': (row['temp_winding_v'] as num).toDouble(),
          'tempWindingW': (row['temp_winding_w'] as num).toDouble(),
          'engineTempExhaust': (row['engine_temp_exhaust'] as num).toDouble(),
        };
      }).toList();
    } catch (e) {
      print('❌ TEMP: Error getting temperature data by generator name: $e');
      return [];
    }
  }

  /// Check if temperature data exists
  static Future<bool> hasTemperatureData(
    String fileId,
    int hour,
    String date,
  ) async {
    try {
      final db = await _dbService.database;
      final result = await db.query(
        'temperature_data',
        where: 'file_id = ? AND hour = ? AND date = ?',
        whereArgs: [fileId, hour, date],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      print('❌ TEMP: Error checking temperature data existence: $e');
      return false;
    }
  }

  /// Delete temperature data
  static Future<bool> deleteTemperatureData(
    String fileId,
    int hour,
    String date,
  ) async {
    try {
      final db = await _dbService.database;
      final deleted = await db.delete(
        'temperature_data',
        where: 'file_id = ? AND hour = ? AND date = ?',
        whereArgs: [fileId, hour, date],
      );

      if (deleted > 0) {
        print('✅ TEMP: Temperature data deleted for $fileId hour $hour');
        return true;
      } else {
        print('❌ TEMP: No temperature data found to delete');
        return false;
      }
    } catch (e) {
      print('❌ TEMP: Error deleting temperature data: $e');
      return false;
    }
  }

  /// Delete all temperature data untuk fileId tertentu
  static Future<bool> deleteAllTemperatureDataByFileId(String fileId) async {
    try {
      final db = await _dbService.database;
      final deleted = await db.delete(
        'temperature_data',
        where: 'file_id = ?',
        whereArgs: [fileId],
      );

      print('✅ TEMP: Deleted $deleted temperature data records for $fileId');
      return true;
    } catch (e) {
      print('❌ TEMP: Error deleting temperature data by fileId: $e');
      return false;
    }
  }

  // ========================================================================
  // CHART DATA METHODS
  // ========================================================================

  /// Get chart data untuk fileId tertentu (untuk grafik)
  static Future<Map<String, List<Map<String, dynamic>>>> getChartData(
    String fileId,
  ) async {
    try {
      final temperatureData = await getTemperatureDataByFileId(fileId);

      final chartData = <String, List<Map<String, dynamic>>>{};

      // Initialize lists for each temperature type
      chartData['waterTemp'] = [];
      chartData['lubeOilTemp'] = [];
      chartData['tempBearing'] = [];
      chartData['tempWindingU'] = [];
      chartData['tempWindingV'] = [];
      chartData['tempWindingW'] = [];
      chartData['engineTempExhaust'] = [];

      for (final data in temperatureData) {
        final hour = data['hour'] as int;

        chartData['waterTemp']!.add({'x': hour, 'y': data['waterTemp']});
        chartData['lubeOilTemp']!.add({'x': hour, 'y': data['lubeOilTemp']});
        chartData['tempBearing']!.add({'x': hour, 'y': data['tempBearing']});
        chartData['tempWindingU']!.add({'x': hour, 'y': data['tempWindingU']});
        chartData['tempWindingV']!.add({'x': hour, 'y': data['tempWindingV']});
        chartData['tempWindingW']!.add({'x': hour, 'y': data['tempWindingW']});
        chartData['engineTempExhaust']!.add({
          'x': hour,
          'y': data['engineTempExhaust'],
        });
      }

      return chartData;
    } catch (e) {
      print('❌ TEMP: Error getting chart data: $e');
      return {};
    }
  }

  /// Get hourly temperature averages untuk date range
  static Future<Map<int, Map<String, double>>> getHourlyAverages(
    String startDate,
    String endDate,
  ) async {
    try {
      final db = await _dbService.database;
      final result = await db.rawQuery(
        '''
        SELECT 
          hour,
          AVG(water_temp) as avg_water_temp,
          AVG(lube_oil_temp) as avg_lube_oil_temp,
          AVG(temp_bearing) as avg_temp_bearing,
          AVG(temp_winding_u) as avg_temp_winding_u,
          AVG(temp_winding_v) as avg_temp_winding_v,
          AVG(temp_winding_w) as avg_temp_winding_w,
          AVG(engine_temp_exhaust) as avg_engine_temp_exhaust
        FROM temperature_data
        WHERE date >= ? AND date <= ?
        GROUP BY hour
        ORDER BY hour ASC
      ''',
        [startDate, endDate],
      );

      final averages = <int, Map<String, double>>{};

      for (final row in result) {
        final hour = row['hour'] as int;
        averages[hour] = {
          'waterTemp': (row['avg_water_temp'] as num?)?.toDouble() ?? 0.0,
          'lubeOilTemp': (row['avg_lube_oil_temp'] as num?)?.toDouble() ?? 0.0,
          'tempBearing': (row['avg_temp_bearing'] as num?)?.toDouble() ?? 0.0,
          'tempWindingU':
              (row['avg_temp_winding_u'] as num?)?.toDouble() ?? 0.0,
          'tempWindingV':
              (row['avg_temp_winding_v'] as num?)?.toDouble() ?? 0.0,
          'tempWindingW':
              (row['avg_temp_winding_w'] as num?)?.toDouble() ?? 0.0,
          'engineTempExhaust':
              (row['avg_engine_temp_exhaust'] as num?)?.toDouble() ?? 0.0,
        };
      }

      return averages;
    } catch (e) {
      print('❌ TEMP: Error getting hourly averages: $e');
      return {};
    }
  }

  // ========================================================================
  // STATISTICS METHODS
  // ========================================================================

  /// Get temperature statistics
  static Future<Map<String, dynamic>> getTemperatureStats() async {
    try {
      final db = await _dbService.database;

      final totalRecordsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM temperature_data',
      );
      final uniqueFilesResult = await db.rawQuery(
        'SELECT COUNT(DISTINCT file_id) as count FROM temperature_data',
      );
      final uniqueDatesResult = await db.rawQuery(
        'SELECT COUNT(DISTINCT date) as count FROM temperature_data',
      );

      // Get temperature ranges
      final rangeResult = await db.rawQuery('''
        SELECT 
          MIN(water_temp) as min_water_temp, MAX(water_temp) as max_water_temp,
          MIN(lube_oil_temp) as min_lube_oil_temp, MAX(lube_oil_temp) as max_lube_oil_temp,
          MIN(temp_bearing) as min_temp_bearing, MAX(temp_bearing) as max_temp_bearing,
          MIN(temp_winding_u) as min_temp_winding_u, MAX(temp_winding_u) as max_temp_winding_u,
          MIN(temp_winding_v) as min_temp_winding_v, MAX(temp_winding_v) as max_temp_winding_v,
          MIN(temp_winding_w) as min_temp_winding_w, MAX(temp_winding_w) as max_temp_winding_w,
          MIN(engine_temp_exhaust) as min_engine_temp_exhaust, MAX(engine_temp_exhaust) as max_engine_temp_exhaust
        FROM temperature_data
      ''');

      final ranges = rangeResult.isNotEmpty
          ? rangeResult.first
          : <String, dynamic>{};

      return {
        'totalRecords': totalRecordsResult.first['count'] as int,
        'uniqueFiles': uniqueFilesResult.first['count'] as int,
        'uniqueDates': uniqueDatesResult.first['count'] as int,
        'temperatureRanges': {
          'waterTemp': {
            'min': (ranges['min_water_temp'] as num?)?.toDouble() ?? 0.0,
            'max': (ranges['max_water_temp'] as num?)?.toDouble() ?? 0.0,
          },
          'lubeOilTemp': {
            'min': (ranges['min_lube_oil_temp'] as num?)?.toDouble() ?? 0.0,
            'max': (ranges['max_lube_oil_temp'] as num?)?.toDouble() ?? 0.0,
          },
          'tempBearing': {
            'min': (ranges['min_temp_bearing'] as num?)?.toDouble() ?? 0.0,
            'max': (ranges['max_temp_bearing'] as num?)?.toDouble() ?? 0.0,
          },
          'tempWindingU': {
            'min': (ranges['min_temp_winding_u'] as num?)?.toDouble() ?? 0.0,
            'max': (ranges['max_temp_winding_u'] as num?)?.toDouble() ?? 0.0,
          },
          'tempWindingV': {
            'min': (ranges['min_temp_winding_v'] as num?)?.toDouble() ?? 0.0,
            'max': (ranges['max_temp_winding_v'] as num?)?.toDouble() ?? 0.0,
          },
          'tempWindingW': {
            'min': (ranges['min_temp_winding_w'] as num?)?.toDouble() ?? 0.0,
            'max': (ranges['max_temp_winding_w'] as num?)?.toDouble() ?? 0.0,
          },
          'engineTempExhaust': {
            'min':
                (ranges['min_engine_temp_exhaust'] as num?)?.toDouble() ?? 0.0,
            'max':
                (ranges['max_engine_temp_exhaust'] as num?)?.toDouble() ?? 0.0,
          },
        },
      };
    } catch (e) {
      print('❌ TEMP: Error getting temperature stats: $e');
      return {
        'totalRecords': 0,
        'uniqueFiles': 0,
        'uniqueDates': 0,
        'temperatureRanges': {},
      };
    }
  }

  // ========================================================================
  // UTILITY METHODS
  // ========================================================================

  /// Clear all temperature data (untuk testing)
  static Future<bool> clearAllTemperatureData() async {
    try {
      final db = await _dbService.database;
      await db.delete('temperature_data');

      print('✅ TEMP: All temperature data cleared');
      return true;
    } catch (e) {
      print('❌ TEMP: Error clearing temperature data: $e');
      return false;
    }
  }

  /// Get data storage size estimate
  static Future<Map<String, int>> getStorageInfo() async {
    try {
      final stats = await getTemperatureStats();
      final totalRecords = stats['totalRecords'] as int;

      // Estimate: Each record ≈ 100 bytes (rough calculation)
      final estimatedBytes = totalRecords * 100;

      return {
        'totalRecords': totalRecords,
        'estimatedBytes': estimatedBytes,
        'estimatedKB': (estimatedBytes / 1024).round(),
        'estimatedMB': (estimatedBytes / (1024 * 1024)).round(),
      };
    } catch (e) {
      print('❌ TEMP: Error getting storage info: $e');
      return {
        'totalRecords': 0,
        'estimatedBytes': 0,
        'estimatedKB': 0,
        'estimatedMB': 0,
      };
    }
  }
}
