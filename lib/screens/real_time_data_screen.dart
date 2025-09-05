import 'package:flutter/material.dart';
// import '../services/sheets_api_service.dart';

/// 📊 Real-time Data Screen (Simplified Version)
/// Placeholder untuk live monitoring data
class RealTimeDataScreen extends StatefulWidget {
  final String? fileId;
  final String? generatorName;

  const RealTimeDataScreen({Key? key, this.fileId, this.generatorName})
    : super(key: key);

  @override
  State<RealTimeDataScreen> createState() => _RealTimeDataScreenState();
}

class _RealTimeDataScreenState extends State<RealTimeDataScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.generatorName ?? 'Real-time Data'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              // Simulate loading
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              });
            },
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading real-time data...'),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.show_chart,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Live Data Monitor',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Generator: ${widget.generatorName ?? "Unknown"}',
                            ),
                            Text(
                              'File ID: ${widget.fileId ?? "Not configured"}',
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.construction,
                                    size: 48,
                                    color: Colors.blue[600],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Real-time Monitoring',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Feature sedang dalam pengembangan.\nGoogle Sheets API integration akan segera tersedia.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.blue[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Status placeholder
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange[700],
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'System Status',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildStatusRow(
                              'API Connection',
                              'Ready',
                              Colors.green,
                            ),
                            _buildStatusRow(
                              'Firebase Functions',
                              'Deployed',
                              Colors.green,
                            ),
                            _buildStatusRow(
                              'Google Sheets API',
                              'Configured',
                              Colors.green,
                            ),
                            _buildStatusRow(
                              'Real-time Data',
                              'Testing',
                              Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
