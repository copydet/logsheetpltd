import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:workmanager/workmanager.dart'; // Disabled for now
import 'database_service.dart';
import '../utils/firestore_collection_utils.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  static SyncManager get instance => _instance;
  SyncManager._internal();

  // Configuration
  static const int SYNC_INTERVAL_MINUTES =
      120; // Reduced from 30 to 120 minutes since we use immediate sync
  static const int DATA_RETENTION_DAYS = 40;
  static const String SYNC_TASK_NAME = 'syncLogsheetData';

  // Services
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<QuerySnapshot>? _firestoreListener;

  // State
  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _isListening = false;
  DateTime? _lastSyncTime;
  DateTime? _lastDownloadTime;
  int _pendingUploads = 0;
  int _newUpdatesFromOthers = 0;
  List<String> _syncErrors = [];
  String? _deviceId;

  // Ambilters
  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  bool get isListening => _isListening;
  DateTime? get lastSyncTime => _lastSyncTime;
  DateTime? get lastDownloadTime => _lastDownloadTime;
  int get pendingUploads => _pendingUploads;
  int get newUpdatesFromOthers => _newUpdatesFromOthers;
  List<String> get syncErrors => List.from(_syncErrors);
  String? get deviceId => _deviceId;

  /// Inisialisasi sync manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔄 SYNC: Initializing SyncManager...');

      // TODO: Initialize Workmanager for background tasks when available
      // await Workmanager().initialize(
      //   callbackDispatcher,
      //   isInDebugMode: false, // Atur to false in production
      // );

      // Pengaturan periodic sync (manual for now)
      await _setupPeriodicSync();

      // Pengaturan connectivity monitoring
      await _setupConnectivityMonitoring();

      // Pengaturan real-time listeners for multi-device sync
      await _setupRealtimeListeners();

      // Muat sync state
      await _loadSyncState();

      // Ambil or generate device ID
      _deviceId = await _getDeviceId();

      _isInitialized = true;
      print('✅ SYNC: SyncManager initialized fully');
    } catch (e) {
      print('❌ SYNC:  to initialize SyncManager: $e');
      rethrow;
    }
  }

  /// Pengaturan periodic background sync
  Future<void> _setupPeriodicSync() async {
    try {
      // TODO: Setup background sync when workmanager is available
      // For now, we'll rely on manual sync triggers

      // Batal existing task
      // await Workmanager().cancelByUniqueName(SYNC_TASK_NAME);

      // Register new periodic task
      // await Workmanager().registerPeriodicTask(
      //   SYNC_TASK_NAME,
      //   SYNC_TASK_NAME,
      //   frequency: Duration(minutes: SYNC_INTERVAL_MINUTES),
      //   constraints: Constraints(
      //     networkType: NetworkType.connected,
      //     requiresBatteryNotLow: true,
      //   ),
      // );

      print(
        '✅ SYNC: Periodic sync setup (manual mode) - sync every $SYNC_INTERVAL_MINUTES minutes',
      );
    } catch (e) {
      print('❌ SYNC:  to setup periodic sync: $e');
    }
  }

  /// Pengaturan connectivity monitoring
  Future<void> _setupConnectivityMonitoring() async {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      if (result != ConnectivityResult.none) {
        print('📶 SYNC: Internet connection restored, starting sync...');
        _performSync();
      }
    });
  }

  /// Muat sync state from local storage
  Future<void> _loadSyncState() async {
    try {
      final prefs = await _databaseService.getSettings();
      final lastSyncStr = prefs['last_sync_time'];
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.tryParse(lastSyncStr);
      }

      final lastDownloadStr = prefs['last_download_time'];
      if (lastDownloadStr != null) {
        _lastDownloadTime = DateTime.tryParse(lastDownloadStr);
      }

      final pendingStr = prefs['pending_uploads'];
      if (pendingStr != null) {
        _pendingUploads = int.tryParse(pendingStr) ?? 0;
      }

      final newUpdatesStr = prefs['new_updates_from_others'];
      if (newUpdatesStr != null) {
        _newUpdatesFromOthers = int.tryParse(newUpdatesStr) ?? 0;
      }

      final errorsStr = prefs['sync_errors'];
      if (errorsStr != null) {
        final errorsList = jsonDecode(errorsStr) as List;
        _syncErrors = errorsList.cast<String>();
      }
    } catch (e) {
      print('⚠️ SYNC:  to load sync state: $e');
    }
  }

  /// Simpan sync state to local storage
  Future<void> _saveSyncState() async {
    try {
      await _databaseService.setSetting(
        'last_sync_time',
        _lastSyncTime?.toIso8601String() ?? '',
      );
      await _databaseService.setSetting(
        'last_download_time',
        _lastDownloadTime?.toIso8601String() ?? '',
      );
      await _databaseService.setSetting(
        'pending_uploads',
        _pendingUploads.toString(),
      );
      await _databaseService.setSetting(
        'new_updates_from_others',
        _newUpdatesFromOthers.toString(),
      );
      await _databaseService.setSetting('sync_errors', jsonEncode(_syncErrors));
    } catch (e) {
      print('⚠️ SYNC:  to save sync state: $e');
    }
  }

  /// Perform manual sync
  Future<bool> forceSyncNow() async {
    if (_isSyncing) {
      print('⚠️ SYNC: Sync already in progress');
      return false;
    }

    print('🔄 SYNC: Starting manual sync...');
    return await _performSync();
  }

  /// Immediate upload after data save - lightweight sync
  Future<bool> triggerImmediateUpload() async {
    if (_isSyncing) {
      print('⚠️ SYNC: Sync in progress, skipping immediate upload');
      return false;
    }

    try {
      // Cek internet connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('❌ SYNC: No internet connection for immediate upload');
        return false;
      }

      print('🚀 SYNC: Starting immediate upload...');

      // Only upload recent data (last 1 hour)
      final recentCutoff = DateTime.now().subtract(Duration(hours: 1));
      final recentLogsheets = await _databaseService.getLogsheetHistoryForSync(
        limit: 10,
        since: recentCutoff,
      );

      if (recentLogsheets.isEmpty) {
        print('📤 SYNC: No recent data to upload');
        return true;
      }

      print('📤 SYNC: Uploading ${recentLogsheets.length} recent logsheets...');

      int uploaded = 0;
      for (final logsheet in recentLogsheets) {
        try {
          await _uploadLogsheetToFirestore(logsheet);
          uploaded++;
        } catch (e) {
          print(
            '❌ SYNC: Failed to upload recent logsheet ${logsheet['id']}: $e',
          );
        }
      }

      print(
        '✅ SYNC: Immediate upload completed - uploaded $uploaded logsheets',
      );
      return uploaded > 0;
    } catch (e) {
      print('❌ SYNC: Immediate upload : $e');
      return false;
    }
  }

  /// Internal sync logic
  Future<bool> _performSync() async {
    if (_isSyncing) return false;

    _isSyncing = true;
    bool success = false;

    try {
      // Cek internet connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('❌ SYNC: No internet connection');
        return false;
      }

      print('🔄 SYNC: Starting sync process...');

      // Step 1: Upload pending logsheets
      await _uploadPendingLogsheets();

      // Step 2: Download updates from other devices (if not using real-time listeners)
      if (!_isListening) {
        await downloadUpdatesFromOthers();
      }

      // Step 3: Cleanup old data
      await _cleanupOldData();

      // Step 4: Update sync state
      _lastSyncTime = DateTime.now();
      await _saveSyncState();

      success = true;
      print('✅ SYNC: Sync completed fully');
    } catch (e) {
      print('❌ SYNC: Sync : $e');
      _addSyncError('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }

    return success;
  }

  /// Upload pending logsheets to Firestore
  Future<void> _uploadPendingLogsheets() async {
    try {
      print('📤 SYNC: Uploading pending logsheets...');

      // Ambil logsheets from last 7 days
      final cutoffDate = DateTime.now().subtract(Duration(days: 7));
      final logsheets = await _databaseService.getLogsheetHistoryForSync(
        limit: 1000,
        since: cutoffDate,
      );

      print('📊 SYNC: Found ${logsheets.length} logsheets to sync');

      int uploaded = 0;
      for (final logsheet in logsheets) {
        try {
          await _uploadLogsheetToFirestore(logsheet);
          uploaded++;
        } catch (e) {
          print('❌ SYNC: Failed to upload logsheet ${logsheet['id']}: $e');
          _addSyncError('Upload failed for logsheet ${logsheet['id']}');
        }
      }

      _pendingUploads = logsheets.length - uploaded;
      print('✅ SYNC: Uploaded $uploaded logsheets, ${_pendingUploads} pending');
    } catch (e) {
      print('❌ SYNC:  to upload logsheets: $e');
      _addSyncError('Upload logsheets failed: $e');
    }
  }

  /// Upload single logsheet to Firestore
  Future<void> _uploadLogsheetToFirestore(Map<String, dynamic> logsheet) async {
    final generatorName = logsheet['generator_name'];
    final collectionName = FirestoreCollectionUtils.getCollectionName(
      generatorName,
    );

    final docId = '${logsheet['date']}_${logsheet['created_at']}';

    final firestoreData = {
      'generatorName': generatorName,
      'date': logsheet['date'],
      'data': logsheet['data'], // Already a Map from _convertRowToLogsheetData
      'syncedAt': FieldValue.serverTimestamp(),
      'deviceId': await _getDeviceId(),
      'version': 1,
    };

    print('📤 SYNC: Uploading to collection: $collectionName, docId: $docId');

    await _firestore
        .collection(collectionName)
        .doc(docId)
        .set(firestoreData, SetOptions(merge: true));
  }

  /// Bersihkanup old data (both local and cloud)
  Future<void> _cleanupOldData() async {
    try {
      print('🧹 SYNC: Cleaning up old data...');

      final cutoffDate = DateTime.now().subtract(
        Duration(days: DATA_RETENTION_DAYS),
      );

      // Bersihkanup local data (older than retention period)
      await _databaseService.cleanupOldData(cutoffDate);

      // Bersihkanup Firestore data
      await _cleanupFirestoreData(cutoffDate);

      print('✅ SYNC: Cleanup completed');
    } catch (e) {
      print('❌ SYNC: Cleanup : $e');
      _addSyncError('Cleanup failed: $e');
    }
  }

  /// Bersihkanup old Firestore data
  Future<void> _cleanupFirestoreData(DateTime cutoffDate) async {
    try {
      final cutoffDateStr =
          '${cutoffDate.year.toString().padLeft(4, '0')}-${cutoffDate.month.toString().padLeft(2, '0')}-${cutoffDate.day.toString().padLeft(2, '0')}';

      // Bersihkanup from all generator collections
      final collections = FirestoreCollectionUtils.getAllCollectionNames();

      for (final collectionName in collections) {
        print('🧹 SYNC: Cleaning up collection: $collectionName');

        final query = await _firestore
            .collection(collectionName)
            .where('date', isLessThan: cutoffDateStr)
            .limit(500) // Batch limit
            .get();

        final batch = _firestore.batch();
        for (final doc in query.docs) {
          batch.delete(doc.reference);
        }

        if (query.docs.isNotEmpty) {
          await batch.commit();
          print(
            '🗑️ SYNC: Deleted ${query.docs.length} old documents from $collectionName',
          );
        }
      }
    } catch (e) {
      print('❌ SYNC: Firestore cleanup : $e');
    }
  }

  /// Ambil device ID for tracking
  Future<String> _getDeviceId() async {
    // For now, use a simple timestamp-based ID
    // In production, you might want to use a more sophisticated device ID
    final prefs = await _databaseService.getSettings();
    String? deviceId = prefs['device_id'];

    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await _databaseService.setSetting('device_id', deviceId);
    }

    return deviceId;
  }

  /// Tambah sync error to tracking
  void _addSyncError(String error) {
    final timestamp = DateTime.now().toIso8601String();
    _syncErrors.add('[$timestamp] $error');

    // Keep only last 10 errors
    if (_syncErrors.length > 10) {
      _syncErrors.removeAt(0);
    }
  }

  /// Restore data from Firestore (for data recovery)
  Future<bool> restoreFromFirestore({DateTime? since}) async {
    try {
      print('📥 SYNC: Starting data restoration from Firestore...');

      final sinceDate = since ?? DateTime.now().subtract(Duration(days: 7));
      final sinceDateStr =
          '${sinceDate.year.toString().padLeft(4, '0')}-${sinceDate.month.toString().padLeft(2, '0')}-${sinceDate.day.toString().padLeft(2, '0')}';

      int restored = 0;

      // Query each generator collection
      for (final collectionName
          in FirestoreCollectionUtils.getAllCollectionNames()) {
        print('📥 SYNC: Restoring from collection: $collectionName');

        final query = await _firestore
            .collection(collectionName)
            .where('date', isGreaterThanOrEqualTo: sinceDateStr)
            .orderBy('date', descending: true)
            .limit(250) // 250 per collection = 1000 total max
            .get();

        for (final doc in query.docs) {
          try {
            final data = doc.data();
            await _restoreLogsheetFromFirestore(data);
            restored++;
          } catch (e) {
            print('❌ SYNC:  to restore document ${doc.id}: $e');
          }
        }
      }

      print('✅ SYNC: Restored $restored logsheets from Firestore');
      return true;
    } catch (e) {
      print('❌ SYNC: Data restoration : $e');
      return false;
    }
  }

  /// Restore single logsheet from Firestore data
  Future<void> _restoreLogsheetFromFirestore(Map<String, dynamic> data) async {
    await _databaseService.saveLogsheetFromFirestore(
      data['generatorName'],
      data['date'],
      data['data'],
    );
  }

  /// Pengaturan real-time listeners for multi-device sync
  Future<void> _setupRealtimeListeners() async {
    try {
      print('👂 SYNC: Setting up real-time listeners...');

      // Dengar to all generator collections for updates in the last 7 days
      final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));
      final dateStr = sevenDaysAgo.toIso8601String().split('T')[0];

      // Note: We'll listen to mitsubishi_1 for now as a primary collection
      // In the future, we could set up separate listeners for each collection
      _firestoreListener = _firestore
          .collection('mitsubishi_1')
          .where('date', isGreaterThanOrEqualTo: dateStr)
          .snapshots()
          .listen(
            _handleFirestoreUpdates,
            onError: (error) {
              print('❌ SYNC: Firestore listener error: $error');
              _addSyncError('Real-time sync error: $error');
            },
          );

      _isListening = true;
      print('✅ SYNC: Real-time listeners active');
    } catch (e) {
      print('❌ SYNC:  to setup real-time listeners: $e');
      _addSyncError('Failed to setup real-time sync: $e');
    }
  }

  /// Tangani real-time updates from Firestore
  Future<void> _handleFirestoreUpdates(QuerySnapshot snapshot) async {
    if (_deviceId == null) return;

    try {
      int newUpdates = 0;

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          // Skip updates from this device
          final sourceDeviceId = data['deviceId'] as String?;
          if (sourceDeviceId == _deviceId) continue;

          // Cek if this is a newer update
          final firestoreTimestamp = data['syncedAt'] as Timestamp?;
          if (firestoreTimestamp != null) {
            final updateTime = firestoreTimestamp.toDate();
            final lastDownload = _lastDownloadTime ?? DateTime(2000);

            if (updateTime.isAfter(lastDownload)) {
              await _processIncomingUpdate(data);
              newUpdates++;
            }
          }
        }
      }

      if (newUpdates > 0) {
        _newUpdatesFromOthers += newUpdates;
        _lastDownloadTime = DateTime.now();
        await _saveSyncState();

        print('🔄 SYNC: Received $newUpdates updates from other devices');
      }
    } catch (e) {
      print('❌ SYNC:  to handle Firestore updates: $e');
      _addSyncError('Failed to process updates from other devices: $e');
    }
  }

  /// Proses incoming update from another device
  Future<void> _processIncomingUpdate(Map<String, dynamic> data) async {
    try {
      // Cek if we already have this data locally
      // For now, we'll always update to ensure latest data
      // TODO: Implementasi proper conflict resolution based on timestamps

      await _restoreLogsheetFromFirestore(data);
      print('📥 SYNC: Updated local data from device ${data['deviceId']}');
    } catch (e) {
      print('❌ SYNC:  to process incoming update: $e');
    }
  }

  /// Download and sync updates from other devices
  Future<bool> downloadUpdatesFromOthers() async {
    if (_isSyncing) {
      print('⚠️ SYNC: Already syncing, skipping download updates');
      return false;
    }

    _isSyncing = true;

    try {
      print('📥 SYNC: Downloading updates from other devices...');

      final lastDownload =
          _lastDownloadTime ?? DateTime.now().subtract(Duration(days: 7));

      int totalDownloaded = 0;

      // Download from all generator collections
      final collections = FirestoreCollectionUtils.getAllCollectionNames();

      for (final collectionName in collections) {
        print('📥 SYNC:  collection: $collectionName');

        final query = await _firestore
            .collection(collectionName)
            .where('syncedAt', isGreaterThan: Timestamp.fromDate(lastDownload))
            .orderBy('syncedAt', descending: true)
            .limit(200)
            .get();

        int downloaded = 0;
        for (final doc in query.docs) {
          final data = doc.data();

          // Skip our own updates
          if (data['deviceId'] == _deviceId) continue;

          await _processIncomingUpdate(data);
          downloaded++;
        }

        totalDownloaded += downloaded;
        print('📥 SYNC: Downloaded $downloaded updates from $collectionName');
      }

      _lastDownloadTime = DateTime.now();
      _newUpdatesFromOthers = 0; // Reset counter after manual download
      await _saveSyncState();

      print('✅ SYNC: Downloaded $totalDownloaded updates from other devices');
      return true;
    } catch (e) {
      print('❌ SYNC:  to download updates: $e');
      _addSyncError('Download updates failed: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Mark updates as seen (reset counter)
  void markUpdatesAsSeen() {
    _newUpdatesFromOthers = 0;
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _firestoreListener?.cancel();
    _isListening = false;
    // TODO: Cancel background tasks when workmanager is available
    // Workmanager().cancelAll();
  }
}

/// Background task callback (disabled for now)
// @pragma('vm:entry-point')
// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     try {
//       print('🔄 BACKGROUND: Executing sync task: $task');
      
//       // For background tasks, we need to initialize Firebase again
//       // This is a simplified version - in production you might want more robust handling
//       await SyncManager.instance._performSync();
      
//       return Future.value(true);
//     } catch (e) {
//       print('❌ BACKGROUND: Task : $e');
//       return Future.value(false);
//     }
//   });
// }
