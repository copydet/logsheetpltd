import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

/// Service untuk mendownload file spreadsheet dari Google Drive
class SpreadsheetDownloadService {
  /// Mendownload file spreadsheet dari Google Drive berdasarkan fileId
  /// Mendukung format Excel (.xlsx) dan PDF
  static Future<void> downloadSpreadsheet(
    String fileId, {
    String format = 'xlsx', // xlsx, pdf
    String? fileName,
  }) async {
    try {
      String url;

      // Pilih URL berdasarkan format yang diinginkan
      switch (format.toLowerCase()) {
        case 'xlsx':
          url =
              'https://docs.google.com/spreadsheets/d/$fileId/export?format=xlsx';
          break;
        case 'pdf':
          url =
              'https://docs.google.com/spreadsheets/d/$fileId/export?format=pdf';
          break;
        default:
          url =
              'https://docs.google.com/spreadsheets/d/$fileId/export?format=xlsx';
      }

      print('📥 DOWNLOAD: Attempting to download from: $url');

      final uri = Uri.parse(url);

      // Coba berbagai metode launch
      bool launched = false;

      // Method 1: Try external application mode
      try {
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          print('✅ DOWNLOAD: External app launch successful');
        }
      } catch (e) {
        print('⚠️ DOWNLOAD: External app launch failed: $e');
      }

      // Method 2: Try platform default mode if external failed
      if (!launched) {
        try {
          if (await canLaunchUrl(uri)) {
            launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
            print('✅ DOWNLOAD: Platform default launch successful');
          }
        } catch (e) {
          print('⚠️ DOWNLOAD: Platform default launch failed: $e');
        }
      }

      // Method 3: Try in-app web view mode as last resort
      if (!launched) {
        try {
          if (await canLaunchUrl(uri)) {
            launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
            print('✅ DOWNLOAD: In-app web view launch successful');
          }
        } catch (e) {
          print('⚠️ DOWNLOAD: In-app web view launch failed: $e');
        }
      }

      if (!launched) {
        throw Exception(
          'Tidak dapat membuka URL download dengan metode apapun',
        );
      }
    } catch (e) {
      print('❌ DOWNLOAD: Error downloading spreadsheet: $e');
      rethrow;
    }
  }

  /// Mendownload dengan menampilkan dialog pilihan format (Excel dan PDF)
  static Future<void> downloadWithFormatChoice(
    BuildContext context,
    String fileId,
    String generatorName,
    String date,
  ) async {
    // Check if this is Firestore data
    if (fileId.startsWith('firestore_')) {
      await _showFirestoreNotSupportedDialog(context);
      return;
    }

    final format = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Format Download'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Download logsheet $generatorName\n$date'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: const Text('Excel (.xlsx)'),
                subtitle: const Text('Format untuk editing data'),
                onTap: () => Navigator.of(context).pop('xlsx'),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('PDF'),
                subtitle: const Text('Format untuk cetak atau share'),
                onTap: () => Navigator.of(context).pop('pdf'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );

    if (format != null) {
      final fileName = 'Logsheet_${generatorName}_$date';

      try {
        await downloadSpreadsheet(fileId, format: format, fileName: fileName);
      } catch (e) {
        // Jika download gagal, tampilkan dialog dengan URL manual
        await _showManualDownloadDialog(context, fileId, format, fileName);
      }
    }
  }

  /// Show manual download dialog when automatic download fails
  static Future<void> _showManualDownloadDialog(
    BuildContext context,
    String fileId,
    String format,
    String fileName,
  ) async {
    final url = format.toLowerCase() == 'xlsx'
        ? 'https://docs.google.com/spreadsheets/d/$fileId/export?format=xlsx'
        : 'https://docs.google.com/spreadsheets/d/$fileId/export?format=pdf';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.download_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('Download Manual'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Download otomatis tidak berhasil di emulator.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              const Text(
                'Silakan copy URL berikut dan buka di browser:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'File: $fileName.$format',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      url,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '💡 Tips: Tekan dan tahan pada URL untuk copy',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Try to launch URL again
                try {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.platformDefault);
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  // If still fails, just close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Silakan copy URL dan buka manual di browser',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text('Coba Lagi'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog for Firestore data (not supported for direct download)
  static Future<void> _showFirestoreNotSupportedDialog(
    BuildContext context,
  ) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 8),
              Text('Info Download'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data ini berasal dari Firestore dan belum support untuk download langsung.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                'Fitur download untuk data Firestore sedang dalam pengembangan.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              SizedBox(height: 12),
              Text(
                'Untuk sementara, Anda dapat melihat data di halaman detail.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Quick download as Excel (default)
  static Future<void> downloadAsExcel(String fileId) async {
    await downloadSpreadsheet(fileId, format: 'xlsx');
  }

  /// Quick download as PDF
  static Future<void> downloadAsPDF(String fileId) async {
    await downloadSpreadsheet(fileId, format: 'pdf');
  }
}
