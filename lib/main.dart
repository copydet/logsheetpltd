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
  print('🔥 APLIKASI: Menginisialisasi Firebase...');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ APLIKASI: Firebase berhasil diinisialisasi');
  } catch (e) {
    print('❌ APLIKASI: Gagal menginisialisasi Firebase: $e');
  }

  // Inisialisasi migrasi SQLite
  print('🔄 APLIKASI: Menginisialisasi migrasi SQLite...');
  final migrationSuccess = await MigrationService.migrateToSQLite();

  if (migrationSuccess) {
    print('✅ APLIKASI: Migrasi SQLite berhasil diselesaikan');
  } else {
    print(
      '❌ APLIKASI: Migrasi SQLite gagal, akan dicoba ulang saat aplikasi digunakan',
    );
  }

  // Inisialisasi Sync Manager
  print('🔄 APLIKASI: Menginisialisasi Sync Manager...');
  try {
    await SyncManager.instance.initialize();
    print('✅ APLIKASI: Sync Manager berhasil diinisialisasi');
  } catch (e) {
    print('❌ APLIKASI: Gagal menginisialisasi Sync Manager: $e');
  }

  runApp(const PowerPlantLogsheetApp());
}
