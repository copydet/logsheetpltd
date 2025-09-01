import 'package:flutter/material.dart';
import '../app_exports.dart';

class AppRoutes {
  static const String main = '/main';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String detailMesin = '/detail_mesin';
  static const String riwayat = '/riwayat';
  static const String pengaturan = '/pengaturan';

  static Map<String, WidgetBuilder> routes = {
    main: (context) => const MainNavigationScreen(),
    login: (context) => const LoginScreen(),
    dashboard: (context) => const DashboardScreen(),
    riwayat: (context) => const RiwayatLogsheetScreen(),
    pengaturan: (context) => const PengaturanScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case detailMesin:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => DetailMesinScreen(
            mesinName: args['name'] ?? 'Generator',
            fileId: args['fileId'] ?? '',
            isActive: args['isActive'] ?? false,
          ),
        );
      default:
        return null;
    }
  }
}
