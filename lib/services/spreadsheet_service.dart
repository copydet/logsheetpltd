import 'dart:convert';
import 'package:http/http.dart' as http;

class SpreadsheetService {
  static const String _baseUrl =
      'https://us-central1-powerplantlogsheet-8780a.cloudfunctions.net/api';

  /// Membaca data dari spreadsheet
  /// [fileId] adalah ID dari file spreadsheet
  /// [range] adalah range yang ingin dibaca (opsional)
  static Future<List<List<dynamic>>> readSpreadsheetData(
    String fileId, {
    String? range,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/read-logsheet/$fileId',
      ).replace(queryParameters: range != null ? {'range': range} : null);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Konversi data ke List<List<dynamic>>
          return List<List<dynamic>>.from(
            data['data'].map((row) => List<dynamic>.from(row)),
          );
        }
        throw Exception('Data tidak valid');
      }

      throw Exception(
        jsonDecode(response.body)['error'] ?? 'Gagal membaca spreadsheet',
      );
    } catch (e) {
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }

  /// Mengkonversi data spreadsheet ke format yang lebih mudah dibaca
  static List<Map<String, dynamic>> convertToMap(List<List<dynamic>> data) {
    if (data.isEmpty) return [];

    final headers = data[0]; // Ambil baris pertama sebagai header
    final rows = data.sublist(1); // Ambil sisa baris sebagai data

    return rows.map((row) {
      Map<String, dynamic> rowMap = {};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        rowMap[headers[i].toString()] = row[i];
      }
      return rowMap;
    }).toList();
  }

  /// Mendapatkan data historis dari beberapa hari sebelumnya
  /// [generatorName] nama generator untuk mencari file terkait
  /// [daysBack] jumlah hari ke belakang yang ingin diambil (default 7 hari)
  static Future<List<Map<String, dynamic>>> getHistoricalData(
    String generatorName, {
    int daysBack = 7,
  }) async {
    List<Map<String, dynamic>> allHistoricalData = [];
    final now = DateTime.now();

    try {
      // Loop untuk mengambil data dari beberapa hari ke belakang
      for (int i = 1; i <= daysBack; i++) {
        final targetDate = now.subtract(Duration(days: i));
        final String formattedDate = _formatDateForFileName(targetDate);

        // Coba cari file berdasarkan nama dan tanggal
        final expectedFileName = 'Logsheet $generatorName, $formattedDate';

        try {
          // Untuk sekarang, kita akan menggunakan metode yang ada
          // Di implementasi nyata, kita perlu mencari file berdasarkan nama
          // atau menggunakan API khusus untuk pencarian file
          print('Looking for historical file: $expectedFileName');

          // TODO: Implementasi file search by name or use dedicated historical data API
          // For now, return empty data
        } catch (e) {
          print('File not found for date: $formattedDate');
          continue;
        }
      }
    } catch (e) {
      print(' getting historical data: $e');
    }

    return allHistoricalData;
  }

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

  /// Mendapatkan data temperature untuk chart dari data logsheet
  static Map<String, List<double>> extractTemperatureData(
    List<Map<String, dynamic>> logsheetData,
  ) {
    Map<String, List<double>> temperatureData = {
      'waterTemp': [],
      'lubeOilTemp': [],
      'engineTempExhaust': [],
      'tempBearing': [],
      'tempWindingAvg': [],
    };

    for (var entry in logsheetData) {
      // Extract temperature values and add to respective lists
      final waterTemp =
          double.tryParse(entry['waterTemp']?.toString() ?? '0') ?? 0;
      final lubeOilTemp =
          double.tryParse(entry['lubeOilTemp']?.toString() ?? '0') ?? 0;
      final exhaustTemp =
          double.tryParse(entry['engineTempExhaust']?.toString() ?? '0') ?? 0;
      final bearingTemp =
          double.tryParse(entry['tempBearing']?.toString() ?? '0') ?? 0;

      // Calculate winding average
      final tempU =
          double.tryParse(entry['tempWindingU']?.toString() ?? '0') ?? 0;
      final tempV =
          double.tryParse(entry['tempWindingV']?.toString() ?? '0') ?? 0;
      final tempW =
          double.tryParse(entry['tempWindingW']?.toString() ?? '0') ?? 0;
      final windingAvg = (tempU + tempV + tempW) / 3;

      temperatureData['waterTemp']!.add(waterTemp);
      temperatureData['lubeOilTemp']!.add(lubeOilTemp);
      temperatureData['engineTempExhaust']!.add(exhaustTemp);
      temperatureData['tempBearing']!.add(bearingTemp);
      temperatureData['tempWindingAvg']!.add(windingAvg);
    }

    return temperatureData;
  }
}
