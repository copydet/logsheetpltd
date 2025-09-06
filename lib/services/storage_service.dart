import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'file_id_sync_service.dart';

class StorageService {
  static const String _activeFileIdKey = 'active_file_id';
  static const String _generatorDataKey = 'generator_data';
  static const String _lastLogsheetDataKey = 'last_logsheet_data';
  static const String _generatorStatusKey = 'generator_status';

  /// Menghitung tanggal logsheet berdasarkan logika bisnis:
  /// - Logsheet baru dibuat setiap jam 10:00 pagi
  /// - Jam 00:00-09:59 menggunakan logsheet dari hari sebelumnya
  /// - Jam 10:00-23:59 menggunakan logsheet hari ini
  static DateTime getLogsheetDate([DateTime? now]) {
    final currentTime = now ?? DateTime.now();

    // Jika jam sekarang 00:00-09:59, gunakan tanggal kemarin
    if (currentTime.hour < 10) {
      return DateTime(currentTime.year, currentTime.month, currentTime.day - 1);
    }

    // Jika jam 10:00-23:59, gunakan tanggal hari ini
    return DateTime(currentTime.year, currentTime.month, currentTime.day);
  }

  /// Format tanggal logsheet menjadi string key
  static String formatLogsheetDateKey([DateTime? now]) {
    final logsheetDate = getLogsheetDate(now);
    return '${logsheetDate.year}-${logsheetDate.month.toString().padLeft(2, '0')}-${logsheetDate.day.toString().padLeft(2, '0')}';
  }

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

  // Simpan fileId aktif per generator dengan tanggal logsheet yang benar
  static Future<void> saveActiveFileId(
    String generatorName,
    String fileId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = formatLogsheetDateKey();

    // Simpan dengan key per tanggal logsheet untuk konsistensi
    final key = '${_activeFileIdKey}_${generatorName}_$dateKey';
    await prefs.setString(key, fileId);

    // Juga simpan tanpa tanggal untuk backward compatibility
    final legacyKey = '${_activeFileIdKey}_$generatorName';
    await prefs.setString(legacyKey, fileId);

    print(
      '🗄️ STORAGE: Saved fileId for $generatorName (logsheet date: $dateKey): $fileId',
    );
  }

  // Ambil fileId aktif per generator untuk logsheet saat ini (tanpa Firestore sync)
  static Future<String?> getActiveFileId(String generatorName) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = formatLogsheetDateKey();

    // Coba ambil file ID untuk logsheet tanggal ini
    final logsheetKey = '${_activeFileIdKey}_${generatorName}_$dateKey';
    final logsheetFileId = prefs.getString(logsheetKey);

    if (logsheetFileId != null && logsheetFileId.isNotEmpty) {
      print(
        '🗄️ STORAGE: Found logsheet fileId for $generatorName (logsheet date: $dateKey): $logsheetFileId',
      );
      return logsheetFileId;
    }

    // Fallback ke legacy key jika tidak ada file ID logsheet
    final legacyKey = '${_activeFileIdKey}_$generatorName';
    final legacyFileId = prefs.getString(legacyKey);

    if (legacyFileId != null && legacyFileId.isNotEmpty) {
      print(
        '🗄️ STORAGE: Using legacy fileId for $generatorName: $legacyFileId',
      );
      return legacyFileId;
    }

    print(
      '🗄️ STORAGE: No fileId found for $generatorName on logsheet date: $dateKey',
    );
    return null;
  }

  // Ambil fileId dengan sinkronisasi Firestore (method terpisah)
  static Future<String?> getFileIdWithFirestoreSync(
    String generatorName,
  ) async {
    // 🔥 PRIORITAS 1: Coba ambil dari Firestore untuk konsistensi cross-device
    try {
      final firestoreFileId = await FileIdSyncService.getConsistentFileId(
        generatorName,
      );
      if (firestoreFileId != null && firestoreFileId.isNotEmpty) {
        print(
          '✅ STORAGE: Using synced fileId from Firestore for $generatorName: $firestoreFileId',
        );
        return firestoreFileId;
      }
    } catch (e) {
      print(
        '⚠️ STORAGE: Failed to get fileId from Firestore for $generatorName: $e',
      );
    }

    // PRIORITAS 2: Fallback ke local storage
    final localFileId = await getActiveFileId(generatorName);
    if (localFileId != null && localFileId.isNotEmpty) {
      // Sync ke Firestore untuk device lain
      try {
        await FileIdSyncService.saveFileIdToFirestore(
          generatorName: generatorName,
          fileId: localFileId,
          createdBy: 'local_storage_sync',
        );
      } catch (e) {
        print('⚠️ STORAGE: Failed to sync local fileId to Firestore: $e');
      }
    }

    return localFileId;
  }

  // Bersihkan file ID lama (file ID kemarin/hari sebelumnya)
  static Future<void> cleanupOldFileIds(String generatorName) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();

    // Hapus file ID dari 7 hari yang lalu
    for (int i = 1; i <= 7; i++) {
      final oldDate = today.subtract(Duration(days: i));
      final oldDateKey =
          '${oldDate.year}-${oldDate.month.toString().padLeft(2, '0')}-${oldDate.day.toString().padLeft(2, '0')}';
      final oldKey = '${_activeFileIdKey}_${generatorName}_$oldDateKey';

      if (prefs.containsKey(oldKey)) {
        await prefs.remove(oldKey);
        print(
          '🗄️ CLEANUP: Removed old fileId for $generatorName ($oldDateKey)',
        );
      }
    }
  }

  // 🏪 CACHE: Simpan status hasData untuk jam tertentu dengan tanggal logsheet yang benar
  static Future<void> setHourDataStatus(
    String generatorName,
    int hour,
    bool hasData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = formatLogsheetDateKey();
    await prefs.setBool(
      'hasData_${dateKey}_${generatorName}_hour_$hour',
      hasData,
    );
  }

  // 🏪 CACHE: Ambil status hasData untuk jam tertentu dengan tanggal logsheet yang benar
  static Future<bool> getHourDataStatus(String generatorName, int hour) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = formatLogsheetDateKey();
    return prefs.getBool('hasData_${dateKey}_${generatorName}_hour_$hour') ??
        false;
  }

  // 🧹 CACHE CLEANUP: Bersihkan cache jam untuk logsheet sebelumnya
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

  // 🔄 CACHE RESET: Reset status untuk jam tertentu pada logsheet saat ini
  static Future<void> resetCurrentHourDataStatus(
    String generatorName,
    int hour,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = formatLogsheetDateKey();
    await prefs.remove('hasData_${dateKey}_${generatorName}_hour_$hour');
    print(
      '🔄 CACHE: Reset hour data status for $generatorName hour $hour on logsheet date: $dateKey',
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
}
