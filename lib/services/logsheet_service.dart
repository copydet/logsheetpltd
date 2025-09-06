import 'dart:convert';
import 'package:http/http.dart' as http;
import 'temperature_storage_service.dart';
import 'database_temperature_service.dart';
import 'database_service.dart';
import 'rest_api_service.dart';
import 'file_id_sync_service.dart';

class LogsheetService {
  static const String _baseUrl =
      'https://us-central1-powerplantlogsheet-8780a.cloudfunctions.net/api';

  /// Buats a new logsheet based on the template
  static Future<Map<String, dynamic>> createLogsheet(
    String generatorName,
  ) async {
    try {
      final timestamp = DateTime.now();

      // Format tanggal dengan nama bulan Indonesia
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

      final String formattedDate =
          '${timestamp.day.toString().padLeft(2, '0')} ${bulan[timestamp.month]} ${timestamp.year}';

      final String newFileName = 'Logsheet $generatorName, $formattedDate';

      final response = await http.post(
        Uri.parse('$_baseUrl/create-logsheet'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'templateFileId': _templateFileId,
          'targetFolderId': _targetFolderId,
          'newFileName': newFileName,
        }),
      );

      print('Create Logsheet Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final fileId = responseData['fileId'];

        print('Successfully created logsheet with fileId: $fileId');

        // 🔥 SYNC FILE ID TO FIRESTORE untuk konsistensi cross-device
        try {
          await FileIdSyncService.saveFileIdToFirestore(
            generatorName: generatorName,
            fileId: fileId,
            createdBy: 'create_logsheet', // atau bisa pakai user email
          );
          print(
            '✅ FILE_SYNC: FileId saved to Firestore for cross-device consistency',
          );
        } catch (e) {
          print('⚠️ FILE_SYNC: Failed to save fileId to Firestore: $e');
          // Don't fail the operation if Firestore save fails
        }

        // Auto-share with team members to prevent permission issues
        try {
          await autoShareWithTeam(fileId);
          print('✅ PERMISSIONS: Auto-shared logsheet with team members');
        } catch (e) {
          print(
            '⚠️ PERMISSIONS: Auto-share failed, but logsheet creation succeeded: $e',
          );
          // Don't fail the entire operation if sharing fails
        }

        return {
          'fileId': fileId,
          'fileName': responseData['fileName'],
          'webViewLink': responseData['webViewLink'],
        };
      }

      final errorData = jsonDecode(response.body);
      if (errorData['error']?.contains('invalid_grant') ?? false) {
        throw AuthenticationException(
          'Autentikasi gagal - Hubungi administrator',
        );
      }

      throw ApiException(errorData['error'] ?? 'Gagal membuat logsheet');
    } catch (e) {
      print(' in createLogsheet: ${e.toString()}');
      if (e is ApiException || e is AuthenticationException) {
        rethrow;
      }
      throw ApiException('Terjadi kesalahan: ${e.toString()}');
    }
  }

  /// Auto-share logsheet with known team members to prevent permission issues
  static Future<void> autoShareWithTeam(String fileId) async {
    final List<String> teamEmails = [
      'sony@pltd.com',
      'dimas@pltd.com',
      'admin@pltd.com',
      // Add more team member emails as needed
    ];

    print(
      '� AUTO_SHARE: Starting auto-share for fileId: $fileId with ${teamEmails.length} team members',
    );

    // First check if we can access the spreadsheet permissions
    try {
      await RestApiService.getSpreadsheetPermissions(fileId);
      print('📋 AUTO-SHARE: Current permissions retrieved successfully');
    } catch (e) {
      print('⚠️ AUTO-SHARE: Cannot retrieve current permissions: $e');
    }

    int successCount = 0;
    int failureCount = 0;

    for (final email in teamEmails) {
      try {
        await RestApiService.shareSpreadsheet(
          fileId,
          emailAddress: email,
          role: 'writer',
          sendNotificationEmail: false, // Don't spam with notifications
        );
        successCount++;
        print('✅ PERMISSIONS: Successfully shared spreadsheet with $email');

        // Small delay between sharing requests to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        failureCount++;
        print('⚠️ PERMISSIONS: Failed to share with $email: $e');
        // Continue with other emails even if one fails
      }
    }

    print(
      '📊 AUTO-SHARE: Completed - Success: $successCount, Failed: $failureCount',
    );

    if (successCount == 0) {
      throw Exception(
        'Failed to share with any team members. All ${teamEmails.length} attempts failed.',
      );
    } else if (failureCount > 0) {
      print(
        '⚠️ AUTO-SHARE: Partial success - ${successCount}/${teamEmails.length} shares succeeded',
      );
    } else {
      print('✅ AUTO-SHARE: All sharing attempts successful');
    }
  }

  /// Smart save with automatic permission handling
  static Future<void> saveLogsheetDataSmart(
    String fileId,
    Map<String, dynamic> logsheetData,
  ) async {
    try {
      // First attempt: normal save
      await saveLogsheetData(fileId, logsheetData);
      print('✅ SMART SAVE: Data berhasil disimpan ke Google Sheets');
    } catch (e) {
      String errorMessage = e.toString().toLowerCase();

      // Enhanced error detection for permission issues (case-insensitive)
      bool isPermissionError =
          errorMessage.contains('unable to update spreadsheet') ||
          errorMessage.contains('permission denied') ||
          errorMessage.contains('500') ||
          errorMessage.contains('403') ||
          errorMessage.contains('not authorized') ||
          errorMessage.contains('access denied') ||
          errorMessage.contains('insufficient permission');

      if (isPermissionError) {
        print(
          '🔍 PERMISSION_CHECK: Permission error detected in error message: $errorMessage',
        );
        print(
          '⚠️ SMART SAVE: Permission issue detected (${e.toString()}), attempting auto-share...',
        );

        try {
          // Try to auto-share with team members first
          await autoShareWithTeam(fileId);
          print(
            '✅ SMART SAVE: Auto-share completed, waiting for permissions to propagate...',
          );

          // Wait longer for Google permissions to propagate
          await Future.delayed(const Duration(seconds: 5));

          // Try multiple retries with increasing delays
          for (int retry = 0; retry < 3; retry++) {
            try {
              print(
                '🔄 RETRY_ATTEMPT: Attempting save after auto-share (attempt ${retry + 1}/3)',
              );
              await saveLogsheetData(fileId, logsheetData);
              print(
                '✅ SMART SAVE: Data berhasil disimpan setelah auto-share (attempt ${retry + 1})',
              );
              return; // Success, exit the method
            } catch (retryError) {
              print('⚠️ SMART SAVE: Retry ${retry + 1} failed: $retryError');
              if (retry < 2) {
                // Wait progressively longer for each retry
                print(
                  '⏰ RETRY_DELAY: Waiting ${(retry + 1) * 3} seconds before next attempt...',
                );
                await Future.delayed(Duration(seconds: (retry + 1) * 3));
              }
            }
          }

          // All retries failed
          print('❌ SMART SAVE: All retries failed after auto-share');
          throw Exception(
            'Failed to save after auto-sharing and multiple retries: ${e.toString()}',
          );
        } catch (shareError) {
          print('❌ SMART SAVE: Auto-share failed: $shareError');
          // Re-throw the original error with additional context
          throw Exception(
            'Permission issue detected and auto-share failed. Original error: ${e.toString()}',
          );
        }
      } else {
        // Non-permission error, just rethrow
        print('❌ SMART SAVE: Non-permission error: $e');
        rethrow;
      }
    }
  }

  /// Enhanced version with graceful degradation - saves to both Sheets and local DB
  static Future<Map<String, dynamic>> saveLogsheetDataWithFallback(
    String fileId,
    Map<String, dynamic> logsheetData,
  ) async {
    print(
      '🎯 ENHANCED_SAVE: saveLogsheetDataWithFallback called with fileId: $fileId',
    );
    print('🎯 ENHANCED_SAVE: logsheetData keys: ${logsheetData.keys.toList()}');

    bool googleSheetsSuccess = false;
    bool localStorageSuccess = false;
    String? googleSheetsError;
    bool permissionIssueDetected = false;

    // Pre-check: Try to verify access to the spreadsheet first
    try {
      await RestApiService.getSpreadsheetPermissions(fileId);
      print('✅ PRE-CHECK: Spreadsheet access verified');
    } catch (e) {
      print('⚠️ PRE-CHECK: Cannot access spreadsheet permissions: $e');
      // This might indicate a permission issue - trigger proactive sharing
      String errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('404') ||
          errorMsg.contains('not found') ||
          errorMsg.contains('permission')) {
        permissionIssueDetected = true;
        print(
          '🔄 PRE-CHECK: Permission issue detected, attempting proactive auto-share...',
        );

        try {
          await autoShareWithTeam(fileId);
          print('✅ PRE-CHECK: Proactive auto-share completed');
          // Wait for permissions to propagate
          await Future.delayed(const Duration(seconds: 3));
        } catch (shareError) {
          print('⚠️ PRE-CHECK: Proactive auto-share failed: $shareError');
        }
      }
    }

    try {
      // Try smart save (includes auto-share for permissions)
      await saveLogsheetDataSmart(fileId, logsheetData);
      googleSheetsSuccess = true;
      print('✅ SHEETS: Data berhasil disimpan ke Google Sheets (smart save)');
    } catch (e) {
      googleSheetsError = e.toString();
      print('❌ SHEETS: Gagal simpan ke Google Sheets: $e');

      // Enhanced error analysis
      String errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('permission') ||
          errorMessage.contains('500') ||
          errorMessage.contains('access denied') ||
          errorMessage.contains('unauthorized')) {
        permissionIssueDetected = true;
      }
    }

    try {
      // Always save to local storage/database as backup
      final databaseService = DatabaseService();
      final now = DateTime.now();

      // Convert the spreadsheet data format to database format
      final dbData = {
        ...logsheetData,
        'fileId': fileId,
        'savedDate': now.toIso8601String(),
        'timestamp': now.toIso8601String(),
      };

      await databaseService.saveLogsheetToHistory(
        fileId,
        logsheetData['generatorName'] ?? 'Unknown',
        dbData,
      );

      localStorageSuccess = true;
      print('✅ DATABASE: Data berhasil disimpan ke local database');
    } catch (e) {
      print('❌ DATABASE: Gagal simpan ke local database: $e');
    }

    // Return comprehensive status
    return {
      'googleSheetsSuccess': googleSheetsSuccess,
      'localStorageSuccess': localStorageSuccess,
      'googleSheetsError': googleSheetsError,
      'permissionIssueDetected': permissionIssueDetected,
      'success': localStorageSuccess, // Overall success if at least local works
    };
  }

  /// Menyimpan data ke spreadsheet
  static Future<void> saveLogsheetData(
    String fileId,
    Map<String, dynamic> logsheetData,
  ) async {
    try {
      print('🔧 SERVICE: saveLogsheetData called');
      print('🔧 SERVICE: fileId parameter = "$fileId"');
      print('🔧 SERVICE: fileId length = ${fileId.length}');
      print('🔧 SERVICE: fileId isEmpty = ${fileId.isEmpty}');

      if (fileId.isEmpty) {
        print('🔧 SERVICE : fileId is empty string!');
        throw ApiException('FileId tidak boleh kosong');
      }

      print('🔧 SERVICE: Saving data to fileId: $fileId');

      // Ambil current hour to determine row number
      final now = DateTime.now();
      final hour = now.hour;
      final minute = now.minute;

      print(
        '🔧 SERVICE: Current time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      );

      // Tentukan jam target berdasarkan waktu saat ini
      // DIUBAH: Simpan data sesuai jam input user, bukan jam +1
      // Logika lama: Jika sudah lewat menit 50, maka bisa mengisi untuk jam berikutnya
      int targetHour = hour; // Selalu gunakan jam yang diinput user

      // Untuk spreadsheet, tetap gunakan logika +1 jam jika minute >= 50
      int spreadsheetTargetHour = hour;
      if (minute >= 50) {
        spreadsheetTargetHour =
            (hour + 1) % 24; // Gunakan modulo untuk handle jam 23 -> 0
      }

      print('🔧 SERVICE: Current hour: $hour, minute: $minute');
      print(
        '🔧 SERVICE: Target hour untuk SQLite: $targetHour (fixed to user input))',
      );
      print(
        '🔧 SERVICE: Target hour untuk spreadsheet: $spreadsheetTargetHour (${minute >= 50 ? "next hour karena >= 50 menit" : "current hour"})',
      );

      // Calculate row number berdasarkan siklus logsheet 24 jam untuk spreadsheet:
      // Jam 10:00-23:00 hari ini = baris 13-26 (14 jam)
      // Jam 00:00-09:00 besok = baris 27-36 (10 jam)
      int rowNumber;
      if (spreadsheetTargetHour >= 10) {
        // Jam 10:00-23:00 hari ini
        rowNumber =
            13 +
            (spreadsheetTargetHour - 10); // 10:00=13, 11:00=14, ..., 23:00=26
      } else {
        // Jam 00:00-09:00 (besok pagi)
        rowNumber =
            27 + spreadsheetTargetHour; // 00:00=27, 01:00=28, ..., 09:00=36
      }

      print(
        '🔧 SERVICE: Using row: $rowNumber (untuk jam ${spreadsheetTargetHour.toString().padLeft(2, '0')}:00)',
      );

      final Map<String, dynamic> data = {
        'D$rowNumber': logsheetData['jamOperasi'], // HM Mesin
        'E$rowNumber': logsheetData['rpm'], // RPM
        'F$rowNumber': logsheetData['lubeOilTemp'], // L/O Temperature
        'G$rowNumber': logsheetData['oilPressure'], // Oil Pressure
        'H$rowNumber': logsheetData['waterTemp'], // Water Temperature
        'J$rowNumber': logsheetData['teganganAccu'], // Accu(V)
        'K$rowNumber': logsheetData['beban'], // Beban (KW)
        'L$rowNumber': logsheetData['voltageR'], // Voltage(R)
        'M$rowNumber': logsheetData['voltageS'], // Voltage(S)
        'N$rowNumber': logsheetData['voltageT'], // Voltage(T)
        'O$rowNumber': logsheetData['ampereR'], // Ampere(R)
        'P$rowNumber': logsheetData['ampereS'], // Ampere(S)
        'Q$rowNumber': logsheetData['ampereT'], // Ampere(T)
        'R$rowNumber': logsheetData['kvar'], // Kvar
        'T$rowNumber':
            logsheetData['hz'], // Frequensi(Hz) - FIXED: T13, bukan S13
        'U$rowNumber': logsheetData['cosPhi'], // CosPhi - FIXED: U13, bukan T13
        'X$rowNumber': logsheetData['tempWindingU'], // Temp Winding (U)
        'Y$rowNumber': logsheetData['tempWindingV'], // Temp Winding(V)
        'Z$rowNumber':
            logsheetData['tempWindingW'], // Temp Winding(W) - FIXED: Z13, bukan W13
        'AA$rowNumber': logsheetData['tempBearing'], // Temp Bearing
        'AB$rowNumber':
            logsheetData['enginePressureCrankcase'], // Press Crankcase
        'AC$rowNumber': logsheetData['engineTempExhaust'], // Temp Exhaust
      };

      print('Sending data: ${jsonEncode({'fileId': fileId, 'data': data})}');

      final response = await http.post(
        Uri.parse('$_baseUrl/update-logsheet'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'fileId': fileId, 'data': data}),
      );

      print('Update response status: ${response.statusCode}');
      print('Update response body: ${response.body}');

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['error'] ?? 'Gagal menyimpan data logsheet';

        // Check for specific permission errors
        if (response.statusCode == 500) {
          throw Exception(
            'Server error: Unable to update spreadsheet. This might be a permission issue if updating from a different device.',
          );
        } else if (response.statusCode == 403) {
          throw Exception('Permission denied to access logsheet: $fileId');
        } else {
          throw ApiException(errorMessage);
        }
      }

      // 🌡️ SAVE TEMPERATURE DATA TO SHARED PREFERENCES
      // Simpan data temperatur ke SharedPreferences untuk keperluan chart
      final temperatureData = {
        'waterTemp':
            double.tryParse(logsheetData['waterTemp']?.toString() ?? '0') ??
            0.0,
        'lubeOilTemp':
            double.tryParse(logsheetData['lubeOilTemp']?.toString() ?? '0') ??
            0.0,
        'tempBearing':
            double.tryParse(logsheetData['tempBearing']?.toString() ?? '0') ??
            0.0,
        'tempWindingU':
            double.tryParse(logsheetData['tempWindingU']?.toString() ?? '0') ??
            0.0,
        'tempWindingV':
            double.tryParse(logsheetData['tempWindingV']?.toString() ?? '0') ??
            0.0,
        'tempWindingW':
            double.tryParse(logsheetData['tempWindingW']?.toString() ?? '0') ??
            0.0,
        'engineTempExhaust':
            double.tryParse(
              logsheetData['engineTempExhaust']?.toString() ?? '0',
            ) ??
            0.0,
      };

      // Simpan ke SQLite database
      await DatabaseTemperatureService.saveTemperatureData(
        fileId: fileId,
        hour: targetHour,
        date: now.toIso8601String().substring(0, 10).replaceAll('-', ''),
        waterTemp: temperatureData['waterTemp']!,
        lubeOilTemp: temperatureData['lubeOilTemp']!,
        tempBearing: temperatureData['tempBearing']!,
        tempWindingU: temperatureData['tempWindingU']!,
        tempWindingV: temperatureData['tempWindingV']!,
        tempWindingW: temperatureData['tempWindingW']!,
        engineTempExhaust: temperatureData['engineTempExhaust']!,
      );

      // Juga simpan ke SharedPreferences untuk backward compatibility
      await TemperatureStorageService.saveTemperatureData(
        fileId: fileId,
        hour: targetHour,
        date: now,
        temperatureData: temperatureData,
      );

      print(
        '🌡️ SERVICE: Temperature data saved to SQLite and SharedPreferences for hour $targetHour',
      );

      // 💾 SAVE TO LOGSHEETS DATABASE FOR FIRESTORE SYNC
      // Tambahkan data ke database SQLite untuk sinkronisasi Firestore
      try {
        final dbService = DatabaseService();

        // Tambahkan metadata yang diperlukan untuk database
        final logsheetDataWithMeta = Map<String, dynamic>.from(logsheetData);
        logsheetDataWithMeta['tanggal'] = now.toIso8601String().substring(
          0,
          10,
        );
        logsheetDataWithMeta['jam'] = targetHour;
        logsheetDataWithMeta['savedDate'] = now.toIso8601String();

        // Ambil generator name from logsheetData
        final generatorName =
            logsheetDataWithMeta['generatorName']?.toString() ?? 'unknown';

        await dbService.saveLogsheetToHistory(
          fileId,
          generatorName,
          logsheetDataWithMeta,
        );
        print(
          '💾 SERVICE: Operational data saved to logsheets database for Firestore sync',
        );
      } catch (e) {
        print(
          '⚠️ SERVICE: Failed to save operational data to logsheets database: $e',
        );
        // Don't rethrow - this is for sync enhancement, not critical for main functionality
      }
    } catch (e) {
      print(' in saveLogsheetData: ${e.toString()}');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Terjadi kesalahan: ${e.toString()}');
    }
  }

  /// Membaca data dari spreadsheet
  static Future<Map<String, dynamic>> readLogsheetData(String fileId) async {
    try {
      print('Reading data from fileId: $fileId');

      final response = await http.post(
        Uri.parse('$_baseUrl/read-logsheet'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'fileId': fileId}),
      );

      print('Read response status: ${response.statusCode}');
      print('Read response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['data'] ?? {};
      }

      final errorData = jsonDecode(response.body);
      throw ApiException(errorData['error'] ?? 'Gagal membaca data logsheet');
    } catch (e) {
      print(' in readLogsheetData: ${e.toString()}');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Terjadi kesalahan: ${e.toString()}');
    }
  }

  /// Ceks if data exists for a specific hour
  static Future<bool> checkHourHasData(String fileId, int hour) async {
    try {
      print('🔍 SERVICE: checkHourHasData called for hour $hour');

      // Calculate row number using same logic as saveLogsheetData
      int rowNumber;
      if (hour >= 10) {
        // Jam 10:00-23:00 hari ini
        rowNumber = 13 + (hour - 10); // 10:00=13, 11:00=14, ..., 23:00=26
      } else {
        // Jam 00:00-09:00 (besok pagi)
        rowNumber = 27 + hour; // 00:00=27, 01:00=28, ..., 09:00=36
      }

      print('🔍 SERVICE:  row $rowNumber for hour $hour');

      // Request specific cells for this hour
      final cells = [
        'D$rowNumber',
        'E$rowNumber',
      ]; // HM Mesin & RPM as key indicators

      final response = await http.post(
        Uri.parse('$_baseUrl/read-specific-cells'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'fileId': fileId, 'cells': cells}),
      );

      print('🔍 SERVICE: Response status: ${response.statusCode}');
      print('🔍 SERVICE: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final cellData = responseData['data'] ?? {};

        // Cek if key cells have data (not null/empty)
        final jamOperasi = cellData['D$rowNumber'];
        final rpm = cellData['E$rowNumber'];

        print('🔍 SERVICE: Cell D$rowNumber (HM Mesin): "$jamOperasi"');
        print('🔍 SERVICE: Cell E$rowNumber (RPM): "$rpm"');

        final hasData =
            jamOperasi != null &&
            jamOperasi.toString().trim().isNotEmpty &&
            jamOperasi.toString() != 'null';

        print('🔍 SERVICE: Hour $hour has data: $hasData');
        return hasData;
      }

      return false;
    } catch (e) {
      print('🔍 SERVICE: Error  hour data: $e');
      return false;
    }
  }

  /// Validasis if a file exists in Google Drive
  static Future<bool> validateFileExists(String fileId) async {
    try {
      print('🔍 VALIDATE:  if file exists: $fileId');

      final response = await http.get(
        Uri.parse('$_baseUrl/validate-file/$fileId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('🔍 VALIDATE: Response status: ${response.statusCode}');
      print('🔍 VALIDATE: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final exists = data['exists'] ?? false;
        print('🔍 VALIDATE: File exists: $exists');
        return exists;
      } else if (response.statusCode == 404) {
        print('🔍 VALIDATE: File not found (404)');
        return false;
      } else {
        print('🔍 VALIDATE:  validating file: ${response.statusCode}');
        // Assume file exists if we can't validate (network issues, etc.)
        return true;
      }
    } catch (e) {
      print('🔍 VALIDATE: Exception validating file: $e');
      // Assume file exists if we can't validate
      return true;
    }
  }

  /// Hapuss a logsheet from Google Drive
  static Future<Map<String, dynamic>> deleteLogsheet(
    String fileId, {
    bool permanent = false,
  }) async {
    try {
      print('🗑️ DELETING LOGSHEET: $fileId (permanent: $permanent)');

      final response = await http.delete(
        Uri.parse(
          '$_baseUrl/api/logsheets/$fileId?permanent=${permanent.toString()}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('🗑️ DELETE RESPONSE STATUS: ${response.statusCode}');
      print('🗑️ DELETE RESPONSE BODY: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ LOGSHEET DELETED FULLY');
        return responseData;
      } else if (response.statusCode == 404) {
        print('❌ LOGSHEET NOT FOUND');
        throw ApiException('Logsheet tidak ditemukan');
      } else {
        print('❌ DELETE : ${response.statusCode}');
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['message'] ?? 'Gagal menghapus logsheet');
      }
    } catch (e) {
      print('❌ DELETE : $e');
      if (e is ApiException) rethrow;
      throw ApiException('Gagal menghapus logsheet: $e');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);

  @override
  String toString() => message;
}
