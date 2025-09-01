import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/generator_status.dart';
import '../services/database_storage_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';

/// Service untuk sinkronisasi status generator manual antar device
class GeneratorStatusSyncService {
  static const String _collectionName = 'generator_status';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription<QuerySnapshot>? _statusListener;
  static String? _deviceId;

  /// Initialize sync service
  static Future<void> initialize() async {
    try {
      _deviceId = await _getDeviceId();
      print('✅ GENERATOR_STATUS: Initialized with device ID: $_deviceId');
    } catch (e) {
      print('❌ GENERATOR_STATUS: Failed to initialize: $e');
    }
  }

  /// Get unique device ID
  static Future<String> _getDeviceId() async {
    final prefs = await StorageService.getGeneratorData();
    String? deviceId = prefs['device_id'];

    if (deviceId == null) {
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await StorageService.saveGeneratorData({'device_id': deviceId});
    }

    return deviceId;
  }

  /// Upload generator status to Firestore
  static Future<bool> uploadGeneratorStatus(
    String generatorName,
    bool isActive,
  ) async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        print('❌ GENERATOR_STATUS: No user logged in');
        return false;
      }

      if (_deviceId == null) {
        await initialize();
      }

      final status = GeneratorStatus(
        generatorName: generatorName,
        isActive: isActive,
        lastUpdated: DateTime.now(),
        updatedBy: user.email,
        deviceId: _deviceId!,
      );

      // Upload to Firestore dengan document ID berdasarkan generator name
      await _firestore
          .collection(_collectionName)
          .doc(generatorName)
          .set(status.toFirestore(), SetOptions(merge: true));

      print(
        '✅ GENERATOR_STATUS: Uploaded $generatorName status: $isActive by ${user.email}',
      );
      return true;
    } catch (e) {
      print('❌ GENERATOR_STATUS: Failed to upload status: $e');
      return false;
    }
  }

  /// Download latest generator statuses from Firestore
  static Future<Map<String, bool>> downloadLatestStatuses(
    List<String> generatorNames,
  ) async {
    try {
      Map<String, bool> statuses = {};

      for (final generatorName in generatorNames) {
        final doc = await _firestore
            .collection(_collectionName)
            .doc(generatorName)
            .get();

        if (doc.exists && doc.data() != null) {
          final status = GeneratorStatus.fromFirestore(doc.data()!);
          statuses[generatorName] = status.isActive;

          // Update local storage if this is from another device
          if (status.deviceId != _deviceId) {
            await DatabaseStorageService.setGeneratorStatus(
              generatorName,
              status.isActive,
            );
            await StorageService.saveGeneratorStatus(
              generatorName,
              status.isActive,
            );

            print(
              '🔄 GENERATOR_STATUS: Synced $generatorName status: ${status.isActive} from ${status.updatedBy}',
            );
          }
        }
      }

      return statuses;
    } catch (e) {
      print('❌ GENERATOR_STATUS: Failed to download statuses: $e');
      return {};
    }
  }

  /// Setup real-time listener for generator status changes
  static void setupRealtimeListener(
    List<String> generatorNames,
    Function(String generatorName, bool isActive, String updatedBy)
    onStatusChanged,
  ) {
    try {
      _statusListener?.cancel();

      _statusListener = _firestore
          .collection(_collectionName)
          .where('generatorName', whereIn: generatorNames)
          .snapshots()
          .listen((snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.modified ||
                  change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                if (data != null) {
                  final status = GeneratorStatus.fromFirestore(data);

                  // Ignore changes from this device
                  if (status.deviceId == _deviceId) continue;

                  // Update local storage
                  DatabaseStorageService.setGeneratorStatus(
                    status.generatorName,
                    status.isActive,
                  );
                  StorageService.saveGeneratorStatus(
                    status.generatorName,
                    status.isActive,
                  );

                  // Notify callback
                  onStatusChanged(
                    status.generatorName,
                    status.isActive,
                    status.updatedBy,
                  );

                  print(
                    '🔔 GENERATOR_STATUS: Real-time update - ${status.generatorName}: ${status.isActive} by ${status.updatedBy}',
                  );
                }
              }
            }
          });

      print(
        '👂 GENERATOR_STATUS: Real-time listener setup for ${generatorNames.length} generators',
      );
    } catch (e) {
      print('❌ GENERATOR_STATUS: Failed to setup real-time listener: $e');
    }
  }

  /// Cancel real-time listener
  static void cancelRealtimeListener() {
    _statusListener?.cancel();
    _statusListener = null;
    print('🔇 GENERATOR_STATUS: Real-time listener cancelled');
  }

  /// Batch upload all generator statuses
  static Future<bool> uploadAllGeneratorStatuses(
    Map<String, bool> generatorStatuses,
  ) async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        print('❌ GENERATOR_STATUS: No user logged in');
        return false;
      }

      if (_deviceId == null) {
        await initialize();
      }

      final batch = _firestore.batch();

      for (final entry in generatorStatuses.entries) {
        final status = GeneratorStatus(
          generatorName: entry.key,
          isActive: entry.value,
          lastUpdated: DateTime.now(),
          updatedBy: user.email,
          deviceId: _deviceId!,
        );

        final docRef = _firestore.collection(_collectionName).doc(entry.key);
        batch.set(docRef, status.toFirestore(), SetOptions(merge: true));
      }

      await batch.commit();

      print(
        '✅ GENERATOR_STATUS: Batch uploaded ${generatorStatuses.length} generator statuses',
      );
      return true;
    } catch (e) {
      print('❌ GENERATOR_STATUS: Failed to batch upload statuses: $e');
      return false;
    }
  }

  /// Get generator status history
  static Future<List<GeneratorStatus>> getStatusHistory(
    String generatorName, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('generatorName', isEqualTo: generatorName)
          .orderBy('lastUpdated', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => GeneratorStatus.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('❌ GENERATOR_STATUS: Failed to get status history: $e');
      return [];
    }
  }

  /// Check if there are newer statuses from other devices
  static Future<bool> hasNewerStatuses(
    Map<String, DateTime> localTimestamps,
  ) async {
    try {
      for (final entry in localTimestamps.entries) {
        final doc = await _firestore
            .collection(_collectionName)
            .doc(entry.key)
            .get();

        if (doc.exists && doc.data() != null) {
          final status = GeneratorStatus.fromFirestore(doc.data()!);

          // Skip if from same device
          if (status.deviceId == _deviceId) continue;

          // Check if remote is newer
          if (status.lastUpdated.isAfter(entry.value)) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      print('❌ GENERATOR_STATUS: Failed to check newer statuses: $e');
      return false;
    }
  }
}
