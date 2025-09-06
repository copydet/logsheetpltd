import 'package:cloud_firestore/cloud_firestore.dart';
import 'storage_service.dart';

class FileIdSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Menyimpan file ID baru ke Firestore ketika spreadsheet dibuat
  static Future<void> saveFileIdToFirestore({
    required String generatorName,
    required String fileId,
    required String createdBy,
  }) async {
    try {
      print(
        '💾 FILE_SYNC: Saving fileId to Firestore for $generatorName: $fileId',
      );

      await _firestore.collection('generator_file_ids').doc(generatorName).set({
        'fileId': fileId,
        'generatorName': generatorName,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print(
        '✅ FILE_SYNC: Successfully saved fileId to Firestore for $generatorName',
      );

      // Juga simpan ke local storage untuk backup
      await StorageService.saveActiveFileId(generatorName, fileId);
      print(
        '✅ FILE_SYNC: Also saved fileId to local storage for $generatorName',
      );
    } catch (e) {
      print(
        '❌ FILE_SYNC: Error saving fileId to Firestore for $generatorName: $e',
      );
      rethrow;
    }
  }

  /// Mengambil file ID dari Firestore dan menyinkronkan ke local storage
  static Future<String?> getFileIdFromFirestore(String generatorName) async {
    try {
      print('📥 FILE_SYNC: Getting fileId from Firestore for $generatorName');

      final doc = await _firestore
          .collection('generator_file_ids')
          .doc(generatorName)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final fileId = data['fileId'] as String?;

        if (fileId != null && fileId.isNotEmpty) {
          print(
            '✅ FILE_SYNC: Found fileId in Firestore for $generatorName: $fileId',
          );

          // Simpan ke local storage untuk caching
          await StorageService.saveActiveFileId(generatorName, fileId);
          print(
            '✅ FILE_SYNC: Synced fileId to local storage for $generatorName',
          );

          return fileId;
        }
      }

      print('⚠️ FILE_SYNC: No fileId found in Firestore for $generatorName');
      return null;
    } catch (e) {
      print(
        '❌ FILE_SYNC: Error getting fileId from Firestore for $generatorName: $e',
      );
      return null;
    }
  }

  /// Mengambil file ID dengan prioritas: Firestore → Local Storage (anti-circular)
  static Future<String?> getConsistentFileId(String generatorName) async {
    try {
      print('🔄 FILE_SYNC: Getting consistent fileId for $generatorName');

      // 1. Coba ambil dari Firestore dulu (sumber kebenaran)
      String? firestoreFileId = await getFileIdFromFirestore(generatorName);
      if (firestoreFileId != null) {
        print(
          '✅ FILE_SYNC: Using Firestore fileId for $generatorName: $firestoreFileId',
        );
        return firestoreFileId;
      }

      print('❌ FILE_SYNC: No fileId found for $generatorName in Firestore');
      return null;
    } catch (e) {
      print(
        '❌ FILE_SYNC: Error getting consistent fileId for $generatorName: $e',
      );
      return null;
    }
  }

  /// Sinkronisasi semua file IDs dari Firestore ke local storage
  static Future<void> syncAllFileIdsFromFirestore() async {
    try {
      print('🔄 FILE_SYNC: Syncing all fileIds from Firestore...');

      final snapshot = await _firestore.collection('generator_file_ids').get();

      int syncedCount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final generatorName = data['generatorName'] as String?;
        final fileId = data['fileId'] as String?;

        if (generatorName != null && fileId != null) {
          await StorageService.saveActiveFileId(generatorName, fileId);
          syncedCount++;
          print('✅ FILE_SYNC: Synced $generatorName → $fileId');
        }
      }

      print(
        '✅ FILE_SYNC: Successfully synced $syncedCount fileIds from Firestore',
      );
    } catch (e) {
      print('❌ FILE_SYNC: Error syncing fileIds from Firestore: $e');
    }
  }

  /// Cek apakah file ID untuk generator sudah ada di Firestore
  static Future<bool> fileIdExistsInFirestore(String generatorName) async {
    try {
      final doc = await _firestore
          .collection('generator_file_ids')
          .doc(generatorName)
          .get();
      return doc.exists && doc.data()?['fileId'] != null;
    } catch (e) {
      print(
        '❌ FILE_SYNC: Error checking fileId existence for $generatorName: $e',
      );
      return false;
    }
  }

  /// Hapus file ID dari Firestore (untuk debugging/maintenance)
  static Future<void> deleteFileIdFromFirestore(String generatorName) async {
    try {
      await _firestore
          .collection('generator_file_ids')
          .doc(generatorName)
          .delete();
      print('🗑️ FILE_SYNC: Deleted fileId for $generatorName from Firestore');
    } catch (e) {
      print('❌ FILE_SYNC: Error deleting fileId for $generatorName: $e');
    }
  }
}
