import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../app_exports.dart';
import '../services/simple_collaboration_service.dart';
import '../services/sync_manager.dart';

class LogsheetFormScreen extends StatefulWidget {
  final String generatorName;
  final int generatorId;
  final String? activeFileId; // Tambah parameter ini

  const LogsheetFormScreen({
    super.key,
    required this.generatorName,
    required this.generatorId,
    this.activeFileId, // Tambah parameter ini
  });

  @override
  State<LogsheetFormScreen> createState() => _LogsheetFormScreenState();
}

class _LogsheetFormScreenState extends State<LogsheetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _selectedIndex = 0;
  late ScaffoldMessengerState _scaffoldMessenger;
  String? _activeFileId;

  // SIMPLIFIED: Hanya perlu tahu apakah ada data existing atau tidak
  bool _hasExistingData = false;
  Map<String, dynamic> _existingData = {};

  // State untuk tracking data energi/BBM
  bool _hasEnergyBbmData = false;

  // Real-time sync untuk cross-device collaboration
  StreamSubscription? _firestoreListener;
  Timer? _periodicDataChecker;

  // Collaboration features disabled to avoid extra Firestore collections
  // bool _isFormLocked = false;

  // Kontroller form
  final TextEditingController _jamOperasiController = TextEditingController();
  final TextEditingController _rpmController = TextEditingController();
  final TextEditingController _lubeOilTempController = TextEditingController();
  final TextEditingController _oilPressureController = TextEditingController();
  final TextEditingController _waterTempController = TextEditingController();
  final TextEditingController _teganganAccuController = TextEditingController();
  final TextEditingController _bebanController = TextEditingController();
  final TextEditingController _voltageRController = TextEditingController();
  final TextEditingController _voltageSController = TextEditingController();
  final TextEditingController _voltageTController = TextEditingController();
  final TextEditingController _ampereRController = TextEditingController();
  final TextEditingController _ampereSController = TextEditingController();
  final TextEditingController _ampereTController = TextEditingController();
  final TextEditingController _kvarController = TextEditingController();
  final TextEditingController _hzController = TextEditingController();
  final TextEditingController _cosPhiController = TextEditingController();
  final TextEditingController _tempWindingUController = TextEditingController();
  final TextEditingController _tempWindingVController = TextEditingController();
  final TextEditingController _tempWindingWController = TextEditingController();
  final TextEditingController _tempBearingController = TextEditingController();
  final TextEditingController _enginePressureCrankcaseController =
      TextEditingController();
  final TextEditingController _engineTempExhaustController =
      TextEditingController();

  // Controller untuk tracking energi dan BBM
  final TextEditingController _kwhAwalController = TextEditingController();
  final TextEditingController _kwhAkhirController = TextEditingController();
  final TextEditingController _totalKwhController = TextEditingController();
  final TextEditingController _bbmAwalController = TextEditingController();
  final TextEditingController _bbmAkhirController = TextEditingController();
  final TextEditingController _totalBbmController = TextEditingController();
  final TextEditingController _sfcController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print(
      '🚀 LOGSHEET FORM: initState called for generator ${widget.generatorName}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scaffoldMessenger = ScaffoldMessenger.of(context);
      print('LOGSHEET: Mulai inisialisasi form...');
      _initializeFormMode();
      await _loadPreviousDayEnergyData(); // Auto-fill kWh dan BBM awal dari hari sebelumnya

      // Tambahkan delay kecil untuk memastikan _activeFileId sudah tersedia
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadExistingEnergyData(); // Load data energi/BBM yang sudah tersimpan

      // Cek collision prevention
      await _checkEditingCollision();

      // Set up form change listeners for real-time collaboration
      _setupFormChangeListeners();

      // Set up real-time sync untuk cross-device collaboration
      _setupRealtimeSync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-refresh form setiap jam untuk update tombol
    _scheduleHourlyRefresh();
  }

  @override
  void didUpdateWidget(LogsheetFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('LOGSHEET: Form diperbarui, refresh mode dan sync...');
    // Refresh form mode ketika widget diupdate (misalnya kembali dari page lain)
    _initializeFormMode();

    // Re-setup real-time sync jika diperlukan
    if (_firestoreListener == null) {
      _setupRealtimeSync();
    }
  }

  // Schedule refresh otomatis setiap pergantian jam
  void _scheduleHourlyRefresh() {
    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    final timeUntilNextHour = nextHour.difference(now);

    print('JADWAL: Refresh dalam ${timeUntilNextHour.inMinutes} menit');

    Future.delayed(timeUntilNextHour, () {
      if (mounted) {
        print('JADWAL: Jam berubah ke ${DateTime.now().hour}, refresh form');
        _initializeFormMode();
        _scheduleHourlyRefresh(); // Schedule next refresh
      }
    });
  }

  // Cek apakah form sedang diedit oleh user lain (collision prevention)
  Future<void> _checkEditingCollision() async {
    try {
      final currentHour = DateTime.now().hour;
      final checkResult = await SimpleCollaborationService.checkIfEditing(
        generatorName: widget.generatorName,
        hour: currentHour,
      );

      if (!checkResult['canEdit']) {
        final message =
            checkResult['message'] ?? 'Sedang diedit oleh user lain';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $message\nMohon coba lagi dalam beberapa menit'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        // Tambahkan small delay sebelum kembali
        await Future.delayed(Duration(seconds: 2));

        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      // Jika bisa edit, mulai session
      await SimpleCollaborationService.startEditing(
        generatorName: widget.generatorName,
        hour: currentHour,
      );

      // Setup heartbeat untuk update aktivitas
      _startActivityHeartbeat();

      print('KOLABORASI: Mulai sesi edit');
    } catch (e) {
      print('KOLABORASI: Error cek konflik: $e');
      // Jika error, lanjutkan saja (fail safe)
    }
  }

  // Heartbeat untuk update aktivitas
  Timer? _activityTimer;

  void _startActivityHeartbeat() {
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(Duration(minutes: 2), (timer) {
      final currentHour = DateTime.now().hour;
      SimpleCollaborationService.updateActivity(
        generatorName: widget.generatorName,
        hour: currentHour,
      );
    });
  }

  // Setup listeners untuk real-time collaboration
  void _setupFormChangeListeners() {
    // Set up listeners untuk semua text controller
    final controllers = [
      _jamOperasiController,
      _rpmController,
      _lubeOilTempController,
      _oilPressureController,
      _waterTempController,
      _teganganAccuController,
      _bebanController,
      _voltageRController,
      _voltageSController,
      _voltageTController,
      _ampereRController,
      _ampereSController,
      _ampereTController,
      _kvarController,
      _hzController,
      _cosPhiController,
      _tempWindingUController,
      _tempWindingVController,
      _tempWindingWController,
      _tempBearingController,
      _enginePressureCrankcaseController,
      _engineTempExhaustController,
    ];

    for (final controller in controllers) {
      // Only add listener if widget is still mounted and controller is valid
      if (!mounted) return;
      try {
        controller.addListener(_onFormDataChanged);
      } catch (e) {
        print('⚠️ Controller already disposed or error adding listener: $e');
      }
    }
  }

  // Setup real-time sync untuk cross-device collaboration
  void _setupRealtimeSync() {
    try {
      print(
        '🔄 FORM_SYNC: Setting up real-time sync for ${widget.generatorName}',
      );

      // Cancel existing listener jika ada
      _firestoreListener?.cancel();

      // Listen untuk updates dari Firestore untuk generator ini
      _firestoreListener = FirestoreRealtimeService.listenToRealtimeUpdates(
        [widget.generatorName],
        (data) {
          if (mounted && data.containsKey(widget.generatorName)) {
            final generatorData = data[widget.generatorName]!;
            print(
              '🔄 FORM_SYNC: Received real-time data: ${generatorData.keys.length} fields',
            );
            _handleRealtimeUpdate(generatorData);
          }
        },
      );

      // Setup periodic checker untuk detect Google Sheets changes
      _setupPeriodicDataChecker();

      print('✅ FORM_SYNC: Real-time sync listener active');
    } catch (e) {
      print('❌ FORM_SYNC: Failed to setup real-time sync: $e');
    }
  }

  // Setup periodic checker untuk detect changes di Google Sheets
  void _setupPeriodicDataChecker() {
    _periodicDataChecker?.cancel();

    _periodicDataChecker = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        print('🔍 PERIODIC_CHECK: Checking for data changes...');

        // Clear cache sebelum check untuk memastikan data fresh
        final currentHour = DateTime.now().hour;
        await StorageService.resetCurrentHourDataStatus(
          widget.generatorName,
          currentHour,
        );

        bool hasData = await _checkIfCurrentHourHasDataInSpreadsheet();

        if (hasData && !_hasExistingData) {
          print('📥 PERIODIC_CHECK: Found new data from another device!');

          // Load data terbaru
          await _loadExistingData();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.sync, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data baru terdeteksi dari device lain! Form beralih ke mode edit.',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('❌ PERIODIC_CHECK: Error checking for data changes: $e');
      }
    });

    print('✅ PERIODIC_CHECK: Periodic data checker started (30s interval)');
  }

  // Handle real-time updates dari device lain
  void _handleRealtimeUpdate(Map<String, dynamic> generatorData) {
    try {
      final currentHour = DateTime.now().hour;
      final dataHour =
          int.tryParse(generatorData['jamOperasi']?.toString() ?? '0') ?? 0;

      print(
        '🔄 FORM_SYNC: Processing real-time update for data hour $dataHour, current hour $currentHour',
      );
      print('📊 FORM_SYNC: Update data keys: ${generatorData.keys.toList()}');

      // Hanya proses update jika untuk jam yang sama atau data memiliki informasi jam
      if (dataHour == currentHour ||
          generatorData.containsKey('kwhAwal') ||
          generatorData.containsKey('bbmAwal')) {
        print(
          '📥 FORM_SYNC: Received valid real-time update for current session',
        );

        // Update form state dan data
        if (mounted) {
          setState(() {
            _hasExistingData = true;
            _existingData = Map<String, dynamic>.from(generatorData);

            print(
              '🔄 FORM_SYNC: State updated - hasExistingData: $_hasExistingData',
            );
          });

          // Fill form dengan data yang baru diterima
          _fillFormWithExistingData(generatorData);

          print('✅ FORM_SYNC: Form updated with data from another device');

          // Show notification kepada user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.sync, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data diperbarui dari device lain! Form sekarang dalam mode edit.',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.blue[600],
                duration: Duration(seconds: 3),
              ),
            );
          }

          // Force rebuild widget untuk update button state
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }
        }
      } else {
        print(
          'ℹ️ FORM_SYNC: Skipping update - data hour $dataHour does not match current hour $currentHour',
        );
      }
    } catch (e) {
      print('❌ FORM_SYNC: Error handling real-time update: $e');
    }
  }

  // Callback ketika form data berubah
  void _onFormDataChanged() {
    // Debounce untuk avoid terlalu banyak update - DISABLED collaboration
    // if (!_isFormLocked) {
    //   _saveFormDraftDebounced();
    // }
  }

  // Pull-to-refresh handler
  Future<void> _refreshFormData() async {
    final currentHour = DateTime.now().hour;
    print('FORM: Refresh untuk jam: $currentHour');

    _scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          'Memuat ulang data untuk jam ${currentHour.toString().padLeft(2, '0')}:00...',
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        duration: const Duration(seconds: 2),
      ),
    );

    _initializeFormMode();
  }

  Timer? _saveDraftTimer;

  // Collaboration features disabled - draft saving removed
  // void _saveFormDraftDebounced() {
  //   // Collaboration draft saving disabled to avoid extra Firestore collections
  //   // _saveDraftTimer?.cancel();
  //   // _saveDraftTimer = Timer(Duration(seconds: 2), () {
  //   //   _saveCurrentFormDataAsDraft();
  //   // });
  // }

  // Save current form data sebagai draft untuk collaboration - DISABLED
  // Future<void> _saveCurrentFormDataAsDraft() async {
  //   if (_isFormLocked) return;

  //   try {
  //     final formData = _collectFormData();
  //     await FormCollaborationService.saveFormDraft(
  //       generatorName: widget.generatorName,
  //       hour: DateTime.now().hour,
  //       formData: formData,
  //     );
  //     print('💾 COLLABORATION: Auto-saved form draft');
  //   } catch (e) {
  //     print('❌ COLLABORATION: Error auto-saving draft: $e');
  //   }
  // }

  // Collect semua form data untuk collaboration - DISABLED
  // Map<String, dynamic> _collectFormData() {
  //   return {
  //     'jamOperasi': _jamOperasiController.text,
  //     'rpm': _rpmController.text,
  //     'lubeOilTemp': _lubeOilTempController.text,
  //     'oilPressure': _oilPressureController.text,
  //     'waterTemp': _waterTempController.text,
  //     'teganganAccu': _teganganAccuController.text,
  //     'beban': _bebanController.text,
  //     'voltageR': _voltageRController.text,
  //     'voltageS': _voltageSController.text,
  //     'voltageT': _voltageTController.text,
  //     'ampereR': _ampereRController.text,
  //     'ampereS': _ampereSController.text,
  //     'ampereT': _ampereTController.text,
  //     'kvar': _kvarController.text,
  //     'hz': _hzController.text,
  //     'cosPhi': _cosPhiController.text,
  //     'tempWindingU': _tempWindingUController.text,
  //     'tempWindingV': _tempWindingVController.text,
  //     'tempWindingW': _tempWindingWController.text,
  //     'tempBearing': _tempBearingController.text,
  //     'enginePressureCrankcase': _enginePressureCrankcaseController.text,
  //     'engineTempExhaust': _engineTempExhaustController.text,
  //     'timestamp': DateTime.now().toIso8601String(),
  //   };
  // }

  // SIMPLIFIED: Inisialisasi form - cek apakah ada data untuk jam saat ini
  void _initializeFormMode() async {
    final currentHour = DateTime.now().hour;
    final dateKey = StorageService.formatLogsheetDateKey();

    print(
      '🔄 FORM_INIT: Menginisialisasi form for ${widget.generatorName} hour: $currentHour on logsheet date: $dateKey',
    );

    // Pastikan file ID konsisten untuk hari ini
    await GeneratorDataManager.ensureConsistentFileId(widget.generatorName);

    // Ambil fileId dari storage (sudah ter-filter untuk hari ini)
    final storedFileId = await StorageService.getFileIdWithFirestoreSync(
      widget.generatorName,
    );

    if (storedFileId != null && storedFileId.isNotEmpty) {
      setState(() {
        _activeFileId = storedFileId;
      });
      print(
        '✅ FORM_INIT: Using consistent fileId for ${widget.generatorName}: ${storedFileId.substring(0, 15)}...',
      );
    } else if (widget.activeFileId != null && widget.activeFileId!.isNotEmpty) {
      setState(() {
        _activeFileId = widget.activeFileId;
      });
      // Simpan ke storage dengan tanggal
      await StorageService.saveActiveFileId(
        widget.generatorName,
        widget.activeFileId!,
      );
      await GeneratorDataManager.updateGeneratorFileId(
        widget.generatorName,
        widget.activeFileId!,
      );
      print(
        '✅ FORM_INIT: Saved passed fileId for ${widget.generatorName}: ${widget.activeFileId!.substring(0, 15)}...',
      );
    } else {
      print(
        '⚠️ FORM_INIT: No fileId available for ${widget.generatorName} on $dateKey',
      );
    }

    // Load data existing dari storage atau spreadsheet
    await _loadExistingData();
  }

  // Load data existing dari spreadsheet atau storage
  Future<void> _loadExistingData() async {
    try {
      print(
        '🔄 LOADING DATA: Starting check for current hour: ${DateTime.now().hour}',
      );

      // METODE BARU: Langsung cek spreadsheet untuk data jam saat ini
      final hasDataInSpreadsheet =
          await _checkIfCurrentHourHasDataInSpreadsheet();

      if (hasDataInSpreadsheet) {
        // Ada data di spreadsheet untuk jam ini, load dan masuk mode EDIT
        final fileId = _activeFileId;
        if (fileId != null) {
          try {
            final spreadsheetData = await LogsheetService.readLogsheetData(
              fileId,
            );
            if (spreadsheetData.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _hasExistingData = true;
                  _existingData = spreadsheetData;
                });
              }
              _fillFormWithExistingData(spreadsheetData);
              print('MODE: EDIT - Data berhasil dimuat dari spreadsheet');
              print('UI: Tampilkan tombol Edit Data');
              return;
            }
          } catch (e) {
            print('❌ Error loading from spreadsheet: $e');
          }
        }
      }

      // Tidak ada data di spreadsheet untuk jam ini, masuk mode SIMPAN BARU
      if (mounted) {
        setState(() {
          _hasExistingData = false;
          _existingData.clear();
        });
      }
      _clearFormForNewHour();
      print('✅ MODE SET: SIMPAN BARU - No data found for current hour');
      print('📝 UI WILL SHOW: Simpan Data button');
    } catch (e) {
      print('❌ Error loading existing data: $e');
      if (mounted) {
        setState(() {
          _hasExistingData = false;
        });
      }
    }
  }

  // Cek apakah jam saat ini sudah ada data yang tersimpan di spreadsheet
  Future<bool> _checkIfCurrentHourHasDataInSpreadsheet() async {
    final currentHour = DateTime.now().hour;
    final fileId = _activeFileId;

    print('🔍 CHECKING SPREADSHEET: Hour=$currentHour, FileId=$fileId');

    // 🔄 SMART CACHE: Check if this is the first time checking this hour today
    final prefs = await SharedPreferences.getInstance();
    final dateKey = StorageService.formatLogsheetDateKey();
    final lastCheckedHourKey = 'lastCheckedHour_$dateKey';
    final lastCheckedHour = prefs.getInt(lastCheckedHourKey) ?? -1;

    // If this is a new hour (different from last checked), reset cache and check fresh
    final isNewHour = currentHour != lastCheckedHour;
    if (isNewHour) {
      print(
        '🆕 NEW HOUR DETECTED: $currentHour (was $lastCheckedHour), checking fresh data',
      );
      await StorageService.resetCurrentHourDataStatus(
        widget.generatorName,
        currentHour,
      );
      await prefs.setInt(lastCheckedHourKey, currentHour);
    } else {
      // 🏪 For same hour, check cache first for quick response
      final cachedStatus = await StorageService.getHourDataStatus(
        widget.generatorName,
        currentHour,
      );
      if (cachedStatus) {
        print(
          '🏪 CACHE HIT: Found saved status for ${widget.generatorName} hour $currentHour = true',
        );
        return true;
      }
    }

    // Clean up old cache daily
    await StorageService.cleanupOldHourDataCache();

    // 🧪 TESTING: Let's also check hour 9 to see how it behaves when data exists
    if (currentHour == 11) {
      await _testHourWithKnownData(
        9,
        fileId,
      ); // Hour 9 should have data based on logs
    }

    if (fileId == null) {
      print('🔍 RESULT: No active fileId, assuming no data');
      return false;
    }

    try {
      // Mechanism retry untuk menangani latensi Google Sheets API
      Map<String, dynamic> spreadsheetData = {};
      int maxRetries = 3;
      int retryCount = 0;

      while (retryCount < maxRetries) {
        print(
          '🔄 ATTEMPT ${retryCount + 1}/$maxRetries: Reading spreadsheet data...',
        );

        // Baca data langsung dari spreadsheet untuk memastikan data terkini
        spreadsheetData = await LogsheetService.readLogsheetData(fileId);

        // Cek apakah kita mendapat data yang bermakna
        if (spreadsheetData.isNotEmpty) {
          // Cek tambahan untuk cell spesifik untuk melihat apakah data benar-benar ada
          String testTargetCell;
          if (currentHour >= 10) {
            final rowNumber = 13 + (currentHour - 10);
            testTargetCell = 'D$rowNumber';
          } else {
            final rowNumber = 27 + currentHour;
            testTargetCell = 'D$rowNumber';
          }

          final testCellValue = spreadsheetData[testTargetCell];
          print('🔄 RETRY CHECK: Cell $testTargetCell = "$testCellValue"');

          // If we recently saved data but still getting null, retry
          if (testCellValue == null ||
              testCellValue.toString().trim().isEmpty ||
              testCellValue.toString() == 'null') {
            print('🔄 RETRY: Data not propagated yet, will retry...');
          } else {
            print('🔄 SUCCESS: Real data found, stopping retry');
            break;
          }
        }

        retryCount++;
        if (retryCount < maxRetries) {
          print('⏳ RETRY: Waiting 3 seconds before next attempt...');
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      if (spreadsheetData.isEmpty) {
        print(
          '🔍 RESULT: Spreadsheet is empty after $maxRetries attempts, no data for current hour',
        );
        return false;
      }

      // Cek apakah ada data untuk jam saat ini berdasarkan struktur row
      // Jam 10:00-23:00 = baris 13-26, Jam 00:00-09:00 = baris 27-36
      String targetCell;
      if (currentHour >= 10) {
        final rowNumber =
            13 + (currentHour - 10); // 10:00=13, 11:00=14, ..., 23:00=26
        targetCell = 'D$rowNumber'; // Cell jam operasi
      } else {
        final rowNumber = 27 + currentHour; // 00:00=27, 01:00=28, ..., 09:00=36
        targetCell = 'D$rowNumber'; // Cell jam operasi
      }

      // : Print semua data dalam range C13-C36 dan D13-D36
      print('🔍 SPREADSHEET :');
      for (int i = 13; i <= 36; i++) {
        final timeCell = 'C$i';
        final jamCell = 'D$i';
        final timeValue = spreadsheetData[timeCell];
        final jamValue = spreadsheetData[jamCell];
        if (timeValue != null || jamValue != null) {
          print('   Row $i: C$i="$timeValue", D$i="$jamValue"');
        }
      }

      // Periksa apakah cell untuk jam ini sudah berisi data
      final cellValue = spreadsheetData[targetCell];
      final hasData =
          cellValue != null && cellValue.toString().trim().isNotEmpty;

      print('🔍 CHECKING CELL: $targetCell for hour $currentHour');
      print('🔍 JAM OPERASI VALUE: "$cellValue"');

      // Cek ulang dengan cell lain di row yang sama (seperti RPM)
      String? rpmCell;
      if (currentHour >= 10) {
        final rowNumber = 13 + (currentHour - 10);
        rpmCell = 'E$rowNumber'; // Cell RPM
      } else {
        final rowNumber = 27 + currentHour;
        rpmCell = 'E$rowNumber'; // Cell RPM
      }
      final rpmValue = spreadsheetData[rpmCell];
      final hasRpmData =
          rpmValue != null && rpmValue.toString().trim().isNotEmpty;

      // Anggap ada data jika jam operasi ATAU RPM terisi
      final finalHasData = hasData || hasRpmData;

      print('🔍 CHECKING CELL: $targetCell for hour $currentHour');
      print('🔍 JAM OPERASI VALUE: "$cellValue"');
      print('🔍 RPM CELL: $rpmCell');
      print('🔍 RPM VALUE: "$rpmValue"');
      print(
        '🔍 RESULT: ${finalHasData ? "⚠️ DATA EXISTS - SHOULD SHOW EDIT MODE" : "✅ NO DATA - SHOULD SHOW SAVE MODE"}',
      );

      return finalHasData;
    } catch (e) {
      print('🔍 ERROR checking spreadsheet data: $e');
      return false; // Jika error, anggap tidak ada data (mode simpan)
    }
  }

  // 🧪 TEST FUNCTION: Check a specific hour to see the data detection behavior
  Future<void> _testHourWithKnownData(int testHour, String? fileId) async {
    print('🧪 TESTING HOUR $testHour (should have data):');

    if (fileId == null) return;

    try {
      final spreadsheetData = await LogsheetService.readLogsheetData(fileId);

      // 🔍 : Print structure in the correct order based on actual spreadsheet
      print('🧪 SPREADSHEET STRUCTURE (key fields):');
      final keyFields = [
        'C$testHour',
        'D$testHour',
        'E$testHour',
        'F$testHour',
        'G$testHour',
        'H$testHour',
        'J$testHour',
        'K$testHour',
        'L$testHour',
        'M$testHour',
        'N$testHour',
        'O$testHour',
        'P$testHour',
        'Q$testHour',
        'R$testHour',
        'T$testHour',
        'U$testHour',
        'X$testHour',
        'Y$testHour',
        'Z$testHour',
        'AA$testHour',
        'AB$testHour',
        'AC$testHour',
      ];

      for (String cellKey in keyFields) {
        final cellValue = spreadsheetData[cellKey];
        if (cellValue != null &&
            cellValue.toString().trim().isNotEmpty &&
            cellValue.toString() != 'null') {
          print('🧪   $cellKey: "$cellValue"');
        }
      }

      // 🔍 : Print expected structure for reference
      print('🧪 EXPECTED STRUCTURE (based on Anda\'s specification):');
      print(
        '🧪   C13=Time(10:00), D13=HM Mesin, E13=RPM, F13=L/O Temp, G13=Oil Press',
      );
      print('🧪   H13=Water Temp, J13=Accu(V), K13=Beban(KW), L13=Voltage(R)');
      print(
        '🧪   M13=Voltage(S), N13=Voltage(T), O13=Ampere(R), P13=Ampere(S)',
      );
      print('🧪   Q13=Ampere(T), R13=Kvar, S13=Hz, U13=CosPhi');
      print(
        '🧪   X13=Temp Winding(U), Y13=Temp Winding(V), W13=Temp Winding(W)',
      );
      print('🧪   AA13=Temp Bearing, AB13=Press Crankcase, AC13=Temp Exhaust');

      String targetCell;
      String rpmCell;

      if (testHour >= 10) {
        final rowNumber = 13 + (testHour - 10);
        targetCell = 'D$rowNumber';
        rpmCell = 'E$rowNumber';
      } else {
        final rowNumber = 27 + testHour;
        targetCell = 'D$rowNumber';
        rpmCell = 'E$rowNumber';
      }

      final jamOperasiValue = spreadsheetData[targetCell];
      final rpmValue = spreadsheetData[rpmCell];

      print('🧪 TEST RESULT for Hour $testHour:');
      print('🧪   Expected Jam Operasi cell: $targetCell');
      print('🧪   Expected RPM cell: $rpmCell');
      print('🧪   Jam Operasi value: "$jamOperasiValue"');
      print('🧪   RPM value: "$rpmValue"');
      print(
        '🧪   Has data: ${jamOperasiValue?.toString().trim().isNotEmpty == true || rpmValue?.toString().trim().isNotEmpty == true}',
      );

      // 🔍 Let's also check if data exists in different rows for hour 9
      if (testHour == 9) {
        print('🧪 Check tambahan');
        for (int row = 30; row <= 40; row++) {
          final testCell = 'D$row';
          final testValue = spreadsheetData[testCell];
          if (testValue != null &&
              testValue.toString().trim().isNotEmpty &&
              testValue.toString() != 'null') {
            print('🧪   Found data in row $row: D$row = "$testValue"');
          }
        }
      }
    } catch (e) {
      print('🧪 TEST ERROR: $e');
    }
  }

  // Bersihkan form untuk jam baru
  void _clearFormForNewHour() {
    print('Clearing form for new hour: ${DateTime.now().hour}');

    // Reset semua field termasuk jam operasi (let user input manually)
    _jamOperasiController.clear(); // ✅ CHANGED: Clear instead of auto-fill
    _rpmController.clear();
    _lubeOilTempController.clear();
    _oilPressureController.clear();
    _waterTempController.clear();
    _teganganAccuController.clear();
    _bebanController.clear();
    _voltageRController.clear();
    _voltageSController.clear();
    _voltageTController.clear();
    _ampereRController.clear();
    _ampereSController.clear();
    _ampereTController.clear();
    _kvarController.clear();
    _hzController.clear();
    _cosPhiController.clear();
    _tempWindingUController.clear();
    _tempWindingVController.clear();
    _tempWindingWController.clear();
    _tempBearingController.clear();
    _enginePressureCrankcaseController.clear();
    _engineTempExhaustController.clear();

    // Reset data yang ada
    _existingData.clear();

    print('Form cleared for new hour entry');
  }

  // Fill form dengan data existing
  void _fillFormWithExistingData(Map<String, dynamic> data) {
    print(
      '📝 FORM_FILL: Filling form with data for jam: ${data['jamOperasi']}, saved at hour: ${data['_savedHour']}',
    );
    print('📝 FORM_FILL: Available data keys: ${data.keys.toList()}');

    // Isi form dengan data operational (abaikan metadata yang diawali dengan _)
    _jamOperasiController.text = data['jamOperasi']?.toString() ?? '';
    _rpmController.text = data['rpm']?.toString() ?? '';
    _lubeOilTempController.text = data['lubeOilTemp']?.toString() ?? '';
    _oilPressureController.text = data['oilPressure']?.toString() ?? '';
    _waterTempController.text = data['waterTemp']?.toString() ?? '';
    _teganganAccuController.text = data['teganganAccu']?.toString() ?? '';
    _bebanController.text = data['beban']?.toString() ?? '';
    _voltageRController.text = data['voltageR']?.toString() ?? '';
    _voltageSController.text = data['voltageS']?.toString() ?? '';
    _voltageTController.text = data['voltageT']?.toString() ?? '';
    _ampereRController.text = data['ampereR']?.toString() ?? '';
    _ampereSController.text = data['ampereS']?.toString() ?? '';
    _ampereTController.text = data['ampereT']?.toString() ?? '';
    _kvarController.text = data['kvar']?.toString() ?? '';
    _hzController.text = data['hz']?.toString() ?? '';
    _cosPhiController.text = data['cosPhi']?.toString() ?? '';
    _tempWindingUController.text = data['tempWindingU']?.toString() ?? '';
    _tempWindingVController.text = data['tempWindingV']?.toString() ?? '';
    _tempWindingWController.text = data['tempWindingW']?.toString() ?? '';
    _tempBearingController.text = data['tempBearing']?.toString() ?? '';
    _enginePressureCrankcaseController.text =
        data['enginePressureCrankcase']?.toString() ?? '';
    _engineTempExhaustController.text =
        data['engineTempExhaust']?.toString() ?? '';

    // ⚡ PERBAIKAN: Isi energy fields (kWh dan BBM) yang sebelumnya terlewat
    _kwhAwalController.text = data['kwhAwal']?.toString() ?? '';
    _kwhAkhirController.text = data['kwhAkhir']?.toString() ?? '';
    _bbmAwalController.text = data['bbmAwal']?.toString() ?? '';
    _bbmAkhirController.text = data['bbmAkhir']?.toString() ?? '';

    print('✅ FORM_FILL: Form filled successfully including energy fields');
    print(
      '📊 FORM_FILL: Energy data - kWh: ${data['kwhAwal']} → ${data['kwhAkhir']}, BBM: ${data['bbmAwal']} → ${data['bbmAkhir']}',
    );
  }

  // Cek apakah waktu sudah memungkinkan untuk entry baru
  bool _canCreateNewEntry() {
    // REMOVED: Tidak perlu lagi cek canCreateNewEntry
    return true;
  }

  // SIMPLIFIED: Get status message
  String _getStatusMessage() {
    final currentHour = DateTime.now().hour;

    if (_hasExistingData) {
      return 'Mode edit untuk jam ${currentHour.toString().padLeft(2, '0')}:00';
    } else {
      return 'Siap untuk mengisi data jam ${currentHour.toString().padLeft(2, '0')}:00';
    }
  }

  // IMPROVED: Get button color berdasarkan kondisi data di spreadsheet
  Color _getButtonColor() {
    if (_hasExistingData) {
      return Colors.grey.shade600; // Edit mode - data sudah ada untuk jam ini
    } else {
      return const Color(0xFF1E3A8A); // Save mode - warna biru aplikasi
    }
  }

  // IMPROVED: Get button icon berdasarkan kondisi data di spreadsheet
  IconData _getButtonIcon() {
    if (_hasExistingData) {
      return Icons.edit; // Edit mode - data sudah ada untuk jam ini
    } else {
      return Icons.save; // Save mode - belum ada data untuk jam ini
    }
  }

  // IMPROVED: Get button text berdasarkan kondisi data di spreadsheet
  String _getButtonText() {
    final currentHour = DateTime.now().hour;
    final buttonText = _hasExistingData
        ? 'Edit Data Jam ${currentHour.toString().padLeft(2, '0')}:00'
        : 'Simpan Data Jam ${currentHour.toString().padLeft(2, '0')}:00';

    print('🎯 BUTTON TEXT: "$buttonText" (hasExistingData: $_hasExistingData)');
    return buttonText;
  }

  @override
  void dispose() {
    // Cleanup collaboration timer
    _saveDraftTimer?.cancel();
    _activityTimer?.cancel();

    // Cleanup real-time sync listener
    _firestoreListener?.cancel();

    // Cleanup periodic data checker
    _periodicDataChecker?.cancel();

    // End collaboration session
    final currentHour = DateTime.now().hour;
    SimpleCollaborationService.endEditing(
      generatorName: widget.generatorName,
      hour: currentHour,
    );

    // Dispose text controllers
    _jamOperasiController.dispose();
    _rpmController.dispose();
    _lubeOilTempController.dispose();
    _oilPressureController.dispose();
    _waterTempController.dispose();
    _teganganAccuController.dispose();
    _bebanController.dispose();
    super.dispose();
  }

  String _getCurrentDateTime() {
    return DateTimeUtils.getCurrentDateTime();
  }

  void _showEnergyBbmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.electrical_services, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              const Text('Data kWh dan BBM'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tracking Energi & BBM Section
                const Text(
                  'Tracking Energi & BBM',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),

                // kWh Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Konsumsi Listrik (kWh)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              icon: Icons.electrical_services,
                              label: 'kWh Awal',
                              controller: _kwhAwalController,
                              hintText: 'Masukkan kWh awal',
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _calculateTotals(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              icon: Icons.electrical_services,
                              label: 'kWh Akhir',
                              controller: _kwhAkhirController,
                              hintText: 'Masukkan kWh akhir',
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _calculateTotals(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildFormField(
                        icon: Icons.flash_on,
                        label: 'Total kWh',
                        controller: _totalKwhController,
                        hintText: 'Total otomatis terhitung',
                        keyboardType: TextInputType.number,
                        readOnly: true,
                        backgroundColor: Colors.blue.withOpacity(0.1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // BBM Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Konsumsi BBM (Liter)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              icon: Icons.local_gas_station,
                              label: 'BBM Awal',
                              controller: _bbmAwalController,
                              hintText: 'Masukkan BBM awal',
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _calculateTotals(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              icon: Icons.local_gas_station,
                              label: 'BBM Akhir',
                              controller: _bbmAkhirController,
                              hintText: 'Masukkan BBM akhir',
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _calculateTotals(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildFormField(
                        icon: Icons.water_drop,
                        label: 'Total BBM',
                        controller: _totalBbmController,
                        hintText: 'Total otomatis terhitung',
                        keyboardType: TextInputType.number,
                        readOnly: true,
                        backgroundColor: Colors.orange.withOpacity(0.1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // SFC Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'SFC (Specific Fuel Consumption)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildFormField(
                        icon: Icons.analytics,
                        label: 'SFC (g/kWh)',
                        controller: _sfcController,
                        hintText: 'SFC otomatis terhitung',
                        keyboardType: TextInputType.number,
                        readOnly: true,
                        backgroundColor: Colors.green.withOpacity(0.1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _saveEnergyBbmData();
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              const Text('Konfirmasi Hapus'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apakah Anda yakin ingin menghapus logsheet untuk ${widget.generatorName}?',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Peringatan:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• Semua data akan dihapus\n• Tindakan ini tidak dapat dibatalkan\n• File spreadsheet akan dihapus permanen',
                      style: TextStyle(fontSize: 14, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteLogsheet();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteLogsheet() async {
    try {
      // Tampilkan loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(width: 16),
              Text('Menghapus logsheet dari Google Drive...'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 30),
        ),
      );

      // ✅ DELETE FILE FROM GOOGLE DRIVE
      if (_activeFileId != null && _activeFileId!.isNotEmpty) {
        print('🗑️ DELETING FROM GOOGLE DRIVE: $_activeFileId');
        await LogsheetService.deleteLogsheet(_activeFileId!, permanent: true);
        print('✅ FILE DELETED FROM GOOGLE DRIVE');
      } else {
        print('⚠️ NO ACTIVE FILE ID TO DELETE');
      }

      // Hapus local storage
      await _clearLocalData();

      // Sembunyikan loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Tampilkan pesan sukses
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Logsheet ${widget.generatorName} berhasil dihapus dari Google Drive',
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Reset form state
      if (mounted) {
        setState(() {
          _activeFileId = null;
          _existingData = {};
          _hasExistingData = false;
        });
      }

      // Clear all form controllers
      _clearFormControllers();

      // Navigate back to dashboard
      Navigator.of(context).pop();
    } catch (e) {
      // Sembunyikan loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text('Gagal menghapus logsheet: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _clearLocalData() async {
    try {
      // Clear local storage data for this generator
      await StorageService.saveActiveFileId(widget.generatorName, '');
      await StorageService.saveGeneratorStatus(widget.generatorName, false);
      await StorageService.saveLastLogsheetData(widget.generatorName, {});

      print('Local data cleared for ${widget.generatorName}');
    } catch (e) {
      print('Error clearing local data: $e');
      throw e;
    }
  }

  void _clearFormControllers() {
    _jamOperasiController.clear();
    _rpmController.clear();
    _lubeOilTempController.clear();
    _oilPressureController.clear();
    _waterTempController.clear();
    _teganganAccuController.clear();
    _bebanController.clear();
    _voltageRController.clear();
    _voltageSController.clear();
    _voltageTController.clear();
    _ampereRController.clear();
    _ampereSController.clear();
    _ampereTController.clear();
    _kvarController.clear();
    _hzController.clear();
    _cosPhiController.clear();
    _tempWindingUController.clear();
    _tempWindingVController.clear();
    _tempWindingWController.clear();
    _tempBearingController.clear();
    _engineTempExhaustController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Isi Logsheet - ${widget.generatorName}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onOpened: () async {
              // Refresh data energi saat popup menu dibuka untuk memastikan state terbaru
              await _loadExistingEnergyData();
            },
            onSelected: (value) {
              if (value == 'new_logsheet') {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Buat Logsheet Baru'),
                      content: const Text(
                        'Apakah Anda yakin ingin membuat logsheet baru?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Tidak'),
                        ),
                        TextButton(
                          onPressed: () async {
                            // Simpan reference ke ScaffoldMessenger sebelum pop
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              context,
                            );

                            // Tampilkan loading terlebih dahulu
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Membuat logsheet baru...'),
                                backgroundColor: Color(0xFF1E3A8A),
                              ),
                            );

                            // Tutup dialog
                            Navigator.of(context).pop();

                            try {
                              // Buat spreadsheet baru
                              final result =
                                  await LogsheetService.createLogsheet(
                                    widget.generatorName,
                                  );

                              // Simpan fileId aktif ke state
                              setState(() {
                                _activeFileId = result['fileId'];
                              });

                              // Simpan ke storage dan update GeneratorDataManager
                              await StorageService.saveActiveFileId(
                                widget.generatorName,
                                result['fileId'],
                              );
                              await GeneratorDataManager.updateGeneratorFileId(
                                widget.generatorName,
                                result['fileId'],
                              );

                              print(
                                '✅ NEW_SPREADSHEET: Created and saved fileId for ${widget.generatorName}: ${result['fileId'].substring(0, 15)}...',
                              );

                              // Hapus snackbar loading
                              scaffoldMessenger.hideCurrentSnackBar();

                              // Tampilkan snackbar sukses
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Logsheet baru berhasil dibuat!',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Nama: ${result['fileName']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Link: ${result['webViewLink']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 10),
                                  action: SnackBarAction(
                                    label: 'TUTUP',
                                    textColor: Colors.white,
                                    onPressed: () {
                                      scaffoldMessenger.hideCurrentSnackBar();
                                    },
                                  ),
                                ),
                              );
                            } catch (e) {
                              // Hapus snackbar loading
                              scaffoldMessenger.hideCurrentSnackBar();

                              // Tampilkan snackbar error
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Gagal membuat logsheet',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        e.toString(),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 8),
                                ),
                              );
                            }
                          },
                          child: const Text('Ya'),
                        ),
                      ],
                    );
                  },
                );
              } else if (value == 'energy_bbm_data') {
                _showEnergyBbmDialog();
              } else if (value == 'delete_logsheet') {
                _showDeleteConfirmationDialog();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'new_logsheet',
                child: Row(
                  children: [
                    Icon(Icons.add, color: Color(0xFF1E3A8A)),
                    SizedBox(width: 8),
                    Text('Buat Logsheet Baru'),
                  ],
                ),
              ),
              if (_activeFileId != null && _activeFileId!.isNotEmpty)
                PopupMenuItem<String>(
                  value: 'energy_bbm_data',
                  child: Row(
                    children: [
                      Icon(
                        _hasEnergyBbmData
                            ? Icons.edit
                            : Icons.electrical_services,
                        color: const Color(0xFF1976D2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _hasEnergyBbmData
                            ? 'Edit data kWh dan BBM'
                            : 'Isi data kWh dan BBM',
                      ),
                    ],
                  ),
                ),
              if (_activeFileId != null && _activeFileId!.isNotEmpty)
                const PopupMenuItem<String>(
                  value: 'delete_logsheet',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Hapus Logsheet'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main form content with pull-to-refresh
          RefreshIndicator(
            color: const Color(0xFF1E3A8A),
            backgroundColor: Colors.white,
            onRefresh: _refreshFormData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16, //
                bottom: 16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date and Status Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getCurrentDateTime(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'AKTIF',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Parameter Operasional Section
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 32),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Parameter Operasional',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            icon: Icons.access_time,
                            label: 'Jam Operasi',
                            controller: _jamOperasiController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.speed,
                            label: 'RPM',
                            controller: _rpmController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.thermostat,
                            label: 'Lube Oil Temperature',
                            controller: _lubeOilTempController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.compress,
                            label: 'Oil Pressure',
                            controller: _oilPressureController,
                            hintText: '0.0',
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          _buildFormField(
                            icon: Icons.water_drop,
                            label: 'Water Temperature',
                            controller: _waterTempController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.battery_charging_full,
                            label: 'Tegangan Accu',
                            controller: _teganganAccuController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.electrical_services,
                            label: 'Beban (Load)',
                            controller: _bebanController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.bolt,
                            label: 'Voltage (R)',
                            controller: _voltageRController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.bolt,
                            label: 'Voltage (S)',
                            controller: _voltageSController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.bolt,
                            label: 'Voltage (T)',
                            controller: _voltageTController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.flash_on,
                            label: 'Ampere (R)',
                            controller: _ampereRController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.flash_on,
                            label: 'Ampere (S)',
                            controller: _ampereSController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.flash_on,
                            label: 'Ampere (T)',
                            controller: _ampereTController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.device_hub,
                            label: 'Kvar',
                            controller: _kvarController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.speed,
                            label: 'Hz',
                            controller: _hzController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.timeline,
                            label: 'CosPhi (PF)',
                            controller: _cosPhiController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.thermostat,
                            label: 'Temp Winding (U)',
                            controller: _tempWindingUController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.thermostat,
                            label: 'Temp Winding (V)',
                            controller: _tempWindingVController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.thermostat,
                            label: 'Temp Winding (W)',
                            controller: _tempWindingWController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.thermostat,
                            label: 'Temp Bearing',
                            controller: _tempBearingController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.compress,
                            label: 'Engine (Pressure Crankcase)',
                            controller: _enginePressureCrankcaseController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _buildFormField(
                            icon: Icons.thermostat,
                            label: 'Engine (Temp Exhaust)',
                            controller: _engineTempExhaustController,
                            hintText: '0',
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),

                    // Action Buttons
                    Column(
                      children: [
                        // SIMPLIFIED: Status info box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: _hasExistingData
                                ? Colors.orange[50]
                                : Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _canCreateNewEntry()
                                  ? Colors.green[300]!
                                  : Colors.orange[300]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _canCreateNewEntry()
                                    ? Icons.schedule
                                    : Icons.lock_clock,
                                color: _canCreateNewEntry()
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getStatusMessage(),
                                  style: TextStyle(
                                    color: _canCreateNewEntry()
                                        ? Colors.green[700]
                                        : Colors.orange[700],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              // SIMPLIFIED: Langsung save saja
                              _saveLogsheet();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getButtonColor(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getButtonIcon(),
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _getButtonText(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.close, color: Colors.grey, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Batal',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ), // RefreshIndicator
          // Collaboration status overlay - temporarily disabled
          // FormCollaborationStatus(
          //   generatorName: widget.generatorName,
          //   hour: DateTime.now().hour,
          //   onFormLocked: () {
          //     setState(() {
          //       _isFormLocked = true;
          //     });
          //   },
          //   onFormUnlocked: () {
          //     setState(() {
          //       _isFormLocked = false;
          //     });
          //   },
          // ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Kembali ke main navigation dan set index yang dipilih
          Navigator.pop(context, {'selectedIndex': index});
        },
        backgroundColor: Colors.white,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
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

  Widget _buildFormField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    Color? backgroundColor,
    Function(String)? onChanged,
  }) {
    // SIMPLIFIED: Field tidak pernah locked, selalu bisa diedit
    final isFieldLocked = false;

    print(
      'Building field $label - isFieldLocked: $isFieldLocked, hasExistingData: $_hasExistingData',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: backgroundColor ?? Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.normal,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Field ini harus diisi';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // Fungsi untuk menghitung total dan SFC secara otomatis
  void _calculateTotals() {
    final kwhAwal = double.tryParse(_kwhAwalController.text) ?? 0.0;
    final kwhAkhir = double.tryParse(_kwhAkhirController.text) ?? 0.0;
    final bbmAwal = double.tryParse(_bbmAwalController.text) ?? 0.0;
    final bbmAkhir = double.tryParse(_bbmAkhirController.text) ?? 0.0;

    // Hitung total kWh
    final totalKwh = kwhAkhir - kwhAwal;
    _totalKwhController.text = totalKwh.toStringAsFixed(2);

    // Hitung total BBM
    final totalBbm = bbmAkhir - bbmAwal;
    _totalBbmController.text = totalBbm.toStringAsFixed(2);

    // Hitung SFC (Specific Fuel Consumption) dalam g/kWh
    if (totalKwh > 0 && totalBbm > 0) {
      // Konversi L BBM ke gram (asumsi density solar ~0.85 kg/L = 850 g/L)
      final bbmInGrams = totalBbm * 850;
      final sfc = bbmInGrams / totalKwh;
      _sfcController.text = sfc.toStringAsFixed(2);
    } else {
      _sfcController.text = '0.00';
    }
  }

  // Fungsi untuk menyimpan data energi dan BBM secara terpisah
  Future<void> _saveEnergyBbmData() async {
    try {
      // Cek apakah ada fileId aktif
      final activeFileId = _activeFileId ?? widget.activeFileId;
      if (activeFileId == null || activeFileId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harap buat logsheet baru terlebih dahulu!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Tampilkan loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menyimpan data energi dan BBM...'),
          backgroundColor: Color(0xFF1E3A8A),
          duration: Duration(seconds: 1),
        ),
      );

      // Persiapkan data energi untuk dikirim
      final currentTime = DateTime.now();
      final Map<String, dynamic> energyData = {
        'generatorName': widget.generatorName,
        'tanggal':
            '${currentTime.year.toString().padLeft(4, '0')}-${currentTime.month.toString().padLeft(2, '0')}-${currentTime.day.toString().padLeft(2, '0')}',
        'jam': currentTime.hour.toString(),
        'kwhAwal': _kwhAwalController.text,
        'kwhAkhir': _kwhAkhirController.text,
        'totalKwh': _totalKwhController.text,
        'bbmAwal': _bbmAwalController.text,
        'bbmAkhir': _bbmAkhirController.text,
        'totalBbm': _totalBbmController.text,
        'sfc': _sfcController.text,
      };

      print('🔍 ENERGY SAVE :');
      print('   📅 tanggal: ${energyData['tanggal']}');
      print('   🕐 jam: ${energyData['jam']}');
      print(
        '   ⚡ kWh: ${energyData['kwhAwal']} → ${energyData['kwhAkhir']} (${energyData['totalKwh']})',
      );
      print(
        '   ⛽ BBM: ${energyData['bbmAwal']} → ${energyData['bbmAkhir']} (${energyData['totalBbm']})',
      );
      print('   📊 SFC: ${energyData['sfc']}');

      // Simpan ke database SQLite
      final databaseService = DatabaseService();

      // Simpan ke database menggunakan method yang benar
      await databaseService.saveLogsheetToHistory(
        activeFileId,
        widget.generatorName,
        energyData,
      );
      print('✅ ENERGY: Saved to SQLite database');

      // Set state bahwa data energi/BBM sudah diisi (bahkan jika gagal ke spreadsheet)
      setState(() {
        _hasEnergyBbmData = true;
      });

      // Kirim ke spreadsheet dan Firestore menggunakan PATCH untuk partial update
      try {
        // Hitung row number untuk data energi/BBM
        // V7: kWh awal, V8: kWh akhir, W8: Total kWh
        // Z7: BBM awal, Z8: BBM akhir, AB8: Total BBM, AC8: SFC

        // Untuk data energi/BBM, kita gunakan row khusus (7 untuk awal, 8 untuk akhir)
        final rowAwal = 7; // Row untuk data awal (kWh awal, BBM awal)
        final rowAkhir = 8; // Row untuk data akhir dan total

        // Siapkan data untuk update spreadsheet dengan cell coordinates
        final updates = <String, dynamic>{};

        // kWh data
        if (_kwhAwalController.text.isNotEmpty) {
          updates['V$rowAwal'] = energyData['kwhAwal']; // V7: kWh Awal
        }
        if (_kwhAkhirController.text.isNotEmpty) {
          updates['V$rowAkhir'] = energyData['kwhAkhir']; // V8: kWh Akhir
        }
        if (_totalKwhController.text.isNotEmpty) {
          updates['W$rowAkhir'] = energyData['totalKwh']; // W8: Total kWh
        }

        // BBM data
        if (_bbmAwalController.text.isNotEmpty) {
          updates['Z$rowAwal'] = energyData['bbmAwal']; // Z7: BBM Awal
        }
        if (_bbmAkhirController.text.isNotEmpty) {
          updates['Z$rowAkhir'] = energyData['bbmAkhir']; // Z8: BBM Akhir
        }
        if (_totalBbmController.text.isNotEmpty) {
          updates['AB$rowAkhir'] = energyData['totalBbm']; // AB8: Total BBM
        }

        // SFC data
        if (_sfcController.text.isNotEmpty) {
          updates['AC$rowAkhir'] = energyData['sfc']; // AC8: SFC
        }

        print('🔧 ENERGY: Sending updates to spreadsheet: $updates');

        final result = await RestApiService.updateLogsheetData(
          activeFileId,
          updates: updates,
        );

        if (result['success'] == true) {
          print('✅ ENERGY: Data berhasil dikirim ke spreadsheet dan Firestore');

          // Set state bahwa data energi/BBM sudah diisi
          setState(() {
            _hasEnergyBbmData = true;
          });

          // 🚀 IMMEDIATE SYNC: Trigger upload after energy/BBM data save
          _triggerImmediateSync();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Data energi dan BBM berhasil disimpan!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          throw Exception(
            'Failed to save to spreadsheet: ${result['message']}',
          );
        }
      } catch (e) {
        print('❌ ENERGY: Error saving to spreadsheet: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Data tersimpan lokal, tapi gagal ke spreadsheet: $e',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ ENERGY: Error saving energy data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Gagal menyimpan data energi: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Fungsi untuk mengambil data energi dari hari sebelumnya
  Future<void> _loadPreviousDayEnergyData() async {
    try {
      print('🔍 ENERGY: Loading previous day energy data...');

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayFormat =
          '${yesterday.year}${yesterday.month.toString().padLeft(2, '0')}${yesterday.day.toString().padLeft(2, '0')}';

      // Coba ambil dari database SQLite terlebih dahulu
      final databaseService = DatabaseService();
      final previousLogsheets = await databaseService.getLogsheetHistory(
        widget.generatorName,
        daysBack: 2, // Ambil 2 hari untuk memastikan ada data
      );

      if (previousLogsheets.isNotEmpty) {
        // Cari data dengan tanggal kemarin
        Map<String, dynamic>? yesterdayData;
        for (final logsheet in previousLogsheets) {
          final logsheetDate = logsheet['tanggal']?.toString() ?? '';
          if (logsheetDate == yesterdayFormat) {
            yesterdayData = logsheet;
            break;
          }
        }

        if (yesterdayData != null) {
          final kwhAkhir = yesterdayData['kwh_akhir']?.toString() ?? '';
          final bbmAkhir = yesterdayData['bbm_akhir']?.toString() ?? '';

          if (kwhAkhir.isNotEmpty && kwhAkhir != '0') {
            _kwhAwalController.text = kwhAkhir;
            print('✅ ENERGY: Auto-filled kWh Awal from yesterday: $kwhAkhir');
          }

          if (bbmAkhir.isNotEmpty && bbmAkhir != '0') {
            _bbmAwalController.text = bbmAkhir;
            print('✅ ENERGY: Auto-filled BBM Awal from yesterday: $bbmAkhir');
          }

          return;
        }
      }

      print('ℹ️ ENERGY: No previous day data found for auto-fill');
    } catch (e) {
      print('⚠️ ENERGY: Error loading previous day data: $e');
    }
  }

  // Fungsi untuk memuat data energi/BBM yang sudah tersimpan untuk logsheet ini
  Future<void> _loadExistingEnergyData() async {
    try {
      // Gunakan fileId yang tersedia dengan fallback ke SharedPreferences
      String? activeFileId = _activeFileId ?? widget.activeFileId;

      // Jika masih kosong, coba dari SharedPreferences
      if (activeFileId == null || activeFileId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        activeFileId = prefs.getString('current_logsheet_file_id');
        print('🔍 ENERGY: Trying fileId from SharedPreferences: $activeFileId');
      }

      if (activeFileId == null || activeFileId.isEmpty) {
        print(
          '⚠️ ENERGY: No active fileId available for loading existing data',
        );
        return;
      }

      print(
        '🔍 ENERGY: Loading existing energy data for fileId: $activeFileId',
      );

      // Method 1: Cek dari spreadsheet API terlebih dahulu (lebih reliable)
      try {
        print('🔍 ENERGY: Checking spreadsheet for existing energy data...');
        final logsheetData = await LogsheetService.readLogsheetData(
          activeFileId,
        );

        // Extract energy data dari spreadsheet response
        final kwhAwal = logsheetData['kwhAwal']?.toString() ?? '';
        final kwhAkhir = logsheetData['kwhAkhir']?.toString() ?? '';
        final totalKwh = logsheetData['totalKwh']?.toString() ?? '';
        final bbmAwal = logsheetData['bbmAwal']?.toString() ?? '';
        final bbmAkhir = logsheetData['bbmAkhir']?.toString() ?? '';
        final totalBbm = logsheetData['totalBbm']?.toString() ?? '';
        final sfc = logsheetData['sfc']?.toString() ?? '';

        print(
          '🔍 ENERGY: Spreadsheet data - kWh: $kwhAwal→$kwhAkhir, BBM: $bbmAwal→$bbmAkhir',
        );

        // Cek apakah ada data energi/BBM yang tidak kosong, bukan 'null', dan bukan '0'
        if ((kwhAwal.isNotEmpty && kwhAwal != 'null' && kwhAwal != '0') ||
            (kwhAkhir.isNotEmpty && kwhAkhir != 'null' && kwhAkhir != '0') ||
            (bbmAwal.isNotEmpty && bbmAwal != 'null' && bbmAwal != '0') ||
            (bbmAkhir.isNotEmpty && bbmAkhir != 'null' && bbmAkhir != '0')) {
          print(
            '✅ ENERGY: Found existing energy data in spreadsheet, loading to form',
          );

          // Load data ke controllers
          _kwhAwalController.text = kwhAwal;
          _kwhAkhirController.text = kwhAkhir;
          _totalKwhController.text = totalKwh;
          _bbmAwalController.text = bbmAwal;
          _bbmAkhirController.text = bbmAkhir;
          _totalBbmController.text = totalBbm;
          _sfcController.text = sfc;

          // Set state bahwa data sudah ada
          setState(() {
            _hasEnergyBbmData = true;
          });

          print('✅ ENERGY: Existing data loaded from spreadsheet');
          return;
        }
      } catch (e) {
        print(
          '⚠️ ENERGY: Error reading from spreadsheet, falling back to database: $e',
        );
      }

      // Method 2: Fallback ke database jika spreadsheet gagal
      final databaseService = DatabaseService();
      final today = DateTime.now();
      final todayFormat =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      print(
        '🔍 ENERGY: Fallback - Looking for data on date: $todayFormat for fileId: $activeFileId',
      );

      // Cari data energi/BBM untuk logsheet hari ini dengan fileId yang sama
      final existingLogsheets = await databaseService.getLogsheetHistory(
        widget.generatorName,
        daysBack: 2, // Ambil 2 hari untuk memastikan
      );

      print(
        '🔍 ENERGY: Found ${existingLogsheets.length} logsheet records total',
      );

      for (final logsheet in existingLogsheets) {
        final logsheetDate = logsheet['tanggal']?.toString() ?? '';
        final logsheetFileId = logsheet['fileId']?.toString() ?? '';

        print(
          '🔍 ENERGY: Checking record - date: $logsheetDate, fileId: $logsheetFileId',
        );

        // Harus sama tanggal DAN fileId untuk memastikan data yang benar
        if (logsheetDate == todayFormat && logsheetFileId == activeFileId) {
          // Cek apakah ada data energi/BBM dengan safe null handling
          final kwhAwal = (logsheet['kwhAwal'] != null)
              ? logsheet['kwhAwal'].toString()
              : '';
          final kwhAkhir = (logsheet['kwhAkhir'] != null)
              ? logsheet['kwhAkhir'].toString()
              : '';
          final totalKwh = (logsheet['totalKwh'] != null)
              ? logsheet['totalKwh'].toString()
              : '';
          final bbmAwal = (logsheet['bbmAwal'] != null)
              ? logsheet['bbmAwal'].toString()
              : '';
          final bbmAkhir = (logsheet['bbmAkhir'] != null)
              ? logsheet['bbmAkhir'].toString()
              : '';
          final totalBbm = (logsheet['totalBbm'] != null)
              ? logsheet['totalBbm'].toString()
              : '';
          final sfc = (logsheet['sfc'] != null)
              ? logsheet['sfc'].toString()
              : '';

          print(
            '🔍 ENERGY: Found data - kWh: $kwhAwal→$kwhAkhir, BBM: $bbmAwal→$bbmAkhir',
          );

          // Cek apakah ada data energi/BBM yang tidak kosong dan bukan 'null'
          if ((kwhAwal.isNotEmpty && kwhAwal != 'null') ||
              (kwhAkhir.isNotEmpty && kwhAkhir != 'null') ||
              (bbmAwal.isNotEmpty && bbmAwal != 'null') ||
              (bbmAkhir.isNotEmpty && bbmAkhir != 'null')) {
            print(
              '✅ ENERGY: Found existing energy data in database, loading to form',
            );

            // Load data ke controllers
            _kwhAwalController.text = kwhAwal;
            _kwhAkhirController.text = kwhAkhir;
            _totalKwhController.text = totalKwh;
            _bbmAwalController.text = bbmAwal;
            _bbmAkhirController.text = bbmAkhir;
            _totalBbmController.text = totalBbm;
            _sfcController.text = sfc;

            // Set state bahwa data sudah ada
            setState(() {
              _hasEnergyBbmData = true;
            });

            print('✅ ENERGY: Existing data loaded from database');
            return;
          }
        }
      }

      print('ℹ️ ENERGY: No existing energy data found for today');
    } catch (e) {
      print('⚠️ ENERGY: Error loading existing energy data: $e');
    }
  }

  void _saveLogsheet() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Cek apakah ada fileId aktif
        final activeFileId = _activeFileId ?? widget.activeFileId;
        if (activeFileId == null) {
          _scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Harap buat logsheet baru terlebih dahulu!'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Tampilkan loading
        final loadingMessage = _hasExistingData
            ? 'Mengupdate data logsheet...'
            : 'Menyimpan data logsheet...';

        _scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(loadingMessage),
            backgroundColor: const Color(0xFF1E3A8A),
          ),
        );

        // Persiapkan data untuk dikirim
        final currentTime = DateTime.now();
        final Map<String, dynamic> logsheetData = {
          'generatorName': widget.generatorName,
          // PENTING: Tambahkan tanggal dan jam yang BENAR
          'tanggal':
              '${currentTime.year.toString().padLeft(4, '0')}-${currentTime.month.toString().padLeft(2, '0')}-${currentTime.day.toString().padLeft(2, '0')}',
          'jam': currentTime.hour.toString(),
          'jamOperasi': _jamOperasiController.text,
          'rpm': _rpmController.text,
          'lubeOilTemp': _lubeOilTempController.text,
          'oilPressure': _oilPressureController.text,
          'waterTemp': _waterTempController.text,
          'teganganAccu': _teganganAccuController.text,
          'beban': _bebanController.text,
          'voltageR': _voltageRController.text,
          'voltageS': _voltageSController.text,
          'voltageT': _voltageTController.text,
          'ampereR': _ampereRController.text,
          'ampereS': _ampereSController.text,
          'ampereT': _ampereTController.text,
          'kvar': _kvarController.text,
          'hz': _hzController.text,
          'cosPhi': _cosPhiController.text,
          'tempWindingU': _tempWindingUController.text,
          'tempWindingV': _tempWindingVController.text,
          'tempWindingW': _tempWindingWController.text,
          'tempBearing': _tempBearingController.text,
          'enginePressureCrankcase': _enginePressureCrankcaseController.text,
          'engineTempExhaust': _engineTempExhaustController.text,
        };

        // HANYA kirim data energi/BBM jika memang ada datanya (tidak kosong)
        // Ini mencegah overwrite data energi yang sudah disimpan terpisah
        if (_kwhAwalController.text.isNotEmpty ||
            _kwhAkhirController.text.isNotEmpty ||
            _hasEnergyBbmData) {
          logsheetData.addAll({
            'kwhAwal': _kwhAwalController.text,
            'kwhAkhir': _kwhAkhirController.text,
            'totalKwh': _totalKwhController.text,
            'bbmAwal': _bbmAwalController.text,
            'bbmAkhir': _bbmAkhirController.text,
            'totalBbm': _totalBbmController.text,
            'sfc': _sfcController.text,
          });
          print('📊 ENERGY: Including energy/BBM data in main save');
        } else {
          print(
            '📊 ENERGY: Skipping energy/BBM data in main save (controllers empty)',
          );
        }

        // Debug log untuk memastikan tanggal dan jam benar
        print('🔍 TIMESTAMP :');
        print('   📅 tanggal: ${logsheetData['tanggal']}');
        print('   🕐 jam: ${logsheetData['jam']}');
        print('   📊 generatorName: ${logsheetData['generatorName']}');

        // Panggil service untuk menyimpan data
        // Coba gunakan REST API terlebih dahulu untuk membuat logsheet baru jika belum ada activeFileId
        bool saveSuccess = false;

        if (activeFileId.isEmpty) {
          // Jika belum ada activeFileId, buat logsheet baru menggunakan REST API
          try {
            final restResponse = await RestApiService.createLogsheet(
              templateFileId: '', // Akan menggunakan default template
              targetFolderId: '', // Akan menggunakan default folder
              generatorName: widget.generatorName,
            );

            if (restResponse['success'] == true) {
              saveSuccess = true;

              // Update activeFileId dari response
              if (restResponse['data'] != null &&
                  restResponse['data']['id'] != null) {
                setState(() {
                  _activeFileId = restResponse['data']['id'];
                });
                await StorageService.saveActiveFileId(
                  widget.generatorName,
                  restResponse['data']['id'],
                );
              }
            }
          } catch (e) {
            print(
              'REST API create logsheet failed, falling back to legacy method: $e',
            );
          }
        }

        // Fallback ke method lama
        if (!saveSuccess) {
          try {
            print(
              '🚀 FORM: Calling enhanced saveLogsheetDataWithFallback method...',
            );
            print('🚀 FORM: activeFileId = "$activeFileId"');
            print('🚀 FORM: logsheetData keys = ${logsheetData.keys.toList()}');
            // Use new method with graceful degradation
            final result = await LogsheetService.saveLogsheetDataWithFallback(
              activeFileId,
              logsheetData,
            );

            if (result['success'] == true) {
              saveSuccess = true;

              // Show appropriate message based on what succeeded
              if (result['googleSheetsSuccess'] == true) {
                print(
                  '✅ SAVE: Data berhasil disimpan ke Google Sheets dan database lokal',
                );
                _scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('✅ Data berhasil disimpan ke Google Sheets'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                print(
                  '⚠️ SAVE: Data tersimpan lokal, tapi gagal ke Google Sheets: ${result['googleSheetsError']}',
                );

                // Check if it's a permission-related error
                String? errorMsg = result['googleSheetsError']
                    ?.toString()
                    .toLowerCase();
                bool isPermissionIssue =
                    result['permissionIssueDetected'] == true ||
                    errorMsg?.contains('permission') == true ||
                    errorMsg?.contains('500') == true ||
                    errorMsg?.contains('access denied') == true ||
                    errorMsg?.contains('unauthorized') == true;

                if (isPermissionIssue) {
                  _scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: const Text(
                        '🔄 Data tersimpan lokal. Sistem sedang mengatur akses multi-device... Coba simpan lagi dalam 10 detik.',
                      ),
                      backgroundColor: Colors.amber,
                      duration: const Duration(seconds: 8),
                      action: SnackBarAction(
                        label: 'Mengerti',
                        textColor: Colors.white,
                        onPressed: () =>
                            _scaffoldMessenger.hideCurrentSnackBar(),
                      ),
                    ),
                  );
                } else {
                  _scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: const Text(
                        '⚠️ Data tersimpan lokal, namun gagal tersimpan ke Google Sheets',
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 4),
                      action: SnackBarAction(
                        label: 'OK',
                        onPressed: () =>
                            _scaffoldMessenger.hideCurrentSnackBar(),
                      ),
                    ),
                  );
                }
              }
            } else {
              throw Exception(
                'Failed to save to both Google Sheets and local database',
              );
            }
          } catch (e) {
            print('Enhanced API save failed: $e');

            // Check if this is a permission-related error for better user messaging
            String errorMessage = e.toString().toLowerCase();
            bool isPermissionError =
                errorMessage.contains('permission issue detected') ||
                errorMessage.contains('auto-sharing') ||
                errorMessage.contains('500') ||
                errorMessage.contains('access denied');

            if (isPermissionError) {
              _scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: const Text(
                    '🔄 Mengatasi masalah akses multi-device... Silakan coba lagi dalam beberapa saat.',
                  ),
                  backgroundColor: Colors.blue,
                  duration: const Duration(seconds: 6),
                  action: SnackBarAction(
                    label: 'Mengerti',
                    onPressed: () => _scaffoldMessenger.hideCurrentSnackBar(),
                  ),
                ),
              );
            }

            // Last resort: try legacy method
            try {
              await LogsheetService.saveLogsheetData(
                activeFileId,
                logsheetData,
              );
              saveSuccess = true;
            } catch (legacyError) {
              print('Legacy API save also failed: $legacyError');
              rethrow;
            }
          }
        }

        // Hapus loading snackbar
        _scaffoldMessenger.hideCurrentSnackBar();

        // Simpan data ke storage untuk persistence
        await StorageService.saveLastLogsheetData(
          widget.generatorName,
          logsheetData,
        );
        await StorageService.saveActiveFileId(
          widget.generatorName,
          activeFileId,
        );

        // TAMBAHAN: Simpan ke riwayat untuk analisis historis
        await HistoricalLogsheetService.saveToHistory(
          widget.generatorName,
          logsheetData,
          activeFileId,
        );

        // Update state setelah berhasil simpan
        final now = DateTime.now();
        setState(() {
          _existingData = logsheetData;
          _hasExistingData = true; // Sekarang sudah ada data
        });

        // 🏪 CACHE UPDATE: Store success state locally to persist across navigation PER GENERATOR
        await StorageService.setHourDataStatus(
          widget.generatorName,
          now.hour,
          true,
        );
        print(
          '✅ CACHED: Set hasData flag for ${widget.generatorName} hour ${now.hour}',
        );

        print(
          'SAVE SUCCESS - Data saved at hour: ${now.hour}, user input jam: ${logsheetData['jamOperasi']}, hasExistingData: $_hasExistingData, time: ${now.hour}:${now.minute}',
        );

        // 🚀 IMMEDIATE SYNC: Trigger upload to Firestore after save
        _triggerImmediateSync();

        // Tampilkan pesan sukses
        const successMessage = 'Logsheet berhasil disimpan!';

        _scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );

        // Jika data terkunci dan tidak bisa create new entry, jangan auto kembali
        // Biarkan user stay di form untuk bisa edit nanti
      } catch (e) {
        // Hapus loading snackbar
        _scaffoldMessenger.hideCurrentSnackBar();

        // Enhanced error handling dengan specific messages
        String errorMessage;
        Color errorColor = Colors.red;

        if (e.toString().contains(
              'Server error: Unable to update spreadsheet',
            ) ||
            e.toString().contains('Permission denied') ||
            e.toString().contains('Failed to update logsheet data: 500')) {
          errorMessage =
              '⚠️ Data tersimpan lokal, tapi gagal ke spreadsheet. Exception: Failed to update logsheet data: 500';
          errorColor = Colors.orange;

          print(
            '📊 PERMISSION ISSUE: Spreadsheet update failed due to permissions',
          );
          print(
            '✅ LOCAL SAVE: Data tetap tersimpan di database lokal dan akan tersync via Firestore',
          );

          // Tetap trigger sync ke Firestore walau Google Sheets gagal
          _triggerImmediateSync();
        } else if (e.toString().contains(
          'Permission denied to access logsheet',
        )) {
          errorMessage =
              '❌ Tidak bisa akses spreadsheet. Hubungi pembuat logsheet untuk memberikan akses.';
          errorColor = Colors.red;
        } else {
          errorMessage = 'Gagal menyimpan logsheet: ${e.toString()}';
          errorColor = Colors.red;
        }

        // Tampilkan pesan error yang sesuai
        _scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Trigger immediate sync after data save
  void _triggerImmediateSync() async {
    try {
      print('🚀 IMMEDIATE SYNC: Triggering upload after data save...');
      final success = await SyncManager.instance.triggerImmediateUpload();
      if (success) {
        print('✅ IMMEDIATE SYNC: Data uploaded to Firestore berhasil');
      } else {
        print('⚠️ IMMEDIATE SYNC: Upload failed or no data to sync');
      }
    } catch (e) {
      print('❌ IMMEDIATE SYNC: Error during immediate sync: $e');
      // Don't show error to user - sync failure shouldn't block UI
    }
  }
}
