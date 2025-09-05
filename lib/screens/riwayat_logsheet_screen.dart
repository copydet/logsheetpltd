import 'package:flutter/material.dart';
import '../app_exports.dart';

class RiwayatLogsheetScreen extends StatefulWidget {
  const RiwayatLogsheetScreen({Key? key}) : super(key: key);

  @override
  State<RiwayatLogsheetScreen> createState() => _RiwayatLogsheetScreenState();
}

class _RiwayatLogsheetScreenState extends State<RiwayatLogsheetScreen> {
  List<Map<String, dynamic>> generators = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadGeneratorData();
  }

  Future<void> _loadGeneratorData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Daftar nama mesin yang akan ditampilkan - SEMUA MESIN
      final List<String> targetGenerators = [
        'Mitsubishi #1',
        'Mitsubishi #2',
        'Mitsubishi #3',
        'Mitsubishi #4',
      ];

      final List<Map<String, dynamic>> generatorList = [];

      // Untuk setiap mesin, coba ambil data real dan hitung logsheet
      for (int i = 0; i < targetGenerators.length; i++) {
        final generatorName = targetGenerators[i];

        try {
          print('🔍 Memuat data untuk $generatorName...');

          // Debug: Cek data hari ini
          final todayCheck = await HistoricalLogsheetService.checkTodayData(
            generatorName,
          );
          print('Today check : $todayCheck');

          // Coba ambil data real dari API untuk menghitung jumlah logsheet
          final response = await RestApiService.getGeneratorDetails(
            generatorName,
            limit: 100, // Ambil semua file
          );

          int realLogsheetCount = 0;
          String lastActivity = '';

          if (response['success'] == true) {
            // Ambil files array langsung dari response
            final allFiles = response['files'] as List? ?? [];

            // Filter files yang benar-benar sesuai dengan generator yang diminta
            final filteredFiles = allFiles.where((file) {
              final fileName = file['name'] as String? ?? '';
              // Pastikan nama file mengandung generator name yang exact
              return fileName.contains('Logsheet $generatorName,');
            }).toList();

            realLogsheetCount = filteredFiles.length;

            // Ambil aktivitas terakhir dari file pertama (terbaru) yang sudah difilter
            if (filteredFiles.isNotEmpty) {
              final latestFile = filteredFiles.first as Map<String, dynamic>?;
              final modifiedTime = latestFile?['modifiedTime'] as String?;
              if (modifiedTime != null) {
                final lastModified = DateTime.tryParse(modifiedTime);
                if (lastModified != null) {
                  final daysDiff = DateTime.now()
                      .difference(lastModified)
                      .inDays;
                  if (daysDiff == 0) {
                    lastActivity = 'Hari ini';
                  } else if (daysDiff == 1) {
                    lastActivity = '1 hari lalu';
                  } else if (daysDiff < 7) {
                    lastActivity = '$daysDiff hari lalu';
                  } else {
                    final weeksDiff = (daysDiff / 7).floor();
                    lastActivity = '$weeksDiff minggu lalu';
                  }
                }
              }
            }
          }

          // Jika tidak ada data real, tampilkan status kosong
          if (realLogsheetCount == 0) {
            realLogsheetCount = 0;
            lastActivity = 'Belum ada data';
          }

          generatorList.add({
            'name': generatorName, // Gunakan nama asli tanpa prefix "Mesin"
            'originalName':
                generatorName, // Tambah field originalName untuk navigasi
            'fileId': 'mitsubishi_${i + 1}',
            'logsheetCount': realLogsheetCount,
            'lastActivity': lastActivity.isEmpty
                ? 'Belum ada data'
                : lastActivity,
          });
        } catch (e) {
          print('Kesalahan mengambil data untuk $generatorName: $e');

          // Jika ada error, tampilkan sebagai tidak ada data
          generatorList.add({
            'name': generatorName, // Gunakan nama asli
            'originalName': generatorName, // Tambah field originalName
            'fileId': 'mitsubishi_${i + 1}',
            'logsheetCount': 0,
            'lastActivity': 'Kesalahan memuat data',
          });
        }
      }

      if (!mounted) return;

      setState(() {
        generators = generatorList;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'Gagal memuat data generator: $e';
        // Fallback ke data default jika semua gagal
        generators = [
          {
            'name': 'Mesin Mitsubishi #3',
            'fileId': 'mitsubishi_3',
            'logsheetCount': 0,
            'lastActivity': 'Belum ada data',
          },
          {
            'name': 'Mesin Mitsubishi #4',
            'fileId': 'mitsubishi_4',
            'logsheetCount': 0,
            'lastActivity': 'Belum ada data',
          },
        ];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Riwayat Logsheet',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
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
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
            ),
            SizedBox(height: 16),
            Text('Memuat data generator...'),
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
              onPressed: _loadGeneratorData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (generators.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.engineering_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak Ada Generator',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada generator yang terdaftar',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGeneratorData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: generators.length,
        itemBuilder: (context, index) {
          final generator = generators[index];
          return _buildGeneratorCard(generator);
        },
      ),
    );
  }

  Widget _buildGeneratorCard(Map<String, dynamic> generator) {
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
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RiwayatLogsheetDetailScreen(
                  generatorName:
                      generator['originalName'] ??
                      generator['name'], // Gunakan originalName untuk navigasi
                  fileId: generator['fileId'].toString().isNotEmpty
                      ? generator['fileId']
                      : null,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.engineering,
                        color: const Color(0xFF1E3A8A),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            generator['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Generator Mitsubishi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          'Total Logsheet',
                          '${generator['logsheetCount'] ?? 0}',
                          Icons.description,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoItem(
                          'Aktivitas Terakhir',
                          generator['lastActivity'].toString().isNotEmpty
                              ? '${generator['lastActivity']}'
                              : 'Tidak ada',
                          Icons.schedule,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
