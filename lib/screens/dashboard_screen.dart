import 'package:flutter/material.dart';
import '../app_exports.dart';
import '../services/sync_manager.dart';
import '../services/generator_status_sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<QuerySnapshot>? _realtimeListener;
  Map<String, Map<String, dynamic>> _firestoreData = {};
  bool _useFirestoreData = false;

  @override
  void initState() {
    super.initState();
    _loadStoredFileIds(); // This now includes loading generator statuses
    _initializeRealtimeData();
    _setupGeneratorStatusSync(); // Pengaturan real-time sync untuk status generator
  }

  @override
  void dispose() {
    _realtimeListener?.cancel();
    GeneratorStatusSyncService.cancelRealtimeListener(); // Batal generator status listener
    super.dispose();
  }

  // Inisialisasi real-time data from Firestore
  Future<void> _initializeRealtimeData() async {
    try {
      print('🔄 DASHBOARD: Initializing Firestore real-time data...');

      // Ambil generator names
      final generatorNames = generators.map((g) => g.name).toList();

      // Cek if Firestore has data
      final firestoreData =
          await FirestoreRealtimeService.getLatestDataForDashboard(
            generatorNames,
          );

      if (firestoreData.isNotEmpty &&
          firestoreData.values.any((data) => data['hasData'] == true)) {
        setState(() {
          _firestoreData = firestoreData;
          _useFirestoreData = true;
        });

        print('✅ DASHBOARD: Using Firestore data for real-time updates');

        // Pengaturan real-time listener
        _realtimeListener = FirestoreRealtimeService.listenToRealtimeUpdates(
          generatorNames,
          (updates) {
            if (mounted) {
              setState(() {
                _firestoreData = updates;
              });
              print('🔄 DASHBOARD: Received real-time updates');
            }
          },
        );
      } else {
        print(
          '⚠️ DASHBOARD: No Firestore data, falling back to SharedPreferences',
        );
        setState(() {
          _useFirestoreData = false;
        });
      }
    } catch (e) {
      print('❌ DASHBOARD:  initializing Firestore data: $e');
      setState(() {
        _useFirestoreData = false;
      });
    }
  }

  // Pengaturan real-time sync untuk generator status manual
  Future<void> _setupGeneratorStatusSync() async {
    try {
      print('🔄 DASHBOARD: Setting up generator status sync...');

      // Inisialisasi service
      await GeneratorStatusSyncService.initialize();

      // Ambil generator names
      final generatorNames = generators.map((g) => g.name).toList();

      // Download latest statuses from other devices
      final latestStatuses =
          await GeneratorStatusSyncService.downloadLatestStatuses(
            generatorNames,
          );

      // Update local generator statuses if there are newer ones
      if (latestStatuses.isNotEmpty) {
        setState(() {
          for (int i = 0; i < generators.length; i++) {
            final generatorName = generators[i].name;
            if (latestStatuses.containsKey(generatorName)) {
              generators[i] = GeneratorData(
                id: generators[i].id,
                name: generators[i].name,
                isActive: latestStatuses[generatorName]!,
                temperature: generators[i].temperature,
                pressure: generators[i].pressure,
                operationHours: generators[i].operationHours,
                fileId: generators[i].fileId,
              );
            }
          }
        });
        print('✅ DASHBOARD: Updated generator statuses from cloud');
      }

      // Pengaturan real-time listener for status changes from other devices
      GeneratorStatusSyncService.setupRealtimeListener(generatorNames, (
        generatorName,
        isActive,
        updatedBy,
      ) {
        if (mounted) {
          setState(() {
            final index = generators.indexWhere((g) => g.name == generatorName);
            if (index != -1) {
              generators[index] = GeneratorData(
                id: generators[index].id,
                name: generators[index].name,
                isActive: isActive,
                temperature: generators[index].temperature,
                pressure: generators[index].pressure,
                operationHours: generators[index].operationHours,
                fileId: generators[index].fileId,
              );
            }
          });
          print(
            '🔔 DASHBOARD: Generator $generatorName status updated to $isActive by $updatedBy',
          );
        }
      });

      print('✅ DASHBOARD: Generator status sync setup completed');
    } catch (e) {
      print('❌ DASHBOARD:  setting up generator status sync: $e');
    }
  }

  // Test REST API connection and show results
  Future<void> _testRestApiConnection() async {
    try {
      print('🔍 Testing REST API connection...');

      // Test Health Check
      try {
        final healthResponse = await RestApiService.healthCheck();
        print('✅ Health Check: ${healthResponse['success']}');

        if (healthResponse['data'] != null) {
          final status = healthResponse['data']['status'];
          print('   Status: $status');
        } else {
          print('   No health data received');
        }
      } catch (e) {
        print('❌ Health Check : $e');
      }

      // Test Generators
      try {
        final generatorsResponse = await RestApiService.getGenerators();
        final generatorCount =
            generatorsResponse['data']?.length ??
            generatorsResponse['generators']?.length ??
            0;
        print(
          '✅ Generators: ${generatorsResponse['success']} - Found $generatorCount generators',
        );
      } catch (e) {
        print('❌ Generators : $e');
      }

      print('✅ REST API test completed');
    } catch (e) {
      print('❌ REST API Test : $e');
    }
  } // Muat fileId yang tersimpan dari storage dan data terakhir

  void _loadStoredFileIds() async {
    print('🔄 DASHBOARD: Loading stored file IDs with consistency check...');

    // Muat dan pastikan GeneratorDataManager ter-update
    await GeneratorDataManager.loadGeneratorData();

    print('🔧 DASHBOARD : Processing ${generators.length} generators...');
    for (int i = 0; i < generators.length; i++) {
      final generatorName = generators[i].name;
      print('📱 DASHBOARD: Processing generator $i: $generatorName');
      print('📱 DASHBOARD:  SQLite for $generatorName...');

      // PRIORITAS 1: Firestore (real-time sync priority)
      // Cek Firestore data terlebih dahulu untuk sinkronisasi real-time
      Map<String, dynamic>? firestoreData;
      try {
        final firestoreResult =
            await FirestoreRealtimeService.getLatestDataForDashboard([
              generatorName,
            ]);
        if (firestoreResult.containsKey(generatorName)) {
          final generatorFirestoreData = firestoreResult[generatorName]!;
          if (generatorFirestoreData['hasData'] == true) {
            firestoreData = generatorFirestoreData;
            print('✅ DASHBOARD: Found Firestore data for $generatorName');
          }
        }
      } catch (e) {
        print(
          '⚠️ DASHBOARD: Firestore data not available for $generatorName: $e',
        );
        firestoreData = null;
      }

      // PRIORITAS 2: Google Sheets API (sumber data utama dari spreadsheet)
      Map<String, dynamic>? sheetsData;
      try {
        final currentFileId = await StorageService.getActiveFileId(
          generatorName,
        );
        if (currentFileId != null &&
            currentFileId.isNotEmpty &&
            !currentFileId.startsWith('EMPTY')) {
          final currentHour = DateTime.now().hour;
          final sheetsResult = await SheetsApiService.getHourlyData(
            currentFileId,
            currentHour,
          );
          if (sheetsResult['success'] == true && sheetsResult['data'] != null) {
            final hourlyData =
                sheetsResult['data']['hourlyData'] as Map<String, dynamic>;
            sheetsData = {
              'fileId': currentFileId,
              'waterTemp': hourlyData['waterTemp']?.toString() ?? '0',
              'oilPressure': hourlyData['oilPressure']?.toString() ?? '0',
              'jamOperasi': hourlyData['jamOperasi']?.toString() ?? '0',
              'source': 'sheets',
              'timestamp': DateTime.now().toIso8601String(),
            };
            print(
              '✅ DASHBOARD: Found Google Sheets data for $generatorName (temp: ${sheetsData['waterTemp']}°C)',
            );
          }
        }
      } catch (e) {
        if (e.toString().contains('404')) {
          print(
            '! DASHBOARD: Google Sheets data not available for $generatorName: $e',
          );
        } else {
          print(
            '⚠️ DASHBOARD: Google Sheets data not available for $generatorName: $e',
          );
        }
        sheetsData = null;
      }

      // PRIORITAS 3: SQLite database (offline fallback)
      final dbData = await _getLatestDataFromSQLite(generatorName);

      if (firestoreData != null) {
        // GUNAKAN DATA FIRESTORE (prioritas tertinggi untuk real-time sync)
        final consistentFileId =
            firestoreData['fileId']?.toString() ??
            await StorageService.getActiveFileId(generatorName) ??
            '';

        print(
          '🔄 DASHBOARD: Using Firestore data for $generatorName with fileId: ${consistentFileId.length > 15 ? consistentFileId.substring(0, 15) : consistentFileId}...',
        );

        // Muat saved generator status from user preference
        bool userSetActive = false;
        try {
          userSetActive = await DatabaseStorageService.getGeneratorStatus(
            generatorName,
          );
          print(
            '✅ DASHBOARD: Loaded user status from SQLite for $generatorName: $userSetActive',
          );
        } catch (e) {
          final savedStatus = await StorageService.getGeneratorStatus(
            generatorName,
          );
          userSetActive = savedStatus ?? false;
          print(
            '⚠️ DASHBOARD: Using SharedPreferences status for $generatorName: $userSetActive',
          );
        }

        setState(() {
          generators[i] = GeneratorData(
            id: generators[i].id,
            name: generators[i].name,
            isActive: userSetActive,
            temperature:
                double.tryParse(
                  firestoreData?['waterTemp']?.toString() ?? '0',
                ) ??
                generators[i].temperature,
            pressure:
                double.tryParse(
                  firestoreData?['oilPressure']?.toString() ?? '0',
                ) ??
                generators[i].pressure,
            operationHours:
                int.tryParse(firestoreData?['jamOperasi']?.toString() ?? '0') ??
                generators[i].operationHours,
            fileId: consistentFileId,
          );
        });
        print(
          '✅ DASHBOARD: Updated $generatorName with Firestore data (temp: ${generators[i].temperature}°C, pressure: ${generators[i].pressure} Bar, hours: ${generators[i].operationHours})',
        );
      } else if (sheetsData != null) {
        // GUNAKAN DATA GOOGLE SHEETS (prioritas kedua untuk data spreadsheet terbaru)
        final consistentFileId =
            sheetsData['fileId']?.toString() ??
            await StorageService.getActiveFileId(generatorName) ??
            '';

        print(
          '🔄 DASHBOARD: Using Google Sheets data for $generatorName with fileId: ${consistentFileId.length > 15 ? consistentFileId.substring(0, 15) : consistentFileId}...',
        );

        // Muat saved generator status from user preference
        bool userSetActive = false;
        try {
          userSetActive = await DatabaseStorageService.getGeneratorStatus(
            generatorName,
          );
          print(
            '✅ DASHBOARD: Loaded user status from SQLite for $generatorName: $userSetActive',
          );
        } catch (e) {
          final savedStatus = await StorageService.getGeneratorStatus(
            generatorName,
          );
          userSetActive = savedStatus ?? false;
          print(
            '⚠️ DASHBOARD: Using SharedPreferences status for $generatorName: $userSetActive',
          );
        }

        setState(() {
          generators[i] = GeneratorData(
            id: generators[i].id,
            name: generators[i].name,
            isActive: userSetActive,
            temperature:
                double.tryParse(sheetsData?['waterTemp']?.toString() ?? '0') ??
                generators[i].temperature,
            pressure:
                double.tryParse(
                  sheetsData?['oilPressure']?.toString() ?? '0',
                ) ??
                generators[i].pressure,
            operationHours:
                int.tryParse(sheetsData?['jamOperasi']?.toString() ?? '0') ??
                generators[i].operationHours,
            fileId: consistentFileId,
          );
        });
        print(
          '✅ DASHBOARD: Updated $generatorName with Google Sheets data (temp: ${generators[i].temperature}°C, pressure: ${generators[i].pressure} Bar, hours: ${generators[i].operationHours})',
        );
      } else if (dbData != null && dbData.isNotEmpty) {
        // FALLBACK KE SQLite DATABASE
        // Dapatkan file ID yang konsisten dari storage
        final consistentFileId = await StorageService.getActiveFileId(
          generatorName,
        );
        String validatedFileId = consistentFileId ?? '';

        print(
          '✅ DASHBOARD: Using consistent fileId for $generatorName: ${validatedFileId.isEmpty ? "EMPTY" : validatedFileId.substring(0, 15)}...',
        );

        // Muat saved generator status FIRST to preserve user settings
        // Priority: SQLite database first, then SharedPreferences as fallback
        bool userSetActive = false;

        // Try SQLite first
        try {
          userSetActive = await DatabaseStorageService.getGeneratorStatus(
            generatorName,
          );
          print(
            '✅ DASHBOARD: Loaded status from SQLite for $generatorName: $userSetActive',
          );
        } catch (e) {
          // Fallback to SharedPreferences
          final savedStatus = await StorageService.getGeneratorStatus(
            generatorName,
          );
          userSetActive = savedStatus ?? false;
          print(
            '⚠️ DASHBOARD: SQLite failed, using SharedPreferences for $generatorName: $userSetActive',
          );

          // Sync to SQLite for consistency
          if (savedStatus != null) {
            await DatabaseStorageService.setGeneratorStatus(
              generatorName,
              userSetActive,
            );
          }
        }

        setState(() {
          generators[i] = GeneratorData(
            id: generators[i].id,
            name: generators[i].name,
            isActive:
                userSetActive, // 🔧 FIX: Use saved user setting, not automatic true
            temperature:
                double.tryParse(dbData['waterTemp']?.toString() ?? '0') ??
                generators[i].temperature,
            pressure:
                double.tryParse(dbData['oilPressure']?.toString() ?? '0') ??
                generators[i].pressure,
            operationHours:
                int.tryParse(dbData['jamOperasi']?.toString() ?? '0') ??
                generators[i].operationHours,
            fileId: validatedFileId,
          );
        });
        print(
          '✅ DASHBOARD: Using SQLite data for ${generatorName} with fileId: $validatedFileId, userActive: $userSetActive',
        );
      } else {
        // PRIORITAS 2: Firestore fallback (multi-user data)
        final firestoreData = _useFirestoreData
            ? _firestoreData[generatorName]
            : null;

        if (firestoreData != null && firestoreData['hasData'] == true) {
          // Muat saved generator status to preserve user settings
          // Priority: SQLite database first, then SharedPreferences as fallback
          bool userSetActive = false;

          try {
            userSetActive = await DatabaseStorageService.getGeneratorStatus(
              generatorName,
            );
            print(
              '✅ DASHBOARD: Loaded status from SQLite for $generatorName: $userSetActive',
            );
          } catch (e) {
            final savedStatus = await StorageService.getGeneratorStatus(
              generatorName,
            );
            userSetActive = savedStatus ?? false;
            print(
              '⚠️ DASHBOARD: SQLite failed, using SharedPreferences for $generatorName: $userSetActive',
            );

            // Sync to SQLite for consistency
            if (savedStatus != null) {
              await DatabaseStorageService.setGeneratorStatus(
                generatorName,
                userSetActive,
              );
            }
          }

          setState(() {
            generators[i] = GeneratorData(
              id: generators[i].id,
              name: generators[i].name,
              isActive:
                  userSetActive, // 🔧 FIX: Use saved user setting, not automatic true
              temperature:
                  double.tryParse(
                    firestoreData['waterTemp']?.toString() ?? '0',
                  ) ??
                  generators[i].temperature,
              pressure:
                  double.tryParse(
                    firestoreData['oilPressure']?.toString() ?? '0',
                  ) ??
                  generators[i].pressure,
              operationHours:
                  int.tryParse(
                    firestoreData['jamOperasi']?.toString() ?? '0',
                  ) ??
                  generators[i].operationHours,
              fileId: firestoreData['fileId'] ?? '',
            );
          });
          print(
            '🔄 DASHBOARD: Using Firestore fallback for ${generatorName}, userActive: $userSetActive',
          );
        } else {
          // PRIORITAS 3: Generator belum memiliki data (Mitsubishi #3, #4, etc.)
          // Muat saved generator status to preserve user manual settings
          final storedFileId = await StorageService.getActiveFileId(
            generatorName,
          );

          // 🔧 MANUAL SWITCH: Load saved status even for generators without data
          bool userSetActive = false;

          try {
            userSetActive = await DatabaseStorageService.getGeneratorStatus(
              generatorName,
            );
            print(
              '✅ DASHBOARD: Loaded manual status from SQLite for $generatorName: $userSetActive',
            );
          } catch (e) {
            final savedStatus = await StorageService.getGeneratorStatus(
              generatorName,
            );
            userSetActive = savedStatus ?? false;
            print(
              '⚠️ DASHBOARD: SQLite failed, using SharedPreferences for $generatorName: $userSetActive',
            );

            // Sync to SQLite for consistency
            if (savedStatus != null) {
              await DatabaseStorageService.setGeneratorStatus(
                generatorName,
                userSetActive,
              );
            }
          }

          setState(() {
            generators[i] = GeneratorData(
              id: generators[i].id,
              name: generators[i].name,
              isActive:
                  userSetActive, // 🔧 MANUAL: Use saved user setting, not automatic false
              temperature: generators[i].temperature, // Gunakan default
              pressure: generators[i].pressure, // Gunakan default
              operationHours: generators[i].operationHours, // Gunakan default
              fileId: storedFileId ?? '', // FileId kosong jika belum ada
            );
          });

          if (storedFileId == null || storedFileId.isEmpty) {
            print(
              '📝 DASHBOARD: Generator ${generatorName} ready for first data entry, manual status: $userSetActive',
            );
          } else {
            print(
              '⚠️ DASHBOARD: Using stored fileId for ${generatorName}: $storedFileId, manual status: $userSetActive',
            );
          }
        }
      }
    }
  }

  // Helper method untuk mengambil data terbaru dari SQLite
  Future<Map<String, dynamic>?> _getLatestDataFromSQLite(
    String generatorName,
  ) async {
    try {
      final dbService = DatabaseService();

      // 🔧 CRITICAL FIX: Juga cek tabel temperature_data untuk konsistensi dengan Chart Widget
      print('📱 DASHBOARD:  SQLite for $generatorName...');

      // PRIORITAS 1: Cek tabel logsheets untuk data lengkap
      final history = await dbService.getLogsheetHistory(
        generatorName,
        daysBack: 0,
      );

      if (history.isNotEmpty) {
        final latestEntry = history.first;
        print(
          '📱 DASHBOARD: Found SQLite data for $generatorName from logsheets table',
        );
        return latestEntry;
      }

      // PRIORITAS 2: Cek tabel temperature_data (yang digunakan Chart) sebagai fallback
      try {
        // Ambil fileId untuk generator ini
        final storedFileId = await StorageService.getActiveFileId(
          generatorName,
        );

        if (storedFileId != null && storedFileId.isNotEmpty) {
          final db = await dbService.database;
          final today = DateTime.now();
          final dateStr =
              '${today.year.toString().padLeft(4, '0')}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';

          print(
            '📱 DASHBOARD: Querying temperature_data for fileId=$storedFileId, date=$dateStr',
          );

          final tempResults = await db.query(
            'temperature_data',
            where: 'file_id = ? AND date = ?',
            whereArgs: [storedFileId, dateStr],
            orderBy: 'hour DESC',
            limit: 1,
          );

          if (tempResults.isNotEmpty) {
            final tempData = tempResults.first;

            // PRIORITAS 3: Ambil jam operasi dari SQLite table logsheets sebagai backup, lalu Google Sheets
            String jamOperasiValue = '0'; // Use proper default

            // Try SQLite logsheets table first - this should have the real user input
            try {
              // Debug: Check if there are ANY logsheet records in the database
              final db = await dbService.database;
              final allLogsheetCount = await db.rawQuery(
                'SELECT COUNT(*) as count FROM logsheets',
              );
              final generatorLogsheetCount = await db.rawQuery(
                'SELECT COUNT(*) as count FROM logsheets WHERE generator_name = ?',
                [generatorName],
              );
              final todayLogsheetCount = await db.rawQuery(
                'SELECT COUNT(*) as count FROM logsheets WHERE generator_name = ? AND DATE(timestamp) = DATE("now", "localtime")',
                [generatorName],
              );

              print(
                '📱 DASHBOARD DEBUG: Total logsheet records: ${allLogsheetCount.first['count']}',
              );
              print(
                '📱 DASHBOARD DEBUG: $generatorName logsheet records: ${generatorLogsheetCount.first['count']}',
              );
              print(
                '📱 DASHBOARD DEBUG: $generatorName TODAY logsheet records: ${todayLogsheetCount.first['count']}',
              );

              // Also show recent logsheet records for this generator
              final recentLogsheets = await db.rawQuery(
                'SELECT * FROM logsheets WHERE generator_name = ? ORDER BY timestamp DESC LIMIT 3',
                [generatorName],
              );
              print(
                '📱 DASHBOARD DEBUG: Recent logsheets for $generatorName: ${recentLogsheets.length} records',
              );
              for (int i = 0; i < recentLogsheets.length; i++) {
                final record = recentLogsheets[i];
                print(
                  '📱 DASHBOARD DEBUG: Record $i: jamOperasi=${record['jam_operasi']}, timestamp=${record['timestamp']}, fileId=${record['file_id']}',
                );
              }

              final logsheetHistory = await dbService.getLogsheetHistory(
                generatorName,
                daysBack: 1, // Change to 1 day back to include today's data
              );

              if (logsheetHistory.isNotEmpty) {
                final latestLogsheet = logsheetHistory.first;
                jamOperasiValue =
                    latestLogsheet['jamOperasi']?.toString() ?? '0';
                print(
                  '📱 DASHBOARD: Retrieved jamOperasi from SQLite logsheets: $jamOperasiValue',
                );
              }
            } catch (e) {
              print(
                '📱 DASHBOARD: Failed to get jamOperasi from SQLite logsheets: $e',
              );
            }

            // If SQLite doesn't have jamOperasi, try Google Sheets as fallback
            if (jamOperasiValue == '0') {
              try {
                // Use HTTP directly to avoid any parsing issues in RestApiService
                final uri = Uri.parse(
                  'https://us-central1-powerplantlogsheet-8780a.cloudfunctions.net/api/logsheets/$storedFileId',
                );
                final response = await http.get(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                );

                if (response.statusCode == 200) {
                  final responseData = jsonDecode(response.body);
                  if (responseData['success'] == true &&
                      responseData['data'] != null) {
                    jamOperasiValue =
                        responseData['data']['jamOperasi']?.toString() ?? '0';
                    print(
                      '📱 DASHBOARD: Retrieved jamOperasi directly from API: $jamOperasiValue',
                    );
                  }
                }
              } catch (e) {
                print(
                  '📱 DASHBOARD: Failed to get jamOperasi from Google Sheets: $e',
                );
                jamOperasiValue = '0'; // Use proper default
              }
            }

            // Konversi format temperature_data ke format yang diharapkan dashboard
            final convertedData = {
              'generator_name': generatorName,
              'fileId': tempData['file_id'],
              'waterTemp': tempData['water_temp']?.toString() ?? '0',
              'oilPressure':
                  tempData['lube_oil_temp']?.toString() ??
                  '0', // gunakan lube_oil_temp sebagai pengganti
              'jamOperasi':
                  jamOperasiValue, // ambil dari Google Sheets, bukan dari hour
              'timestamp':
                  '${tempData['date']} ${tempData['hour'].toString().padLeft(2, '0')}:00:00',
            };
            print(
              '📱 DASHBOARD: Found SQLite temperature_data for $generatorName (hour=${tempData['hour']}, waterTemp=${tempData['water_temp']}, jamOperasi=$jamOperasiValue)',
            );
            return convertedData;
          }
        }
      } catch (e) {
        print('📱 DASHBOARD: Error  temperature_data: $e');
      }

      print('📱 DASHBOARD: No SQLite data found for $generatorName today');
      return null;
    } catch (e) {
      print('❌ DASHBOARD:  loading SQLite data for $generatorName: $e');
      return null;
    }
  }

  // Method untuk refresh data dari storage
  Future<void> _refreshGeneratorData() async {
    _loadStoredFileIds();
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    final months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final dayName = days[now.weekday % 7];
    final day = now.day;
    final month = months[now.month];
    final year = now.year;

    return '$dayName, $day $month $year';
  }

  final List<GeneratorData> generators = [
    GeneratorData(
      id: 1,
      name: 'Mitsubishi #1',
      isActive: false,
      temperature: 0,
      pressure: 0,
      operationHours: 0,
      fileId: '',
    ),
    GeneratorData(
      id: 2,
      name: 'Mitsubishi #2',
      isActive: false,
      temperature: 0,
      pressure: 0,
      operationHours: 0,
      fileId: '',
    ),
    GeneratorData(
      id: 3,
      name: 'Mitsubishi #3',
      isActive: false,
      temperature: 0,
      pressure: 0,
      operationHours: 0,
      fileId: '',
    ),
    GeneratorData(
      id: 4,
      name: 'Mitsubishi #4',
      isActive: false,
      temperature: 0,
      pressure: 0,
      operationHours: 0,
      fileId: '',
    ),
  ];

  int _getActiveCount() {
    return generators.where((g) => g.isActive).length;
  }

  void _updateGeneratorStatus(int id, bool newStatus) async {
    setState(() {
      final index = generators.indexWhere((g) => g.id == id);
      if (index != -1) {
        generators[index] = GeneratorData(
          id: generators[index].id,
          name: generators[index].name,
          isActive: newStatus,
          temperature: generators[index].temperature,
          pressure: generators[index].pressure,
          operationHours: generators[index].operationHours,
          fileId: generators[index].fileId,
        );
      }
    });

    // 🔧 MANUAL SWITCH: Save to local storage systems
    final generator = generators.firstWhere((g) => g.id == id);

    // Primary storage: SQLite database
    await DatabaseStorageService.setGeneratorStatus(generator.name, newStatus);

    // Backup storage: SharedPreferences (for compatibility)
    await StorageService.saveGeneratorStatus(generator.name, newStatus);

    print(
      '✅ DASHBOARD: Updated ${generator.name} status to $newStatus (MANUAL)',
    );

    // 🚀 SYNC MANUAL STATUS: Upload to Firestore for multi-device sync
    try {
      final uploaded = await GeneratorStatusSyncService.uploadGeneratorStatus(
        generator.name,
        newStatus,
      );
      if (uploaded) {
        print(
          '✅ DASHBOARD: Generator ${generator.name} status synced to cloud',
        );
      }
    } catch (e) {
      print('❌ DASHBOARD:  to sync generator status: $e');
    }

    // 🚀 IMMEDIATE SYNC: Trigger upload after generator status change
    _triggerImmediateSync();
  }

  void _updateGeneratorFileId(int id, String fileId) async {
    setState(() {
      final index = generators.indexWhere((g) => g.id == id);
      if (index != -1) {
        generators[index] = GeneratorData(
          id: generators[index].id,
          name: generators[index].name,
          isActive: generators[index].isActive,
          temperature: generators[index].temperature,
          pressure: generators[index].pressure,
          operationHours: generators[index].operationHours,
          fileId: fileId,
        );

        // Simpan ke storage
        StorageService.saveActiveFileId(generators[index].name, fileId);
      }
    });
  }

  /// Trigger immediate sync after data changes
  void _triggerImmediateSync() async {
    try {
      print(
        '🚀 IMMEDIATE SYNC: Triggering upload after generator status change...',
      );
      final success = await SyncManager.instance.triggerImmediateUpload();
      if (success) {
        print(
          '✅ IMMEDIATE SYNC: Generator status synced to Firestore successfully',
        );
      } else {
        print('⚠️ IMMEDIATE SYNC: Upload  or no data to sync');
      }
    } catch (e) {
      print('❌ IMMEDIATE SYNC:  during immediate sync: $e');
      // Don't show error to user - sync failure shouldn't block UI
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        title: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Power Plant Logsheet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getCurrentDate(),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          // Status API Connection menggunakan REST API Health Check
          FutureBuilder<Map<String, dynamic>>(
            future: RestApiService.healthCheck(),
            builder: (context, snapshot) {
              bool isHealthy = false;
              String statusText = 'API';

              if (snapshot.hasData && snapshot.data!['success'] == true) {
                final healthData = snapshot.data!['data'];
                if (healthData != null && healthData['status'] != null) {
                  isHealthy = healthData['status'] == 'healthy';
                  statusText = isHealthy ? 'API OK' : 'API Down';
                } else {
                  statusText = 'API Error';
                }
              } else if (snapshot.hasError) {
                statusText = 'API Error';
              } else if (snapshot.connectionState == ConnectionState.waiting) {
                statusText = 'Loading...';
              }

              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isHealthy
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    _testRestApiConnection();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Testing REST API connection... Check debug console',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isHealthy ? Icons.api : Icons.error_outline,
                        size: 16,
                        color: isHealthy ? Colors.green[300] : Colors.red[300],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: isHealthy
                              ? Colors.green[300]
                              : Colors.red[300],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Online',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshGeneratorData,
        color: const Color(0xFF1E3A8A),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(
                    255,
                    139,
                    133,
                    133,
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mesin Aktif',
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_getActiveCount()} Mesin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...generators
                  .map(
                    (generator) => GeneratorCard(
                      generator: generator,
                      onStatusChanged: _updateGeneratorStatus,
                      onFileIdChanged: _updateGeneratorFileId,
                      onDataRefresh: _refreshGeneratorData,
                    ),
                  )
                  .toList(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class GeneratorCard extends StatefulWidget {
  final GeneratorData generator;
  final Function(int id, bool status) onStatusChanged;
  final Function(int id, String fileId) onFileIdChanged;
  final VoidCallback onDataRefresh;

  const GeneratorCard({
    super.key,
    required this.generator,
    required this.onStatusChanged,
    required this.onFileIdChanged,
    required this.onDataRefresh,
  });

  @override
  State<GeneratorCard> createState() => _GeneratorCardState();
}

class _GeneratorCardState extends State<GeneratorCard> {
  late bool isActive;

  @override
  void initState() {
    super.initState();
    isActive = widget.generator.isActive;
  }

  @override
  void didUpdateWidget(GeneratorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generator != widget.generator) {
      setState(() {
        isActive = widget.generator.isActive;
      });
    }
  }

  void _toggleActive(bool value) async {
    String title = value ? 'Hidupkan mesin?' : 'Standbykan mesin?';
    String content = value
        ? 'Apakah Anda yakin ingin menghidupkan mesin?'
        : 'Apakah Anda yakin ingin men-standby-kan mesin?';
    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya'),
          ),
        ],
      ),
    );
    if (result == true) {
      setState(() {
        isActive = value;
      });
      // Call the callback to update parent state
      widget.onStatusChanged(widget.generator.id, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final generator = widget.generator;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.pushNamed(
          context,
          '/detail_mesin',
          arguments: {
            'name': generator.name,
            'fileId': generator.fileId,
            'isActive': generator.isActive,
          },
        );
        // Refresh data saat kembali dari detail
        widget.onDataRefresh();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        generator.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          // Indikator status logsheet
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: generator.fileId.isNotEmpty
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: generator.fileId.isNotEmpty
                                    ? Colors.blue.withOpacity(0.3)
                                    : Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              generator.fileId.isNotEmpty
                                  ? 'Ada Logsheet'
                                  : 'Belum Ada',
                              style: TextStyle(
                                fontSize: 10,
                                color: generator.fileId.isNotEmpty
                                    ? Colors.blue[700]
                                    : Colors.orange[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: isActive,
                            activeColor: Colors.green,
                            inactiveThumbColor: Colors.red,
                            onChanged: (value) {
                              _toggleActive(value);
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isActive ? 'ON' : 'OFF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isActive
                        ? 'Mesin sedang beroperasi'
                        : 'Mesin dalam standby',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricItem(
                          'Suhu',
                          isActive ? '${generator.temperature}°C' : '-°C',
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricItem(
                          'Tekanan',
                          isActive ? '${generator.pressure} Bar' : '- Bar',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricItem(
                          'Operasi',
                          '${generator.operationHours} Jam',
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            isActive
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: const Color(0xFF1E3A8A),
                        child: InkWell(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LogsheetFormScreen(
                                  generatorName: generator.name,
                                  generatorId: generator.id,
                                  activeFileId: generator.fileId.isNotEmpty
                                      ? generator.fileId
                                      : null,
                                ),
                              ),
                            );

                            // Jika ada perubahan selectedIndex dari navbar
                            if (result != null &&
                                result['selectedIndex'] != null) {
                              // Kembali ke main navigation dengan index yang dipilih
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/main',
                                (route) => false,
                                arguments: {
                                  'selectedIndex': result['selectedIndex'],
                                },
                              );
                              return;
                            }

                            // Jika berhasil membuat logsheet, update fileId
                            if (result != null && result['fileId'] != null) {
                              widget.onFileIdChanged(
                                generator.id,
                                result['fileId'],
                              );
                            }

                            // Refresh data setelah kembali dari form
                            widget.onDataRefresh();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.description,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Isi Logsheet',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.power_off,
                          color: Colors.grey[600],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mesin Tidak Aktif',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(_getIconForMetric(label), color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForMetric(String label) {
    switch (label) {
      case 'Suhu':
        return Icons.thermostat;
      case 'Tekanan':
        return Icons.speed;
      case 'Operasi':
        return Icons.access_time;
      default:
        return Icons.info;
    }
  }
}

class GeneratorData {
  final int id;
  final String name;
  final bool isActive;
  final double temperature;
  final double pressure;
  final int operationHours;
  final String fileId;

  GeneratorData({
    required this.id,
    required this.name,
    required this.isActive,
    required this.temperature,
    required this.pressure,
    required this.operationHours,
    this.fileId = '',
  });
}
