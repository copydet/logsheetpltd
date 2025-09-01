// import '../constants/app_constants.dart'; // Tidak digunakan lagi

class DateTimeUtils {
  static String getCurrentDateTime() {
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

    return '$dayName, $day $month $year pukul $hour:$minute';
  }

  static String formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    return '$day/$month/$year';
  }

  static bool canCreateNewEntry() {
    // Bisa buat entry baru kapan saja (tidak ada batasan menit)
    return true;
  }

  static bool isDataLocked() {
    // Data tidak pernah terkunci karena batasan waktu
    // Hanya terkunci jika sudah ada data untuk jam tersebut
    return false;
  }

  static int getCurrentHourSlot() {
    return DateTime.now().hour;
  }

  static int getNextHourSlot() {
    return (DateTime.now().hour + 1) % 24;
  }
}
