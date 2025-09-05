import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_collection_utils.dart';

/// Service untuk mengambil data historis dari Firestore
class FirestoreHistoricalService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mendapatkan summary harian dari Firestore untuk riwayat
  static Future<List<Map<String, dynamic>>> getDailySummary(
    String generatorName, {
    int daysBack = 7,
  }) async {
    try {
      print(
        '📊 FIRESTORE: Getting daily summary for $generatorName ($daysBack days)',
      );

      // Get collection name for this generator
      final collectionName = FirestoreCollectionUtils.getCollectionName(generatorName);
      print('📊 FIRESTORE: Using collection: $collectionName');

      final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));
      final cutoffDateStr =
          '${cutoffDate.year.toString().padLeft(4, '0')}-${cutoffDate.month.toString().padLeft(2, '0')}-${cutoffDate.day.toString().padLeft(2, '0')}';

      final query = await _firestore
          .collection(collectionName)
          .where('date', isGreaterThanOrEqualTo: cutoffDateStr)
          .orderBy('date', descending: true)
          .get();

      print('🔍 FIRESTORE: Found ${query.docs.length} documents');

      // Group by date
      Map<String, List<Map<String, dynamic>>> groupedByDate = {};

      for (final doc in query.docs) {
        final data = doc.data();
        final date = data['date'] as String;

        if (!groupedByDate.containsKey(date)) {
          groupedByDate[date] = [];
        }

        // Convert Firestore data to expected format
        final logsheetData = data['data'] as Map<String, dynamic>? ?? {};

        // Create formatted entry similar to original format
        final entry = {
          'fileId': 'firestore_${generatorName.replaceAll(' ', '_')}_$date',
          'generatorName': generatorName,
          'date': date,
          'savedDate': date,
          'timestamp':
              data['syncedAt']?.toDate()?.toIso8601String() ??
              DateTime.now().toIso8601String(),
          'source': 'firestore',
          ...logsheetData,
        };

        groupedByDate[date]!.add(entry);
      }

      // Create daily summaries
      List<Map<String, dynamic>> dailySummaries = [];

      groupedByDate.forEach((date, entries) {
        final summary = _createDailySummary(date, entries, generatorName);
        dailySummaries.add(summary);
      });

      print('✅ FIRESTORE: Created ${dailySummaries.length} daily summaries');
      return dailySummaries;
    } catch (e) {
      print('❌ FIRESTORE: Error getting daily summary: $e');
      return [];
    }
  }

  /// Create daily summary from entries
  static Map<String, dynamic> _createDailySummary(
    String date,
    List<Map<String, dynamic>> entries,
    String generatorName,
  ) {
    if (entries.isEmpty) {
      return {
        'date': date,
        'dateFormatted': _formatDate(date),
        'generatorName': generatorName,
        'fileId': 'firestore_${generatorName.replaceAll(' ', '_')}_$date',
        'hasData': false,
        'rawData': [],
        'entryCount': 0,
        'totalKwh': 0.0,
        'totalBbm': 0.0,
        'averageSfc': 0.0,
        'isRealData': true, // Firestore data is considered real/shared data
        'source': 'firestore',
      };
    }

    // Calculate energy/fuel aggregates for new fields
    double totalKwh = 0.0;
    double totalBbm = 0.0;
    double totalSfc = 0.0;
    int validSfcCount = 0;

    for (final entry in entries) {
      // Total KwH - ambil nilai terbesar (data terakhir hari)
      final kwhValue = _parseDouble(entry['totalKwh']);
      if (kwhValue > totalKwh) {
        totalKwh = kwhValue;
      }

      // Total BBM - ambil nilai terbesar (data terakhir hari)
      final bbmValue = _parseDouble(entry['totalBbm']);
      if (bbmValue > totalBbm) {
        totalBbm = bbmValue;
      }

      // SFC - hitung rata-rata
      final sfcValue = _parseDouble(entry['sfc']);
      if (sfcValue > 0) {
        totalSfc += sfcValue;
        validSfcCount++;
      }
    }

    return {
      'date': date,
      'dateFormatted': _formatDate(date),
      'generatorName': generatorName,
      'fileId': 'firestore_${generatorName.replaceAll(' ', '_')}_$date',
      'hasData': true,
      'rawData': entries,
      'entryCount': entries.length,
      'totalKwh': totalKwh,
      'totalBbm': totalBbm,
      'averageSfc': validSfcCount > 0 ? (totalSfc / validSfcCount) : 0.0,
      'isRealData': true, // Firestore data is considered real/shared data
      'source': 'firestore',
    };
  }

  /// Parse string to double safely
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Format date from YYYY-MM-DD to readable format
  static String _formatDate(String date) {
    try {
      final dateTime = DateTime.parse(date);
      final months = [
        '',
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];

      return '${dateTime.day} ${months[dateTime.month]} ${dateTime.year}';
    } catch (e) {
      return date;
    }
  }

  /// Get specific date data for download
  static Future<Map<String, dynamic>?> getDateData(
    String generatorName,
    String date,
  ) async {
    try {
      print('📊 FIRESTORE: Getting data for $generatorName on $date');

      // Get collection name for this generator
      final collectionName = FirestoreCollectionUtils.getCollectionName(generatorName);
      print('📊 FIRESTORE: Using collection: $collectionName for download');

      final query = await _firestore
          .collection(collectionName)
          .where('date', isEqualTo: date)
          .get();

      if (query.docs.isEmpty) {
        print('⚠️ FIRESTORE: No data found for $date');
        return null;
      }

      // Combine all entries for that date
      List<Map<String, dynamic>> entries = [];
      for (final doc in query.docs) {
        final data = doc.data();
        final logsheetData = data['data'] as Map<String, dynamic>? ?? {};

        entries.add({
          'fileId': 'firestore_${generatorName.replaceAll(' ', '_')}_$date',
          'generatorName': generatorName,
          'date': date,
          'timestamp':
              data['syncedAt']?.toDate()?.toIso8601String() ??
              DateTime.now().toIso8601String(),
          'source': 'firestore',
          ...logsheetData,
        });
      }

      print('✅ FIRESTORE: Found ${entries.length} entries for download');

      return {
        'fileId': 'firestore_${generatorName.replaceAll(' ', '_')}_$date',
        'date': date,
        'generatorName': generatorName,
        'entries': entries,
        'totalEntries': entries.length,
        'source': 'firestore',
      };
    } catch (e) {
      print('❌ FIRESTORE: Error getting date data: $e');
      return null;
    }
  }
}
