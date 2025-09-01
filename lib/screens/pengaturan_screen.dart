import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/shift_photo_service.dart';
import '../models/firebase_user_model.dart';

class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen>
    with WidgetsBindingObserver {
  FirebaseUserModel? currentUser;
  final ShiftPhotoService _photoService = ShiftPhotoService();
  String? _todayPhotoUrl;
  bool _hasPhotoToday = false;
  String _currentShift = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentUser();
    _loadShiftPhotoData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh photo data when app becomes active again
      _loadShiftPhotoData();
    }
  }

  Future<void> _loadShiftPhotoData() async {
    try {
      final hasPhoto = await _photoService.hasPhotoToday();
      final photoUrl = await _photoService.getCurrentPhotoUrl();
      final shift = _photoService.getCurrentShift();

      if (mounted) {
        setState(() {
          _hasPhotoToday = hasPhoto;
          _todayPhotoUrl = photoUrl;
          _currentShift = shift;
        });
      }
    } catch (e) {
      print('Error loading shift photo data: $e');
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (mounted) {
        setState(() {
          currentUser = user;
        });
      }
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  void _showFullscreenPhoto(String photoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 60,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Foto Shift - ${_currentShift.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastLogin(DateTime lastLogin) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${lastLogin.day} ${months[lastLogin.month - 1]} ${lastLogin.year}, '
        '${lastLogin.hour.toString().padLeft(2, '0')}:${lastLogin.minute.toString().padLeft(2, '0')} WIB';
  }

  String _getShiftTime(String shift) {
    switch (shift) {
      case 'pagi':
        return '08:00-15:00';
      case 'sore':
        return '15:00-23:00';
      case 'malam':
        return '23:00-08:00';
      case 'I':
        return '08:00-15:00';
      case 'II':
        return '15:00-23:00';
      case 'III':
        return '23:00-08:00';
      default:
        return '08:00-15:00';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        title: const Text(
          'Pengaturan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Online',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser?.displayName ?? 'Loading...',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          currentUser?.roleDisplayName ?? 'Loading role...',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          currentUser?.email ?? 'Loading email...',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentUser?.lastLogin != null
                              ? 'Login terakhir: ${_formatLastLogin(currentUser!.lastLogin!)}'
                              : 'Login terakhir: -',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Foto Shift Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _hasPhotoToday
                              ? const Color(0xFF1E3A8A)
                              : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _hasPhotoToday
                              ? Icons.camera_alt
                              : Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Foto Shift Hari Ini',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Shift $_currentShift (${_getShiftTime(_currentShift)})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _hasPhotoToday
                              ? const Color(0xFF1E3A8A)
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _hasPhotoToday ? 'SUDAH' : 'BELUM',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Foto preview atau placeholder
                  GestureDetector(
                    onTap: () {
                      if (_hasPhotoToday && _todayPhotoUrl != null) {
                        _showFullscreenPhoto(_todayPhotoUrl!);
                      }
                    },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _hasPhotoToday
                              ? const Color(0xFF1E3A8A).withOpacity(0.3)
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                        color: _hasPhotoToday
                            ? const Color(0xFF1E3A8A).withOpacity(0.05)
                            : Colors.grey.shade50,
                      ),
                      child: _hasPhotoToday && _todayPhotoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _todayPhotoUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                      size: 40,
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _hasPhotoToday
                                        ? Icons.check_circle
                                        : Icons.camera_alt_outlined,
                                    size: 40,
                                    color: _hasPhotoToday
                                        ? const Color(0xFF1E3A8A)
                                        : Colors.grey,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _hasPhotoToday
                                        ? 'Foto shift sudah diambil'
                                        : 'Belum ada foto shift',
                                    style: TextStyle(
                                      color: _hasPhotoToday
                                          ? const Color(0xFF1E3A8A)
                                          : Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Akun & Preferensi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Akun & Preferensi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildMenuItem(Icons.lock, 'Ubah Password'),
                  _buildMenuItem(Icons.help_outline, 'Bantuan & FAQ'),
                  _buildMenuItem(
                    Icons.info_outline,
                    'Tentang Aplikasi',
                    subtitle: 'Versi 2.1.0',
                  ),

                  const SizedBox(height: 10),
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'Keluar / Log Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Konfirmasi Logout'),
                              content: const Text('Anda yakin ingin logout?'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Tidak'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                    // Lakukan logout dengan AuthService
                                    await AuthService.logout();
                                    // Kembali ke login screen
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      '/login',
                                      (route) => false,
                                    );
                                  },
                                  child: const Text('Ya'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Column(
                      children: const [
                        Text(
                          'PLTD Logsheet v2.1.0',
                          style: TextStyle(fontSize: 11, color: Colors.black38),
                        ),
                        Text(
                          '© 2023 PT Pembangkit Listrik',
                          style: TextStyle(fontSize: 11, color: Colors.black38),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1E3A8A)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(fontSize: 12))
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
        onTap: () {},
      ),
    );
  }
}
