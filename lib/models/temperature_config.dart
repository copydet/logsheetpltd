import 'package:flutter/material.dart';

class TemperatureConfig {
  final String title;
  final String unit;
  final Color color;
  final IconData icon;
  final List<double> yAxisValues;
  final double maxY;
  final double minY;

  TemperatureConfig({
    required this.title,
    required this.unit,
    required this.color,
    required this.icon,
    required this.yAxisValues,
    required this.maxY,
    required this.minY,
  });
}

// Common temperature configurations
final Map<String, TemperatureConfig> temperatureConfigs = {
  'waterTemp': TemperatureConfig(
    title: 'Water Temperature',
    unit: '°C',
    color: Colors.blue,
    icon: Icons.water_drop,
    yAxisValues: [0, 20, 50, 80, 100],
    maxY: 100,
    minY: 0,
  ),
  'lubeOilTemp': TemperatureConfig(
    title: 'Lube Oil Temperature',
    unit: '°C',
    color: Colors.green,
    icon: Icons.oil_barrel,
    yAxisValues: [0, 20, 40, 60, 80, 100, 120],
    maxY: 120,
    minY: 0,
  ),
  'engineTempExhaust': TemperatureConfig(
    title: 'Exhaust Temperature',
    unit: '°C',
    color: Colors.red,
    icon: Icons.local_fire_department,
    yAxisValues: [0, 100, 200, 300, 400, 500, 600, 700],
    maxY: 700,
    minY: 0,
  ),
  'tempBearing': TemperatureConfig(
    title: 'Bearing Temperature',
    unit: '°C',
    color: Colors.orange,
    icon: Icons.settings,
    yAxisValues: [0, 20, 30, 50, 80],
    maxY: 80,
    minY: 0,
  ),
  'tempWindingAvg': TemperatureConfig(
    title: 'Winding Temperature (Average)',
    unit: '°C',
    color: Colors.purple,
    icon: Icons.electrical_services,
    yAxisValues: [0, 20, 50, 80, 100],
    maxY: 100,
    minY: 0,
  ),
};
