import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  static const String _baseUrl =
      'https://us-central1-powerplantlogsheet-8780a.cloudfunctions.net/api';

  /// Mencari file spreadsheet berdasarkan nama generator di folder Google Drive
  static Future<List<Map<String, dynamic>>> searchLogsheetFiles(
    String generatorName, {
    int daysBack = 7,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/search-files').replace(
        queryParameters: {
          'generatorName': generatorName,
          'daysBack': daysBack.toString(),
        },
      );

      print('Searching files for $generatorName: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['files'] != null) {
          print('Found ${data['totalFound']} files for $generatorName');
          return List<Map<String, dynamic>>.from(data['files']);
        }
        return [];
      } else {
        print('Search files : ${response.statusCode} - ${response.body}');
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print(' searching logsheet files: $e');
      return [];
    }
  }

  /// Mendapatkan daftar semua file logsheet yang ada di folder
  static Future<List<Map<String, dynamic>>> getAllLogsheetFiles() async {
    try {
      final uri = Uri.parse('$_baseUrl/list-files');

      print('Getting all logsheet files: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['files'] != null) {
          print('Found ${data['totalFiles']} total logsheet files');
          return List<Map<String, dynamic>>.from(data['files']);
        }
        return [];
      } else {
        print('List files : ${response.statusCode} - ${response.body}');
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print(' getting all logsheet files: $e');
      return [];
    }
  }

  /// Mencari file berdasarkan tanggal dan nama generator
  static Future<String?> findFileByDate(
    String generatorName,
    DateTime targetDate,
  ) async {
    try {
      final formattedDate = _formatDateForFileName(targetDate);
      final expectedFileName = 'Logsheet $generatorName, $formattedDate';

      final uri = Uri.parse('$_baseUrl/find-file').replace(
        queryParameters: {
          'fileName': expectedFileName,
          'generatorName': generatorName,
          'date': targetDate.toIso8601String(),
        },
      );

      print('Finding file: $expectedFileName');
      print('Search URI: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['fileId'] != null) {
          print('Found file: ${data['fileName']} (${data['fileId']})');
          return data['fileId'] as String;
        }
      } else if (response.statusCode == 404) {
        print('File not found: $expectedFileName');
      } else if (response.statusCode == 500) {
        final errorData = jsonDecode(response.body);
        if (errorData['details'] == 'invalid_grant') {
          print('Authentication expired, ing in 2 seconds...');
          await Future.delayed(Duration(seconds: 2));

          // Coba lagi once
          final retryResponse = await http.get(uri);
          if (retryResponse.statusCode == 200) {
            final retryData = jsonDecode(retryResponse.body);
            if (retryData['success'] == true && retryData['fileId'] != null) {
              print(
                'Found file on retry: ${retryData['fileName']} (${retryData['fileId']})',
              );
              return retryData['fileId'] as String;
            }
          }
        }
        print('Find file : ${response.statusCode} - ${response.body}');
      } else {
        print('Find file : ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print(' finding file by date: $e');
      return null;
    }
  }

  /// Mendapatkan informasi file berdasarkan fileId
  static Future<Map<String, dynamic>?> getFileInfo(String fileId) async {
    try {
      final uri = Uri.parse('$_baseUrl/file-info/$fileId');

      print('Getting file  for: $fileId');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['file'] != null) {
          print('File info retrieved: ${data['file']['name']}');
          return Map<String, dynamic>.from(data['file']);
        }
      } else {
        print('Get file info : ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error getting file : $e');
      return null;
    }
  }

  /// Mendapatkan statistik folder (jumlah file, ukuran total, dll)
  static Future<Map<String, dynamic>> getFolderStats() async {
    try {
      final uri = Uri.parse('$_baseUrl/folder-stats');

      print('Getting folder stats...');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['stats'] != null) {
          final stats = Map<String, dynamic>.from(data['stats']);
          print(
            'Folder stats retrieved: ${stats['totalFiles']} files, ${stats['generators']?.length ?? 0} generators',
          );
          return stats;
        }
      } else {
        print(
          'Get folder stats error: ${response.statusCode} - ${response.body}',
        );
      }
      return {'totalFiles': 0, 'totalSize': 0, 'generators': <String>[]};
    } catch (e) {
      print(' getting folder stats: $e');
      return {'totalFiles': 0, 'totalSize': 0, 'generators': <String>[]};
    }
  }

  /// Mendapatkan data historis real dari Google Drive
  static Future<List<Map<String, dynamic>>> getRealHistoricalData(
    String generatorName, {
    int daysBack = 7,
  }) async {
    try {
      List<Map<String, dynamic>> allData = [];
      final now = DateTime.now();

      print(
        'Getting real historical data for $generatorName (last $daysBack days)',
      );

      // Cari file untuk setiap hari dalam rentang yang diminta
      for (int i = 0; i < daysBack; i++) {
        final targetDate = now.subtract(Duration(days: i));

        print('Searching for data on ${_formatDateForFileName(targetDate)}');

        // Cari file untuk tanggal ini
        final fileId = await findFileByDate(generatorName, targetDate);

        if (fileId != null) {
          try {
            print(
              'Found file $fileId for ${_formatDateForFileName(targetDate)}',
            );
            // Ambil data dari file yang ditemukan
            final fileData = await _readFileData(fileId);
            if (fileData.isNotEmpty) {
              // Tambahkan metadata tanggal
              for (final entry in fileData) {
                entry['fileDate'] = targetDate.toIso8601String();
                entry['fileId'] = fileId;
                entry['isRealData'] = true;
              }
              allData.addAll(fileData);
              print(
                'Added ${fileData.length} entries from ${_formatDateForFileName(targetDate)}',
              );
            }
          } catch (e) {
            print(' reading file $fileId for date $targetDate: $e');
          }
        } else {
          print('No file found for ${_formatDateForFileName(targetDate)}');
        }
      }

      // Urutkan berdasarkan tanggal (terbaru dulu)
      allData.sort((a, b) {
        final dateA = DateTime.tryParse(a['fileDate'] ?? '') ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['fileDate'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      print('Total historical entries found: ${allData.length}');
      return allData;
    } catch (e) {
      print(' getting real historical data: $e');
      return [];
    }
  }

  /// Membaca data dari file spreadsheet dengan semua field termasuk energy/fuel
  static Future<List<Map<String, dynamic>>> _readFileData(String fileId) async {
    try {
      // PRIORITAS 1: Gunakan sheets API extension untuk data lengkap
      try {
        final uri = Uri.parse('$_baseUrl/logsheet/$fileId/hourly-data');
        print('📊 Trying sheets API extension: $uri');

        final response = await http.get(uri);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null) {
            print('✅ fully read hourly data from sheets API');
            return _convertHourlyDataToLogsheetFormat(data['data']);
          }
        }
      } catch (e) {
        print('⚠️ Sheets API extension not available: $e');
      }

      // PRIORITAS 2: Fallback ke endpoint standard
      final uri = Uri.parse('$_baseUrl/read-logsheet');
      print('📋 Reading data from file: $fileId using standard endpoint');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fileId': fileId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          print('✅ fully read logsheet data from standard endpoint');
          // Konversi single data entry menjadi list
          return [data['data']];
        }
      } else {
        print('❌ Read file : ${response.statusCode} - ${response.body}');
      }
      return [];
    } catch (e) {
      print('❌  reading file data: $e');
      return [];
    }
  }

  /// Konversi data hourly ke format logsheet standar
  static List<Map<String, dynamic>> _convertHourlyDataToLogsheetFormat(
    Map<String, dynamic> hourlyApiData,
  ) {
    try {
      List<Map<String, dynamic>> result = [];

      final hourlyData = hourlyApiData['hourlyData'] as List<dynamic>? ?? [];

      for (final hourEntry in hourlyData) {
        final hourData = hourEntry['data'] as Map<String, dynamic>? ?? {};

        // Skip jika tidak ada data untuk jam ini
        if (hourData.isEmpty || hourData['jamOperasi'] == null) {
          continue;
        }

        // Ubah ke format logsheet standar
        final logsheetEntry = {
          'generatorName': hourlyApiData['header']?['generatorName'] ?? '',
          'tanggal': hourlyApiData['header']?['date'] ?? '',
          'jam': hourEntry['hour']?.toString() ?? '',
          'jamOperasi': hourData['jamOperasi'],
          'rpm': hourData['rpm'],
          'lubeOilTemp': hourData['lubeOilTemp'],
          'oilPressure': hourData['oilPressure'],
          'waterTemp': hourData['waterTemp'],
          'teganganAccu': hourData['teganganAccu'],
          'beban': hourData['beban'],
          'voltageR': hourData['voltageR'],
          'voltageS': hourData['voltageS'],
          'voltageT': hourData['voltageT'],
          'ampereR': hourData['ampereR'],
          'ampereS': hourData['ampereS'],
          'ampereT': hourData['ampereT'],
          'kvar': hourData['kvar'],
          'hz': hourData['hz'],
          'cosPhi': hourData['cosPhi'],
          'tempWindingU': hourData['tempWindingU'],
          'tempWindingV': hourData['tempWindingV'],
          'tempWindingW': hourData['tempWindingW'],
          'tempBearing': hourData['tempBearing'],
          'enginePressureCrankcase': hourData['enginePressureCrankcase'],
          'engineTempExhaust': hourData['engineTempExhaust'],
          // Energy/Fuel data - FIELD YANG DIPERLUKAN
          'kwhAwal': hourData['kwhAwal'],
          'kwhAkhir': hourData['kwhAkhir'],
          'totalKwh': hourData['totalKwh'],
          'bbmAwal': hourData['bbmAwal'],
          'bbmAkhir': hourData['bbmAkhir'],
          'totalBbm': hourData['totalBbm'],
          'sfc': hourData['sfc'],
          'timestamp': DateTime.now().toIso8601String(),
        };

        result.add(logsheetEntry);
      }

      print('📊 Converted ${result.length} hourly entries to at');
      return result;
    } catch (e) {
      print('❌  converting hourly data: $e');
      return [];
    }
  }

  /// Konversi data mentah dari spreadsheet ke format Map
  /// Format tanggal untuk nama file
  static String _formatDateForFileName(DateTime date) {
    final List<String> bulan = [
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

    return '${date.day.toString().padLeft(2, '0')} ${bulan[date.month]} ${date.year}';
  }

  /// Mendapatkan nama generator dari nama file
  static String? extractGeneratorName(String fileName) {
    final regex = RegExp(r'Logsheet (.+?),');
    final match = regex.firstMatch(fileName);
    return match?.group(1);
  }

  /// Mendapatkan tanggal dari nama file
  static DateTime? extractDateFromFileName(String fileName) {
    try {
      final regex = RegExp(r'Logsheet .+?, (.+)');
      final match = regex.firstMatch(fileName);
      if (match != null) {
        final dateStr = match.group(1);
        // Parse format "DD Bulan YYYY"
        return _parseDateString(dateStr!);
      }
      return null;
    } catch (e) {
      print(' extracting date from filename: $e');
      return null;
    }
  }

  /// Parse string tanggal format Indonesia
  static DateTime? _parseDateString(String dateStr) {
    try {
      final bulanMap = {
        'Januari': 1,
        'Februari': 2,
        'Maret': 3,
        'April': 4,
        'Mei': 5,
        'Juni': 6,
        'Juli': 7,
        'Agustus': 8,
        'September': 9,
        'Oktober': 10,
        'November': 11,
        'Desember': 12,
      };

      final parts = dateStr.split(' ');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = bulanMap[parts[1]];
        final year = int.tryParse(parts[2]);

        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
      return null;
    } catch (e) {
      print(' parsing date string: $e');
      return null;
    }
  }
}
