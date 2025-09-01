import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// Service sederhana untuk mencegah bentrok editing form logsheet
/// Hanya menggunakan collection 'editing_sessions' yang minimal
class SimpleCollaborationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _sessionsCollection = 'editing_sessions';

  /// Cek apakah form sedang diedit oleh user lain
  static Future<Map<String, dynamic>> checkIfEditing({
    required String generatorName,
    required int hour,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'canEdit': false, 'message': 'User tidak terautentikasi'};
      }

      final sessionId = '${generatorName}_$hour';
      final sessionDoc = await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        return {'canEdit': true, 'message': 'Form tersedia untuk diedit'};
      }

      final data = sessionDoc.data()!;
      final otherUserUid = data['userUid'] as String;
      final otherUserName = data['userName'] as String;
      final lastActivity = (data['lastActivity'] as Timestamp).toDate();

      // Jika user yang sama, boleh edit
      if (otherUserUid == currentUser.uid) {
        return {'canEdit': true, 'message': 'Melanjutkan editing Anda'};
      }

      // Jika sudah lebih dari 10 menit tidak ada aktivitas, anggap abandoned
      final minutesSinceLastActivity = DateTime.now()
          .difference(lastActivity)
          .inMinutes;
      if (minutesSinceLastActivity > 10) {
        return {'canEdit': true, 'message': 'Session sebelumnya timeout'};
      }

      return {
        'canEdit': false,
        'message': 'Sedang diedit oleh $otherUserName',
        'otherUser': otherUserName,
        'lastActivity': lastActivity.toIso8601String(),
      };
    } catch (e) {
      print('❌ COLLABORATION: Error checking edit status: $e');
      return {'canEdit': true, 'message': 'Error, melanjutkan editing'};
    }
  }

  /// Mulai session editing
  static Future<bool> startEditing({
    required String generatorName,
    required int hour,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) return false;

      final sessionId = '${generatorName}_$hour';

      await _firestore.collection(_sessionsCollection).doc(sessionId).set({
        'generatorName': generatorName,
        'hour': hour,
        'userUid': currentUser.uid,
        'userName': currentUser.email,
        'startedAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
      });

      print(
        '✅ COLLABORATION: Started editing session for $generatorName hour $hour',
      );
      return true;
    } catch (e) {
      print('❌ COLLABORATION: Error starting editing session: $e');
      return false;
    }
  }

  /// Update aktivitas terakhir (heartbeat)
  static Future<void> updateActivity({
    required String generatorName,
    required int hour,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) return;

      final sessionId = '${generatorName}_$hour';

      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ COLLABORATION: Error updating activity: $e');
    }
  }

  /// Akhiri session editing
  static Future<void> endEditing({
    required String generatorName,
    required int hour,
  }) async {
    try {
      final sessionId = '${generatorName}_$hour';

      await _firestore.collection(_sessionsCollection).doc(sessionId).delete();

      print(
        '✅ COLLABORATION: Ended editing session for $generatorName hour $hour',
      );
    } catch (e) {
      print('❌ COLLABORATION: Error ending editing session: $e');
    }
  }

  /// Cleanup sessions lama (> 1 jam)
  static Future<void> cleanupOldSessions() async {
    try {
      final oneHourAgo = DateTime.now().subtract(Duration(hours: 1));

      final query = await _firestore
          .collection(_sessionsCollection)
          .where('lastActivity', isLessThan: Timestamp.fromDate(oneHourAgo))
          .get();

      for (final doc in query.docs) {
        await doc.reference.delete();
      }

      if (query.docs.isNotEmpty) {
        print('🧹 COLLABORATION: Cleaned up ${query.docs.length} old sessions');
      }
    } catch (e) {
      print('❌ COLLABORATION: Error cleaning up sessions: $e');
    }
  }
}
