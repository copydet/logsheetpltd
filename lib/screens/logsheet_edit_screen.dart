import 'dart:async';
import 'package:flutter/material.dart';
import '../app_exports.dart';

class LogsheetEditScreen extends StatefulWidget {
  final String generatorName;
  final int generatorId;
  final String? activeFileId;
  final Map<String, dynamic> existingData; // Data yang sudah ada

  const LogsheetEditScreen({
    super.key,
    required this.generatorName,
    required this.generatorId,
    required this.activeFileId,
    required this.existingData,
  });

  @override
  State<LogsheetEditScreen> createState() => _LogsheetEditScreenState();
}

class _LogsheetEditScreenState extends State<LogsheetEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late ScaffoldMessengerState _scaffoldMessenger;
  Timer? _hourCheckTimer;
  int? _currentHourSlot;
  bool _isUpdating = false;

  // Form controllers
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldMessenger = ScaffoldMessenger.of(context);
      _initializeEditMode();
      _startHourCheckTimer();
    });
  }

  @override
  void dispose() {
    _hourCheckTimer?.cancel();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _jamOperasiController.dispose();
    _rpmController.dispose();
    _lubeOilTempController.dispose();
    _oilPressureController.dispose();
    _waterTempController.dispose();
    _teganganAccuController.dispose();
    _bebanController.dispose();
    _voltageRController.dispose();
    _voltageSController.dispose();
    _voltageTController.dispose();
    _ampereRController.dispose();
    _ampereSController.dispose();
    _ampereTController.dispose();
    _kvarController.dispose();
    _hzController.dispose();
    _cosPhiController.dispose();
    _tempWindingUController.dispose();
    _tempWindingVController.dispose();
    _tempWindingWController.dispose();
    _tempBearingController.dispose();
    _enginePressureCrankcaseController.dispose();
    _engineTempExhaustController.dispose();
  }

  void _initializeEditMode() {
    setState(() {
      _currentHourSlot = DateTime.now().hour;
    });

    // Fill form dengan data existing
    _fillFormWithData(widget.existingData);

    print('Edit mode initialized for hour $_currentHourSlot');
  }

  void _startHourCheckTimer() {
    _hourCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final currentHour = DateTime.now().hour;
      if (currentHour != _currentHourSlot) {
        print(
          'Hour changed from $_currentHourSlot to $currentHour - returning to form mode',
        );
        // Kembali ke halaman form biasa
        Navigator.of(context).pushReplacementNamed(
          '/logsheet_form',
          arguments: {
            'generatorName': widget.generatorName,
            'generatorId': widget.generatorId,
            'activeFileId': widget.activeFileId,
          },
        );
      }
    });
  }

  void _fillFormWithData(Map<String, dynamic> data) {
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
  }

  Future<void> _updateLogsheet() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.activeFileId == null) {
      _scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Tidak ada logsheet aktif untuk diupdate'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    // Show loading
    _scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Mengupdate data logsheet...'),
        backgroundColor: Colors.orange,
        duration: Duration(hours: 1),
      ),
    );

    try {
      // Prepare data untuk update
      final currentTime = DateTime.now();
      final logsheetData = {
        // PENTING: Tambahkan tanggal dan jam yang BENAR untuk edit
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
        'generatorName': widget.generatorName,
      };

      // Debug log untuk memastikan tanggal dan jam benar pada edit
      print('🔍 EDIT TIMESTAMP DEBUG: Updating data with:');
      print('   📅 tanggal: ${logsheetData['tanggal']}');
      print('   🕐 jam: ${logsheetData['jam']}');
      print('   📊 generatorName: ${logsheetData['generatorName']}');

      // Update ke spreadsheet
      await LogsheetService.saveLogsheetData(
        widget.activeFileId!,
        logsheetData,
      );

      // Update storage dengan timestamp baru
      final dataWithTimestamp = Map<String, dynamic>.from(logsheetData);
      dataWithTimestamp['savedAt'] = DateTime.now().millisecondsSinceEpoch;
      dataWithTimestamp['savedHour'] = DateTime.now().hour;

      await StorageService.saveLastLogsheetData(
        widget.generatorName,
        dataWithTimestamp,
      );

      // Hide loading
      _scaffoldMessenger.hideCurrentSnackBar();

      // Show success
      _scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Data berhasil diperbarui!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Return to previous screen after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context, {'updated': true}); // Return updated status
        }
      });
    } catch (e) {
      // Hide loading
      _scaffoldMessenger.hideCurrentSnackBar();

      // Show error
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal update data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Return to dashboard with no update indication
        Navigator.pop(context, {'updated': false});
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white, // Background putih konsisten
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E3A8A), // Warna biru konsisten
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context, {'updated': false});
            },
          ),
          title: Text(
            'Edit Logsheet - ${widget.generatorName}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
                          DateTimeUtils.getCurrentDateTime(),
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
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'EDIT',
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
                    // Status info box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mode Edit - Data jam ${DateTime.now().hour.toString().padLeft(2, '0')}:00 akan diperbarui',
                              style: TextStyle(
                                color: Colors.orange[700],
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
                        onPressed: _isUpdating ? null : _updateLogsheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.update,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Update Data',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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
                        onPressed: () =>
                            Navigator.pop(context, {'updated': false}),
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
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 0, // Highlight dashboard karena akan kembali ke sana
          onTap: (index) {
            // Kembali ke main navigation dan set index yang dipilih
            Navigator.pop(context, {'selectedIndex': index, 'updated': false});
          },
          backgroundColor: Colors.white,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Pengaturan',
            ),
          ],
        ),
      ),
    ); // Closing Scaffold
  } // Closing WillPopScope

  Widget _buildFormField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: 'Masukkan $label',
              hintStyle: TextStyle(color: Colors.orange[400]),
              filled: true,
              fillColor: Colors.orange[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange[600]!, width: 2),
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
                return '$label tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 4),
          Text(
            'Mode edit aktif - data dapat diubah',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
