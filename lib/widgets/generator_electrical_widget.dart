import 'package:flutter/material.dart';
import '../widgets/parameter_card.dart';

class GeneratorElectricalWidget extends StatelessWidget {
  final Map<String, dynamic> logsheetData;
  final Map<String, dynamic> realTimeData; // Data real-time dari spreadsheet

  const GeneratorElectricalWidget({
    Key? key,
    required this.logsheetData,
    this.realTimeData = const {},
  }) : super(key: key);

  String _getDataValue(String key, {String defaultValue = '0'}) {
    // Mapping key ke real-time data
    Map<String, String> realTimeMapping = {
      'voltageR': 'Voltage R',
      'voltageS': 'Voltage S',
      'voltageT': 'Voltage T',
      'ampereR': 'Ampere R',
      'ampereS': 'Ampere S',
      'ampereT': 'Ampere T',
      'frequency': 'Frequency (Hz)',
      'cosPhi': 'CosPhi',
      'kvar': 'Kvar',
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
            'Parameter Listrik Generator',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 16),
          // Voltage
          Row(
            children: [
              Expanded(
                child: ParameterCard(
                  icon: Icons.flash_on,
                  value: _getDataValue('voltageR'),
                  label: 'Voltage R (V)',
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ParameterCard(
                  icon: Icons.flash_on,
                  value: _getDataValue('voltageS'),
                  label: 'Voltage S (V)',
                  color: Colors.yellow[700]!,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ParameterCard(
                  icon: Icons.flash_on,
                  value: _getDataValue('voltageT'),
                  label: 'Voltage T (V)',
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Ampere
          Row(
            children: [
              Expanded(
                child: ParameterCard(
                  icon: Icons.electrical_services,
                  value: _getDataValue('ampereR'),
                  label: 'Ampere R (A)',
                  color: Colors.red[300]!,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ParameterCard(
                  icon: Icons.electrical_services,
                  value: _getDataValue('ampereS'),
                  label: 'Ampere S (A)',
                  color: Colors.yellow[600]!,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ParameterCard(
                  icon: Icons.electrical_services,
                  value: _getDataValue('ampereT'),
                  label: 'Ampere T (A)',
                  color: Colors.blue[300]!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Frekuensi, kVAR, Cos Phi
          Row(
            children: [
              Expanded(
                child: ParameterCard(
                  icon: Icons.waves,
                  value: _getDataValue('hz'),
                  label: 'Frekuensi (Hz)',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ParameterCard(
                  icon: Icons.power,
                  value: _getDataValue('kvar'),
                  label: 'kVAR',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ParameterCard(
                  icon: Icons.analytics,
                  value: _getDataValue('cosPhi'),
                  label: 'Cos Phi',
                  color: Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
