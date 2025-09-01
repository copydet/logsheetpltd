import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import '../models/firebase_user_model.dart';

class ShiftPhotoService {
  static const String _storageRef = 'shift_photos';
  static const String _photoUrlKey = 'current_shift_photo_url';
  static const String _photoDateKey = 'shift_photo_date';

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Enum untuk tipe shift
  static const String SHIFT_PAGI = 'pagi'; // 08:00-15:00
  static const String SHIFT_SORE = 'sore'; // 15:00-23:00
  static const String SHIFT_MALAM = 'malam'; // 23:00-08:00

  // Get current shift based on time
  String getCurrentShift() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 8 && hour < 15) {
      return SHIFT_PAGI;
    } else if (hour >= 15 && hour < 23) {
      return SHIFT_SORE;
    } else {
      return SHIFT_MALAM;
    }
  }

  // Get shift display name
  String getShiftDisplayName(String shift) {
    switch (shift) {
      case SHIFT_PAGI:
        return 'Pagi (08:00-15:00)';
      case SHIFT_SORE:
        return 'Sore (15:00-23:00)';
      case SHIFT_MALAM:
        return 'Malam (23:00-08:00)';
      default:
        return 'Unknown Shift';
    }
  }

  // Check if user has uploaded photo for current shift today
  Future<bool> hasPhotoToday({String? specificShift}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentShift = specificShift ?? getCurrentShift();
      final savedDate = prefs.getString('${_photoDateKey}_$currentShift');
      final today = DateTime.now();
      final todayString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      print(
        '📷 PHOTO: Checking photo for shift $currentShift today: $todayString',
      );
      print('📷 PHOTO: Saved date for $currentShift: $savedDate');

      return savedDate == todayString;
    } catch (e) {
      print('❌ PHOTO: Error checking photo date: $e');
      return false;
    }
  }

  // Get current shift photo URL
  Future<String?> getCurrentPhotoUrl({String? specificShift}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentShift = specificShift ?? getCurrentShift();
      return prefs.getString('${_photoUrlKey}_$currentShift');
    } catch (e) {
      print('❌ PHOTO: Error getting photo URL: $e');
      return null;
    }
  }

  // Take photo from camera
  Future<XFile?> takePhoto() async {
    try {
      print('📷 PHOTO: Opening camera...');
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null) {
        print('📷 PHOTO: Photo captured: ${photo.path}');
      } else {
        print('📷 PHOTO: No photo taken');
      }

      return photo;
    } catch (e) {
      print('❌ PHOTO: Error taking photo: $e');
      throw Exception('Gagal mengambil foto: $e');
    }
  }

  // Upload photo to Firebase Storage
  Future<String> uploadPhoto(
    XFile photo,
    FirebaseUserModel user, {
    String? specificShift,
  }) async {
    try {
      final currentShift = specificShift ?? getCurrentShift();
      print(
        '📤 PHOTO: Starting upload for user: ${user.displayName}, shift: $currentShift',
      );

      // Create unique filename with timestamp, user info, and shift
      final now = DateTime.now();
      final dateString =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeString =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName =
          'shift_${currentShift}_${user.email}_${dateString}_${timeString}.jpg';

      // Create reference to Firebase Storage
      final ref = _storage.ref().child(_storageRef).child(fileName);

      // Upload file
      final file = File(photo.path);
      print('📤 PHOTO: Uploading to: $_storageRef/$fileName');

      final uploadTask = ref.putFile(file);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📤 PHOTO: Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ PHOTO: Upload successful, URL: $downloadUrl');

      // Save photo info locally for current shift
      await _savePhotoInfo(downloadUrl, currentShift);

      return downloadUrl;
    } catch (e) {
      print('❌ PHOTO: Upload failed: $e');
      throw Exception('Gagal mengupload foto: $e');
    }
  }

  // Save photo info to local storage for specific shift
  Future<void> _savePhotoInfo(String photoUrl, String shift) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await prefs.setString('${_photoUrlKey}_$shift', photoUrl);
      await prefs.setString('${_photoDateKey}_$shift', todayString);

      print('💾 PHOTO: Photo info saved locally for shift: $shift');
    } catch (e) {
      print('❌ PHOTO: Error saving photo info: $e');
    }
  }

  // Clear today's photo for specific shift (for testing or if user wants to retake)
  Future<void> clearTodayPhoto({String? specificShift}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentShift = specificShift ?? getCurrentShift();
      await prefs.remove('${_photoUrlKey}_$currentShift');
      await prefs.remove('${_photoDateKey}_$currentShift');
      print('🧹 PHOTO: Today\'s photo info cleared for shift: $currentShift');
    } catch (e) {
      print('❌ PHOTO: Error clearing photo info: $e');
    }
  }

  // Get all shift photos for current user (for settings page)
  Future<List<Map<String, dynamic>>> getUserShiftPhotos() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User tidak terautentikasi');
      }

      print('📋 PHOTO: Getting user shift photos...');

      // List all files in user's shift photos folder
      final ref = _storage.ref().child(_storageRef);
      final listResult = await ref.listAll();

      List<Map<String, dynamic>> userPhotos = [];

      for (final item in listResult.items) {
        // Check if this photo belongs to current user
        if (item.name.contains('shift_${currentUser.email}_')) {
          try {
            final metadata = await item.getMetadata();
            final downloadUrl = await item.getDownloadURL();

            userPhotos.add({
              'name': item.name,
              'url': downloadUrl,
              'uploaded': metadata.timeCreated,
              'size': metadata.size,
            });
          } catch (e) {
            print('❌ PHOTO: Error getting photo info for ${item.name}: $e');
          }
        }
      }

      // Sort by upload date (newest first)
      userPhotos.sort((a, b) => b['uploaded'].compareTo(a['uploaded']));

      print('📋 PHOTO: Found ${userPhotos.length} photos for user');
      return userPhotos;
    } catch (e) {
      print('❌ PHOTO: Error getting user photos: $e');
      return [];
    }
  }

  // Delete specific photo
  Future<bool> deletePhoto(String photoName) async {
    try {
      final ref = _storage.ref().child(_storageRef).child(photoName);
      await ref.delete();
      print('🗑️ PHOTO: Deleted photo: $photoName');
      return true;
    } catch (e) {
      print('❌ PHOTO: Error deleting photo: $e');
      return false;
    }
  }
}
