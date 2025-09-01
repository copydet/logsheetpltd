import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/spreadsheet_service.dart';
import '../services/storage_service.dart';
import '../models/temperature_config.dart';

class DetailRiwayatLogsheetScreen extends StatefulWidget {
  final String generatorName;
  final String fileId;

  const DetailRiwayatLogsheetScreen({
    Key? key,
    required this.generatorName,
    required this.fileId,
  }) : super(key: key);

  @override
  State<DetailRiwayatLogsheetScreen> createState() =>
      _DetailRiwayatLogsheetScreenState();
}

class _DetailRiwayatLogsheetScreenState
    extends State<DetailRiwayatLogsheetScreen> {
  bool isLoading = true;
  String? error;
  List<Map<String, dynamic>> historicalData = [];
  Map<String, List<double>> temperatureData = {};
  PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadHistoricalData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoricalData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Load current spreadsheet data
      final currentData = await SpreadsheetService.readSpreadsheetData(
        widget.fileId,
      );
      final currentMapData = SpreadsheetService.convertToMap(currentData);

      // Load historical data from previous days
      final historical = await SpreadsheetService.getHistoricalData(
        widget.generatorName,
        daysBack: 7,
      );

      // Combine current and historical data
      final allData = [...historical, ...currentMapData];

      // Extract temperature data for charts
      final tempData = SpreadsheetService.extractTemperatureData(allData);

      setState(() {
        historicalData = allData;
        temperatureData = tempData;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Gagal memuat data historis: $e';
        isLoading = false;
      });
    }
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
                      '• Semua data historis akan dihapus\n• Tindakan ini tidak dapat dibatalkan\n• File spreadsheet akan dihapus permanen',
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
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Menghapus logsheet...'),
              ],
            ),
          );
        },
      );

      // TODO: Implement actual delete functionality
      // This would typically involve:
      // 1. Delete the spreadsheet file using Google Drive API
      // 2. Clear local storage data
      // 3. Reset generator status

      // For now, simulate the delete process
      await Future.delayed(const Duration(seconds: 2));

      // Clear local storage
      await _clearLocalData();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Logsheet ${widget.generatorName} berhasil dihapus'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate back to previous screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
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
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Riwayat ${widget.generatorName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!isLoading && error == null && historicalData.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.black87),
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteConfirmationDialog();
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      const Text('Hapus Logsheet'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _buildErrorWidget()
          : _buildContent(),
      floatingActionButton:
          !isLoading && error == null && historicalData.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showDeleteConfirmationDialog,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.delete, color: Colors.white),
              label: const Text(
                'Hapus Logsheet',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red[700], fontSize: 16),
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

  Widget _buildContent() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.history, color: Colors.blue[700], size: 24),
              const SizedBox(width: 8),
              const Text(
                'Data Historis Temperature',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),

        // Historical Temperature Charts
        Expanded(
          child: historicalData.isEmpty
              ? _buildNoDataWidget()
              : _buildHistoricalCharts(),
        ),

        // Summary Statistics
        _buildSummarySection(),
      ],
    );
  }

  Widget _buildNoDataWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Belum ada data historis tersedia',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Data akan muncul setelah logsheet diisi beberapa kali',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalCharts() {
    return Column(
      children: [
        // Horizontal ScrollView for Temperature Charts
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
            },
            itemCount: temperatureConfigs.length,
            itemBuilder: (context, index) {
              final config = temperatureConfigs.values.elementAt(index);
              final paramKey = temperatureConfigs.keys.elementAt(index);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildHistoricalTemperatureCard(config, paramKey),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Page indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < temperatureConfigs.length; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _currentPageIndex
                      ? Colors.blue[700]
                      : Colors.grey[400],
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Current parameter name
        Text(
          temperatureConfigs.values.elementAt(_currentPageIndex).title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.blue[700],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoricalTemperatureCard(
    TemperatureConfig config,
    String paramKey,
  ) {
    final data = temperatureData[paramKey] ?? [];

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
          // Card Header
          Row(
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
                      'Data Points: ${data.length}',
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
          ),
          const SizedBox(height: 16),

          // Chart
          Expanded(
            child: data.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada data untuk parameter ini',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : LineChart(_buildHistoricalLineChartData(config, data)),
          ),
        ],
      ),
    );
  }

  LineChartData _buildHistoricalLineChartData(
    TemperatureConfig config,
    List<double> data,
  ) {
    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        horizontalInterval: _calculateHorizontalInterval(config),
        getDrawingHorizontalLine: (value) {
          return const FlLine(color: Colors.grey, strokeWidth: 0.5);
        },
        getDrawingVerticalLine: (value) {
          return const FlLine(color: Colors.grey, strokeWidth: 0.5);
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              return _buildBottomTitle(value.toInt());
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return _buildLeftTitle(value, config);
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      minX: 0,
      maxX: data.length > 1 ? data.length - 1.0 : 1.0,
      minY: config.minY,
      maxY: config.maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: config.color,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: config.color,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                config.color.withOpacity(0.3),
                config.color.withOpacity(0.1),
                config.color.withOpacity(0.05),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();
              final temp = spot.y.toStringAsFixed(1);

              return LineTooltipItem(
                'Data #${index + 1}\n$temp${config.unit}',
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
          getTooltipColor: (touchedSpot) => config.color.withOpacity(0.9),
        ),
      ),
    );
  }

  Widget _buildBottomTitle(int value) {
    return Text(
      '#${value + 1}',
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: Colors.grey,
      ),
    );
  }

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

  double _calculateHorizontalInterval(TemperatureConfig config) {
    return (config.maxY - config.minY) / 4; // 4 intervals
  }

  Widget _buildSummarySection() {
    if (historicalData.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Ringkasan Data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Total Data Points: ${historicalData.length}',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'Generator: ${widget.generatorName}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Periode: 7 hari terakhir',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
