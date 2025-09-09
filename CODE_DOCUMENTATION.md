# 📱 Flutter Logsheet PLTD - Dokumentasi Kode Lengkap

> **Sistem Manajemen Logsheet Pembangkit Listrik Tenaga Diesel**  
> Aplikasi Flutter dengan sinkronisasi real-time cross-device menggunakan Firebase Firestore dan Google Sheets

## 📋 Daftar Isi

- [🏗️ Struktur Arsitektur](#struktur-arsitektur)
- [📱 Entry Point & Configuration](#entry-point--configuration)
- [🔧 Services Layer](#services-layer)
- [📊 Models & Data Layer](#models--data-layer)
- [🖥️ Screens & UI Layer](#screens--ui-layer)
- [🧩 Widgets & Components](#widgets--components)
- [⚡ Utils & Helpers](#utils--helpers)

---

## 🏗️ Struktur Arsitektur

Aplikasi ini menggunakan **Clean Architecture** dengan pembagian layer yang jelas:

```
lib/
├── 📱 main.dart                   # Entry point aplikasi
├── 🔧 app.dart                    # Aplikasi root widget
├── 📦 app_exports.dart            # Barrel exports untuk import mudah
├── 🔥 firebase_options.dart       # Konfigurasi Firebase
├── 
├── ⚙️  config/                    # Konfigurasi aplikasi
├── 🎯 constants/                  # Konstanta dan konfigurasi
├── 👨‍💼 managers/                   # Business logic managers
├── 📊 models/                     # Data models dan entitas
├── 🖥️  screens/                   # Layar/halaman aplikasi
├── 🔧 services/                   # Layer service dan API
├── ⚡ utils/                      # Utility functions dan helpers
└── 🧩 widgets/                    # Reusable UI components
```

---

## 📱 Entry Point & Configuration

### 🚀 main.dart
**Fungsi**: Entry point aplikasi dengan konfigurasi Firebase dan inisialisasi sistem

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_exports.dart';
import 'services/migration_service.dart';
import 'services/sync_manager.dart';

void main() async {
  // Pastikan Flutter binding telah diinisialisasi
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  print('APLIKASI: Memulai Firebase...');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('APLIKASI: Firebase sudah siap');
  } catch (e) {
    print('APLIKASI: Firebase gagal dimulai: $e');
  }

  // Inisialisasi migrasi SQLite
  print('APLIKASI: Memulai migrasi database...');
  final migrationSuccess = await MigrationService.migrateToSQLite();

  if (migrationSuccess) {
    print('APLIKASI: Migrasi database selesai');
  } else {
    print(
      '❌ APLIKASI: Migrasi SQLite gagal, akan dicoba ulang saat aplikasi digunakan',
    );
  }

  // Inisialisasi Sync Manager
  print('APLIKASI: Memulai sync manager...');
  try {
    await SyncManager.instance.initialize();
    print('APLIKASI: Sync manager sudah siap');
  } catch (e) {
    print('APLIKASI: Sync manager gagal dimulai: $e');
  }

  runApp(const PowerPlantLogsheetApp());
}
```

### 🔧 app.dart
**Fungsi**: Root widget aplikasi dengan konfigurasi routing dan theme

```dart
import 'package:flutter/material.dart';
import 'config/app_routes.dart';
import 'config/app_theme.dart';

/// Main application widget dengan konfigurasi routing lengkap
class PowerPlantLogsheetApp extends StatelessWidget {
  const PowerPlantLogsheetApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Power Plant Logsheet',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.main,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      onUnknownRoute: (settings) {
        print('❌ ROUTING: Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Error'),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Route not found: ${settings.name}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/main');
                    },
                    child: const Text('Back to Dashboard'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

---

## ⚙️ Configuration Layer

### 🛣️ app_routes.dart
**Fungsi**: Konfigurasi routing aplikasi untuk navigasi antar halaman

```dart
import 'package:flutter/material.dart';
import '../app_exports.dart';

class AppRoutes {
  static const String main = '/main';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String detailMesin = '/detail_mesin';
  static const String riwayat = '/riwayat';
  static const String pengaturan = '/pengaturan';

  static Map<String, WidgetBuilder> routes = {
    main: (context) => const MainNavigationScreen(),
    login: (context) => const LoginScreen(),
    dashboard: (context) => const DashboardScreen(),
    riwayat: (context) => const RiwayatLogsheetScreen(),
    pengaturan: (context) => const PengaturanScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case detailMesin:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => DetailMesinScreen(
            mesinName: args['name'] ?? 'Generator',
            fileId: args['fileId'] ?? '',
            isActive: args['isActive'] ?? false,
          ),
        );
      default:
        return null;
    }
  }
}
```

---

## 🔧 Services Layer

### 📋 LogsheetService
**Fungsi**: Service utama untuk manajemen logsheet dengan Google Sheets integration

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'temperature_storage_service.dart';
import 'database_temperature_service.dart';
import 'database_service.dart';
import 'rest_api_service.dart';
import 'file_id_sync_service.dart';
import '../constants/google_drive_config.dart';

class LogsheetService {
  static const String _baseUrl =
      'https://us-central1-powerplantlogsheet-8780a.cloudfunctions.net/api';

  /// Membuat logsheet baru berdasarkan template
  ///
  /// BUSINESS LOGIC: Setiap hari, user membuat spreadsheet BARU untuk hari tersebut.
  /// Setiap spreadsheet memiliki fileId unik yang disinkronisasi antar device.
  ///
  /// @param generatorName - Nama generator (contoh: 'Mitsubishi #1')
  /// @param templateFileId - Opsional: Template khusus untuk di-copy
  /// @param targetFolderId - Opsional: Folder khusus untuk membuat logsheet
  ///
  /// Hasil: Map dengan fileId, fileName, dan webViewLink dari logsheet yang dibuat
  static Future<Map<String, dynamic>> createLogsheet(
    String generatorName, {
    String? templateFileId,
    String? targetFolderId,
  }) async {
    try {
      final timestamp = DateTime.now();

      // Format tanggal dengan nama bulan Indonesia
      final List<String> bulan = [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ];

      final String formattedDate =
          '${timestamp.day.toString().padLeft(2, '0')} ${bulan[timestamp.month]} ${timestamp.year}';

      final String newFileName = 'Logsheet $generatorName, $formattedDate';

      // Gunakan ID yang disediakan atau fallback ke default berbasis config
      final String effectiveTemplateFileId =
          templateFileId ?? GoogleDriveConfig.getTemplateFileId(generatorName);
      final String effectiveTargetFolderId =
          targetFolderId ?? GoogleDriveConfig.getTargetFolderId();

      final response = await http.post(
        Uri.parse('$_baseUrl/create-logsheet'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'templateFileId': effectiveTemplateFileId,
          'targetFolderId': effectiveTargetFolderId,
          'newFileName': newFileName,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final fileId = responseData['fileId'];

        // 🔥 SYNC FILE ID TO FIRESTORE untuk konsistensi cross-device
        try {
          await FileIdSyncService.saveFileIdToFirestore(
            generatorName: generatorName,
            fileId: fileId,
            createdBy: 'create_logsheet',
          );
        } catch (e) {
          print('⚠️ FILE_SYNC: Failed to save fileId to Firestore: $e');
        }

        // Bagikan otomatis dengan anggota tim untuk mencegah masalah izin
        try {
          await autoShareWithTeam(fileId);
        } catch (e) {
          // Jangan gagalkan seluruh operasi jika sharing gagal
        }

        return {
          'fileId': fileId,
          'fileName': responseData['fileName'],
          'webViewLink': responseData['webViewLink'],
        };
      }

      throw ApiException('Gagal membuat logsheet');
    } catch (e) {
      throw ApiException('Terjadi kesalahan: ${e.toString()}');
    }
  }

  /// Bagikan otomatis logsheet dengan anggota tim yang sudah dikenal untuk mencegah masalah izin
  static Future<void> autoShareWithTeam(String fileId) async {
    final List<String> teamEmails = [
      'sony@pltd.com',
      'dimas@pltd.com',
      'admin@pltd.com',
    ];

    for (final email in teamEmails) {
      try {
        await RestApiService.shareSpreadsheet(
          fileId,
          emailAddress: email,
          role: 'writer',
          sendNotificationEmail: false,
        );
        // Jeda kecil antara permintaan sharing untuk menghindari rate limiting
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        // Lanjutkan dengan email lain meskipun satu gagal
        print('⚠️ PERMISSIONS: Failed to share with $email: $e');
      }
    }
  }
}
```

### 🔥 FirestoreRealtimeService
**Fungsi**: Real-time synchronization dengan Firebase Firestore untuk cross-device data sync
