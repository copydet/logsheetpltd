import 'package:flutter/material.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/shift_photo_service.dart';
import '../models/firebase_user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _errorMessage;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _selectedShift;
  String? _photoPath;
  bool _isLoading = false;
  bool _photoUploaded = false;
  String _currentShift = '';

  @override
  void initState() {
    super.initState();
    _initializeShift();
    _checkExistingPhoto();
  }

  void _initializeShift() {
    final photoService = ShiftPhotoService();
    setState(() {
      _currentShift = photoService.getCurrentShift();
    });
  }

  Future<void> _checkExistingPhoto() async {
    try {
      final photoService = ShiftPhotoService();
      final hasPhoto = await photoService.hasPhotoToday();
      final photoUrl = await photoService.getCurrentPhotoUrl();

      setState(() {
        _photoUploaded = hasPhoto;
        if (hasPhoto && photoUrl != null) {
          _photoPath = photoUrl; // Store URL for network image
        }
      });
    } catch (e) {
      print('Error  existing photo: $e');
    }
  }

  Future<void> _takeShiftPhoto() async {
    try {
      final photoService = ShiftPhotoService();

      // Take photo
      final photo = await photoService.takePhoto();
      if (photo == null) return;

      // Show loading
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // For demo, create a dummy user - in real app, get from auth
      final dummyUser = FirebaseUserModel(
        uid: 'demo_uid',
        username: 'demo',
        displayName: 'Demo User',
        email: _usernameController.text.trim().isNotEmpty
            ? _usernameController.text.trim()
            : 'demo@pltd.com',
        role: 'operator',
        isActive: true,
        generatorAccess: [],
        permissions: UserPermissions(
          canEditLogsheets: true,
          canExportData: false,
          canViewAllGenerators: true,
          canManageUsers: false,
          canConfigureSystem: false,
          canDeleteEntries: false,
          canViewAnalytics: false,
          canViewReports: false,
        ),
      );

      // Upload photo untuk shift saat ini
      await photoService.uploadPhoto(photo, dummyUser);

      setState(() {
        _photoPath = photo.path;
        _photoUploaded = true;
        _isLoading = false;
      });

      if (mounted) {
        final shiftName = photoService.getShiftDisplayName(_currentShift);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Foto shift $shiftName berhasil diupload!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal mengambil foto: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 350,
            margin: const EdgeInsets.symmetric(vertical: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flash_on,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Selamat Datang',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Silakan masuk untuk melanjutkan pencatatan logsheet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                // Email
                TextField(
                  controller: _usernameController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Contoh: dimas@pltd.com',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Password
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Masukkan Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Foto Shift
                Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: _photoUploaded
                              ? Colors.green[100]
                              : Colors.grey[200],
                          backgroundImage: _photoPath != null
                              ? (_photoPath!.startsWith('http')
                                    ? NetworkImage(_photoPath!) as ImageProvider
                                    : FileImage(File(_photoPath!)))
                              : null,
                          child: _photoPath == null
                              ? Icon(
                                  _photoUploaded
                                      ? Icons.check_circle
                                      : Icons.camera_alt,
                                  color: _photoUploaded
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 32,
                                )
                              : null,
                        ),
                        if (_photoUploaded)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _photoUploaded
                          ? '✅ Foto shift ${ShiftPhotoService().getShiftDisplayName(_currentShift)} sudah diupload'
                          : 'Upload foto shift ${ShiftPhotoService().getShiftDisplayName(_currentShift)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _photoUploaded ? Colors.green : Colors.black54,
                        fontWeight: _photoUploaded
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload'),
                          onPressed: () {
                            // TODO: Implementasi upload
                          },
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _photoUploaded
                                ? Colors.green[100]
                                : Colors.grey[200],
                            foregroundColor: _photoUploaded
                                ? Colors.green[800]
                                : Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _photoUploaded
                                      ? Icons.refresh
                                      : Icons.camera_alt,
                                ),
                          label: Text(
                            _isLoading
                                ? 'Mengupload...'
                                : (_photoUploaded
                                      ? 'Ambil Ulang'
                                      : 'Ambil Foto'),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  await _takeShiftPhoto();
                                },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Pilih Shift Kerja
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Pilih Shift Kerja',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildShiftCard(
                      'Pagi',
                      '08:00-15:00',
                      Icons.wb_sunny,
                      Colors.orange,
                      'pagi',
                    ),
                    _buildShiftCard(
                      'Sore',
                      '15:00-23:00',
                      Icons.wb_twilight,
                      Colors.deepOrange,
                      'sore',
                    ),
                    _buildShiftCard(
                      'Malam',
                      '23:00-08:00',
                      Icons.nightlight_round,
                      Colors.indigo,
                      'malam',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Login Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B7280),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.login, color: Colors.white),
                    label: Text(
                      _isLoading ? 'Masuk...' : 'Login',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final username = _usernameController.text.trim();
                            final password = _passwordController.text;

                            if (username.isEmpty || password.isEmpty) {
                              setState(() {
                                _errorMessage =
                                    'Username dan password harus diisi!';
                              });
                              return;
                            }

                            // Cek foto shift wajib untuk shift saat ini
                            final photoService = ShiftPhotoService();
                            final hasPhotoToday = await photoService
                                .hasPhotoToday();
                            final currentShiftName = photoService
                                .getShiftDisplayName(
                                  photoService.getCurrentShift(),
                                );
                            if (!hasPhotoToday) {
                              setState(() {
                                _errorMessage =
                                    '⚠️ Wajib upload foto shift $currentShiftName sebelum login!\nSilakan ambil foto terlebih dahulu.';
                              });
                              return;
                            }

                            setState(() {
                              _isLoading = true;
                              _errorMessage = null;
                            });

                            try {
                              final result = await AuthService.login(
                                username,
                                password,
                              );

                              if (result != null) {
                                if (mounted) {
                                  // Navigate ke dashboard
                                  Navigator.pushReplacementNamed(
                                    context,
                                    '/main',
                                  );
                                }
                              } else {
                                setState(() {
                                  _errorMessage =
                                      'Login gagal. Periksa username dan password Anda.';
                                });
                              }
                            } catch (e) {
                              setState(() {
                                _errorMessage = 'Error: ${e.toString()}';
                              });
                            } finally {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          },
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    // TODO: Implementasi forgot password
                  },
                  child: const Text(
                    'Lupa password?',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'PLTD Logsheet v1.0.0',
                  style: TextStyle(fontSize: 11, color: Colors.black38),
                ),
                const Text(
                  '© 2025 Universitas Siber Asia - Supriyadi',
                  style: TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShiftCard(
    String title,
    String time,
    IconData icon,
    Color color,
    String value,
  ) {
    final isSelected = _selectedShift == value;
    final isCurrentShift =
        _currentShift == value; // Cek if this is current shift

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedShift = value;
        });
      },
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.12)
              : (isCurrentShift ? color.withOpacity(0.05) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : (isCurrentShift ? color.withOpacity(0.5) : Colors.grey[300]!),
            width: isSelected ? 2 : (isCurrentShift ? 2 : 1),
          ),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Icon(icon, color: color, size: 24),
                if (isCurrentShift && !isSelected)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
            Text(
              time,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            if (isCurrentShift)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'AKTIF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
