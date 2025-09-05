import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/firebase_user_model.dart';

/// AuthService dengan Firebase Authentication
/// Menggantikan sistem login lama dengan autentikasi yang aman
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========================================================================
  // AUTHENTICATION METHODS
  // ========================================================================

  /// Login dengan username dan password
  /// Username akan dikonversi ke format email (username@pltd.com)
  static Future<FirebaseUserModel?> login(
    String username,
    String password,
  ) async {
    try {
      print('🔐 AUTH: Attempting login for: $username');

      // Konversi username ke email format
      final email = _convertUsernameToEmail(username);
      print('🔐 AUTH: Using email: $email');

      // Firebase Authentication
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        final uid = userCredential.user!.uid;
        print('🔐 AUTH: Firebase login ful, UID: $uid');

        // Ambil user profile dari Firestore
        final userProfile = await _getUserProfile(uid);

        if (userProfile != null) {
          // Update last login
          await _updateLastLogin(uid);

          // Simpan session
          await _saveUserSession(userProfile);

          print('✅ AUTH: Login berhasil untuk ${userProfile.displayName}');
          return userProfile;
        } else {
          print('❌ AUTH: User profile tidak ditemukan');
          await _auth.signOut();
          return null;
        }
      }

      return null;
    } on FirebaseAuthException catch (e) {
      print('❌ AUTH: Firebase Auth : ${e.code} - ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          print('💡 AUTH: User tidak terdaftar dalam sistem');
          break;
        case 'wrong-password':
          print('💡 AUTH: Password salah');
          break;
        case 'invalid-email':
          print('💡 AUTH: Format email tidak valid');
          break;
        case 'user-disabled':
          print('💡 AUTH: Akun user telah dinonaktifkan');
          break;
        case 'too-many-requests':
          print('💡 AUTH: Terlalu banyak percobaan login');
          break;
        default:
          print('💡 AUTH:  tidak dikenal: ${e.code}');
      }
      return null;
    } catch (e) {
      print('❌ AUTH: Unexpected : $e');
      return null;
    }
  }

  /// Logout user
  static Future<void> logout() async {
    try {
      await _auth.signOut();
      await _clearUserSession();
      print('✅ AUTH: Logout berhasil');
    } catch (e) {
      print('❌ AUTH:  during logout: $e');
    }
  }

  /// Cek if user is currently logged in
  static Future<bool> isLoggedIn() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Verify session
      final prefs = await SharedPreferences.getInstance();
      final userUid = prefs.getString('user_uid');
      return userUid != null;
    } catch (e) {
      print('❌ AUTH: Error  login status: $e');
      return false;
    }
  }

  /// Ambil current user profile
  static Future<FirebaseUserModel?> getCurrentUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      return await _getUserProfile(currentUser.uid);
    } catch (e) {
      print('❌ AUTH:  getting current user: $e');
      return null;
    }
  }

  /// Ambil saved session
  static Future<FirebaseUserModel?> getSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString('user_session');

      if (sessionData != null) {
        // Parse JSON string untuk mendapatkan user data
        return null; // Sementara return null, nanti akan diperbaiki dengan proper JSON parsing
      }

      return null;
    } catch (e) {
      print('❌ AUTH:  getting saved session: $e');
      return null;
    }
  }

  // ========================================================================
  // PRIVATE HELPER METHODS
  // ========================================================================

  /// Ubah username to email format for Firebase Auth
  static String _convertUsernameToEmail(String username) {
    if (username.contains('@')) {
      return username; // Already email format
    }
    return '$username@pltd.com';
  }

  /// Ambil user profile dari Firestore berdasarkan berbagai metode pencarian
  static Future<FirebaseUserModel?> _getUserProfile(String uid) async {
    try {
      print('👤 AUTH: Getting user profile for UID: $uid');

      // Method 1: Cari berdasarkan UID (format standar Firebase)
      DocumentSnapshot doc = await _firestore
          .collection('user_profile')
          .doc(uid)
          .get();

      if (doc.exists) {
        print('✅ AUTH: Found user profile by UID');
        final data = doc.data();
        if (data != null && data is Map<String, dynamic>) {
          print(
            '👤 AUTH: User profile loaded: ${data['displayName'] ?? data['username']}',
          );
          return FirebaseUserModel.fromFirestore(data, uid);
        }
      }

      // Method 2: Cari berdasarkan email Firebase Auth (jika document ID = email)
      final currentUser = _auth.currentUser;
      if (currentUser?.email != null) {
        print(
          '👤 AUTH: Trying to find profile by email: ${currentUser!.email}',
        );

        doc = await _firestore
            .collection('user_profile')
            .doc(currentUser.email)
            .get();

        if (doc.exists) {
          print('✅ AUTH: Found user profile by email as document ID');
          final data = doc.data();
          if (data != null && data is Map<String, dynamic>) {
            print(
              '👤 AUTH: User profile loaded: ${data['displayName'] ?? data['username']}',
            );
            return FirebaseUserModel.fromFirestore(data, currentUser.email!);
          }
        }

        // Method 3: Query berdasarkan email field
        final querySnapshot = await _firestore
            .collection('user_profile')
            .where('email', isEqualTo: currentUser.email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          print('✅ AUTH: Found user profile by email query');
          final data = querySnapshot.docs.first.data();
          print(
            '👤 AUTH: User profile loaded: ${data['displayName'] ?? data['username']}',
          );
          return FirebaseUserModel.fromFirestore(
            data,
            querySnapshot.docs.first.id,
          );
        }
      }

      print('❌ AUTH: User profile not found in Firestore');
      print('💡 AUTH: Please create user profile manually in Firebase Console');
      return null;
    } catch (e) {
      print('❌ AUTH:  getting user profile: $e');
      return null;
    }
  }

  /// Update last login timestamp
  static Future<void> _updateLastLogin(String documentId) async {
    try {
      await _firestore.collection('user_profile').doc(documentId).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
      print('📅 AUTH: Last login updated');
    } catch (e) {
      print('❌ AUTH:  updating last login: $e');
    }
  }

  /// Simpan user session to local storage
  static Future<void> _saveUserSession(FirebaseUserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uid', user.uid);
      await prefs.setString('user_email', user.email);
      await prefs.setString('user_display_name', user.displayName);
      await prefs.setString('last_activity', DateTime.now().toIso8601String());
      print('💾 AUTH: User session saved');
    } catch (e) {
      print('❌ AUTH:  saving user session: $e');
    }
  }

  /// Bersihkan user session from local storage
  static Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_uid');
      await prefs.remove('user_email');
      await prefs.remove('user_display_name');
      await prefs.remove('last_activity');
      print('🧹 AUTH: User session cleared');
    } catch (e) {
      print('❌ AUTH:  clearing user session: $e');
    }
  }

  // ========================================================================
  // PASSWORD RESET
  // ========================================================================

  /// Send password reset email
  static Future<bool> sendPasswordResetEmail(String username) async {
    try {
      final email = _convertUsernameToEmail(username);
      await _auth.sendPasswordResetEmail(email: email);
      print('📧 AUTH: Password reset email sent to $email');
      return true;
    } catch (e) {
      print('❌ AUTH:  sending password reset email: $e');
      return false;
    }
  }

  // ========================================================================
  // USER MANAGEMENT (Admin only)
  // ========================================================================

  /// Buat new user (Admin only)
  static Future<bool> createUser({
    required String email,
    required String password,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      // This would require Firebase Admin SDK for production
      print('⚠️ AUTH: User creation requires Firebase Admin SDK');
      return false;
    } catch (e) {
      print('❌ AUTH:  creating user: $e');
      return false;
    }
  }

  /// Update user profile
  static Future<bool> updateUserProfile({
    required String documentId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _firestore
          .collection('user_profile')
          .doc(documentId)
          .update(updates);
      print('✅ AUTH: User profile updated');
      return true;
    } catch (e) {
      print('❌ AUTH:  updating user profile: $e');
      return false;
    }
  }

  // ========================================================================
  // DEBUG METHODS
  // ========================================================================

  /// Ambil current Firebase user info (for debugging)
  static Map<String, dynamic>? getFirebaseUserInfo() {
    final user = _auth.currentUser;
    if (user == null) return null;

    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'emailVerified': user.emailVerified,
      'creationTime': user.metadata.creationTime?.toIso8601String(),
      'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
    };
  }
}
