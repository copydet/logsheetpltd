import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/temperature_config.dart';
import '../services/database_temperature_service.dart';
import '../services/firestore_realtime_service.dart';

/// ============================================================================
/// TEMPERATURE LINE CHART WIDGET
/// ============================================================================
/// Widget untuk menampilkan chart temperature monitoring dengan fitur:
/// - Multiple parameter temperature (Water, Lube Oil, Exhaust, Bearing, Winding)
/// - Navigasi horizontal dengan PageView
/// - Data loading dari spreadsheet, SharedPreferences, dan real-time
/// - Chart responsif dengan tooltips dan indicators
/// ============================================================================

class TemperatureLineChartWidget extends StatefulWidget {
  /// File ID untuk storage SharedPreferences
  final String fileId;

  /// Generator name untuk Firestore data
  final String generatorName;

  /// Data logsheet saat ini
  final Map<String, dynamic> logsheetData;

  /// Data real-time dari spreadsheet
  final Map<String, dynamic> realTimeData;

  /// Data semua jam hari ini dari spreadsheet
  final List<Map<String, dynamic>>? allHourlyData;

  /// Flag untuk menggunakan data berdasarkan generator (true) atau fileId (false)
  final bool useGeneratorData;

  const TemperatureLineChartWidget({
    Key? key,
    required this.fileId,
    required this.generatorName,
    required this.logsheetData,
    this.realTimeData = const {},
    this.allHourlyData,
    this.useGeneratorData = true, // Default menggunakan data generator
  }) : super(key: key);

  @override
  State<TemperatureLineChartWidget> createState() =>
      _TemperatureLineChartWidgetState();
}

class _TemperatureLineChartWidgetState
    extends State<TemperatureLineChartWidget> {
  // ========================================================================
  // PROPERTI & CONTROLLER
  // ========================================================================

  late PageController _pageController;
  int _currentPageIndex = 0;

  // ========================================================================
  // METODE LIFECYCLE
  // ========================================================================

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void didUpdateWidget(TemperatureLineChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Paksa refresh chart jika ada data baru
    if (oldWidget.logsheetData != widget.logsheetData ||
        oldWidget.realTimeData != widget.realTimeData) {
      setState(() {
        // Picu rebuild chart dengan data terbaru
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ========================================================================
  // METODE BUILD UTAMA
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [_buildHeader(), _buildChartsCarousel(), _buildPageIndicator()],
    );
  }

  // ========================================================================
  // METODE PEMBUATAN UI
  // ========================================================================

  /// Header dengan title dan icon
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(Icons.thermostat, color: Colors.blue[700], size: 24),
          const SizedBox(width: 8),
          const Text(
            'Temperature Monitoring',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// Carousel untuk menampilkan multiple chart temperature
  Widget _buildChartsCarousel() {
    return SizedBox(
      height: 280,
      child: PageView.builder(
        controller: _pageController,
        itemCount: temperatureConfigs.length,
        onPageChanged: (index) {
          setState(() {
            _currentPageIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final entry = temperatureConfigs.entries.elementAt(index);
          final paramKey = entry.key;
          final config = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildTemperatureCard(config: config, paramKey: paramKey),
          );
        },
      ),
    );
  }

  /// Page indicator dengan dots dan label
  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          // Indikator titik
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              temperatureConfigs.length,
              (index) => GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPageIndex == index ? 12 : 8,
                  height: _currentPageIndex == index ? 12 : 8,
                  decoration: BoxDecoration(
                    color: _currentPageIndex == index
                        ? Colors.blue[700]
                        : Colors.grey[400],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Label chart saat ini
          Text(
            temperatureConfigs.entries.elementAt(_currentPageIndex).value.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // METODE KARTU TEMPERATUR
  // ========================================================================

  /// Membuat card untuk satu parameter temperature
  Widget _buildTemperatureCard({
    required TemperatureConfig config,
    required String paramKey,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(config, paramKey),
          const SizedBox(height: 16),
          _buildChart(config),
        ],
      ),
    );
  }

  /// Header dari temperature card
  Widget _buildCardHeader(TemperatureConfig config, String paramKey) {
    return Row(
      children: [
        Icon(config.icon, color: config.color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Current: ${_getCurrentValue(paramKey)} ${config.unit}',
                style: TextStyle(
                  fontSize: 14,
                  color: config.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Chart dengan FutureBuilder untuk loading data async
  Widget _buildChart(TemperatureConfig config) {
    return Expanded(
      child: FutureBuilder<List<FlSpot>>(
        future: _generateTemperatureData(config),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red[400], size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading chart data',
                    style: TextStyle(color: Colors.red[600], fontSize: 12),
                  ),
                ],
              ),
            );
          }

          final chartData = snapshot.data ?? [];
          if (chartData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, color: Colors.grey[400], size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'No data available',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return LineChart(_buildLineChartData(config, chartData));
        },
      ),
    );
  }

  // ========================================================================
  // CHART CONFIGURATION METHODS
  // ========================================================================

  /// Membuat konfigurasi data untuk LineChart
  LineChartData _buildLineChartData(
    TemperatureConfig config,
    List<FlSpot> chartData,
  ) {
    // Gunakan 12 jam terakhir untuk x-axis (0-11)
    return LineChartData(
      gridData: _buildGridData(),
      titlesData: _buildTitlesData(config),
      borderData: _buildBorderData(),
      lineTouchData: _buildTouchData(config),
      minX: 0,
      maxX: 11, // 12 jam terakhir (0-11)
      minY: config.minY,
      maxY: config.maxY,
      lineBarsData: [_buildLineBarData(config, chartData)],
    );
  }

  /// Konfigurasi grid untuk chart
  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      drawHorizontalLine: true,
      horizontalInterval: null, // Auto interval
      verticalInterval: 2, // Setiap 2 jam untuk 12 jam terakhir
      getDrawingHorizontalLine: (value) =>
          FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
      getDrawingVerticalLine: (value) =>
          FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
    );
  }

  /// Konfigurasi border untuk chart
  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
    );
  }

  /// Konfigurasi titles (label sumbu) untuk chart
  FlTitlesData _buildTitlesData(TemperatureConfig config) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) => _buildLeftTitle(value, config),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (value, meta) => _buildBottomTitle(value.toInt()),
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  /// Konfigurasi touch interaction untuk chart
  LineTouchData _buildTouchData(TemperatureConfig config) {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (touchedSpot) => config.color.withOpacity(0.9),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((LineBarSpot touchedSpot) {
            return LineTooltipItem(
              '${touchedSpot.y.toStringAsFixed(1)}${config.unit}',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            );
          }).toList();
        },
      ),
      getTouchedSpotIndicator:
          (LineChartBarData barData, List<int> indicators) {
            return indicators.map((int index) {
              return TouchedSpotIndicatorData(
                FlLine(color: config.color, strokeWidth: 2, dashArray: [5, 5]),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 8,
                      color: config.color,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
              );
            }).toList();
          },
    );
  }

  /// Konfigurasi line bar data untuk chart
  LineChartBarData _buildLineBarData(
    TemperatureConfig config,
    List<FlSpot> chartData,
  ) {
    return LineChartBarData(
      spots: chartData,
      isCurved: true,
      color: config.color,
      barWidth: 3,
      isStrokeCapRound: true,
      belowBarData: BarAreaData(
        show: true,
        color: config.color.withOpacity(0.1),
      ),
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 6,
            color: config.color,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
    );
  }

  // ========================================================================
  // CHART LABEL METHODS
  // ========================================================================

  /// Membuat label untuk sumbu Y (temperature values)
  Widget _buildLeftTitle(double value, TemperatureConfig config) {
    return Text(
      value.toInt().toString(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: config.color.withOpacity(0.7),
      ),
    );
  }

  /// Membuat label untuk sumbu X (time hours) - 12 jam terakhir
  Widget _buildBottomTitle(int position) {
    // Hitung jam aktual berdasarkan posisi dalam 12 jam terakhir
    final currentHour = DateTime.now().hour;
    final actualHour = (currentHour - 11 + position + 24) % 24;

    // Tampilkan label hanya untuk posisi genap agar tidak terlalu padat
    if (position % 2 == 0) {
      // Tampilkan setiap 2 posisi: 0, 2, 4, 6, 8, 10
      final timeStr = '${actualHour.toString().padLeft(2, '0')}:00';
      return Text(
        timeStr,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
        ),
      );
    }
    return const Text(''); // Return empty untuk posisi lainnya
  }

  // ========================================================================
  // DATA PROCESSING METHODS
  // ========================================================================

  /// Generate data temperature untuk chart berdasarkan prioritas:
  /// 1. Data SQLite database (offline-first, data lokal user)
  /// 2. Data Firestore (fallback untuk multi-user data)
  /// 3. Data real dari spreadsheet (allHourlyData)
  /// 4. Current real-time value
  Future<List<FlSpot>> _generateTemperatureData(
    TemperatureConfig config,
  ) async {
    final String paramKey = _getParameterKey(config.title);
    List<FlSpot> spots = [];

    try {
      print('🔍 ===== CHART DEBUG: ${widget.generatorName} =====');
      print('� FileId: ${widget.fileId}');
      print('📊 Parameter: $paramKey');
      print('�🌡️ CHART: Loading temperature data for $paramKey');

      // PRIORITAS 1: Gunakan data SQLite database (offline-first)
      spots = await _extractSpotsFromSQLiteDatabase(paramKey, config);
      if (spots.isNotEmpty) {
        print('✅ 🌡️ CHART: Using SQLite database (${spots.length} points)');
        return spots;
      }

      // PRIORITAS 2: Gunakan data Firestore (fallback multi-user)
      spots = await _extractSpotsFromFirestore(paramKey, config);
      if (spots.isNotEmpty) {
        print('✅ 🌡️ CHART: Using Firestore data (${spots.length} points)');
        return spots;
      }

      // PRIORITAS 3: Gunakan data real dari spreadsheet
      if (widget.allHourlyData != null && widget.allHourlyData!.isNotEmpty) {
        spots = _extractSpotsFromSpreadsheetData(paramKey, config);
        if (spots.isNotEmpty) {
          print('🌡️ CHART: Using spreadsheet data (${spots.length} points)');
          return spots;
        }
      }

      // PRIORITAS 4: Gunakan current real-time value
      spots = _extractSpotsFromCurrentValue(paramKey, config);
      print(
        '🌡️ CHART: Using current real-time value (${spots.length} points)',
      );
    } catch (e) {
      print('🌡️ CHART: Error loading temperature data: $e');
    }

    return spots;
  }

  /// Mengambil parameter key berdasarkan title config
  String _getParameterKey(String title) {
    switch (title) {
      case 'Water Temperature':
        return 'waterTemp';
      case 'Lube Oil Temperature':
        return 'lubeOilTemp';
      case 'Exhaust Temperature':
        return 'engineTempExhaust';
      case 'Bearing Temperature':
        return 'tempBearing';
      case 'Winding Temperature (Average)':
        return 'tempWindingAvg';
      default:
        return title.toLowerCase().replaceAll(' ', '');
    }
  }

  /// Extract spots dari data spreadsheet - 12 jam terakhir
  List<FlSpot> _extractSpotsFromSpreadsheetData(
    String paramKey,
    TemperatureConfig config,
  ) {
    List<FlSpot> spots = [];

    print(
      '🌡️ CHART: Processing ${widget.allHourlyData!.length} spreadsheet entries for last 12 hours',
    );

    final dataLength = widget.allHourlyData!.length;

    // Ambil 12 jam terakhir dari data spreadsheet
    final startIndex = (dataLength - 12).clamp(0, dataLength);

    for (int i = 0; i < 12; i++) {
      final dataIndex = startIndex + i;

      if (dataIndex < dataLength) {
        final hourlyEntry = widget.allHourlyData![dataIndex];
        final tempValue = _extractTemperatureValue(hourlyEntry, paramKey);

        if (tempValue != null && tempValue > 0) {
          final clampedValue = tempValue.clamp(config.minY, config.maxY);
          spots.add(FlSpot(i.toDouble(), clampedValue));
          print(
            '🌡️ CHART: Added spreadsheet point at position $i (data index $dataIndex): $clampedValue°C',
          );
        }
      }
    }

    return spots;
  }

  /// Extract spots dari Firestore data (prioritas utama) - 12 jam terakhir
  Future<List<FlSpot>> _extractSpotsFromFirestore(
    String paramKey,
    TemperatureConfig config,
  ) async {
    List<FlSpot> spots = [];

    try {
      print(
        '🌡️ CHART: Loading from Firestore for generator: ${widget.generatorName}',
      );

      // Gunakan Firestore untuk data temperature multi-user
      final temperatureData =
          await FirestoreRealtimeService.getTemperatureDataForChart(
            widget.generatorName,
          );

      print(
        '🌡️ CHART: Found ${temperatureData.length} temperature records from Firestore',
      );

      if (temperatureData.isEmpty) {
        return spots;
      }

      // Hitung range 12 jam terakhir berdasarkan jam sekarang
      final currentHour = DateTime.now().hour;

      print('🌡️ CHART: Current hour: $currentHour');

      // Map data berdasarkan jam yang ada dalam 12 jam terakhir
      // Posisi 0 = jam sekarang - 11, Posisi 11 = jam sekarang
      for (int position = 0; position < 12; position++) {
        final targetHour = (currentHour - 11 + position + 24) % 24;

        // Cari data untuk jam ini
        Map<String, dynamic>? foundRecord;
        for (final record in temperatureData) {
          final recordHour = record['hour'] ?? -1;
          if (recordHour == targetHour) {
            foundRecord = record;
            break;
          }
        }

        if (foundRecord != null) {
          final tempValue = _extractTemperatureValue(foundRecord, paramKey);

          if (tempValue != null && tempValue > 0) {
            final clampedValue = tempValue.clamp(config.minY, config.maxY);
            spots.add(FlSpot(position.toDouble(), clampedValue));

            print(
              '🌡️ CHART: ✅ Added Firestore point at position $position (target hour $targetHour, record hour ${foundRecord['hour']}): $clampedValue°C',
            );
          }
        }
      }

      print(
        '🌡️ CHART: Firestore extraction complete: ${spots.length} data points for last 12 hours',
      );
    } catch (e) {
      print('🌡️ CHART: Error loading from Firestore: $e');
    }

    return spots;
  }

  /// Extract spots dari SQLite Database (prioritas kedua) - 12 jam terakhir
  Future<List<FlSpot>> _extractSpotsFromSQLiteDatabase(
    String paramKey,
    TemperatureConfig config,
  ) async {
    List<FlSpot> spots = [];

    try {
      print('🔍 ===== SQLite DATABASE EXTRACTION =====');
      print('🆔 Querying fileId: ${widget.fileId}');
      print('📊 Generator: ${widget.generatorName}');
      print('🌡️ Parameter: $paramKey');
      print('🔄 Use Generator Data: ${widget.useGeneratorData}');

      // Pilih method berdasarkan flag useGeneratorData
      final temperatureData = widget.useGeneratorData
          ? await DatabaseTemperatureService.getTemperatureDataByGeneratorName(
              widget.generatorName,
              limitDays: 7, // Ambil data 7 hari terakhir
            )
          : await DatabaseTemperatureService.getTemperatureDataByFileId(
              widget.fileId,
            );

      print(
        '📊 Found ${temperatureData.length} temperature records from SQLite',
      );

      if (temperatureData.isEmpty) {
        print(
          widget.useGeneratorData
              ? '❌ SQLite: No data found for generator: ${widget.generatorName}'
              : '❌ SQLite: No data found for fileId: ${widget.fileId}',
        );
        return spots;
      }

      // Debug: Print semua data yang ditemukan
      print('📋 Raw SQLite Data:');
      for (int i = 0; i < temperatureData.length && i < 5; i++) {
        final record = temperatureData[i];
        print(
          '   Record $i: hour=${record['hour']}, $paramKey=${record[paramKey]}',
        );
      }
      if (temperatureData.length > 5) {
        print('   ... and ${temperatureData.length - 5} more records');
      }

      // Hitung range 12 jam terakhir berdasarkan jam sekarang
      final currentHour = DateTime.now().hour;

      print('🌡️ CHART: Current hour: $currentHour');

      // Map data berdasarkan jam yang ada dalam 12 jam terakhir
      // Posisi 0 = jam sekarang - 11, Posisi 11 = jam sekarang
      for (int position = 0; position < 12; position++) {
        final targetHour = (currentHour - 11 + position + 24) % 24;

        // Cari data untuk jam ini - prioritaskan data terbaru jika ada multiple entries
        Map<String, dynamic>? foundRecord;

        if (widget.useGeneratorData) {
          // Untuk generator data, cari entri terbaru untuk jam ini
          // Data sudah diurutkan DESC berdasarkan date dan hour
          for (final record in temperatureData) {
            final recordHour = record['hour'] ?? -1;
            if (recordHour == targetHour) {
              foundRecord = record;
              break; // Ambil yang pertama (terbaru)
            }
          }
        } else {
          // Untuk fileId specific, cari entri untuk jam ini
          for (final record in temperatureData) {
            final recordHour = record['hour'] ?? -1;
            if (recordHour == targetHour) {
              foundRecord = record;
              break;
            }
          }
        }

        if (foundRecord != null) {
          final tempValue = _extractTemperatureValue(foundRecord, paramKey);

          if (tempValue != null && tempValue > 0) {
            final clampedValue = tempValue.clamp(config.minY, config.maxY);
            spots.add(FlSpot(position.toDouble(), clampedValue));

            print(
              '🌡️ CHART: ✅ Added SQLite point at position $position (target hour $targetHour, record hour ${foundRecord['hour']}): $clampedValue°C',
            );
          }
        }
      }

      print(
        '🌡️ CHART: SQLite extraction complete: ${spots.length} data points for last 12 hours',
      );

      // 🛠️ FIX: Jika data tidak cukup, coba fallback untuk Mitsubishi #1
      if (spots.length < 2 && widget.generatorName.contains('Mitsubishi #1')) {
        print(
          '🌡️ CHART: ⚠️ SQLite data insufficient (${spots.length} points), trying fallback for ${widget.generatorName}...',
        );

        // Jika Mitsubishi #1 dengan fileId bermasalah, coba fileId yang benar
        if (widget.fileId == '1-_G5vZD6xyXpxu1skcdQMB1auGBEW8upurPMuCm9YwA') {
          final correctFileId = '19Rq7EtX1IGdkXcie8c7O4WSDYd2SpM0rbeTehKkD-Zo';
          print(
            '🌡️ CHART: 🔧 Trying correct fileId for ${widget.generatorName}: $correctFileId',
          );

          final fallbackData =
              await DatabaseTemperatureService.getTemperatureDataByFileId(
                correctFileId,
              );
          print(
            '🌡️ CHART: Found ${fallbackData.length} fallback records from SQLite',
          );

          if (fallbackData.isNotEmpty) {
            final fallbackSpots = <FlSpot>[];

            // Proses data fallback dengan cara yang sama
            for (int position = 0; position < 12; position++) {
              final targetHour = (currentHour - 11 + position + 24) % 24;

              Map<String, dynamic>? foundRecord;
              for (final record in fallbackData) {
                final recordHour = record['hour'] ?? -1;
                if (recordHour == targetHour) {
                  foundRecord = record;
                  break;
                }
              }

              if (foundRecord != null) {
                final tempValue = _extractTemperatureValue(
                  foundRecord,
                  paramKey,
                );

                if (tempValue != null && tempValue > 0) {
                  final clampedValue = tempValue.clamp(
                    config.minY,
                    config.maxY,
                  );
                  fallbackSpots.add(FlSpot(position.toDouble(), clampedValue));

                  print(
                    '🌡️ CHART: ✅ Added fallback point at position $position (target hour $targetHour, record hour ${foundRecord['hour']}): $clampedValue°C',
                  );
                }
              }
            }

            if (fallbackSpots.length >= 2) {
              print(
                '🌡️ CHART: ✅ Using fallback data for ${widget.generatorName} (${fallbackSpots.length} points)',
              );
              return fallbackSpots;
            }
          }
        }
      }
    } catch (e) {
      print('🌡️ CHART: Error loading from SQLite: $e');
    }

    return spots;
  }

  /// Extract spots dari current value
  List<FlSpot> _extractSpotsFromCurrentValue(
    String paramKey,
    TemperatureConfig config,
  ) {
    final currentValue = double.tryParse(_getCurrentValue(paramKey)) ?? 0;

    if (currentValue > 0) {
      // Current value selalu di posisi terakhir (posisi 11) untuk 12 jam terakhir
      final clampedValue = currentValue.clamp(config.minY, config.maxY);
      print(
        '🌡️ CHART: Added current real-time point at position 11 (current hour): $clampedValue°C',
      );
      return [FlSpot(11.0, clampedValue)];
    }

    return [];
  }

  /// Extract temperature value dari data entry
  double? _extractTemperatureValue(Map<String, dynamic> data, String paramKey) {
    if (paramKey == 'tempWindingAvg') {
      return _calculateWindingAverage(data);
    }

    return double.tryParse(data[paramKey]?.toString() ?? '0');
  }

  /// Hitung rata-rata temperature winding U, V, W
  double? _calculateWindingAverage(Map<String, dynamic> data) {
    final tempU =
        double.tryParse(data['tempWindingU']?.toString() ?? '0') ?? 0.0;
    final tempV =
        double.tryParse(data['tempWindingV']?.toString() ?? '0') ?? 0.0;
    final tempW =
        double.tryParse(data['tempWindingW']?.toString() ?? '0') ?? 0.0;

    if (tempU > 0 || tempV > 0 || tempW > 0) {
      return (tempU + tempV + tempW) / 3;
    }

    return null;
  }

  // ========================================================================
  // CURRENT VALUE METHODS
  // ========================================================================

  /// Mendapatkan current value untuk parameter dengan prioritas:
  /// 1. Real-time data dari spreadsheet
  /// 2. Data logsheet
  String _getCurrentValue(String paramKey) {
    // Mapping parameter key ke key di real-time data
    final Map<String, String> realTimeMapping = {
      'tempWindingU': 'Temp Winding U',
      'tempWindingV': 'Temp Winding V',
      'tempWindingW': 'Temp Winding W',
      'tempBearing': 'Temp Bearing',
      'lubeOilTemp': 'Lube Oil Temp',
      'waterTemp': 'Water Temp',
      'engineTempExhaust': 'Engine Temp Exhaust',
    };

    // Handle winding average secara khusus
    if (paramKey == 'tempWindingAvg') {
      return _calculateCurrentWindingAverage();
    }

    // Cek real-time data dulu
    if (widget.realTimeData.isNotEmpty &&
        realTimeMapping.containsKey(paramKey)) {
      final realTimeValue = widget.realTimeData[realTimeMapping[paramKey]]
          ?.toString();
      if (realTimeValue != null &&
          realTimeValue != 'N/A' &&
          realTimeValue.isNotEmpty) {
        return realTimeValue;
      }
    }

    // Fallback ke logsheet data
    final value = widget.logsheetData[paramKey];
    return value?.toString() ?? '0';
  }

  /// Hitung current value untuk winding average
  String _calculateCurrentWindingAverage() {
    // Prioritas dari real-time data, fallback ke logsheet data
    final tempU = _getTemperatureFromSources('tempWindingU') ?? 0;
    final tempV = _getTemperatureFromSources('tempWindingV') ?? 0;
    final tempW = _getTemperatureFromSources('tempWindingW') ?? 0;

    final average = (tempU + tempV + tempW) / 3;
    return average.toStringAsFixed(1);
  }

  /// Helper untuk mendapatkan temperature dari berbagai sumber
  double? _getTemperatureFromSources(String paramKey) {
    // Mapping untuk real-time data
    final Map<String, String> realTimeMapping = {
      'tempWindingU': 'Temp Winding U',
      'tempWindingV': 'Temp Winding V',
      'tempWindingW': 'Temp Winding W',
    };

    // Cek real-time data dulu
    if (widget.realTimeData.isNotEmpty &&
        realTimeMapping.containsKey(paramKey)) {
      final realTimeValue = widget.realTimeData[realTimeMapping[paramKey]];
      if (realTimeValue != null && realTimeValue != 'N/A') {
        return double.tryParse(realTimeValue.toString());
      }
    }

    // Fallback ke logsheet data
    return double.tryParse(widget.logsheetData[paramKey]?.toString() ?? '0');
  }
}
