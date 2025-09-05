import 'package:flutter/material.dart';

class RiwayatGeneratorCard extends StatelessWidget {
  final Map<String, dynamic> generator;
  final VoidCallback? onTap;

  const RiwayatGeneratorCard({Key? key, required this.generator, this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool hasData = generator['fileId'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _buildStatusIcon(),
        title: _buildTitle(),
        subtitle: _buildSubtitle(hasData),
        trailing: _buildTrailing(hasData),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatusIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: generator['isActive']
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.electrical_services,
        color: generator['isActive'] ? Colors.green : Colors.grey,
        size: 24,
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      generator['name'],
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildSubtitle(bool hasData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          generator['isActive'] ? 'Status: Aktif' : 'Status: Tidak Aktif',
          style: TextStyle(
            fontSize: 14,
            color: generator['isActive'] ? Colors.green : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hasData ? 'Logsheet tersedia' : 'Belum ada logsheet yang dibuat',
          style: TextStyle(
            fontSize: 12,
            color: hasData ? Colors.blue : Colors.orange[600],
            fontWeight: hasData ? FontWeight.normal : FontWeight.w500,
          ),
        ),
        if (!hasData) ...[
          const SizedBox(height: 2),
          Text(
            'Klik untuk melihat panduan',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTrailing(bool hasData) {
    if (!hasData) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Text(
          'Kosong',
          style: TextStyle(
            fontSize: 10,
            color: Colors.orange[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]);
  }
}
