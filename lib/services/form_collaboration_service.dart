import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'auth_service.dart';

/// Service untuk real-time collaboration di form logsheet
class FormCollaborationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _activeSessionsCollection = 'active_form_sessions';
  static const String _formDraftsCollection = 'form_drafts';

  /// Model untuk active session
  static Map<String, dynamic> _createSessionData({
    required String generatorName,
    required int hour,
    required String userName,
    required String userUid,
    String? fileId,
  }) {
    return {
      'generatorName': generatorName,
      'hour': hour,
      'userName': userName,
      'userUid': userUid,
      'fileId': fileId,
      'startedAt': FieldValue.serverTimestamp(),
      'lastActivity': FieldValue.serverTimestamp(),
      'status': 'editing', // editing, saving, completed
    };
  }

  /// Mulai editing session (claim form)
  static Future<bool> startEditingSession({
    required String generatorName,
    required int hour,
    String? fileId,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) return false;

      final sessionId = '${generatorName}_${hour}';

      // Cek apakah ada user lain yang sedang edit
      final existingSession = await _firestore
          .collection(_activeSessionsCollection)
          .doc(sessionId)
          .get();

      if (existingSession.exists) {
        final data = existingSession.data()!;
        final lastActivity = (data['lastActivity'] as Timestamp?)?.toDate();
        final otherUserUid = data['userUid'] as String?;

        // Jika ada aktivitas dalam 5 menit terakhir dan bukan user yang sama
        if (lastActivity != null &&
            otherUserUid != currentUser.uid &&
            DateTime.now().difference(lastActivity).inMinutes < 5) {
          print(
            '⚠️ COLLABORATION: Form sedang diedit oleh ${data['userName']}',
          );
          return false; // Form sedang digunakan
        }
      }

      // Claim form untuk user ini
      await _firestore
          .collection(_activeSessionsCollection)
          .doc(sessionId)
          .set(
            _createSessionData(
              generatorName: generatorName,
              hour: hour,
              userName: currentUser.displayName,
              userUid: currentUser.uid,
              fileId: fileId,
            ),
          );

      print(
        '✅ COLLABORATION: Sesi editing dimulai for $generatorName hour $hour',
      );
      return true;
    } catch (e) {
      print('❌ COLLABORATION:  starting editing session: $e');
      return false;
    }
  }

  /// Update last activity (heartbeat)
  static Future<void> updateActivity({
    required String generatorName,
    required int hour,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) return;

      final sessionId = '${generatorName}_${hour}';

      await _firestore
          .collection(_activeSessionsCollection)
          .doc(sessionId)
          .update({'lastActivity': FieldValue.serverTimestamp()});
    } catch (e) {
      print('❌ COLLABORATION:  updating activity: $e');
    }
  }

  /// Selesai editing session
  static Future<void> endEditingSession({
    required String generatorName,
    required int hour,
  }) async {
    try {
      final sessionId = '${generatorName}_${hour}';

      await _firestore
          .collection(_activeSessionsCollection)
          .doc(sessionId)
          .delete();

      print(
        '✅ COLLABORATION: Ended editing session for $generatorName hour $hour',
      );
    } catch (e) {
      print('❌ COLLABORATION:  ending editing session: $e');
    }
  }

  /// Dengar for other users editing the same form
  static StreamSubscription<DocumentSnapshot>? listenForCollaborators({
    required String generatorName,
    required int hour,
    required Function(Map<String, dynamic>?) onCollaboratorUpdate,
  }) {
    final sessionId = '${generatorName}_${hour}';

    return _firestore
        .collection(_activeSessionsCollection)
        .doc(sessionId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            onCollaboratorUpdate(data);
          } else {
            onCollaboratorUpdate(null);
          }
        });
  }

  /// Simpan form draft for real-time sharing
  static Future<void> saveFormDraft({
    required String generatorName,
    required int hour,
    required Map<String, dynamic> formData,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) return;

      final draftId = '${generatorName}_${hour}';

      await _firestore.collection(_formDraftsCollection).doc(draftId).set({
        'generatorName': generatorName,
        'hour': hour,
        'formData': formData,
        'lastModifiedBy': currentUser.displayName,
        'lastModifiedByUid': currentUser.uid,
        'lastModified': FieldValue.serverTimestamp(),
      });

      print('💾 : Saved draft for $generatorName hour $hour');
    } catch (e) {
      print('❌ COLLABORATION:  saving draft: $e');
    }
  }

  /// Muat form draft
  static Future<Map<String, dynamic>?> loadFormDraft({
    required String generatorName,
    required int hour,
  }) async {
    try {
      final draftId = '${generatorName}_${hour}';

      final doc = await _firestore
          .collection(_formDraftsCollection)
          .doc(draftId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        print('📖 : Loaded draft for $generatorName hour $hour');
        return data;
      }
      return null;
    } catch (e) {
      print('❌ COLLABORATION:  loading draft: $e');
      return null;
    }
  }

  /// Dengar for form draft changes (real-time collaboration)
  static StreamSubscription<DocumentSnapshot>? listenForDraftChanges({
    required String generatorName,
    required int hour,
    required Function(Map<String, dynamic>?) onDraftUpdate,
  }) {
    final draftId = '${generatorName}_${hour}';

    return _firestore
        .collection(_formDraftsCollection)
        .doc(draftId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            onDraftUpdate(data);
          } else {
            onDraftUpdate(null);
          }
        });
  }

  /// Bersihkan up old sessions and drafts
  static Future<void> cleanupOldSessions() async {
    try {
      final cutoffTime = DateTime.now().subtract(Duration(minutes: 10));

      // Bersihkan up old sessions
      final oldSessions = await _firestore
          .collection(_activeSessionsCollection)
          .where('lastActivity', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();

      for (final doc in oldSessions.docs) {
        await doc.reference.delete();
      }

      // Bersihkan up old drafts (older than 24 hours)
      final oldDraftsCutoff = DateTime.now().subtract(Duration(hours: 24));
      final oldDrafts = await _firestore
          .collection(_formDraftsCollection)
          .where(
            'lastModified',
            isLessThan: Timestamp.fromDate(oldDraftsCutoff),
          )
          .get();

      for (final doc in oldDrafts.docs) {
        await doc.reference.delete();
      }

      print(
        '🧹 COLLABORATION: Cleaned up ${oldSessions.docs.length} old sessions and ${oldDrafts.docs.length} old drafts',
      );
    } catch (e) {
      print('❌ COLLABORATION:  cleaning up: $e');
    }
  }

  /// Cek if form is locked by another user
  static Future<Map<String, dynamic>?> checkFormLock({
    required String generatorName,
    required int hour,
  }) async {
    try {
      final sessionId = '${generatorName}_${hour}';
      final currentUser = await AuthService.getCurrentUser();

      final doc = await _firestore
          .collection(_activeSessionsCollection)
          .doc(sessionId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final lastActivity = (data['lastActivity'] as Timestamp?)?.toDate();
        final otherUserUid = data['userUid'] as String?;

        // Jika ada aktivitas dalam 5 menit terakhir dan bukan user yang sama
        if (lastActivity != null &&
            otherUserUid != currentUser?.uid &&
            DateTime.now().difference(lastActivity).inMinutes < 5) {
          return {
            'isLocked': true,
            'lockedBy': data['userName'],
            'lockedByUid': data['userUid'],
            'lockedAt': lastActivity,
            'minutesAgo': DateTime.now().difference(lastActivity).inMinutes,
          };
        }
      }

      return null; // Form tidak terkunci
    } catch (e) {
      print('❌ COLLABORATION: Error  form lock: $e');
      return null;
    }
  }

  /// Force unlock form (untuk admin)
  static Future<void> forceUnlockForm({
    required String generatorName,
    required int hour,
  }) async {
    try {
      final sessionId = '${generatorName}_${hour}';

      await _firestore
          .collection(_activeSessionsCollection)
          .doc(sessionId)
          .delete();

      print('🔓 : Force unlocked form $generatorName hour $hour');
    } catch (e) {
      print('❌ COLLABORATION:  force unlocking form: $e');
    }
  }
}
