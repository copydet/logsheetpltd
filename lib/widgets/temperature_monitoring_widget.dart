import 'package:flutter/material.dart';
import '../widgets/temperature_chart_widget.dart';
import '../widgets/winding_temperature_chart_widget.dart';

class TemperatureMonitoringWidget extends StatefulWidget {
  final Map<String, dynamic> logsheetData;

  const TemperatureMonitoringWidget({Key? key, required this.logsheetData})
    : super(key: key);

  @override
  State<TemperatureMonitoringWidget> createState() =>
      _TemperatureMonitoringWidgetState();
}

class _TemperatureMonitoringWidgetState
    extends State<TemperatureMonitoringWidget> {
  PageController _temperaturePageController = PageController();
  int _currentTemperatureIndex = 0;

  String _getDataValue(String key, {String defaultValue = '0'}) {
    return widget.logsheetData[key]?.toString() ?? defaultValue;
  }

  @override
  void dispose() {
    _temperaturePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header dengan indicator
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monitoring Temperatur',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                Row(
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.only(left: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentTemperatureIndex == index
                            ? const Color(0xFF1E3A8A)
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          // PageView untuk grafik
          Expanded(
            child: PageView(
              controller: _temperaturePageController,
              onPageChanged: (index) {
                setState(() {
                  _currentTemperatureIndex = index;
                });
              },
              children: [
                TemperatureChartWidget(
                  title: 'Water Temperature',
                  currentValue: _getDataValue('waterTemp'),
                  unit: '°C',
                  color: Colors.blue,
                  icon: Icons.water_drop,
                ),
                TemperatureChartWidget(
                  title: 'Exhaust Temperature',
                  currentValue: _getDataValue('engineTempExhaust'),
                  unit: '°C',
                  color: Colors.deepOrange,
                  icon: Icons.local_fire_department,
                ),
                TemperatureChartWidget(
                  title: 'Bearing Temperature',
                  currentValue: _getDataValue('tempBearing'),
                  unit: '°C',
                  color: Colors.grey[600]!,
                  icon: Icons.settings,
                ),
                WindingTemperatureChartWidget(
                  tempU: _getDataValue('tempWindingU'),
                  tempV: _getDataValue('tempWindingV'),
                  tempW: _getDataValue('tempWindingW'),
                ),
              ],
            ),
          ),
          // Swipe indicator text
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Geser untuk melihat grafik lainnya',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
