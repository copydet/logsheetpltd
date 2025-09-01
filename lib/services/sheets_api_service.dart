import 'dart:convert';
import 'package:http/http.dart' as http;

/// 📊 Service untuk Google Sheets API Integration
/// Mengakses data cell-by-cell dari logsheet spreadsheets
/// Menggunakan struktur cell yang benar: D13-AC36 untuk data 24 jam
class SheetsApiService {
  static const String _baseUrl =
      'https://us-central1-powerplantlogsheet-8780a.cloudfunctions.net/api';

  // Headers default
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ===========================
  // 📋 REAL-TIME DATA ENDPOINTS
  // ===========================

  /// [GET] /api/logsheet/{fileId}/hourly-data/{hour} => Data per jam spesifik (0-23)
  static Future<Map<String, dynamic>> getHourlyData(
    String fileId,
    int hour,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/logsheet/$fileId/hourly-data/$hour');
      print('📊 GET /api/logsheet/$fileId/hourly-data/$hour');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Retrieved hourly data for hour $hour');
        return data;
      } else {
        throw Exception('Failed to get hourly data: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting hourly data: $e');
      rethrow;
    }
  }

  /// [GET] /api/logsheet/{fileId}/operational-status => Status operasional real-time
  static Future<Map<String, dynamic>> getOperationalStatus(
    String fileId,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/logsheet/$fileId/operational-status');
      print('🔧 GET /api/logsheet/$fileId/operational-status');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Retrieved operational status');
        return data;
      } else {
        throw Exception(
          'Failed to get operational status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error getting operational status: $e');
      rethrow;
    }
  }

  // ===========================
  // 🔧 UTILITY METHODS
  // ===========================

  /// Parse hourly data untuk display yang user-friendly
  static Map<String, String> parseHourlyData(Map<String, dynamic> response) {
    final hourlyData = response['data']['hourlyData'] as Map<String, dynamic>;

    return {
      'Jam Operasi': hourlyData['jamOperasi']?.toString() ?? 'N/A',
      'RPM': hourlyData['rpm']?.toString() ?? 'N/A',
      'Lube Oil Temp': hourlyData['lubeOilTemp']?.toString() ?? 'N/A',
      'Oil Pressure': hourlyData['oilPressure']?.toString() ?? 'N/A',
      'Water Temp': hourlyData['waterTemp']?.toString() ?? 'N/A',
      'Tegangan Accu': hourlyData['teganganAccu']?.toString() ?? 'N/A',
      'Beban (Load)': hourlyData['beban']?.toString() ?? 'N/A',
      'Voltage R': hourlyData['voltageR']?.toString() ?? 'N/A',
      'Voltage S': hourlyData['voltageS']?.toString() ?? 'N/A',
      'Voltage T': hourlyData['voltageT']?.toString() ?? 'N/A',
      'Ampere R': hourlyData['ampereR']?.toString() ?? 'N/A',
      'Ampere S': hourlyData['ampereS']?.toString() ?? 'N/A',
      'Ampere T': hourlyData['ampereT']?.toString() ?? 'N/A',
      'Kvar': hourlyData['kvar']?.toString() ?? 'N/A',
      'Frequency (Hz)': hourlyData['frequency']?.toString() ?? 'N/A',
      'CosPhi': hourlyData['cosPhi']?.toString() ?? 'N/A',
      'Temp Winding U': hourlyData['tempWindingU']?.toString() ?? 'N/A',
      'Temp Winding V': hourlyData['tempWindingV']?.toString() ?? 'N/A',
      'Temp Winding W': hourlyData['tempWindingW']?.toString() ?? 'N/A',
      'Temp Bearing': hourlyData['tempBearing']?.toString() ?? 'N/A',
      'Engine Pressure': hourlyData['enginePressure']?.toString() ?? 'N/A',
      'Engine Temp Exhaust':
          hourlyData['engineTempExhaust']?.toString() ?? 'N/A',
    };
  }

  /// Parse operational status untuk monitoring
  static Map<String, dynamic> parseOperationalStatus(
    Map<String, dynamic> response,
  ) {
    final data = response['data'];
    final operationalData = data['operationalData'] as Map<String, dynamic>;
    final status = data['status'] as Map<String, dynamic>;

    return {
      'currentHour': data['currentHour'],
      'isRunning': status['isRunning'] ?? false,
      'isNormal': status['isNormal'] ?? false,
      'performance': status['performance'] ?? 'Unknown',
      'alerts': status['alerts'] ?? [],
      'operationalData': {
        'RPM': operationalData['rpm']?.toString() ?? 'N/A',
        'Load': operationalData['beban']?.toString() ?? 'N/A',
        'Voltage R': operationalData['voltageR']?.toString() ?? 'N/A',
        'Voltage S': operationalData['voltageS']?.toString() ?? 'N/A',
        'Voltage T': operationalData['voltageT']?.toString() ?? 'N/A',
        'Frequency': operationalData['frequency']?.toString() ?? 'N/A',
        'Oil Temp': operationalData['lubeOilTemp']?.toString() ?? 'N/A',
        'Water Temp': operationalData['waterTemp']?.toString() ?? 'N/A',
      },
    };
  }

  // ===========================
  // 📊 BATCH DATA OPERATIONS
  // ===========================

  /// Get data untuk multiple hours sekaligus
  static Future<List<Map<String, dynamic>>> getMultipleHours(
    String fileId,
    List<int> hours,
  ) async {
    try {
      final List<Map<String, dynamic>> results = [];

      for (final hour in hours) {
        try {
          final hourlyData = await getHourlyData(fileId, hour);
          results.add(hourlyData);
        } catch (e) {
          print('⚠️ Failed to get data for hour $hour: $e');
          // Continue dengan hour berikutnya
        }
      }

      return results;
    } catch (e) {
      print('❌ Error getting multiple hours data: $e');
      rethrow;
    }
  }

  /// Get data untuk shift tertentu (pagi, siang, malam)
  static Future<List<Map<String, dynamic>>> getShiftData(
    String fileId,
    String shift,
  ) async {
    List<int> hours = [];

    switch (shift.toLowerCase()) {
      case 'pagi':
        hours = [6, 7, 8, 9, 10, 11, 12, 13]; // 06:00-13:00
        break;
      case 'siang':
        hours = [14, 15, 16, 17, 18, 19, 20, 21]; // 14:00-21:00
        break;
      case 'malam':
        hours = [22, 23, 0, 1, 2, 3, 4, 5]; // 22:00-05:00
        break;
      default:
        throw Exception('Invalid shift. Use: pagi, siang, malam');
    }

    return getMultipleHours(fileId, hours);
  }

  // ===========================
  // 🎯 HELPER METHODS
  // ===========================

  /// Check apakah generator sedang running berdasarkan RPM
  static bool isGeneratorRunning(Map<String, dynamic> hourlyData) {
    try {
      final rpm = double.tryParse(hourlyData['rpm']?.toString() ?? '0') ?? 0;
      return rpm > 100; // Threshold minimum untuk running
    } catch (e) {
      return false;
    }
  }

  /// Check apakah parameter operasional dalam range normal
  static bool isOperationalNormal(Map<String, dynamic> operationalData) {
    try {
      final rpm =
          double.tryParse(operationalData['rpm']?.toString() ?? '0') ?? 0;
      final frequency =
          double.tryParse(operationalData['frequency']?.toString() ?? '0') ?? 0;
      final oilTemp =
          double.tryParse(operationalData['lubeOilTemp']?.toString() ?? '0') ??
          0;

      // Basic thresholds untuk power plant generator
      return rpm >= 1400 &&
          rpm <= 1600 &&
          frequency >= 49 &&
          frequency <= 51 &&
          oilTemp <= 100;
    } catch (e) {
      return false;
    }
  }

  /// Get performance level berdasarkan load
  static String getPerformanceLevel(Map<String, dynamic> hourlyData) {
    try {
      final load = double.tryParse(hourlyData['beban']?.toString() ?? '0') ?? 0;

      if (load > 80) return 'High Load';
      if (load > 50) return 'Normal Load';
      if (load > 0) return 'Light Load';
      return 'Idle';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Convert jam ke row number sesuai logsheet structure
  static int hourToRow(int hour) {
    if (hour >= 10 && hour <= 23) {
      return 13 + (hour - 10); // Row 13-26 untuk jam 10-23
    } else {
      return 27 + hour; // Row 27-36 untuk jam 0-9
    }
  }

  /// Convert row number ke jam
  static int rowToHour(int row) {
    if (row >= 13 && row <= 26) {
      return 10 + (row - 13); // Jam 10-23
    } else if (row >= 27 && row <= 36) {
      return row - 27; // Jam 0-9
    } else {
      throw Exception('Invalid row number. Must be 13-26 or 27-36');
    }
  }
}
