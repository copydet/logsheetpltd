import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesInspector {
  /// Inspect semua data di SharedPreferences
  static Future<Map<String, dynamic>> inspectAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      Map<String, dynamic> inspection = {
        'totalKeys': allKeys.length,
        'estimatedSize': 0,
        'keysBreakdown': <String, int>{},
        'largestEntries': <Map<String, dynamic>>[],
        'logsheetData': <String, dynamic>{},
      };

      int totalSize = 0;
      List<Map<String, dynamic>> entries = [];

      // Analisa setiap key
      for (final key in allKeys) {
        final value = prefs.getString(key) ?? '';
        final size = utf8.encode(key + value).length;
        totalSize += size;

        entries.add({
          'key': key,
          'size': size,
          'valuePreview': value.length > 100
              ? '${value.substring(0, 100)}...'
              : value,
        });

        // Kategorikan berdasarkan prefix
        String category = 'other';
        if (key.contains('logsheet_history_'))
          category = 'history';
        else if (key.contains('file_id_'))
          category = 'fileIds';
        else if (key.contains('logsheet'))
          category = 'logsheet';

        inspection['keysBreakdown'][category] =
            (inspection['keysBreakdown'][category] ?? 0) + 1;

        // Simpan data logsheet untuk analisa
        if (key.contains('logsheet')) {
          inspection['logsheetData'][key] = {
            'size': size,
            'preview': value.length > 50
                ? '${value.substring(0, 50)}...'
                : value,
          };
        }
      }

      // Sort berdasarkan size dan ambil yang terbesar
      entries.sort((a, b) => (b['size'] as int).compareTo(a['size'] as int));
      inspection['largestEntries'] = entries.take(10).toList();
      inspection['estimatedSize'] = totalSize;

      return inspection;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Format size dalam bytes ke human readable
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Cek apakah SharedPreferences hampir penuh
  static Future<Map<String, dynamic>> checkHealth() async {
    final inspection = await inspectAll();
    final size = inspection['estimatedSize'] as int? ?? 0;

    String status = 'healthy';
    String warning = '';

    if (size > 5 * 1024 * 1024) {
      // > 5MB
      status = 'critical';
      warning = 'SharedPreferences hampir penuh! Perlu dibersihkan.';
    } else if (size > 2 * 1024 * 1024) {
      // > 2MB
      status = 'warning';
      warning = 'SharedPreferences mulai besar. Pertimbangkan untuk cleanup.';
    } else if (size > 1024 * 1024) {
      // > 1MB
      status = 'caution';
      warning = 'SharedPreferences cukup besar tapi masih aman.';
    }

    return {
      'status': status,
      'warning': warning,
      'size': size,
      'sizeFormatted': formatBytes(size),
      'recommendation': _getRecommendation(status, inspection),
    };
  }

  static String _getRecommendation(
    String status,
    Map<String, dynamic> inspection,
  ) {
    if (status == 'critical') {
      return 'URGENT: Hapus data lama atau gunakan database untuk data besar.';
    } else if (status == 'warning') {
      return 'Pertimbangkan untuk membersihkan data logsheet lama atau pindah ke database.';
    } else if (status == 'caution') {
      return 'Monitor penggunaan dan cleanup berkala.';
    }
    return 'SharedPreferences dalam kondisi baik.';
  }

  /// Cleanup data lama berdasarkan tanggal
  static Future<int> cleanupOldData({int keepDays = 30}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      int deletedCount = 0;
      final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));

      for (final key in allKeys) {
        if (key.contains('logsheet_history_')) {
          // Extract date from key: logsheet_history_Mitsubishi #1_2025-08-21
          final parts = key.split('_');
          if (parts.length >= 4) {
            try {
              final dateStr = parts.last;
              final date = DateTime.parse(dateStr);

              if (date.isBefore(cutoffDate)) {
                await prefs.remove(key);
                deletedCount++;
                print('🗑️ Deleted old data: $key');
              }
            } catch (e) {
              print('⚠️ Could not parse date from key: $key');
            }
          }
        }
      }

      return deletedCount;
    } catch (e) {
      print('❌ Error during cleanup: $e');
      return 0;
    }
  }

  /// Print detailed report
  static Future<void> printDetailedReport() async {
    print('\n📊 SHARED PREFERENCES INSPECTION REPORT');
    print('=' * 50);

    final inspection = await inspectAll();
    final health = await checkHealth();

    print('🔍 Total Keys: ${inspection['totalKeys']}');
    print('📏 Estimated Size: ${health['sizeFormatted']}');
    print('🚦 Status: ${health['status'].toString().toUpperCase()}');

    if (health['warning'].toString().isNotEmpty) {
      print('⚠️ Warning: ${health['warning']}');
    }

    print('\n📂 Keys Breakdown:');
    final breakdown = inspection['keysBreakdown'] as Map<String, dynamic>;
    breakdown.forEach((category, count) {
      print('   $category: $count keys');
    });

    print('\n🔝 Largest Entries:');
    final largest = inspection['largestEntries'] as List<dynamic>;
    for (int i = 0; i < largest.length && i < 5; i++) {
      final entry = largest[i] as Map<String, dynamic>;
      print('   ${i + 1}. ${entry['key']} (${formatBytes(entry['size'])})');
      print('      Preview: ${entry['valuePreview']}');
    }

    print('\n💡 Recommendation: ${health['recommendation']}');
    print('=' * 50);
  }
}
