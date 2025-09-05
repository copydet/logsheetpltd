import 'package:flutter/material.dart';

class LogsheetSnackBar {
  static void showSuccess(
    BuildContext context, {
    required String fileName,
    String? webViewLink,
  }) {
    // Hapus loading SnackBar terlebih dahulu
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Logsheet baru berhasil dibuat!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Nama: $fileName', style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'TUTUP',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    // Hapus loading SnackBar terlebih dahulu
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gagal membuat logsheet',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(message, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  static void showLoading(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Membuat logsheet baru...'),
        backgroundColor: Color(0xFF1E3A8A),
      ),
    );
  }
}
