import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../app_exports.dart';
import '../services/firestore_realtime_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class DetailMesinScreen extends StatefulWidget {
  final String mesinName;
  final String fileId;
  final bool isActive;

  const DetailMesinScreen({
    Key? key,
    required this.mesinName,
    required this.fileId,
    required this.isActive,
  }) : super(key: key);

  @override
  State<DetailMesinScreen> createState() => _DetailMesinScreenState();
}

class _DetailMesinScreenState extends State<DetailMesinScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> logsheetData = {};
  Map<String, dynamic> realTimeData = {}; // Data real-time dari spreadsheet
  List<Map<String, dynamic>> allHourlyData = []; // NEW: Data semua jam hari ini
  bool isLoading = true;
  String? error;

  // Current valid fileId state variable
  String _currentValidFileId = '';

  // Firestore real-time variables
  StreamSubscription<QuerySnapshot>? _realtimeSubscription;
  Map<String, dynamic> _firestoreData = {};
  bool _isUsingFirestore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🔧 CRITICAL FIX: Validasi fileId untuk Mitsubishi #1 di Detail Screen
    _currentValidFileId = widget.fileId;
    _validateAndFixFileId();
    _initializeRealtimeData();
  }

  // Validasi dan perbaiki fileId untuk Mitsubishi #1
  Future<void> _validateAndFixFileId() async {
    if (widget.mesinName == 'Mitsubishi #1') {
      final problematicFileIds = [
        '1m-7mAUx8bFKBb9IeGcFUaH96nBJWT0Rw9Pv7VnP-iAM',
        '1-_G5vZD6xyXpxu1skcdQMB1auGBEW8upurPMuCm9YwA',
        '19Rq7EtX1IGdkXcie8c7O4WSDYd2SpM0rbeTehKkD-Zo',
      ];

      if (problematicFileIds.contains(widget.fileId)) {
        // Gunakan fileId terbaru yang benar dari storage
        final currentFileId = await StorageService.getActiveFileId(
          widget.mesinName,
        );
        if (currentFileId != null && currentFileId.isNotEmpty) {
          _currentValidFileId = currentFileId;
          print(
            '🔧 DETAIL: Fixed fileId for ${widget.mesinName}: $currentFileId (was: ${widget.fileId})',
          );
        }
      }
    }
  }

  // Dapatkan fileId yang benar untuk chart widget
  String _getCorrectedFileId() {
    return _currentValidFileId;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh data ketika app kembali ke foreground
    if (state == AppLifecycleState.resumed) {
      print('🔄 DETAIL: App resumed, refreshing data...');
      _refreshData();
    }
  }

  // Method untuk refresh semua data termasuk chart
  Future<void> _refreshData() async {
    print('🔄 DETAIL: Starting comprehensive data refresh...');
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      // Cancel existing subscription
      _realtimeSubscription?.cancel();

      // Reset state
      if (mounted) {
        setState(() {
          _isUsingFirestore = false;
          _firestoreData = {};
        });
      }

      // Reload logsheet data
      await _loadLogsheetData();

      // Reload hourly data untuk chart
      await _loadAllHourlyData();

      // Reinitialize real-time data
      await _initializeRealtimeData();

      print('✅ DETAIL: Data refresh completed');
    } catch (e) {
      print('❌ DETAIL: Error during refresh: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Initialize real-time data dengan Firestore fallback
  Future<void> _initializeRealtimeData() async {
    await _loadLogsheetData(); // Load local/Google Drive data first

    // Try to get real-time data from Firestore
    try {
      final firestoreData =
          await FirestoreRealtimeService.getDetailedDataForGenerator(
            widget.mesinName,
          );
      if (firestoreData.isNotEmpty && mounted) {
        setState(() {
          // Use the latest entry data from Firestore
          if (firestoreData.isNotEmpty) {
            _firestoreData = firestoreData.first;
            _isUsingFirestore = true;
            // Update realTimeData with latest Firestore data
            realTimeData = firestoreData.first;
          }
        });

        // Setup real-time listener
        _setupRealtimeListener();
      }
    } catch (e) {
      print('Firestore detail data not available, using Google Drive: $e');
    }
  }

  void _setupRealtimeListener() {
    _realtimeSubscription = FirestoreRealtimeService.listenToRealtimeUpdates(
      [widget.mesinName],
      (data) {
        if (mounted && data.containsKey(widget.mesinName)) {
          setState(() {
            final generatorData = data[widget.mesinName]!;
            _firestoreData = generatorData;
            // Update realTimeData with latest Firestore data for UI
            realTimeData = generatorData;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  // NEW: Fungsi untuk mengambil semua data hourly hari ini
  Future<void> _loadAllHourlyData() async {
    try {
      String fileId = widget.fileId;
      if (fileId.isEmpty) {
        final storedFileId = await StorageService.getActiveFileId(
          widget.mesinName,
        );
        if (storedFileId != null) {
          fileId = storedFileId;
        }
      }

      if (fileId.isNotEmpty) {
        // Buat service baru untuk membaca semua data hari ini dari spreadsheet
        final todayData = await _readAllTodayDataFromSpreadsheet(fileId);

        if (mounted) {
          setState(() {
            allHourlyData = todayData;
          });

          print(
            '🔄 DETAIL: Loaded ${allHourlyData.length} hourly data points for today',
          );
        }
      }
    } catch (e) {
      print('🔄 DETAIL: Error loading hourly data: $e');
    }
  }

  // NEW: Baca semua data hari ini dari spreadsheet
  Future<List<Map<String, dynamic>>> _readAllTodayDataFromSpreadsheet(
    String fileId,
  ) async {
    List<Map<String, dynamic>> todayData = [];

    try {
      print('🔍 Reading all today data from spreadsheet: $fileId');

      // Gunakan LogsheetService untuk membaca data dari spreadsheet
      final spreadsheetData = await LogsheetService.readLogsheetData(fileId);

      if (spreadsheetData.isNotEmpty) {
        // LogsheetService.readLogsheetData hanya mengembalikan data current hour
        // Kita perlu menggunakan service lain atau mengextend untuk membaca semua rows

        // Untuk sementara, gunakan data yang ada dan coba ambil dari HistoricalLogsheetService
        print('🔍 Trying to get historical data for today...');

        final historicalData =
            await HistoricalLogsheetService.getHistoricalData(
              widget.mesinName,
              daysBack: 1, // Hanya hari ini
            );

        // Filter hanya data hari ini
        final today = DateTime.now();
        final todayEntries = historicalData.where((data) {
          final dataDate = DateTime.tryParse(
            data['savedDate'] ?? data['fileDate'] ?? '',
          );
          if (dataDate != null) {
            return dataDate.year == today.year &&
                dataDate.month == today.month &&
                dataDate.day == today.day;
          }
          return false;
        }).toList();

        print('🔍 Found ${todayEntries.length} historical entries for today');

        if (todayEntries.isNotEmpty) {
          // Debug: print sample data structure
          print('🔍 Sample historical data structure:');
          for (int i = 0; i < math.min(3, todayEntries.length); i++) {
            Map<String, dynamic> sample = todayEntries[i];
            print(
              '🔍 Entry $i: jamOperasi=${sample['jamOperasi']}, timestamp=${sample['timestamp'] ?? sample['savedDate']}, keys=${sample.keys.toList()}',
            );
          }

          todayData = todayEntries;
        } else {
          // Jika tidak ada data historis, gunakan data current saja
          print('🔍 No historical data found, using current data only');
          Map<String, dynamic> currentData = Map.from(spreadsheetData);
          currentData['jamOperasi'] = DateTime.now().hour.toString();
          currentData['timestamp'] = DateTime.now().toIso8601String();
          todayData = [currentData];
        }
      } else {
        print('🔍 No spreadsheet data available');
      }
    } catch (e) {
      print('❌ Error reading all today data: $e');

      // Fallback: gunakan data logsheet yang sudah ada jika ada error
      if (logsheetData.isNotEmpty) {
        print('🔄 Using fallback: current logsheet data');
        Map<String, dynamic> currentData = Map.from(logsheetData);
        currentData['jamOperasi'] = DateTime.now().hour.toString();
        currentData['timestamp'] = DateTime.now().toIso8601String();
        todayData = [currentData];
      }
    }

    print('🔍 Final today data count: ${todayData.length}');
    return todayData;
  }

  // Load data real-time dari spreadsheet existing data
  Future<void> _loadRealTimeData() async {
    if (widget.fileId.isEmpty) {
      print('⚠️ No fileId available for real-time data');
      return;
    }

    try {
      print('🔄 Loading real-time data for ${widget.mesinName}');

      // Ambil data dari logsheet yang sudah ada
      if (logsheetData.isNotEmpty && mounted) {
        setState(() {
          realTimeData = _parseLogsheetDataToRealTime(logsheetData);
        });

        print('✅ Real-time data loaded from existing logsheet data');
        print('📊 Real-time data keys: ${realTimeData.keys.toList()}');
      } else {
        print('⚠️ No logsheet data available for real-time parsing');
      }
    } catch (e) {
      print('❌ Error loading real-time data: $e');
    }
  }

  // Parse data logsheet menjadi format real-time
  Map<String, dynamic> _parseLogsheetDataToRealTime(Map<String, dynamic> data) {
    return {
      'currentHour': DateTime.now().hour,
      'isRunning': widget.isActive,
      'isNormal': true,
      'performance': 'Normal',
      'alerts': [],
      'operationalData': {
        'RPM': data['rpm']?.toString() ?? 'N/A',
        'Load': data['beban']?.toString() ?? 'N/A',
        'Voltage R': data['voltageR']?.toString() ?? 'N/A',
        'Voltage S': data['voltageS']?.toString() ?? 'N/A',
        'Voltage T': data['voltageT']?.toString() ?? 'N/A',
        'Frequency': data['hz']?.toString() ?? 'N/A',
        'Oil Temp': data['lubeOilTemp']?.toString() ?? 'N/A',
        'Water Temp': data['waterTemp']?.toString() ?? 'N/A',
      },
      'hourlyData': {
        'Jam Operasi': data['jamOperasi']?.toString() ?? 'N/A',
        'RPM': data['rpm']?.toString() ?? 'N/A',
        'Lube Oil Temp': data['lubeOilTemp']?.toString() ?? 'N/A',
        'Oil Pressure': data['oilPressure']?.toString() ?? 'N/A',
        'Water Temp': data['waterTemp']?.toString() ?? 'N/A',
        'Tegangan Accu': data['teganganAccu']?.toString() ?? 'N/A',
        'Beban (Load)': data['beban']?.toString() ?? 'N/A',
        'Voltage R': data['voltageR']?.toString() ?? 'N/A',
        'Voltage S': data['voltageS']?.toString() ?? 'N/A',
        'Voltage T': data['voltageT']?.toString() ?? 'N/A',
        'Ampere R': data['ampereR']?.toString() ?? 'N/A',
        'Ampere S': data['ampereS']?.toString() ?? 'N/A',
        'Ampere T': data['ampereT']?.toString() ?? 'N/A',
        'Kvar': data['kvar']?.toString() ?? 'N/A',
        'Frequency (Hz)': data['hz']?.toString() ?? 'N/A',
        'CosPhi': data['cosPhi']?.toString() ?? 'N/A',
        'Temp Winding U': data['tempWindingU']?.toString() ?? 'N/A',
        'Temp Winding V': data['tempWindingV']?.toString() ?? 'N/A',
        'Temp Winding W': data['tempWindingW']?.toString() ?? 'N/A',
        'Temp Bearing': data['tempBearing']?.toString() ?? 'N/A',
        'Engine Pressure': data['enginePressureCrankcase']?.toString() ?? 'N/A',
        'Engine Temp Exhaust': data['engineTempExhaust']?.toString() ?? 'N/A',
      },
    };
  }

  Future<void> _loadLogsheetData({bool forceRefresh = false}) async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
          error = null;
        });
      }

      Map<String, dynamic>? data;

      // Debug: Print info
      print('🔄 DETAIL: Loading data for ${widget.mesinName}');
      print('🔄 DETAIL: fileId = "${widget.fileId}"');
      print('🔄 DETAIL: forceRefresh = $forceRefresh');

      // 🔧 CRITICAL FIX: Dapatkan fileId yang benar untuk Mitsubishi #1
      String validFileId = widget.fileId;
      if (widget.mesinName == 'Mitsubishi #1') {
        final problematicFileIds = [
          '1m-7mAUx8bFKBb9IeGcFUaH96nBJWT0Rw9Pv7VnP-iAM',
          '1-_G5vZD6xyXpxu1skcdQMB1auGBEW8upurPMuCm9YwA',
          '19Rq7EtX1IGdkXcie8c7O4WSDYd2SpM0rbeTehKkD-Zo',
        ];

        if (problematicFileIds.contains(widget.fileId)) {
          final currentFileId = await StorageService.getActiveFileId(
            widget.mesinName,
          );
          if (currentFileId != null && currentFileId.isNotEmpty) {
            validFileId = currentFileId;
            print(
              '🔧 DETAIL: Using corrected fileId: $validFileId (was: ${widget.fileId})',
            );
          }
        }
      }

      // Jika tidak force refresh, coba ambil dari storage terlebih dahulu
      if (!forceRefresh) {
        final storedData = await StorageService.getLastLogsheetData(
          widget.mesinName,
        );
        if (storedData != null) {
          data = storedData;
          print('🔄 DETAIL: Loaded data from storage: ${data.keys.toList()}');
        }
      }

      // Coba ambil fileId dari storage jika tidak ada, atau gunakan fileId yang sudah divalidasi
      String fileId = validFileId;
      if (fileId.isEmpty) {
        final storedFileId = await StorageService.getActiveFileId(
          widget.mesinName,
        );
        if (storedFileId != null) {
          fileId = storedFileId;
          print('🔄 DETAIL: Using stored fileId: $fileId');
        }
      } else {
        print('🔄 DETAIL: Using validated fileId: $fileId');
      }

      // Cek apakah fileId tersedia
      if (fileId.isEmpty) {
        if (mounted) {
          setState(() {
            error =
                'Belum ada logsheet untuk generator ini. Data pengisian akan muncul setelah logsheet dibuat dan diisi.';
            isLoading = false;
          });
        }
        return;
      }

      // Coba ambil data terbaru dari spreadsheet
      try {
        print('🔄 DETAIL: Reading from spreadsheet with fileId: $fileId');
        final spreadsheetData = await LogsheetService.readLogsheetData(fileId);
        if (spreadsheetData.isNotEmpty) {
          data = spreadsheetData;
          print(
            '🔄 DETAIL: Loaded data from spreadsheet: ${data.keys.toList()}',
          );
          print('🔄 DETAIL: Sample data: ${data.entries.take(5).toList()}');
          // Update storage dengan data terbaru
          await StorageService.saveLastLogsheetData(widget.mesinName, data);
        } else {
          print('🔄 DETAIL: Spreadsheet data is empty');
        }
      } catch (e) {
        print('🔄 DETAIL: Error loading from spreadsheet: $e');
        // Jika gagal ambil dari spreadsheet, gunakan data dari storage
      }

      if (mounted) {
        setState(() {
          logsheetData = data ?? {};
          isLoading = false;
        });
      }

      // Load real-time data setelah logsheet data dimuat
      if (logsheetData.isNotEmpty) {
        await _loadRealTimeData();
        await _loadAllHourlyData(); // NEW: Load semua data hourly untuk chart
      }

      // Jika tidak ada data sama sekali
      if (logsheetData.isEmpty && mounted) {
        setState(() {
          error = 'Belum ada data logsheet yang tersimpan untuk generator ini.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Terjadi kesalahan saat memuat data: ${e.toString()}';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header section
          DetailHeaderWidget(
            mesinName: widget.mesinName,
            isActive: widget.isActive,
            onBackPressed: () => Navigator.pop(context),
            isFirestoreConnected:
                _isUsingFirestore, // Kirim status koneksi Firestore
          ),

          // Firestore Status Indicator (Hidden - now shown in header as cloud icon)
          // if (_isUsingFirestore)
          //   Container(
          //     width: double.infinity,
          //     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //     margin: EdgeInsets.only(bottom: 8),
          //     decoration: BoxDecoration(
          //       color: Colors.green[50],
          //       border: Border.all(color: Colors.green[200]!),
          //     ),
          //     child: Row(
          //       children: [
          //         Icon(Icons.cloud_done, color: Colors.green[600], size: 16),
          //         SizedBox(width: 8),
          //         Text(
          //           'Real-time data from Firestore',
          //           style: TextStyle(
          //             color: Colors.green[700],
          //             fontSize: 12,
          //             fontWeight: FontWeight.w500,
          //           ),
          //         ),
          //         Spacer(),
          //         Container(
          //           width: 8,
          //           height: 8,
          //           decoration: BoxDecoration(
          //             color: Colors.green[500],
          //             shape: BoxShape.circle,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),

          // Content area
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF1E3A8A),
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Loading indicator
                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Memuat data logsheet...'),
                            ],
                          ),
                        ),
                      ),

                    // Error display
                    if (error != null && !isLoading)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 48,
                              color: Colors.orange[600],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              error!,
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _refreshData,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh Data'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[600],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Data sections (hanya tampilkan jika tidak ada error dan tidak loading)
                    if (!isLoading && error == null) ...[
                      // Grafik Temperatur Section dengan real-time data
                      TemperatureLineChartWidget(
                        fileId: _getCorrectedFileId(),
                        generatorName: widget.mesinName,
                        logsheetData: logsheetData,
                        realTimeData: realTimeData['hourlyData'] ?? {},
                        allHourlyData:
                            allHourlyData, // NEW: Kirim data semua jam
                        useGeneratorData:
                            true, // Gunakan data dari semua logsheet generator
                      ),

                      const SizedBox(height: 16),

                      // Parameter Engine dengan real-time data
                      EngineParametersWidget(
                        logsheetData: logsheetData,
                        realTimeData: realTimeData['hourlyData'] ?? {},
                      ),

                      const SizedBox(height: 16),

                      // Parameter Listrik Generator dengan real-time data
                      GeneratorElectricalWidget(
                        logsheetData: logsheetData,
                        realTimeData: realTimeData['hourlyData'] ?? {},
                      ),

                      const SizedBox(height: 16),

                      // Informasi Tambahan
                      const AdditionalInfoWidget(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar (konsisten dengan dashboard)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex:
            0, // Dashboard terpilih karena kita berasal dari dashboard
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(
                context,
                '/main',
                arguments: {'selectedIndex': 0}, // Dashboard
              );
              break;
            case 1:
              Navigator.pushReplacementNamed(
                context,
                '/main',
                arguments: {'selectedIndex': 1}, // Riwayat
              );
              break;
            case 2:
              Navigator.pushReplacementNamed(
                context,
                '/main',
                arguments: {'selectedIndex': 2}, // Pengaturan
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
