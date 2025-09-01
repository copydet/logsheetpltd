import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _activeFileIdKey = 'active_file_id';
  static const String _generatorDataKey = 'generator_data';
  static const String _lastLogsheetDataKey = 'last_logsheet_data';
  static const String _generatorStatusKey = 'generator_status';

  // Simpan status generator (on/off)
  static Future<void> saveGeneratorStatus(
    String generatorName,
    bool isActive,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_generatorStatusKey}_$generatorName';
    await prefs.setBool(key, isActive);
  }

  // Ambil status generator (on/off)
  static Future<bool?> getGeneratorStatus(String generatorName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_generatorStatusKey}_$generatorName';
    return prefs.getBool(key);
  }

  // Simpan fileId aktif per generator
  static Future<void> saveActiveFileId(
    String generatorName,
    String fileId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_activeFileIdKey}_$generatorName';
    await prefs.setString(key, fileId);
  }

  // Ambil fileId aktif per generator
  static Future<String?> getActiveFileId(String generatorName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_activeFileIdKey}_$generatorName';
    return prefs.getString(key);
  }

  // 🏪 CACHE: Simpan status hasData untuk jam tertentu dengan tanggal PER GENERATOR
  static Future<void> setHourDataStatus(
    String generatorName,
    int hour,
    bool hasData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await prefs.setBool(
      'hasData_${dateKey}_${generatorName}_hour_$hour',
      hasData,
    );
  }

  // 🏪 CACHE: Ambil status hasData untuk jam tertentu dengan tanggal PER GENERATOR
  static Future<bool> getHourDataStatus(String generatorName, int hour) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return prefs.getBool('hasData_${dateKey}_${generatorName}_hour_$hour') ??
        false;
  }

  // 🧹 CACHE CLEANUP: Bersihkan cache jam untuk hari sebelumnya PER GENERATOR
  static Future<void> cleanupOldHourDataCache() async {
    final prefs = await SharedPreferences.getInstance();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayKey =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    // Daftar generator yang dikenal
    final generators = [
      'Mitsubishi #1',
      'Mitsubishi #2',
      'Mitsubishi #3',
      'Mitsubishi #4',
    ];

    // Hapus cache untuk semua jam hari kemarin (0-23) untuk semua generator
    for (String generator in generators) {
      for (int hour = 0; hour < 24; hour++) {
        await prefs.remove('hasData_${yesterdayKey}_${generator}_hour_$hour');
      }
    }
    print(
      '🧹 CACHE: Cleaned up old hour data cache for all generators on $yesterdayKey',
    );
  }

  // 🔄 CACHE RESET: Reset status untuk jam tertentu hari ini PER GENERATOR (untuk jam baru)
  static Future<void> resetCurrentHourDataStatus(
    String generatorName,
    int hour,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await prefs.remove('hasData_${dateKey}_${generatorName}_hour_$hour');
    print(
      '🔄 CACHE: Reset hour data status for $generatorName hour $hour on $dateKey',
    );
  }

  // Simpan data generator
  static Future<void> saveGeneratorData(
    Map<String, String> generatorFileIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(generatorFileIds);
    await prefs.setString(_generatorDataKey, jsonString);
  }

  // Ambil data generator
  static Future<Map<String, String>> getGeneratorData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_generatorDataKey);
    if (jsonString != null) {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<String, String>();
    }
    return {};
  }

  // Simpan data logsheet terakhir per generator dengan timestamp
  static Future<void> saveLastLogsheetData(
    String generatorName,
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_lastLogsheetDataKey}_$generatorName';

    // Tambahkan timestamp dan jam saat menyimpan
    final dataWithTimestamp = Map<String, dynamic>.from(data);
    dataWithTimestamp['_savedAt'] = DateTime.now().toIso8601String();
    dataWithTimestamp['_savedHour'] = DateTime.now().hour;

    final jsonString = jsonEncode(dataWithTimestamp);
    await prefs.setString(key, jsonString);
  }

  // Ambil data logsheet terakhir per generator
  static Future<Map<String, dynamic>?> getLastLogsheetData(
    String generatorName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_lastLogsheetDataKey}_$generatorName';
    final jsonString = prefs.getString(key);
    if (jsonString != null) {
      final data = jsonDecode(jsonString).cast<String, dynamic>();
      return data;
    }
    return null;
  }

  // Ambil data logsheet hanya jika masih untuk jam yang sama
  static Future<Map<String, dynamic>?> getLastLogsheetDataForCurrentHour(
    String generatorName,
  ) async {
    final data = await getLastLogsheetData(generatorName);
    if (data == null) return null;

    final currentHour = DateTime.now().hour;
    final savedHour = data['_savedHour'];

    // Hanya return data jika jam masih sama
    if (savedHour != null && savedHour == currentHour) {
      // PERBAIKAN: Tetap sertakan metadata _savedHour untuk keperluan edit mode logic
      final dataWithMetadata = Map<String, dynamic>.from(data);
      dataWithMetadata.remove(
        '_savedAt',
      ); // Hapus hanya timestamp, keep _savedHour
      return dataWithMetadata;
    }

    return null; // Data sudah kadaluarsa (jam berbeda)
  }

  // Hapus data generator tertentu
  static Future<void> removeGeneratorData(String generatorName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_activeFileIdKey}_$generatorName');
    await prefs.remove('${_lastLogsheetDataKey}_$generatorName');
  }

  // Hapus semua data
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Cek apakah generator memiliki data
  static Future<bool> hasGeneratorData(String generatorName) async {
    final fileId = await getActiveFileId(generatorName);
    return fileId != null;
  }

  /// CRITICAL FIX: Reset fileId bermasalah untuk Mitsubishi #1
  static Future<void> resetProblematicMitsubishi1FileId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentFileId = await getActiveFileId('Mitsubishi #1');

      // Daftar fileId bermasalah
      final problematicFileIds = [
        '1m-7mAUx8bFKBb9IeGcFUaH96nBJWT0Rw9Pv7VnP-iAM',
        '1-_G5vZD6xyXpxu1skcdQMB1auGBEW8upurPMuCm9YwA',
        '19Rq7EtX1IGdkXcie8c7O4WSDYd2SpM0rbeTehKkD-Zo',
      ];

      if (currentFileId != null && problematicFileIds.contains(currentFileId)) {
        // Reset fileId bermasalah
        final key = '${_activeFileIdKey}_Mitsubishi #1';
        await prefs.remove(key);
        print(
          '🧹 STORAGE: Reset problematic fileId for Mitsubishi #1: $currentFileId',
        );

        // Hapus juga cache terkait
        final allKeys = prefs.getKeys();
        for (String key in allKeys) {
          if (key.contains('Mitsubishi #1') && key.contains('hasData')) {
            await prefs.remove(key);
          }
        }
        print('✅ STORAGE: Cleared all cache for Mitsubishi #1');
      }
    } catch (e) {
      print('❌ STORAGE: Error resetting Mitsubishi #1 fileId: $e');
    }
  }
}
