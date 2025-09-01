/// DEPRECATED: Legacy user service with hardcoded credentials
/// This service has been replaced by Firebase Authentication (AuthService)
/// 
/// The old system used hardcoded credentials:
/// - Manager: supri/12345
/// - Leaders: leader1, leader2/shift123  
/// - Operators: operator1-3/op123
///
/// New system uses Firebase Auth with username->email conversion:
/// - dimas -> dimas@pltd.com
/// - All authentication through Firebase
/// - User profiles stored in Firestore
/// - Secure authentication without hardcoded passwords
///
/// TODO: Remove this file after confirming Firebase Auth is working

import 'package:shared_preferences/shared_preferences.dart';

@deprecated
class UserService {
  static const String _usersKey = 'app_users';
  static const String _currentUserKey = 'current_user';
  static const String _lastActivityKey = 'last_activity';

  /// DEPRECATED: Use AuthService.login() instead
  @deprecated
  static Future<dynamic> authenticateUser(
    String username,
    String password,
  ) async {
    print('⚠️ UserService.authenticateUser() is deprecated.');
    print('🔄 Please use AuthService.login() instead for Firebase authentication.');
    return null;
  }

  /// DEPRECATED: Use Firebase Auth instead
  @deprecated
  static Future<void> initializeUsers() async {
    print('⚠️ UserService.initializeUsers() is deprecated.');
    print('🔄 Firebase Auth handles user initialization automatically.');
  }

  /// DEPRECATED: Use Firebase Auth instead  
  @deprecated
  static List<dynamic> getDefaultUsers() {
    print('⚠️ UserService.getDefaultUsers() is deprecated.');
    print('🔄 User data is now stored in Firestore.');
    return [];
  }

  /// Clean up old user data
  static Future<void> cleanupOldUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_usersKey);
      await prefs.remove(_currentUserKey);
      await prefs.remove(_lastActivityKey);
      print('🧹 Old user data cleaned up successfully');
    } catch (e) {
      print('❌ Error cleaning up old user data: $e');
    }
  }
}
