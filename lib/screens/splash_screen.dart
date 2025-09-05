import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/firebase_user_model.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      print('🔍 SPLASH: Checking login status...');

      // Add delay untuk splash effect
      await Future.delayed(const Duration(seconds: 2));

      // Check login status
      final FirebaseUserModel? user = await AuthService.getCurrentUser();

      if (!mounted) return;

      if (user != null) {
        print('✅ SPLASH: Auto-login successful for ${user.username}');
        // User sudah login, ke MainNavigationScreen dengan navbar
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      } else {
        print('🔐 SPLASH: No valid session, redirecting to login');
        // User belum login, ke login screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      print('❌ SPLASH: Error checking login status: $e');
      // Error, redirect ke login untuk safety
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.flash_on,
                color: Color(0xFF1E3A8A),
                size: 60,
              ),
            ),
            const SizedBox(height: 32),

            // App Title
            const Text(
              'Power Plant Logsheet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            const Text(
              'Monitoring Generator Mitsubishi',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 48),

            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 24),

            // Loading Text
            const Text(
              'Memuat aplikasi...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
