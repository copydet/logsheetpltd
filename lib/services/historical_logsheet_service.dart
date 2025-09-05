import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_drive_service.dart';
import 'rest_api_service.dart';
import 'spreadsheet_service.dart';
import 'database_service.dart';
import 'firestore_historical_service.dart' as fhs;

class HistoricalLogsheetService {
  static const String _historyPrefix = 'logsheet_history_';
  static const String _fileIdPrefix = 'file_id_history_';

  /// Simpan data logsheet ke riwayat lokal
  static Future<void> saveToHistory(
    String generatorName,
    Map<String, dynamic> logsheetData,
    String fileId,
  ) async {
    try {
      final now = DateTime.now();

      // Tambahkan metadata waktu
      final dataWithMetadata = {
        ...logsheetData,
        'savedDate': now.toIso8601String(),
        'generatorName': generatorName,
        'fileId': fileId,
      };

      // PRIORITAS 1: Simpan ke SQLite database
      try {
        final dbService = DatabaseService();
        await dbService.saveLogsheetToHistory(
          fileId,
          generatorName,
          dataWithMetadata,
        );
        print('💾 Saved to SQLite: $generatorName');
      } catch (e) {
        print('❌  saving to SQLite: $e');
      }

      // PRIORITAS 2: Backup ke SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final dateKey = _formatDateKey(now);
        final historyKey = '$_historyPrefix${generatorName}_$dateKey';
        final fileIdKey = '$_fileIdPrefix${generatorName}_$dateKey';

        await prefs.setString(historyKey, json.encode(dataWithMetadata));
        await prefs.setString(fileIdKey, fileId);
        print('💾 Backup saved to SharedPreferences: $historyKey');
      } catch (e) {
        print('❌  saving to SharedPreferences: $e');
      }
    } catch (e) {
      print('❌  saving to history: $e');
    }
  }

  /// Cek apakah ada data untuk hari ini (berguna untuk troubleshooting)
  static Future<Map<String, dynamic>> checkTodayData(
    String generatorName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final dateKey = _formatDateKey(today);

      // Cek data lokal untuk hari ini
      final historyKey = '$_historyPrefix${generatorName}_$dateKey';
      final fileIdKey = '$_fileIdPrefix${generatorName}_$dateKey';

      final localData = prefs.getString(historyKey);
      final fileId = prefs.getString(fileIdKey);

      print('🔍  today data for $generatorName:');
      print('   Date key: $dateKey');
      print('   Local data exists: ${localData != null}');
      print('   File ID exists: ${fileId != null}');

      if (localData != null) {
        final parsed = json.decode(localData);
        print('   Local data preview: ${parsed['tanggal']} ${parsed['jam']}');
      }

      // Cek juga di Google Drive
      final driveFileId = await GoogleDriveService.findFileByDate(
        generatorName,
        today,
      );
      print(
        '   Google Drive file: ${driveFileId != null ? driveFileId : "Not found"}',
      );

      return {
        'hasLocalData': localData != null,
        'hasFileId': fileId != null,
        'hasDriveFile': driveFileId != null,
        'localData': localData,
        'fileId': fileId,
        'driveFileId': driveFileId,
      };
    } catch (e) {
      print('Error  today data: $e');
      return {
        'hasLocalData': false,
        'hasFileId': false,
        'hasDriveFile': false,
        'error': e.toString(),
      };
    }
  }

  /// Ambil data riwayat REAL dari Multi-Source (Firestore + Google Drive + lokal)
  static Future<List<Map<String, dynamic>>> getHistoricalData(
    String generatorName, {
    int daysBack = 7,
  }) async {
    try {
      print(
        '=== Getting historical data for $generatorName (${daysBack} days) ===',
      );

      // PRIORITAS 1: Ambil data dari Firestore (real-time, multi-user)
      print('Step 1: Fetching data from Firestore (real-time, multi-user)...');
      final firestoreData =
          await fhs.FirestoreHistoricalService.getDailySummary(
            generatorName,
            daysBack: daysBack,
          );

      print('✓ Firestore data: ${firestoreData.length} daily summaries');

      // PRIORITAS 2: Ambil data real dari Google Drive
      print('Step 2: Fetching real data from Google Drive...');
      final realData = await GoogleDriveService.getRealHistoricalData(
        generatorName,
        daysBack: daysBack,
      );

      print('✓ Real data from Google Drive: ${realData.length} entries');

      // PRIORITAS 3: Ambil data lokal sebagai backup
      print('Step 3: Fetching local backup data...');
      final localData = await _getLocalHistoricalData(
        generatorName,
        daysBack: daysBack,
      );

      print('✓ Local backup data: ${localData.length} entries');

      // Gabungkan data dengan prioritas: Firestore > Google Drive > Local
      final allData = <Map<String, dynamic>>[];

      // PRIORITAS TINGGI: Jika ada data Firestore (real-time, multi-user), gunakan itu
      if (firestoreData.isNotEmpty) {
        print(
          'Step 4: Using Firestore data as primary source (real-time, multi-user)',
        );
        // Konversi daily summary Firestore ke format yang konsisten
        for (final summary in firestoreData) {
          if (summary['hasData'] == true) {
            final rawData =
                summary['rawData'] as List<Map<String, dynamic>>? ?? [];
            allData.addAll(rawData);
          }
        }
        print('✓ Added ${allData.length} entries from Firestore');
      } else {
        // FALLBACK: Gunakan Google Drive + Local data
        print(
          'Step 4: Firestore empty, using Google Drive + Local as fallback',
        );

        // Tambahkan data Google Drive terlebih dahulu
        allData.addAll(realData);

        // Tambahkan data lokal yang tidak ada di data Google Drive
        int localAddedCount = 0;
        for (final localEntry in localData) {
          final localDate = DateTime.tryParse(localEntry['savedDate'] ?? '');
          if (localDate != null) {
            // Cek apakah sudah ada data real untuk tanggal ini
            final hasRealData = realData.any((realEntry) {
              final realDate = DateTime.tryParse(
                realEntry['fileDate'] ?? realEntry['savedDate'] ?? '',
              );
              return realDate != null && _isSameDay(localDate, realDate);
            });

            // Jika belum ada data real, tambahkan data lokal
            if (!hasRealData) {
              localEntry['isRealData'] = false;
              localEntry['source'] = 'local_storage';
              allData.add(localEntry);
              localAddedCount++;
            }
          }
        }

        print(
          '✓ Added ${realData.length} Google Drive + $localAddedCount local = ${allData.length} total',
        );
      }

      // Urutkan berdasarkan waktu (terbaru dulu)
      allData.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['fileDate'] ?? a['savedDate'] ?? '') ??
            DateTime(2000);
        final dateB =
            DateTime.tryParse(b['fileDate'] ?? b['savedDate'] ?? '') ??
            DateTime(2000);
        return dateB.compareTo(dateA);
      });

      print(
        '✓ Historical data retrieved successfully: ${allData.length} entries',
      );
      return allData;
    } catch (e) {
      print(' getting historical data: $e');
      // Fallback ke data lokal jika ada error
      return await _getLocalHistoricalData(generatorName, daysBack: daysBack);
    }
  }

  /// Ambil data lokal sebagai backup (SQLite + SharedPreferences fallback)
  static Future<List<Map<String, dynamic>>> _getLocalHistoricalData(
    String generatorName, {
    int daysBack = 7,
  }) async {
    try {
      print('📱 Getting local historical data for $generatorName...');
      List<Map<String, dynamic>> historicalData = [];

      // PRIORITAS 1: Ambil data dari SQLite database
      final sqliteData = await _getSQLiteHistoricalData(
        generatorName,
        daysBack: daysBack,
      );
      historicalData.addAll(sqliteData);
      print('✓ SQLite data: ${sqliteData.length} entries');

      // PRIORITAS 2: Fallback ke SharedPreferences untuk data lama
      if (historicalData.isEmpty) {
        print('📦 SQLite empty, trying SharedPreferences fallback...');
        final sharedPrefsData = await _getSharedPreferencesHistoricalData(
          generatorName,
          daysBack: daysBack,
        );
        historicalData.addAll(sharedPrefsData);
        print('✓ SharedPreferences data: ${sharedPrefsData.length} entries');
      }

      // Urutkan berdasarkan waktu (terbaru dulu)
      historicalData.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['savedDate'] ?? a['timestamp'] ?? '') ??
            DateTime(2000);
        final dateB =
            DateTime.tryParse(b['savedDate'] ?? b['timestamp'] ?? '') ??
            DateTime(2000);
        return dateB.compareTo(dateA);
      });

      print('✅ Total local historical data: ${historicalData.length} entries');
      return historicalData;
    } catch (e) {
      print('❌  getting local historical data: $e');
      return [];
    }
  }

  /// Ambil data historis dari SQLite database
  static Future<List<Map<String, dynamic>>> _getSQLiteHistoricalData(
    String generatorName, {
    int daysBack = 7,
  }) async {
    try {
      final dbService = DatabaseService();

      // DEBUG: Check total records and counts by generator
      await dbService.getTotalLogsheetCount();
      await dbService.getLogsheetCountByGenerator();

      final results = await dbService.getLogsheetHistory(
        generatorName,
        daysBack: daysBack,
      );

      print(
        '🗄️ SQLite query returned ${results.length} logsheet records for $generatorName',
      );

      // Ubah data from SQLite format to historical format
      final List<Map<String, dynamic>> historicalData = [];

      for (final record in results) {
        // Ubah SQLite record to historical format
        final historicalRecord = {
          'savedDate': record['timestamp'],
          'generatorName': record['generator_name'],
          'fileId': record['file_id'] ?? '',
          'fileDate': record['date'],
          'source': 'sqlite_database',
          'isRealData': false,

          // Engine data
          'rpm': record['rpm'],
          'jamOperasi': record['jam_operasi'],
          'lubeOilTemp': record['lube_oil_temp'],
          'oilPressure': record['oil_pressure'],
          'waterTemp': record['water_temp'],
          'teganganAccu': record['tegangan_accu'],
          'beban': record['beban'],

          // Electrical data
          'voltageR': record['voltage_r'],
          'voltageS': record['voltage_s'],
          'voltageT': record['voltage_t'],
          'ampereR': record['ampere_r'],
          'ampereS': record['ampere_s'],
          'ampereT': record['ampere_t'],
          'hz': record['frequency'],
          'cosPhi': record['cosinus'],
          'kvar': record['kvar'],

          // Temperature data
          'tempWindingU': record['temp_winding_u'],
          'tempWindingV': record['temp_winding_v'],
          'tempWindingW': record['temp_winding_w'],
          'tempBearing': record['temp_bearing'],
          'enginePressureCrankcase': record['engine_pressure_crankcase'],
          'engineTempExhaust': record['engine_temp_exhaust'],

          // Energy/Fuel data - ADD THESE FIELDS
          'kwhAwal': record['kwh_awal'],
          'kwhAkhir': record['kwh_akhir'],
          'totalKwh': record['total_kwh'],
          'bbmAwal': record['bbm_awal'],
          'bbmAkhir': record['bbm_akhir'],
          'totalBbm': record['total_bbm'],
          'sfc': record['sfc'],
        };

        historicalData.add(historicalRecord);
      }

      return historicalData;
    } catch (e) {
      print('❌  getting SQLite historical data: $e');
      return [];
    }
  }

  /// Ambil data historis dari SharedPreferences (fallback)
  static Future<List<Map<String, dynamic>>> _getSharedPreferencesHistoricalData(
    String generatorName, {
    int daysBack = 7,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      List<Map<String, dynamic>> historicalData = [];

      // Loop untuk mengambil data dari beberapa hari ke belakang
      for (int i = 0; i < daysBack; i++) {
        final targetDate = now.subtract(Duration(days: i));
        final dateKey = _formatDateKey(targetDate);

        // Coba ambil data lokal dari SharedPreferences
        final localData = await _getLocalDataForDate(
          prefs,
          generatorName,
          dateKey,
        );
        if (localData.isNotEmpty) {
          historicalData.addAll(localData);
        }

        // Coba ambil data dari Google Sheets jika ada file ID
        final fileIdKey = '$_fileIdPrefix${generatorName}_$dateKey';
        final fileId = prefs.getString(fileIdKey);
        if (fileId != null && fileId.isNotEmpty) {
          final sheetData = await _getSheetDataForDate(fileId, targetDate);
          if (sheetData.isNotEmpty) {
            historicalData.addAll(sheetData);
          }
        }
      }

      return historicalData;
    } catch (e) {
      print('❌  getting SharedPreferences historical data: $e');
      return [];
    }
  }

  /// Ambil data lokal untuk tanggal tertentu
  static Future<List<Map<String, dynamic>>> _getLocalDataForDate(
    SharedPreferences prefs,
    String generatorName,
    String dateKey,
  ) async {
    try {
      final historyKey = '$_historyPrefix${generatorName}_$dateKey';
      final dataString = prefs.getString(historyKey);

      if (dataString != null) {
        final data = json.decode(dataString) as Map<String, dynamic>;
        return [data];
      }
    } catch (e) {
      print(' getting local data for $dateKey: $e');
    }
    return [];
  }

  /// Ambil data untuk tanggal tertentu (prioritas SQLite → Google Drive → SharedPreferences)
  static Future<List<Map<String, dynamic>>> getDataForDate(
    String generatorName,
    DateTime targetDate,
  ) async {
    try {
      print(
        '🔍 Getting data for $generatorName on ${targetDate.toString().substring(0, 10)}',
      );

      // PRIORITAS 1: Coba ambil dari SQLite
      final dbService = DatabaseService();
      final sqliteData = await dbService.getLogsheetByDate(
        generatorName,
        targetDate,
      );

      if (sqliteData.isNotEmpty) {
        print('✅ Found ${sqliteData.length} records from SQLite');

        // Ubah SQLite format to standard format
        final convertedData = sqliteData
            .map(
              (record) => {
                'savedDate': record['timestamp'],
                'generatorName': record['generator_name'],
                'fileId': record['file_id'] ?? '',
                'hour': record['hour'],
                'source': 'sqlite_database',

                // Engine data
                'rpm': record['rpm'],
                'jamOperasi': record['jam_operasi'],
                'lubeOilTemp': record['lube_oil_temp'],
                'oilPressure': record['oil_pressure'],
                'waterTemp': record['water_temp'],
                'teganganAccu': record['tegangan_accu'],
                'beban': record['beban'],

                // Electrical data
                'voltageR': record['voltage_r'],
                'voltageS': record['voltage_s'],
                'voltageT': record['voltage_t'],
                'ampereR': record['ampere_r'],
                'ampereS': record['ampere_s'],
                'ampereT': record['ampere_t'],
                'hz': record['frequency'],
                'cosPhi': record['cosinus'],
                'kvar': record['kvar'],

                // Temperature data
                'tempWindingU': record['temp_winding_u'],
                'tempWindingV': record['temp_winding_v'],
                'tempWindingW': record['temp_winding_w'],
                'tempBearing': record['temp_bearing'],
                'enginePressureCrankcase': record['engine_pressure_crankcase'],
                'engineTempExhaust': record['engine_temp_exhaust'],
              },
            )
            .toList();

        return convertedData;
      }

      // PRIORITAS 2: Coba ambil dari Google Drive
      print('📡 No SQLite data, trying Google Drive...');
      try {
        final fileId = await GoogleDriveService.findFileByDate(
          generatorName,
          targetDate,
        );

        if (fileId != null) {
          final sheetData = await SpreadsheetService.readSpreadsheetData(
            fileId,
          );
          final mapData = SpreadsheetService.convertToMap(sheetData);

          if (mapData.isNotEmpty) {
            print('✅ Found ${mapData.length} records from Google Drive');

            // Filter data untuk tanggal yang diminta
            final filteredData = mapData.where((data) {
              final savedDate = DateTime.tryParse(data['savedDate'] ?? '');
              if (savedDate != null) {
                return _isSameDay(savedDate, targetDate);
              }
              return false;
            }).toList();

            // Mark as Google Drive source
            for (final data in filteredData) {
              data['source'] = 'google_drive';
            }

            return filteredData;
          }
        }
      } catch (e) {
        print('❌  getting Google Drive data: $e');
      }

      // PRIORITAS 3: Fallback ke SharedPreferences
      print('📱 No Google Drive data, trying SharedPreferences...');
      final dateKey = _formatDateKey(targetDate);
      final prefs = await SharedPreferences.getInstance();
      final historyKey = '$_historyPrefix${generatorName}_$dateKey';
      final dataString = prefs.getString(historyKey);

      if (dataString != null) {
        print('✅ Found data in SharedPreferences');
        final data = json.decode(dataString) as Map<String, dynamic>;
        data['source'] = 'shared_preferences';
        return [data];
      }

      print('❌ No data found for the specified date');
      return [];
    } catch (e) {
      print('❌  getting data for date: $e');
      return [];
    }
  }

  /// Ambil data dari Google Sheets untuk tanggal tertentu
  static Future<List<Map<String, dynamic>>> _getSheetDataForDate(
    String fileId,
    DateTime targetDate,
  ) async {
    try {
      // Ambil data dari spreadsheet
      final sheetData = await SpreadsheetService.readSpreadsheetData(fileId);
      final mapData = SpreadsheetService.convertToMap(sheetData);

      // Filter data untuk tanggal target
      final filteredData = mapData.where((data) {
        final savedDate = DateTime.tryParse(data['savedDate'] ?? '');
        if (savedDate != null) {
          return _isSameDay(savedDate, targetDate);
        }
        return false;
      }).toList();

      return filteredData;
    } catch (e) {
      print(' getting sheet data for ${targetDate.toIso8601String()}: $e');
      return [];
    }
  }

  /// Dapatkan ringkasan data untuk setiap hari dengan data REAL
  static Future<List<Map<String, dynamic>>> getDailySummary(
    String generatorName, {
    int daysBack = 7,
  }) async {
    try {
      final historicalData = await getHistoricalData(
        generatorName,
        daysBack: daysBack,
      );
      final Map<String, List<Map<String, dynamic>>> groupedByDate = {};

      // Kelompokkan data berdasarkan tanggal
      for (final data in historicalData) {
        final savedDate = DateTime.tryParse(
          data['fileDate'] ?? data['savedDate'] ?? '',
        );
        if (savedDate != null) {
          final dateKey = _formatDateKey(savedDate);
          groupedByDate[dateKey] ??= [];
          groupedByDate[dateKey]!.add(data);
        }
      }

      // Buat ringkasan untuk setiap hari
      final summaries = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (int i = 0; i < daysBack; i++) {
        final targetDate = now.subtract(Duration(days: i));
        final dateKey = _formatDateKey(targetDate);
        final dayData = groupedByDate[dateKey] ?? [];

        final summary = _createDailySummary(targetDate, dayData);
        summaries.add(summary);
      }

      return summaries;
    } catch (e) {
      print(' getting daily summary: $e');
      return [];
    }
  }

  /// Buat ringkasan harian
  static Map<String, dynamic> _createDailySummary(
    DateTime date,
    List<Map<String, dynamic>> dayData,
  ) {
    print(
      '🔍 _createDailySummary: Processing ${dayData.length} records for ${_formatDateDisplay(date)}',
    );

    if (dayData.isEmpty) {
      return {
        'date': date.toIso8601String(),
        'dateFormatted': _formatDateDisplay(date),
        'entryCount': 0,
        'hasData': false,
        'totalKwh': 0.0,
        'totalBbm': 0.0,
        'averageSfc': 0.0,
        'isRealData': false,
        'fileId': null, // Tidak ada data, jadi tidak ada fileId
      };
    }

    // Hitung Total KwH, Total BBM, dan Average SFC
    double totalKwh = 0.0;
    double totalBbm = 0.0;
    double totalSfc = 0.0;
    int validSfcCount = 0;
    bool hasRealData = false;
    String? fileId; // Ambil fileId untuk download

    for (final data in dayData) {
      print(
        '🔍 Processing record: ${data['generatorName']} - ${data['tanggal'] ?? data['fileDate']}',
      );

      // Cek apakah ini data real dari Google Drive
      if (data['fileDate'] != null) {
        hasRealData = true;
        // Ambil fileId dari data real pertama yang ditemukan
        if (fileId == null && data['fileId'] != null) {
          fileId = data['fileId'].toString();
        }
      }

      // Prioritas tinggi: Cek apakah ada fileId yang BUKAN dari Firestore
      // untuk memastikan download bisa bekerja dengan Google Drive fileId asli
      final currentFileId = data['fileId']?.toString() ?? '';
      if (currentFileId.isNotEmpty && !currentFileId.startsWith('firestore_')) {
        // Ini adalah Google Drive fileId asli, prioritaskan untuk download
        if (fileId == null || fileId.startsWith('firestore_')) {
          fileId = currentFileId;
          hasRealData =
              true; // Mark sebagai real data karena ada Google Drive fileId
        }
      }

      // Total KwH - akumulasi nilai terbesar dalam hari (nilai kumulatif terakhir)
      String? kwhStr =
          data['totalKwh']?.toString() ?? data['kwhTotal']?.toString() ?? '0';
      final totalKwhValue = double.tryParse(kwhStr.replaceAll(',', '.'));
      if (totalKwhValue != null && totalKwhValue > 0) {
        // Filter data yang tidak realistis (>500 kWh per hari untuk 1 generator)
        if (totalKwhValue <= 500.0) {
          // Ambil nilai terbesar karena totalKwh adalah kumulatif harian
          if (totalKwhValue > totalKwh) {
            totalKwh = totalKwhValue;
          }
          print(
            '✅ Found valid totalKwh: $totalKwhValue (current max: $totalKwh)',
          );
        } else {
          print(
            '⚠️ Skipping unrealistic totalKwh: $totalKwhValue (too high, likely test data)',
          );
        }
      }

      // Total BBM - akumulasi nilai terbesar dalam hari (nilai kumulatif terakhir)
      String? bbmStr =
          data['totalBbm']?.toString() ?? data['bbmTotal']?.toString() ?? '0';
      final totalBbmValue = double.tryParse(bbmStr.replaceAll(',', '.'));
      if (totalBbmValue != null && totalBbmValue > 0) {
        // Filter data yang tidak realistis (>1000L per hari untuk 1 generator)
        if (totalBbmValue <= 1000.0) {
          // Ambil nilai terbesar karena totalBbm adalah kumulatif harian
          if (totalBbmValue > totalBbm) {
            totalBbm = totalBbmValue;
          }
          print(
            '✅ Found valid totalBbm: $totalBbmValue (current max: $totalBbm)',
          );
        } else {
          print(
            '⚠️ Skipping unrealistic totalBbm: $totalBbmValue (too high, likely test data)',
          );
        }
      }

      // SFC - dari field sfc dengan validasi realistis
      String? sfcStr = data['sfc']?.toString() ?? '0';
      final sfcValue = double.tryParse(sfcStr.replaceAll(',', '.'));
      if (sfcValue != null && sfcValue > 0) {
        // Filter SFC yang tidak realistis (>10000 g/kWh)
        if (sfcValue <= 10000.0) {
          totalSfc += sfcValue;
          validSfcCount++;
          print('✅ Found valid SFC: $sfcValue');
        } else {
          print(
            '⚠️ Skipping unrealistic SFC: $sfcValue (too high, likely test data)',
          );
        }
      }
    }

    final summary = {
      'date': date.toIso8601String(),
      'dateFormatted': _formatDateDisplay(date),
      'entryCount': dayData.length,
      'hasData': true,
      'totalKwh': totalKwh,
      'totalBbm': totalBbm,
      'averageSfc': validSfcCount > 0 ? totalSfc / validSfcCount : 0.0,
      'rawData': dayData,
      'isRealData': hasRealData,
      'fileId': fileId, // Tambahkan fileId untuk download
    };

    print(
      '📊 Summary created: KwH=${summary['totalKwh']}, BBM=${summary['totalBbm']}, SFC=${summary['averageSfc']}',
    );
    return summary;
  }

  /// Format tanggal untuk key penyimpanan (YYYY-MM-DD)
  static String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Format tanggal untuk tampilan
  static String _formatDateDisplay(DateTime date) {
    final days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final dayName = days[date.weekday % 7];
    return '$dayName, ${date.day} ${months[date.month]} ${date.year}';
  }

  /// Cek apakah dua tanggal sama (tanpa mempertimbangkan jam)
  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Hapus data riwayat untuk generator tertentu
  static Future<void> clearHistory(String generatorName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // Hapus semua key yang berkaitan dengan generator ini
      final keysToRemove = keys
          .where(
            (key) =>
                key.startsWith('$_historyPrefix$generatorName') ||
                key.startsWith('$_fileIdPrefix$generatorName'),
          )
          .toList();

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      print('Cleared history for $generatorName');
    } catch (e) {
      print(' clearing history: $e');
    }
  }

  /// Mendapatkan statistik folder dari Google Drive
  static Future<Map<String, dynamic>> getFolderStatistics() async {
    try {
      return await GoogleDriveService.getFolderStats();
    } catch (e) {
      print(' getting folder statistics: $e');
      return {
        'totalFiles': 0,
        'totalSize': 0,
        'generators': <String>[],
        'error': e.toString(),
      };
    }
  }

  /// ===========================
  /// 🆕 REST API ALTERNATIVE METHODS
  /// ===========================

  /// Mendapatkan data historis menggunakan REST API (alternatif modern)
  static Future<List<Map<String, dynamic>>> getHistoricalDataUsingRestApi(
    String generatorName, {
    int daysBack = 7,
  }) async {
    try {
      print(
        '=== Getting historical data using REST API for $generatorName ===',
      );

      // Gunakan REST API untuk mendapatkan detail generator
      final generatorDetails = await RestApiService.getGeneratorDetails(
        generatorName,
        limit: daysBack,
      );

      if (!generatorDetails['success']) {
        print('❌ Generator not found: $generatorName');
        return [];
      }

      final files = generatorDetails['files'] as List;
      print('✓ Found ${files.length} files for $generatorName');

      List<Map<String, dynamic>> allData = [];

      // Baca data dari setiap file menggunakan REST API
      for (final file in files) {
        try {
          final fileId = file['id'];
          final logsheetData = await RestApiService.getLogsheet(
            fileId,
            includeMetadata: true,
          );

          if (logsheetData['success']) {
            final rawData = logsheetData['data'] as List;
            final metadata = logsheetData['metadata'];

            // Konversi data mentah ke format yang diharapkan
            final convertedData = _convertRawDataToHistoricalFormat(
              rawData,
              fileId,
              metadata,
            );

            allData.addAll(convertedData);
            print(
              '✓ Added ${convertedData.length} entries from ${file['name']}',
            );
          }
        } catch (e) {
          print('❌ Error reading file ${file['id']}: $e');
        }
      }

      // Urutkan berdasarkan tanggal (terbaru dulu)
      allData.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['fileDate'] ?? a['savedDate'] ?? '') ??
            DateTime(2000);
        final dateB =
            DateTime.tryParse(b['fileDate'] ?? b['savedDate'] ?? '') ??
            DateTime(2000);
        return dateB.compareTo(dateA);
      });

      print('✅ REST API: Retrieved ${allData.length} total historical entries');
      return allData;
    } catch (e) {
      print('❌  getting historical data using REST API: $e');
      return [];
    }
  }

  /// Mendapatkan analytics summary menggunakan REST API
  static Future<Map<String, dynamic>> getAnalyticsSummary({
    int days = 30,
  }) async {
    try {
      print('📊 Getting analytics summary for last $days days');

      final analytics = await RestApiService.getAnalyticsSummary(days: days);

      if (analytics['success']) {
        final summary = analytics['analytics'];
        print('✅ Analytics retrieved: ${summary['totalLogsheets']} logsheets');
        return summary;
      } else {
        print('❌  to get analytics summary');
        return {};
      }
    } catch (e) {
      print('❌  getting analytics summary: $e');
      return {};
    }
  }

  /// Helper untuk konversi data mentah ke format historical
  static List<Map<String, dynamic>> _convertRawDataToHistoricalFormat(
    List<dynamic> rawData,
    String fileId,
    Map<String, dynamic>? metadata,
  ) {
    List<Map<String, dynamic>> result = [];

    if (rawData.isEmpty) return result;

    // Ambil header dari baris pertama (jika ada)
    final headers = rawData.isNotEmpty ? List<String>.from(rawData[0]) : [];

    // Proses setiap baris data (mulai dari baris ke-2)
    for (int i = 1; i < rawData.length; i++) {
      final row = List<dynamic>.from(rawData[i]);
      Map<String, dynamic> rowMap = {};

      // Map setiap kolom dengan header yang sesuai
      for (int j = 0; j < headers.length && j < row.length; j++) {
        if (headers[j].isNotEmpty &&
            row[j] != null &&
            row[j].toString().trim().isNotEmpty) {
          rowMap[headers[j]] = row[j];
        }
      }

      // Tambahkan metadata
      rowMap['fileId'] = fileId;
      rowMap['fileDate'] =
          metadata?['modifiedTime'] ?? DateTime.now().toIso8601String();
      rowMap['isRealData'] = true;
      rowMap['source'] = 'google_drive_rest_api';
      rowMap['rowIndex'] = i;

      // Hanya tambahkan jika ada data yang bermakna
      if (rowMap.length > 4) {
        // Lebih dari metadata saja
        result.add(rowMap);
      }
    }

    return result;
  }

  /// Test konektivitas dengan REST API
  static Future<bool> testRestApiConnection() async {
    try {
      print('🔧 Testing REST API connection...');

      final isAvailable = await RestApiService.isApiAvailable();

      if (isAvailable) {
        print('✅ REST API is available and healthy');
        return true;
      } else {
        print('❌ REST API is not available');
        return false;
      }
    } catch (e) {
      print('❌  testing REST API connection: $e');
      return false;
    }
  }
}
