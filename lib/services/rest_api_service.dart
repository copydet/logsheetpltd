import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service untuk mengakses REST API endpoints Firebase Functions
/// Menggunakan HTTP methods yang sesuai: GET, POST, PUT, PATCH, DELETE
/// Updated untuk menggunakan endpoints /api/... yang baru
class RestApiService {
  static const String _baseUrl =
      'https://us-central1-powerplantlogsheet-8780a.cloudfunctions.net/api';

  // Headers default untuk semua request
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ===========================
  // 🏭 GENERATOR ENDPOINTS (REST API)
  // ===========================

  /// [GET] /api/generators => Mendapatkan daftar semua generator dengan pagination
  static Future<Map<String, dynamic>> getGenerators({
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/generators').replace(
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      );

      print('🔍 GET /api/generators (page: $page, limit: $limit)');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Tangani format lama dan format baru
        if (data['data'] != null) {
          // Format baru dengan paginasi
          print('✅ Retrieved ${data['data'].length} generators (new format)');
        } else if (data['generators'] != null) {
          // Format lama - konversi ke format baru untuk konsistensi
          data['data'] = data['generators'];
          print(
            '✅ Retrieved ${data['generators'].length} generators (legacy format, converted)',
          );
        } else {
          print('✅ Retrieved generators with unknown format');
        }

        return data;
      } else {
        throw Exception('Failed to get generators: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting generators: $e');
      rethrow;
    }
  }

  /// [GET] /api/generators/:generatorName => Mendapatkan detail generator dengan filter
  static Future<Map<String, dynamic>> getGeneratorDetails(
    String generatorName, {
    int limit = 10,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final queryParams = <String, String>{'limit': limit.toString()};
      if (dateFrom != null) queryParams['dateFrom'] = dateFrom;
      if (dateTo != null) queryParams['dateTo'] = dateTo;

      final uri = Uri.parse(
        '$_baseUrl/generators/$generatorName',
      ).replace(queryParameters: queryParams);

      print('🔍 GET /api/generators/$generatorName (limit: $limit)');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(
          '✅ Retrieved ${data['totalFiles'] ?? data['files']?.length ?? 0} files for $generatorName',
        );
        return data;
      } else if (response.statusCode == 404) {
        print('❌ Generator not found: $generatorName');
        return {'success': false, 'message': 'Generator not found'};
      } else {
        throw Exception(
          'Failed to get generator details: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error getting generator details: $e');
      rethrow;
    }
  }

  // ===========================
  // 📝 LOGSHEET ENDPOINTS (REST API)
  // ===========================

  /// [POST] /api/logsheets => Membuat logsheet baru
  static Future<Map<String, dynamic>> createLogsheet({
    required String templateFileId,
    required String targetFolderId,
    required String generatorName,
    String? date,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/logsheets');

      final body = {
        'templateFileId': templateFileId,
        'targetFolderId': targetFolderId,
        'generatorName': generatorName,
        if (date != null) 'date': date,
      };

      print('📝 POST /api/logsheets - Creating logsheet for $generatorName');

      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ Created logsheet: ${data['data']['name']}');
        return data;
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception('Validation error: ${error['message']}');
      } else {
        throw Exception('Failed to create logsheet: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error creating logsheet: $e');
      rethrow;
    }
  }

  /// [GET] /api/logsheets/:fileId => Mendapatkan data logsheet tertentu
  static Future<Map<String, dynamic>> getLogsheet(
    String fileId, {
    String range = 'Sheet1!D13:AC36',
    bool includeMetadata = true,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/logsheets/$fileId').replace(
        queryParameters: {
          'range': range,
          'includeMetadata': includeMetadata.toString(),
        },
      );

      print('📖 GET /api/logsheets/$fileId');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Retrieved logsheet with ${data['data']['rowCount']} rows');
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Logsheet not found: $fileId');
      } else if (response.statusCode == 403) {
        throw Exception('Permission denied to access logsheet: $fileId');
      } else {
        throw Exception('Failed to get logsheet: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting logsheet: $e');
      rethrow;
    }
  }

  /// [PUT] /api/logsheets/:fileId => Update seluruh data logsheet (replace all)
  static Future<Map<String, dynamic>> replaceLogsheetData(
    String fileId, {
    required List<List<dynamic>> values,
    String range = 'Sheet1!D13:AC36',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/logsheets/$fileId');

      final body = {'range': range, 'values': values};

      print('✏️ PUT /api/logsheets/$fileId - Replacing all data');

      final response = await http.put(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Replaced ${data['data']['updatedCells']} cells');
        return data;
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception('Invalid data format: ${error['message']}');
      } else {
        throw Exception(
          'Failed to replace logsheet data: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error replacing logsheet data: $e');
      rethrow;
    }
  }

  /// [PATCH] /api/logsheets/:fileId => Update sebagian data logsheet (partial update)
  static Future<Map<String, dynamic>> updateLogsheetData(
    String fileId, {
    required Map<String, dynamic> updates,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/logsheets/$fileId');

      final body = {'updates': updates};

      print(
        '🔧 PATCH /api/logsheets/$fileId - Updating ${updates.length} cells',
      );

      final response = await http.patch(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 UPDATE RESPONSE: $data');

        // Cek struktur data sebelum mengakses
        if (data != null &&
            data['data'] != null &&
            data['data']['updatedCells'] != null) {
          print('✅ Updated ${data['data']['updatedCells']} cells');
        } else {
          print('✅ Update successful (cells count not available)');
        }
        return data;
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception('Invalid updates format: ${error['message']}');
      } else {
        throw Exception(
          'Failed to update logsheet data: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error updating logsheet data: $e');
      rethrow;
    }
  }

  /// [DELETE] /api/logsheets/:fileId => Hapus logsheet (move to trash atau permanent)
  static Future<Map<String, dynamic>> deleteLogsheet(
    String fileId, {
    bool permanent = false,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/logsheets/$fileId',
      ).replace(queryParameters: {'permanent': permanent.toString()});

      print('🗑️ DELETE /api/logsheets/$fileId (permanent: $permanent)');

      final response = await http.delete(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ ${data['message']}');
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Logsheet not found: $fileId');
      } else {
        throw Exception('Failed to delete logsheet: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error deleting logsheet: $e');
      rethrow;
    }
  }

  /// [POST] /api/logsheets/:fileId/restore => Restore logsheet dari trash
  static Future<Map<String, dynamic>> restoreLogsheet(String fileId) async {
    try {
      final uri = Uri.parse('$_baseUrl/logsheets/$fileId/restore');

      print('🔄 POST /api/logsheets/$fileId/restore');

      final response = await http.post(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ ${data['message']}');
        return data;
      } else {
        throw Exception('Failed to restore logsheet: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error restoring logsheet: $e');
      rethrow;
    }
  }

  // ===========================
  // 📊 ANALYTICS ENDPOINTS (REST API)
  // ===========================

  /// [GET] /api/analytics/summary => Analisis data logsheet untuk dashboard
  static Future<Map<String, dynamic>> getAnalyticsSummary({
    int days = 30,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/analytics/summary',
      ).replace(queryParameters: {'days': days.toString()});

      print('📊 GET /api/analytics/summary (last $days days)');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Tangani format lama (analytics) dan format baru (data)
        Map<String, dynamic> analyticsData;

        if (data['data'] != null) {
          // Format baru
          analyticsData = data['data'];
          print('✅ Retrieved analytics (new format)');
        } else if (data['analytics'] != null) {
          // Format lama - konversi ke format baru
          analyticsData = data['analytics'];
          data['data'] = analyticsData; // Tambah field data untuk konsistensi
          print('✅ Retrieved analytics (legacy format, converted)');
        } else {
          // Fallback untuk format tidak dikenal
          analyticsData = {};
          data['data'] = analyticsData;
          print('✅ Retrieved analytics (unknown format, using fallback)');
        }

        final totalLogsheets = analyticsData['totalLogsheets'] ?? 0;
        print('   Total logsheets: $totalLogsheets');

        return data;
      } else {
        throw Exception('Failed to get analytics: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting analytics: $e');
      rethrow;
    }
  }

  // ===========================
  // 🔧 SYSTEM ENDPOINTS (REST API)
  // ===========================

  /// [GET] /api/health => Health check endpoint
  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      final uri = Uri.parse('$_baseUrl/health');

      print('🔧 GET /api/health');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Tangani format terbungkus {success, data} dan format langsung
        Map<String, dynamic> result;

        if (data['success'] != null) {
          // Format terbungkus baru
          result = data;
          final healthData = data['data'];
          final status = healthData != null
              ? healthData['status'] ?? 'unknown'
              : 'unknown';
          print('✅ API Status: $status (wrapped format)');
        } else if (data['status'] != null) {
          // Format langsung - bungkus untuk konsistensi
          result = {'success': true, 'data': data};
          print('✅ API Status: ${data['status']} (direct format, wrapped)');
        } else {
          // Format tidak dikenal
          result = {'success': false, 'data': null};
          print('❌ API Status: unknown format');
        }

        return result;
      } else {
        throw Exception('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in health check: $e');
      rethrow;
    }
  }

  // ===========================
  // 🔍 LEGACY COMPATIBILITY
  // ===========================

  /// [GET] /search-files => Kompatibilitas dengan service lama
  static Future<Map<String, dynamic>> searchFiles(
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

      print('🔍 GET /search-files - Searching for $generatorName');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Found ${data['totalFound']} files');
        return data;
      } else {
        throw Exception('Failed to search files: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error searching files: $e');
      rethrow;
    }
  }

  /// [GET] /list-files => Kompatibilitas dengan service lama
  static Future<Map<String, dynamic>> listFiles() async {
    try {
      final uri = Uri.parse('$_baseUrl/list-files');

      print('📋 GET /list-files');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Listed ${data['totalFiles']} files');
        return data;
      } else {
        throw Exception('Failed to list files: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error listing files: $e');
      rethrow;
    }
  }

  /// [GET] /find-file => Kompatibilitas dengan service lama
  static Future<Map<String, dynamic>> findFile({
    String? fileName,
    String? generatorName,
    String? date,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (fileName != null) queryParams['fileName'] = fileName;
      if (generatorName != null) queryParams['generatorName'] = generatorName;
      if (date != null) queryParams['date'] = date;

      final uri = Uri.parse(
        '$_baseUrl/find-file',
      ).replace(queryParameters: queryParams);

      print('🎯 GET /find-file');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Found file: ${data['fileName']}');
        return data;
      } else if (response.statusCode == 404) {
        print('❌ File not found');
        return {'success': false, 'message': 'File not found'};
      } else {
        throw Exception('Failed to find file: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error finding file: $e');
      rethrow;
    }
  }

  /// [GET] /file-info/:fileId => Kompatibilitas dengan service lama
  static Future<Map<String, dynamic>> getFileInfo(String fileId) async {
    try {
      final uri = Uri.parse('$_baseUrl/file-info/$fileId');

      print('ℹ️ GET /file-info/$fileId');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Retrieved file info: ${data['file']['name']}');
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('File not found: $fileId');
      } else {
        throw Exception('Failed to get file info: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting file info: $e');
      rethrow;
    }
  }

  /// [GET] /folder-stats => Kompatibilitas dengan service lama
  static Future<Map<String, dynamic>> getFolderStats() async {
    try {
      final uri = Uri.parse('$_baseUrl/folder-stats');

      print('📊 GET /folder-stats');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Retrieved folder stats: ${data['stats']['totalFiles']} files');
        return data;
      } else {
        throw Exception('Failed to get folder stats: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting folder stats: $e');
      rethrow;
    }
  }

  // ===========================
  // 🛠️ UTILITY METHODS
  // ===========================

  /// Helper untuk format error response
  static String getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }

  /// Helper untuk check network connectivity
  static Future<bool> isApiAvailable() async {
    try {
      final result = await healthCheck();
      return result['status'] == 'healthy';
    } catch (e) {
      print('⚠️ API not available: $e');
      return false;
    }
  }

  /// Helper untuk format tanggal ke format yang diharapkan API
  static String formatDateForApi(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
}
