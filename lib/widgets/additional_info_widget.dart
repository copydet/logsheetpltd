import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AdditionalInfoWidget extends StatefulWidget {
  const AdditionalInfoWidget({Key? key}) : super(key: key);

  @override
  State<AdditionalInfoWidget> createState() => _AdditionalInfoWidgetState();
}

class _AdditionalInfoWidgetState extends State<AdditionalInfoWidget> {
  String operatorName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadCurrentOperator();
  }

  Future<void> _loadCurrentOperator() async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (mounted) {
        setState(() {
          operatorName = currentUser?.displayName ?? 'Tidak Diketahui';
        });
      }
    } catch (e) {
      print('❌ Error loading current operator: $e');
      if (mounted) {
        setState(() {
          operatorName = 'Tidak Diketahui';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Icon(Icons.info, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Informasi Tambahan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Merk Mesin', 'Mitsubishi'),
          _buildInfoRow('Model', 'S 16R PTA-S'),
          _buildInfoRow('Kapasitas', '1000 KW'),
          _buildInfoRow('Operator saat ini', operatorName),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
