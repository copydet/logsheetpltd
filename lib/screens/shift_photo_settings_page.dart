import 'package:flutter/material.dart';
import '../services/shift_photo_service.dart';
import '../widgets/shift_photo_upload_widget.dart';

class ShiftPhotoSettingsPage extends StatefulWidget {
  const ShiftPhotoSettingsPage({Key? key}) : super(key: key);

  @override
  State<ShiftPhotoSettingsPage> createState() => _ShiftPhotoSettingsPageState();
}

class _ShiftPhotoSettingsPageState extends State<ShiftPhotoSettingsPage> {
  final ShiftPhotoService _photoService = ShiftPhotoService();
  List<Map<String, dynamic>> _userPhotos = [];
  bool _isLoading = true;
  String? _todayPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserPhotos();
  }

  Future<void> _loadUserPhotos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final photos = await _photoService.getUserShiftPhotos();
      final todayPhoto = await _photoService.getCurrentPhotoUrl();

      setState(() {
        _userPhotos = photos;
        _todayPhotoUrl = todayPhoto;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ SETTINGS:  loading photos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePhoto(String photoName, int index) async {
    try {
      final success = await _photoService.deletePhoto(photoName);
      if (success) {
        setState(() {
          _userPhotos.removeAt(index);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Foto berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal menghapus foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foto Shift'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserPhotos,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload foto hari ini
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.today, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Foto Shift Hari Ini',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ShiftPhotoUploadWidget(
                      onPhotoUploaded: (photoUrl) {
                        // Refresh the photo list when new photo is uploaded
                        _loadUserPhotos();
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Riwayat foto shift
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Riwayat Foto Shift',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_isLoading) ...[
                      const Center(child: CircularProgressIndicator()),
                    ] else if (_userPhotos.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Belum ada foto shift',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Foto shift yang Anda ambil akan ditampilkan di sini',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _userPhotos.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final photo = _userPhotos[index];
                          final uploadDate = photo['uploaded'] as DateTime;
                          final isToday = _todayPhotoUrl == photo['url'];

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isToday
                                    ? Colors.green
                                    : Colors.grey.shade300,
                                width: isToday ? 2 : 1,
                              ),
                              color: isToday
                                  ? Colors.green.shade50
                                  : Colors.white,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Thumbnail foto
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey.shade200,
                                      child: Image.network(
                                        photo['url'],
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                              if (loadingProgress == null)
                                                return child;
                                              return const Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              );
                                            },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                                size: 30,
                                              );
                                            },
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // Info foto
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _formatDate(uploadDate),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (isToday) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'HARI INI',
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
                                        const SizedBox(height: 4),
                                        Text(
                                          'Waktu: ${_formatTime(uploadDate)}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'Ukuran: ${_formatFileSize(photo['size'])}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Action buttons
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.fullscreen),
                                        onPressed: () {
                                          // Show full screen image
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  _FullScreenImagePage(
                                                    imageUrl: photo['url'],
                                                    title:
                                                        'Foto ${_formatDate(uploadDate)}',
                                                  ),
                                            ),
                                          );
                                        },
                                        color: Colors.blue,
                                        iconSize: 20,
                                      ),
                                      if (!isToday) // Don't allow deleting today's photo
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () {
                                            // Confirm deletion
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Hapus Foto'),
                                                content: Text(
                                                  'Yakin ingin menghapus foto tanggal ${_formatDate(uploadDate)}?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text('Batal'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _deletePhoto(
                                                        photo['name'],
                                                        index,
                                                      );
                                                    },
                                                    child: const Text(
                                                      'Hapus',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          color: Colors.red,
                                          iconSize: 20,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenImagePage extends StatelessWidget {
  final String imageUrl;
  final String title;

  const _FullScreenImagePage({required this.imageUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.white, size: 100),
                  SizedBox(height: 16),
                  Text(
                    'Gagal memuat gambar',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
