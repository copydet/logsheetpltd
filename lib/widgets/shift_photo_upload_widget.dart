import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/shift_photo_service.dart';
import '../models/firebase_user_model.dart';

class ShiftPhotoUploadWidget extends StatefulWidget {
  final Function(String photoUrl)? onPhotoUploaded;
  final bool isRequired;

  const ShiftPhotoUploadWidget({
    Key? key,
    this.onPhotoUploaded,
    this.isRequired = false,
  }) : super(key: key);

  @override
  State<ShiftPhotoUploadWidget> createState() => _ShiftPhotoUploadWidgetState();
}

class _ShiftPhotoUploadWidgetState extends State<ShiftPhotoUploadWidget> {
  final ShiftPhotoService _photoService = ShiftPhotoService();
  XFile? _selectedPhoto;
  bool _isUploading = false;
  String? _uploadedPhotoUrl;
  bool _hasPhotoToday = false;

  @override
  void initState() {
    super.initState();
    _checkExistingPhoto();
  }

  Future<void> _checkExistingPhoto() async {
    try {
      final hasPhoto = await _photoService.hasPhotoToday();
      final photoUrl = await _photoService.getCurrentPhotoUrl();

      setState(() {
        _hasPhotoToday = hasPhoto;
        _uploadedPhotoUrl = photoUrl;
      });

      print('📷 PHOTO: Has photo today: $hasPhoto, URL: $photoUrl');
    } catch (e) {
      print('❌ PHOTO: Error  existing photo: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _photoService.takePhoto();
      if (photo != null) {
        setState(() {
          _selectedPhoto = photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadPhoto(FirebaseUserModel user) async {
    if (_selectedPhoto == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final photoUrl = await _photoService.uploadPhoto(_selectedPhoto!, user);

      setState(() {
        _uploadedPhotoUrl = photoUrl;
        _hasPhotoToday = true;
        _selectedPhoto = null;
        _isUploading = false;
      });

      if (widget.onPhotoUploaded != null) {
        widget.onPhotoUploaded!(photoUrl);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Foto shift berhasil diunggah!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _retakePhoto() async {
    try {
      await _photoService.clearTodayPhoto();
      setState(() {
        _hasPhotoToday = false;
        _uploadedPhotoUrl = null;
        _selectedPhoto = null;
      });
    } catch (e) {
      print('❌ PHOTO:  clearing photo: $e');
    }
  }

  Widget _buildPhotoPreview() {
    if (_selectedPhoto != null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(_selectedPhoto!.path), fit: BoxFit.cover),
        ),
      );
    } else if (_uploadedPhotoUrl != null && _hasPhotoToday) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            _uploadedPhotoUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.error, color: Colors.red, size: 48),
              );
            },
          ),
        ),
      );
    } else {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isRequired ? Colors.red : Colors.grey.shade300,
            width: widget.isRequired ? 2 : 1,
          ),
          color: Colors.grey.shade50,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 48,
              color: widget.isRequired ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              widget.isRequired ? 'Foto Shift Wajib' : 'Belum ada foto',
              style: TextStyle(
                color: widget.isRequired ? Colors.red : Colors.grey,
                fontWeight: widget.isRequired
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            if (widget.isRequired) ...[
              const SizedBox(height: 4),
              const Text(
                'Silakan ambil foto sebelum login',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.camera_alt, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Foto Shift Hari Ini',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.isRequired) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'WAJIB',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _buildPhotoPreview(),
            const SizedBox(height: 16),
            if (_hasPhotoToday && _uploadedPhotoUrl != null) ...[
              // Photo already uploaded today
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Foto shift hari ini sudah diunggah',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _retakePhoto,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Ambil Ulang Foto'),
                ),
              ),
            ] else if (_selectedPhoto != null) ...[
              // Photo selected but not uploaded
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.upload, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Foto siap diunggah. Klik tombol unggah untuk melanjutkan.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Ambil Ulang'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading
                          ? null
                          : () async {
                              // For demo purposes, we'll simulate getting current user
                              // In real implementation, this should come from auth service
                              final currentUser = FirebaseUserModel(
                                uid: 'demo_uid',
                                username: 'demo',
                                displayName: 'Demo User',
                                email: 'demo@pltd.com',
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
                              await _uploadPhoto(currentUser);
                            },
                      icon: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: Text(
                        _isUploading ? 'Mengunggah...' : 'Unggah Foto',
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // No photo taken yet
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Ambil Foto Shift'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isRequired ? Colors.red : null,
                    foregroundColor: widget.isRequired ? Colors.white : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
