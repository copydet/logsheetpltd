import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1E40AF);

  static const Color success = Colors.green;
  static const Color warning = Colors.orange;
  static const Color error = Colors.red;

  static const Color background = Colors.white;
  static const Color surface = Color(0xFFF5F5F5);

  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.grey;

  // Generator status colors
  static const Color statusOnline = Colors.green;
  static const Color statusOffline = Colors.red;
  static const Color statusMaintenance = Colors.orange;
}

class AppSizes {
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  static const double iconSmall = 16.0;
  static const double iconMedium = 20.0;
  static const double iconLarge = 24.0;

  static const double buttonHeight = 50.0;
  static const double cardElevation = 8.0;
}

class AppStrings {
  static const String appName = 'Logsheet Generator';

  // Generator names
  static const List<String> generatorNames = [
    'Mitsubishi #1',
    'Mitsubishi #2',
    'Mitsubishi #3',
    'Mitsubishi #4',
  ];

  // Status messages
  static const String statusActive = 'AKTIF';
  static const String statusOffline = 'OFFLINE';
  static const String statusMaintenance = 'MAINTENANCE';

  // Form labels
  static const String jamOperasi = 'Jam Operasi';
  static const String rpm = 'RPM';
  static const String lubeOilTemp = 'Lube Oil Temperature';
  static const String oilPressure = 'Oil Pressure';
  static const String waterTemp = 'Water Temperature';
  static const String teganganAccu = 'Tegangan Accu';
  static const String beban = 'Beban (Load)';
  static const String voltageR = 'Voltage (R)';
  static const String voltageS = 'Voltage (S)';
  static const String voltageT = 'Voltage (T)';
  static const String ampereR = 'Ampere (R)';
  static const String ampereS = 'Ampere (S)';
  static const String ampereT = 'Ampere (T)';
  static const String kvar = 'Kvar';
  static const String hz = 'Hz';
  static const String cosPhi = 'CosPhi (PF)';
  static const String tempWindingU = 'Temp Winding (U)';
  static const String tempWindingV = 'Temp Winding (V)';
  static const String tempWindingW = 'Temp Winding (W)';
  static const String tempBearing = 'Temp Bearing';
  static const String enginePressureCrankcase = 'Engine (Pressure Crankcase)';
  static const String engineTempExhaust = 'Engine (Temp Exhaust)';

  // Navigation
  static const String dashboard = 'Dashboard';
  static const String history = 'Riwayat';
  static const String settings = 'Pengaturan';

  // Buttons
  static const String save = 'Simpan';
  static const String edit = 'Edit';
  static const String cancel = 'Batal';
  static const String update = 'Update';
  static const String createNew = 'Buat Baru';
}

class AppDurations {
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  static const Duration snackbarShort = Duration(seconds: 2);
  static const Duration snackbarMedium = Duration(seconds: 5);
  static const Duration snackbarLong = Duration(seconds: 10);
}

class AppConstraints {
  static const int lockTimeMinute =
      0; // Form terbuka hanya di awal jam (menit 0)
  static const int maxRetries = 3;
  static const int timeoutSeconds = 30;
}
