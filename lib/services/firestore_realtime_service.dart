import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../utils/firestore_collection_utils.dart';

/// Service untuk real-time data dari Firestore untuk Dashboard dan Detail
class FirestoreRealtimeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, StreamSubscription<QuerySnapshot>> _activeListeners =
      {};

  /// Ambil latest data for dashboard (semua generators)
  static Future<Map<String, Map<String, dynamic>>> getLatestDataForDashboard(
    List<String> generatorNames,
  ) async {
    try {
      print('📊 FIRESTORE: Getting latest data for dashboard');

      Map<String, Map<String, dynamic>> result = {};
      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      for (final generatorName in generatorNames) {
        try {
          // Ambil collection name for this generator
          final collectionName = FirestoreCollectionUtils.getCollectionName(
            generatorName,
          );

          // Ambil latest data for today for this generator
          final query = await _firestore
              .collection(collectionName)
              .where('date', isEqualTo: todayStr)
              .orderBy('syncedAt', descending: true)
              .limit(1)
              .get();

          if (query.docs.isNotEmpty) {
            final doc = query.docs.first;
            final data = doc.data();
            final logsheetData = data['data'] as Map<String, dynamic>;

            result[generatorName] = {
              'generatorName': generatorName,
              'fileId':
                  'firestore_${generatorName.replaceAll(' ', '_')}_$todayStr',
              'hasData': true,
              'lastUpdate': data['syncedAt']?.toDate()?.toIso8601String(),
              'source': 'firestore',
              ...logsheetData,
            };

            print('✅ FIRESTORE: Found data for $generatorName');
          } else {
            print('⚠️ FIRESTORE: No data found for $generatorName today');
            result[generatorName] = {
              'generatorName': generatorName,
              'hasData': false,
              'source': 'firestore',
            };
          }
        } catch (e) {
          print('❌ FIRESTORE:  getting data for $generatorName: $e');
          result[generatorName] = {
            'generatorName': generatorName,
            'hasData': false,
            'error': e.toString(),
            'source': 'firestore',
          };
        }
      }

      return result;
    } catch (e) {
      print('❌ FIRESTORE:  getting dashboard data: $e');
      return {};
    }
  }

  /// Ambil detailed data for specific generator (untuk detail screen)
  static Future<List<Map<String, dynamic>>> getDetailedDataForGenerator(
    String generatorName, {
    int daysBack = 1,
  }) async {
    try {
      print('📊 FIRESTORE: Getting detailed data for $generatorName');

      // 🔧 FIX: Sederhanakan query untuk menghindari composite index requirement
      // Gunakan query yang lebih sederhana dan filter di client side
      QuerySnapshot query;

      // Ambil collection name for this generator
      final collectionName = FirestoreCollectionUtils.getCollectionName(
        generatorName,
      );

      try {
        // Coba query dengan orderBy terlebih dahulu
        query = await _firestore
            .collection(collectionName)
            .orderBy('syncedAt', descending: true)
            .limit(50) // Batasi untuk performa
            .get();

        print('✅ FIRESTORE: Using optimized query with syncedAt orderBy');
      } catch (indexError) {
        print(
          '⚠️ FIRESTORE: syncedAt index not available, trying simple query',
        );

        try {
          // Fallback ke query tanpa orderBy
          query = await _firestore.collection(collectionName).limit(20).get();

          print('✅ FIRESTORE: Using simple query without orderBy');
        } catch (simpleError) {
          print(
            '❌ FIRESTORE: All query methods failed, returning empty result',
          );
          print('Error details: $simpleError');
          return [];
        }
      }

      List<Map<String, dynamic>> result = [];

      for (final doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>?;

        // 🔧 FIX: Tambahkan null checks dan validasi data
        if (data == null) continue;

        final logsheetData = data['data'] as Map<String, dynamic>?;
        if (logsheetData == null) continue;

        final docDate = data['date'] as String?;
        if (docDate == null) continue;

        // Client-side filtering berdasarkan tanggal jika diperlukan
        if (daysBack > 0) {
          try {
            final documentDate = DateTime.parse(docDate);
            final cutoffDate = DateTime.now().subtract(
              Duration(days: daysBack),
            );
            if (documentDate.isBefore(cutoffDate)) continue;
          } catch (e) {
            // Jika parsing tanggal gagal, skip dokumen ini
            print('⚠️ FIRESTORE: Invalid date format in document: $docDate');
            continue;
          }
        }

        result.add({
          'fileId': 'firestore_${generatorName.replaceAll(' ', '_')}_$docDate',
          'generatorName': generatorName,
          'date': docDate,
          'timestamp':
              data['syncedAt']?.toDate()?.toIso8601String() ??
              DateTime.now().toIso8601String(),
          'source': 'firestore',
          'isRealData': true,
          ...logsheetData,
        });
      }

      print(
        '✅ FIRESTORE: Found ${result.length} detailed records for $generatorName',
      );
      return result;
    } catch (e) {
      print('❌ FIRESTORE:  getting detailed data for $generatorName: $e');
      return [];
    }
  }

  /// Pengaturan real-time listener for dashboard
  static StreamSubscription<QuerySnapshot>? listenToRealtimeUpdates(
    List<String> generatorNames,
    Function(Map<String, Map<String, dynamic>>) onUpdate,
  ) {
    try {
      print('👂 FIRESTORE: Setting up real-time listener for dashboard');

      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // With separate collections, we need to set up listeners for each generator
      // For now, we'll listen to all collections and merge the updates
      // In a production setup, this could be optimized with Firestore collection group queries

      // Pengaturan listeners for each collection and merge results
      Map<String, Map<String, dynamic>> allUpdates = {};

      for (final generatorName in generatorNames) {
        final collectionName = FirestoreCollectionUtils.getCollectionName(
          generatorName,
        );

        _firestore
            .collection(collectionName)
            .where('date', isEqualTo: todayStr)
            .snapshots()
            .listen(
              (snapshot) {
                // Tangani individual collection update
                Map<String, Map<String, dynamic>> generatorUpdate = {};
                _handleRealtimeUpdate(snapshot, [generatorName], (updates) {
                  generatorUpdate.addAll(updates);
                });

                // Merge with all updates
                allUpdates.addAll(generatorUpdate);

                // Call main update handler with merged data
                onUpdate(allUpdates);
              },
              onError: (error) {
                print(
                  '❌ FIRESTORE: Real-time listener error for $collectionName: $error',
                );
              },
            );
      }

      // Kembalikan first collection listener for compatibility
      // Note: In production, this should be handled differently
      final firstGeneratorCollection =
          FirestoreCollectionUtils.getCollectionName(generatorNames.first);

      return _firestore
          .collection(firstGeneratorCollection)
          .where('date', isEqualTo: todayStr)
          .snapshots()
          .listen(
            (snapshot) {
              _handleRealtimeUpdate(snapshot, generatorNames, onUpdate);
            },
            onError: (error) {
              print('❌ FIRESTORE: Real-time listener error: $error');
            },
          );
    } catch (e) {
      print('❌ FIRESTORE:  setting up real-time listener: $e');
      return null;
    }
  }

  /// Tangani real-time updates
  static void _handleRealtimeUpdate(
    QuerySnapshot snapshot,
    List<String> generatorNames,
    Function(Map<String, Map<String, dynamic>>) onUpdate,
  ) {
    try {
      Map<String, Map<String, dynamic>> updates = {};

      // Group by generator name and get latest for each
      Map<String, QueryDocumentSnapshot> latestByGenerator = {};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final generatorName = data['generatorName'] as String;
        final syncedAt = data['syncedAt'] as Timestamp?;

        if (!latestByGenerator.containsKey(generatorName) ||
            (syncedAt != null &&
                latestByGenerator[generatorName]!.data()
                    is Map<String, dynamic> &&
                (latestByGenerator[generatorName]!.data()
                        as Map<String, dynamic>)['syncedAt']
                    is Timestamp &&
                syncedAt.compareTo(
                      (latestByGenerator[generatorName]!.data()
                          as Map<String, dynamic>)['syncedAt'],
                    ) >
                    0)) {
          latestByGenerator[generatorName] = doc;
        }
      }

      // Ubah to update format
      for (final entry in latestByGenerator.entries) {
        final generatorName = entry.key;
        final doc = entry.value;
        final data = doc.data() as Map<String, dynamic>;
        final logsheetData = data['data'] as Map<String, dynamic>;

        updates[generatorName] = {
          'generatorName': generatorName,
          'fileId':
              'firestore_${generatorName.replaceAll(' ', '_')}_${data['date']}',
          'hasData': true,
          'lastUpdate': data['syncedAt']?.toDate()?.toIso8601String(),
          'source': 'firestore',
          'isRealtime': true,
          ...logsheetData,
        };
      }

      // Tambah empty data for generators not found
      for (final generatorName in generatorNames) {
        if (!updates.containsKey(generatorName)) {
          updates[generatorName] = {
            'generatorName': generatorName,
            'hasData': false,
            'source': 'firestore',
            'isRealtime': true,
          };
        }
      }

      print('🔄 FIRESTORE: Real-time update for ${updates.length} generators');
      onUpdate(updates);
    } catch (e) {
      print('❌ FIRESTORE:  handling real-time update: $e');
    }
  }

  /// Pengaturan listener for specific generator (detail screen)
  static StreamSubscription<QuerySnapshot>? listenToGeneratorUpdates(
    String generatorName,
    Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    try {
      print('👂 FIRESTORE: Setting up listener for $generatorName');

      final cutoffDate = DateTime.now().subtract(Duration(days: 1));
      final cutoffDateStr =
          '${cutoffDate.year.toString().padLeft(4, '0')}-${cutoffDate.month.toString().padLeft(2, '0')}-${cutoffDate.day.toString().padLeft(2, '0')}';

      final listenerId = 'generator_$generatorName';

      // Batal existing listener
      _activeListeners[listenerId]?.cancel();

      // Ambil collection name for this generator
      final collectionName = FirestoreCollectionUtils.getCollectionName(
        generatorName,
      );

      _activeListeners[listenerId] = _firestore
          .collection(collectionName)
          .where('date', isGreaterThanOrEqualTo: cutoffDateStr)
          .snapshots()
          .listen(
            (snapshot) {
              _handleGeneratorUpdate(snapshot, generatorName, onUpdate);
            },
            onError: (error) {
              print('❌ FIRESTORE: Generator listener error: $error');
            },
          );

      return _activeListeners[listenerId];
    } catch (e) {
      print('❌ FIRESTORE:  setting up generator listener: $e');
      return null;
    }
  }

  /// Tangani generator-specific updates
  static void _handleGeneratorUpdate(
    QuerySnapshot snapshot,
    String generatorName,
    Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    try {
      List<Map<String, dynamic>> updates = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final logsheetData = data['data'] as Map<String, dynamic>;

        updates.add({
          'fileId':
              'firestore_${generatorName.replaceAll(' ', '_')}_${data['date']}',
          'generatorName': generatorName,
          'date': data['date'],
          'timestamp':
              data['syncedAt']?.toDate()?.toIso8601String() ??
              DateTime.now().toIso8601String(),
          'source': 'firestore',
          'isRealData': true,
          'isRealtime': true,
          ...logsheetData,
        });
      }

      // Sort by timestamp descending
      updates.sort(
        (a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''),
      );

      print(
        '🔄 FIRESTORE: Real-time update for $generatorName: ${updates.length} records',
      );
      onUpdate(updates);
    } catch (e) {
      print('❌ FIRESTORE:  handling generator update: $e');
    }
  }

  /// Batal specific listener
  static void cancelListener(String listenerId) {
    _activeListeners[listenerId]?.cancel();
    _activeListeners.remove(listenerId);
    print('🔇 FIRESTORE: Cancelled listener: $listenerId');
  }

  /// Batal all listeners
  static void cancelAllListeners() {
    for (final listener in _activeListeners.values) {
      listener.cancel();
    }
    _activeListeners.clear();
    print('🔇 FIRESTORE: Cancelled all listeners');
  }

  /// Ambil connection status
  static Future<bool> checkConnection() async {
    try {
      await _firestore.collection('_connection_test').limit(1).get();
      return true;
    } catch (e) {
      print('❌ FIRESTORE: Connection check : $e');
      return false;
    }
  }

  /// Ambil temperature data for chart from Firestore (last 12 hours)
  static Future<List<Map<String, dynamic>>> getTemperatureDataForChart(
    String generatorName,
  ) async {
    try {
      print(
        '🌡️ FIRESTORE: Getting temperature data for chart: $generatorName',
      );

      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Ambil collection name for this generator
      final collectionName = FirestoreCollectionUtils.getCollectionName(
        generatorName,
      );

      // Ambil all data for today for this generator, ordered by timestamp
      final query = await _firestore
          .collection(collectionName)
          .where('date', isEqualTo: todayStr)
          .orderBy('syncedAt', descending: false)
          .get();

      List<Map<String, dynamic>> temperatureData = [];

      if (query.docs.isNotEmpty) {
        print(
          '🌡️ FIRESTORE: Found ${query.docs.length} records for $generatorName today',
        );

        for (final doc in query.docs) {
          final data = doc.data();
          final logsheetData = data['data'] as Map<String, dynamic>;
          final syncedAt = data['syncedAt']?.toDate();

          if (syncedAt != null && logsheetData.isNotEmpty) {
            // Extract hour from timestamp
            final hour = syncedAt.hour;

            // Buat temperature record with hour information
            temperatureData.add({
              'hour': hour,
              'timestamp': syncedAt.toIso8601String(),
              'waterTemp': logsheetData['waterTemp'],
              'lubeOilTemp': logsheetData['lubeOilTemp'],
              'engineTempExhaust': logsheetData['engineTempExhaust'],
              'tempBearing': logsheetData['tempBearing'],
              'tempWindingU': logsheetData['tempWindingU'],
              'tempWindingV': logsheetData['tempWindingV'],
              'tempWindingW': logsheetData['tempWindingW'],
              'source': 'firestore',
            });
          }
        }

        print(
          '🌡️ FIRESTORE: Processed ${temperatureData.length} temperature records',
        );
      } else {
        print(
          '⚠️ FIRESTORE: No temperature data found for $generatorName today',
        );
      }

      return temperatureData;
    } catch (e) {
      print('❌ FIRESTORE:  getting temperature data: $e');
      return [];
    }
  }
}
