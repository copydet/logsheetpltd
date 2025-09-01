import 'package:flutter/material.dart';

class DetailHeaderWidget extends StatelessWidget {
  final String mesinName;
  final bool isActive;
  final VoidCallback onBackPressed;
  final bool isFirestoreConnected; // NEW: Status koneksi Firestore

  const DetailHeaderWidget({
    Key? key,
    required this.mesinName,
    required this.isActive,
    required this.onBackPressed,
    this.isFirestoreConnected = false, // Default tidak terhubung
  }) : super(key: key);

  String _getCurrentDateTime() {
    final now = DateTime.now();
    final days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    final months = [
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

    final dayName = days[now.weekday % 7];
    final day = now.day;
    final month = months[now.month];
    final year = now.year;
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    return '$dayName, $day $month $year - $hour:$minute WIB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E3A8A),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onBackPressed,
              ),
              const Text(
                'Detail Mesin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Ikon awan untuk status Firestore dengan tooltip dan klik
              Builder(
                builder: (BuildContext context) {
                  return GestureDetector(
                    onTap: () {
                      // Tampilkan SnackBar dengan keterangan status
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isFirestoreConnected
                                ? 'Real time data firestore - Terhubung'
                                : 'Real time data firestore - Tidak terhubung',
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: isFirestoreConnected
                              ? Colors.green
                              : Colors.grey,
                        ),
                      );
                    },
                    child: Tooltip(
                      message: isFirestoreConnected
                          ? 'Real time data firestore - Terhubung'
                          : 'Real time data firestore - Tidak terhubung',
                      child: Icon(
                        Icons.cloud,
                        color: isFirestoreConnected
                            ? Colors.green
                            : Colors.grey,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mesinName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _getCurrentDateTime(),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  isActive ? 'ON' : 'OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
