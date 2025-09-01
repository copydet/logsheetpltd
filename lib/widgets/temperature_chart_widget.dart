import 'package:flutter/material.dart';

class TemperatureChartWidget extends StatelessWidget {
  final String title;
  final String currentValue;
  final String unit;
  final Color color;
  final IconData icon;

  const TemperatureChartWidget({
    Key? key,
    required this.title,
    required this.currentValue,
    required this.unit,
    required this.color,
    required this.icon,
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
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '$currentValue $unit',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Simulasi grafik dengan bars
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  // Grafik simulasi dengan bars
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(12, (index) {
                        double height = 20 + (index * 5 % 60);
                        return Container(
                          width: 8,
                          height: height,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Label waktu
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
}
