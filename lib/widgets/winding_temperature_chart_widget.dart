import 'package:flutter/material.dart';

class WindingTemperatureChartWidget extends StatelessWidget {
  final String tempU;
  final String tempV;
  final String tempW;

  const WindingTemperatureChartWidget({
    Key? key,
    required this.tempU,
    required this.tempV,
    required this.tempW,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header dengan nilai current
          Row(
            children: [
              const Icon(Icons.thermostat, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Temperatur Winding U-V-W',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Nilai saat ini
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTempValue('U', tempU, Colors.red[400]!),
              _buildTempValue('V', tempV, Colors.yellow[600]!),
              _buildTempValue('W', tempW, Colors.blue[400]!),
            ],
          ),
          const SizedBox(height: 16),
          // Grafik simulasi dengan multi-colored bars
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(12, (index) {
                        return Row(
                          children: [
                            Container(
                              width: 4,
                              height: 20 + (index * 3 % 40),
                              decoration: BoxDecoration(
                                color: Colors.red[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Container(
                              width: 4,
                              height: 25 + (index * 4 % 35),
                              decoration: BoxDecoration(
                                color: Colors.yellow[600],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Container(
                              width: 4,
                              height: 15 + (index * 5 % 45),
                              decoration: BoxDecoration(
                                color: Colors.blue[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '00:00',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        '12:00',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        '23:00',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTempValue(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        Text(
          '$value°C',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
