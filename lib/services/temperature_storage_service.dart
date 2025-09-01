import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service khusus untuk menyimpan dan membaca data temperatur
/// Digunakan untuk chart yang memerlukan riwayat data 8 jam terakhir
class TemperatureStorageService {
  static const String _keyPrefix = 'temp_data_';

  /// Menyimpan data temperatur untuk jam tertentu
  static Future<void> saveTemperatureData({
    required String fileId,
    required int hour,
    required DateTime date,
    required Map<String, double> temperatureData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Key format: temp_data_fileId_YYYYMMDD_HH
      final dateStr = date
          .toIso8601String()
          .substring(0, 10)
          .replaceAll('-', '');
      final key =
          '${_keyPrefix}${fileId}_${dateStr}_${hour.toString().padLeft(2, '0')}';

      // Data yang disimpan
      final dataToSave = {
        'fileId': fileId,
        'hour': hour,
        'date': dateStr,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'waterTemp': temperatureData['waterTemp'] ?? 0.0,
        'lubeOilTemp': temperatureData['lubeOilTemp'] ?? 0.0,
        'tempBearing': temperatureData['tempBearing'] ?? 0.0,
        'tempWindingU': temperatureData['tempWindingU'] ?? 0.0,
        'tempWindingV': temperatureData['tempWindingV'] ?? 0.0,
        'tempWindingW': temperatureData['tempWindingW'] ?? 0.0,
        'engineTempExhaust': temperatureData['engineTempExhaust'] ?? 0.0,
      };

      await prefs.setString(key, json.encode(dataToSave));

      print('🌡️ TEMP STORAGE: Saved data for hour $hour');
      print('🌡️ TEMP STORAGE: Key: $key');
      print('🌡️ TEMP STORAGE: Data: $dataToSave');
    } catch (e) {
      print('❌ TEMP STORAGE: Error saving temperature data: $e');
    }
  }

  /// Mengambil data temperatur untuk 8 jam terakhir
  static Future<List<Map<String, dynamic>>> getLast8HoursTemperatureData({
    required String fileId,
    DateTime? targetDate,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final date = targetDate ?? DateTime.now();
      final currentHour = date.hour;

      List<Map<String, dynamic>> result = [];

      // Generate 8 jam terakhir ending di jam sekarang
      for (int i = 7; i >= 0; i--) {
        int targetHour = currentHour - i;
        DateTime targetDateTime = date;

        // Handle jam negatif (hari sebelumnya)
        if (targetHour < 0) {
          targetHour += 24;
          targetDateTime = date.subtract(Duration(days: 1));
        }

        final dateStr = targetDateTime
            .toIso8601String()
            .substring(0, 10)
            .replaceAll('-', '');
        final key =
            '${_keyPrefix}${fileId}_${dateStr}_${targetHour.toString().padLeft(2, '0')}';

        final dataStr = prefs.getString(key);

        if (dataStr != null) {
          try {
            final data = json.decode(dataStr) as Map<String, dynamic>;
            data['position'] = 7 - i; // Position di chart (0-7)
            result.add(data);
            print(
              '🌡️ TEMP STORAGE: Found data for hour $targetHour: ${data['waterTemp']}°C',
            );
          } catch (e) {
            print(
              '❌ TEMP STORAGE: Error parsing data for hour $targetHour: $e',
            );
          }
        } else {
          // Tidak ada data untuk jam ini, tambahkan placeholder
          result.add({
            'fileId': fileId,
            'hour': targetHour,
            'date': dateStr,
            'position': 7 - i,
            'waterTemp': 0.0,
            'lubeOilTemp': 0.0,
            'tempBearing': 0.0,
            'tempWindingU': 0.0,
            'tempWindingV': 0.0,
            'tempWindingW': 0.0,
            'engineTempExhaust': 0.0,
            'isEmpty': true,
          });
          print('🌡️ TEMP STORAGE: No data for hour $targetHour');
        }
      }

      print(
        '🌡️ TEMP STORAGE: Retrieved ${result.length} temperature data points',
      );
      print(
        '🌡️ TEMP STORAGE: Hours: ${result.map((e) => e['hour']).toList()}',
      );

      return result;
    } catch (e) {
      print('❌ TEMP STORAGE: Error getting temperature data: $e');
      return [];
    }
  }

  /// Menghapus data temperatur yang lebih dari 7 hari
  static Future<void> cleanupOldTemperatureData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      final cutoffDate = DateTime.now().subtract(Duration(days: 7));
      final cutoffDateStr = cutoffDate
          .toIso8601String()
          .substring(0, 10)
          .replaceAll('-', '');

      int deletedCount = 0;

      for (String key in keys) {
        if (key.startsWith(_keyPrefix)) {
          // Extract date dari key format: temp_data_fileId_YYYYMMDD_HH
          final parts = key.split('_');
          if (parts.length >= 4) {
            final dateStr = parts[3];
            if (dateStr.compareTo(cutoffDateStr) < 0) {
              await prefs.remove(key);
              deletedCount++;
            }
          }
        }
      }

      if (deletedCount > 0) {
        print(
          '🌡️ TEMP STORAGE: Cleaned up $deletedCount old temperature records',
        );
      }
    } catch (e) {
      print('❌ TEMP STORAGE: Error cleaning up old data: $e');
    }
  }

  /// Debug: Lihat semua data temperatur yang tersimpan
  static Future<void> debugPrintAllTemperatureData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith(_keyPrefix))
          .toList();

      print('🌡️ TEMP STORAGE DEBUG: Found ${keys.length} temperature records');

      for (String key in keys) {
        final dataStr = prefs.getString(key);
        if (dataStr != null) {
          final data = json.decode(dataStr);
          print(
            '🌡️ $key: Hour ${data['hour']}, Water: ${data['waterTemp']}°C',
          );
        }
      }
    } catch (e) {
      print('❌ TEMP STORAGE DEBUG: Error: $e');
    }
  }
}
