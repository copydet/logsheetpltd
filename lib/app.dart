import 'package:flutter/material.dart';
import 'config/app_routes.dart';
import 'config/app_theme.dart';

/// Main application widget dengan konfigurasi routing lengkap
class PowerPlantLogsheetApp extends StatelessWidget {
  const PowerPlantLogsheetApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Power Plant Logsheet',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.main,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      onUnknownRoute: (settings) {
        print('❌ ROUTING: Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Error'),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Route not found: ${settings.name}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/main');
                    },
                    child: const Text('Back to Dashboard'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
