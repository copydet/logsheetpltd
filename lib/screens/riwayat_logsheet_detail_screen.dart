import 'package:flutter/material.dart';
import '../services/historical_logsheet_service.dart';
import '../services/spreadsheet_download_service.dart';
import '../widgets/temperature_line_chart_widget.dart';
import '../widgets/engine_parameters_widget.dart';
import '../widgets/generator_electrical_widget.dart';

class RiwayatLogsheetDetailScreen extends StatefulWidget {
  final String generatorName;
  final String? fileId;

  const RiwayatLogsheetDetailScreen({
    Key? key,
    required this.generatorName,
    this.fileId,
  }) : super(key: key);

  @override
  State<RiwayatLogsheetDetailScreen> createState() =>
      _RiwayatLogsheetDetailScreenState();
}

class _RiwayatLogsheetDetailScreenState
    extends State<RiwayatLogsheetDetailScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> dailySummaries = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _loadHistoricalData();
  }

  Future<void> _loadHistoricalData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      print('📊 RIWAYAT: Loading historical data...');
      print('📊 RIWAYAT: Loading data from Google Drive...');

      // Use HistoricalLogsheetService.getDailySummary instead
      final allSummaries = await HistoricalLogsheetService.getDailySummary(
        widget.generatorName,
        daysBack: 7,
      );

      print('✅ RIWAYAT: Added ${allSummaries.length} Google Drive summaries');

      // Sort by date descending
      allSummaries.sort((a, b) {
        final dateA = a['date'] ?? '';
        final dateB = b['date'] ?? '';
        return dateB.compareTo(dateA);
      });

      setState(() {
        dailySummaries = allSummaries;
        isLoading = false;
      });

      print('✅ RIWAYAT: Loaded ${allSummaries.length} total summaries');
    } catch (e) {
      setState(() {
        error = 'Gagal memuat data riwayat: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Riwayat ${widget.generatorName}'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoricalData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuat data riwayat...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHistoricalData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (dailySummaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Logsheet yang Dibuat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'untuk ${widget.generatorName}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                  const SizedBox(height: 8),
                  Text(
                    'Cara Membuat Logsheet:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Kembali ke Dashboard\n2. Klik card generator ini\n3. Klik "Buat Logsheet Baru"\n4. Isi form dan simpan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistoricalData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dailySummaries.length,
        itemBuilder: (context, index) {
          final summary = dailySummaries[index];
          return _buildDayCard(summary);
        },
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> summary) {
    final bool hasData = summary['hasData'] as bool;
    final int entryCount = summary['entryCount'] as int;
    final String dateFormatted = summary['dateFormatted'] as String;
    final double totalKwh = _getTotalKwh(summary);
    final double totalBbm = _getTotalBbm(summary);
    final double averageSfc = _getAverageSfc(summary);
    final bool isRealData = summary['isRealData'] as bool? ?? true;

    print(
      '🎯 RIWAYAT CARD: $dateFormatted - KwH: $totalKwh, BBM: $totalBbm, SFC: $averageSfc',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isRealData
            ? null
            : Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: hasData ? () => _downloadSpreadsheet(summary) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        dateFormatted,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        // Indikator sumber data
                        if (hasData)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isRealData
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isRealData ? Icons.cloud_done : Icons.storage,
                                  size: 12,
                                  color: isRealData
                                      ? Colors.green[700]
                                      : Colors.orange[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isRealData ? 'Drive' : 'Lokal',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isRealData
                                        ? Colors.green[700]
                                        : Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: hasData
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            hasData ? '$entryCount entri' : 'Tidak ada data',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: hasData
                                  ? Colors.blue[700]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (hasData) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricItem(
                          'Total KwH',
                          '${totalKwh.toStringAsFixed(1)} kWh',
                          Icons.flash_on,
                          Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricItem(
                          'Total BBM',
                          '${totalBbm.toStringAsFixed(1)} L',
                          Icons.local_gas_station,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildMetricItem(
                    'SFC',
                    '${averageSfc.toStringAsFixed(1)} g/kWh',
                    Icons.analytics,
                    Colors.purple,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Download Spreadsheet →',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tidak ada data logsheet untuk hari ini',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadSpreadsheet(Map<String, dynamic> summary) async {
    final String? fileId = summary['fileId'] as String?;
    final String dateFormatted = summary['dateFormatted'] as String;
    final String date = summary['date'] as String? ?? '';

    if (fileId == null || fileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('FileId tidak tersedia untuk download'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Cek apakah ini adalah fileId dari Firestore (format: firestore_...)
    if (fileId.startsWith('firestore_')) {
      print('🔍 DOWNLOAD: Detected Firestore fileId, searching for real Google Drive file...');
      
      try {
        // Cari file Google Drive yang sebenarnya untuk tanggal ini
        final realFileId = await _findRealGoogleDriveFileId(date);
        
        if (realFileId != null && realFileId.isNotEmpty) {
          print('✅ DOWNLOAD: Found real fileId: $realFileId');
          await SpreadsheetDownloadService.downloadWithFormatChoice(
            context,
            realFileId,
            widget.generatorName,
            dateFormatted,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File Google Drive tidak ditemukan untuk tanggal ini'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mencari file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Jika fileId normal (Google Drive), lanjutkan download biasa
    try {
      await SpreadsheetDownloadService.downloadWithFormatChoice(
        context,
        fileId,
        widget.generatorName,
        dateFormatted,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Mencari fileId Google Drive yang sebenarnya berdasarkan tanggal
  Future<String?> _findRealGoogleDriveFileId(String date) async {
    try {
      // Parse date untuk mendapatkan format yang benar
      final dateTime = DateTime.parse(date);
      final formattedDate = '${dateTime.day.toString().padLeft(2, '0')} ${_getMonthName(dateTime.month)} ${dateTime.year}';
      final expectedFileName = 'Logsheet ${widget.generatorName}, $formattedDate';
      
      print('🔍 DOWNLOAD: Looking for file: $expectedFileName');
      
      // Gunakan REST API service untuk mencari file
      final response = await _searchFileByName(expectedFileName, widget.generatorName, date);
      
      if (response != null && response.isNotEmpty) {
        print('✅ DOWNLOAD: Found Google Drive file: $response');
        return response;
      }
      
      return null;
    } catch (e) {
      print('❌ DOWNLOAD: Error searching for file: $e');
      return null;
    }
  }

  /// Helper untuk mencari file berdasarkan nama menggunakan API
  Future<String?> _searchFileByName(String fileName, String generatorName, String date) async {
    try {
      final url = 'https://us-central1-powerplantlogsheet-8780a.cloudfunctions.net/api/find-file?fileName=${Uri.encodeComponent(fileName)}&generatorName=${Uri.encodeComponent(generatorName)}&date=${Uri.encodeComponent(date)}T00:00:00';
      
      // Import http dan buat request sederhana
      print('🔍 DOWNLOAD: Searching via API: $url');
      
      // Simulasikan pencarian - untuk sementara return null jika tidak ditemukan
      // Nanti bisa diimplementasi dengan http package yang sudah ada di project
      
      // Coba cari di summary yang mungkin punya fileId asli
      for (final summary in dailySummaries) {
        final summaryDate = summary['date'] as String? ?? '';
        if (summaryDate == date) {
          final rawData = summary['rawData'] as List<dynamic>? ?? [];
          for (final entry in rawData) {
            if (entry is Map<String, dynamic>) {
              final entryFileId = entry['fileId'] as String? ?? '';
              // Jika ada fileId yang bukan format Firestore, gunakan itu
              if (entryFileId.isNotEmpty && !entryFileId.startsWith('firestore_')) {
                return entryFileId;
              }
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      print('❌ DOWNLOAD: Error in search API: $e');
      return null;
    }
  }

  /// Helper untuk mendapatkan nama bulan
  String _getMonthName(int month) {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month];
  }

  // Helper methods untuk mengambil data yang sudah dihitung
  double _getTotalKwh(Map<String, dynamic> summary) {
    final value = (summary['totalKwh'] as num?)?.toDouble() ?? 0.0;
    print('🔍 _getTotalKwh: Extracted value $value from summary');
    return value;
  }

  double _getTotalBbm(Map<String, dynamic> summary) {
    final value = (summary['totalBbm'] as num?)?.toDouble() ?? 0.0;
    print('🔍 _getTotalBbm: Extracted value $value from summary');
    return value;
  }

  double _getAverageSfc(Map<String, dynamic> summary) {
    final value = (summary['averageSfc'] as num?)?.toDouble() ?? 0.0;
    print('🔍 _getAverageSfc: Extracted value $value from summary');
    return value;
  }
}

// Screen baru dengan format detail mesin untuk riwayat
class RiwayatDetailMesinStyleScreen extends StatefulWidget {
  final String generatorName;
  final String dateFormatted;
  final String? fileId; // ADD: fileId parameter
  final Map<String, dynamic> logsheetData;
  final List<Map<String, dynamic>> allDayData;

  const RiwayatDetailMesinStyleScreen({
    Key? key,
    required this.generatorName,
    required this.dateFormatted,
    this.fileId, // ADD: fileId parameter
    required this.logsheetData,
    required this.allDayData,
  }) : super(key: key);

  @override
  State<RiwayatDetailMesinStyleScreen> createState() =>
      _RiwayatDetailMesinStyleScreenState();
}

class _RiwayatDetailMesinStyleScreenState
    extends State<RiwayatDetailMesinStyleScreen> {
  Map<String, dynamic> realTimeData = {};

  @override
  void initState() {
    super.initState();
    realTimeData = _parseLogsheetDataToRealTime(widget.logsheetData);
  }

  // Parse data logsheet menjadi format real-time (sama dengan detail_mesin_screen)
  Map<String, dynamic> _parseLogsheetDataToRealTime(Map<String, dynamic> data) {
    return {
      'currentHour': DateTime.now().hour,
      'isRunning': true, // Untuk riwayat, anggap selalu running
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Detail ${widget.generatorName}'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.engineering,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.generatorName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Data Logsheet - ${widget.dateFormatted}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Temperature Chart
            TemperatureLineChartWidget(
              fileId: widget.fileId ?? '',
              generatorName: widget.generatorName,
              logsheetData: widget.logsheetData,
              realTimeData: realTimeData,
              allHourlyData: widget.allDayData, // Gunakan data hari lengkap
              useGeneratorData:
                  false, // Untuk riwayat, gunakan data spesifik fileId
            ),

            const SizedBox(height: 20),

            // Engine Parameters
            EngineParametersWidget(
              logsheetData: widget.logsheetData,
              realTimeData: realTimeData,
            ),

            const SizedBox(height: 20),

            // Generator Electrical Parameters
            GeneratorElectricalWidget(
              logsheetData: widget.logsheetData,
              realTimeData: realTimeData,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1E3A8A),
        unselectedItemColor: Colors.grey,
        currentIndex: 1, // Riwayat tab
        onTap: (index) {
          switch (index) {
            case 0: // Dashboard
              Navigator.of(context).popUntil((route) => route.isFirst);
              break;
            case 1: // Riwayat - stay here
              break;
            case 2: // Pengaturan
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.pushNamed(context, '/pengaturan');
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
