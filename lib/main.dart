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
