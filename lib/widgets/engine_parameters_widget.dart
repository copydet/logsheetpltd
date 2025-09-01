import 'package:flutter/material.dart';
import '../widgets/parameter_card.dart';

class EngineParametersWidget extends StatelessWidget {
  final Map<String, dynamic> logsheetData;
  final Map<String, dynamic> realTimeData; // Data real-time dari spreadsheet

  const EngineParametersWidget({
    Key? key,
    required this.logsheetData,
    this.realTimeData = const {},
  }) : super(key: key);

  String _getDataValue(String key, {String defaultValue = '0'}) {
    // Mapping key ke real-time data
    Map<String, String> realTimeMapping = {
      'jamOperasi': 'Jam Operasi',
      'rpm': 'RPM',
      'oilPressure': 'Oil Pressure',
      'teganganAccu': 'Tegangan Accu',
      'beban': 'Beban (Load)',
      'enginePressureCrankcase': 'Engine Pressure',
    };

    // Prioritas: cek real-time data dulu
    if (realTimeData.isNotEmpty && realTimeMapping.containsKey(key)) {
      final realTimeValue = realTimeData[realTimeMapping[key]]?.toString();
      if (realTimeValue != null &&
          realTimeValue != 'N/A' &&
          realTimeValue.isNotEmpty) {
        return realTimeValue;
      }
    }

    // Fallback ke data historical
    return logsheetData[key]?.toString() ?? defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Parameter Engine',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ParameterCard(
                  icon: Icons.access_time,
                  value: _getDataValue('jamOperasi'),
                  label: 'Jam Operasi',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ParameterCard(
                  icon: Icons.speed,
                  value: _getDataValue('rpm'),
                  label: 'RPM',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ParameterCard(
                  icon: Icons.oil_barrel,
                  value: _getDataValue('oilPressure'),
                  label: 'Oil Pressure (Bar)',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ParameterCard(
                  icon: Icons.battery_charging_full,
                  value: _getDataValue('teganganAccu'),
                  label: 'Tegangan Accu (V)',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ParameterCard(
                  icon: Icons.electrical_services,
                  value: _getDataValue('beban'),
                  label: 'Beban (kW)',
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ParameterCard(
                  icon: Icons.waves,
                  value: _getDataValue('enginePressureCrankcase'),
                  label: 'Crankcase Press',
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
