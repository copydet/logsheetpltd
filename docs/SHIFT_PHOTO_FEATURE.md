# Fitur Foto Shift Wajib

## Overview
Fitur ini mengimplementasikan requirement untuk foto shift yang **wajib** diambil sebelum pengguna dapat login ke aplikasi. Foto akan diunggah ke Firebase Storage dan ditampilkan di halaman pengaturan.

## Firebase Storage Path
```
gs://powerplantlogsheet-8780a.firebasestorage.app/shift_photos/
```

## File Structure

### Services
- **`lib/services/shift_photo_service.dart`**
  - Service utama untuk mengelola foto shift
  - Upload ke Firebase Storage dengan path `shift_photos/`
  - Validasi foto harian menggunakan SharedPreferences
  - Format nama file: `shift_{email}_{YYYYMMDD}_{HHMM}.jpg`

### Widgets
- **`lib/widgets/shift_photo_upload_widget.dart`**
  - Widget UI untuk upload foto shift
  - Menampilkan preview foto
  - Validasi foto wajib dengan UI yang jelas
  - Status upload dengan progress indicator

### Screens
- **`lib/screens/login_screen.dart`**
  - Terintegrasi dengan validasi foto wajib
  - Tidak bisa login tanpa foto hari ini
  - Error message yang informatif

- **`lib/screens/shift_photo_settings_page.dart`**
  - Halaman pengaturan untuk menampilkan foto shift
  - Riwayat foto dengan thumbnail
  - Fitur view fullscreen dan delete foto lama
  - Card khusus seperti yang diminta

## Fitur Utama

### 1. Validasi Foto Wajib
- Foto shift **wajib** diambil setiap hari sebelum login
- Validasi berdasarkan tanggal (tidak bisa menggunakan foto kemarin)
- Error message jelas jika belum upload foto

### 2. Upload ke Firebase Storage
- Auto upload ke path: `gs://powerplantlogsheet-8780a.firebasestorage.app/shift_photos/`
- Nama file unik dengan timestamp dan email user
- Compress foto otomatis (max 1920x1080, quality 80%)
- Progress indicator saat upload

### 3. Penyimpanan Lokal
- SharedPreferences untuk track foto hari ini
- Cache URL foto untuk akses cepat
- Validasi berdasarkan tanggal sistem

### 4. Halaman Pengaturan
- **Card khusus** untuk foto shift seperti diminta
- Riwayat semua foto user
- Thumbnail dengan info lengkap (tanggal, waktu, ukuran file)
- View fullscreen dengan zoom
- Delete foto lama (kecuali foto hari ini)

## Konfigurasi Dependencies

Sudah ditambahkan di `pubspec.yaml`:
```yaml
dependencies:
  firebase_storage: ^13.0.0
  image_picker: ^1.0.4
  file_picker: ^8.0.6
```

## Flow Penggunaan

### Login Flow
1. User masuk ke halaman login
2. Widget foto shift menampilkan status (wajib/sudah upload)
3. Jika belum upload foto hari ini:
   - Tombol "Ambil Foto Shift" dengan warna merah
   - Pesan "Foto Shift Wajib"
4. User mengambil foto → preview → upload
5. Setelah upload sukses, baru bisa login
6. Validasi di tombol login: cek foto wajib

### Settings Flow
1. Navigasi ke halaman pengaturan foto shift
2. Card "Foto Shift Hari Ini" - upload/view foto current
3. Card "Riwayat Foto Shift" - history semua foto
4. Fitur view fullscreen dan delete

## Technical Details

### Firebase Storage Rules
Pastikan rules Firebase Storage mengizinkan authenticated users:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /shift_photos/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Error Handling
- Network error handling
- Firebase Storage error handling  
- Image picker permission handling
- File format validation

## Status Implementation
✅ Service foto shift dengan Firebase Storage  
✅ Widget upload dengan validasi wajib  
✅ Integrasi login screen dengan validasi  
✅ Halaman settings dengan card khusus  
✅ Dependencies dan konfigurasi  
✅ Error handling dan UX  

## Next Steps
- Test permission kamera di device fisik
- Konfigurasi Firebase Storage rules
- Fine-tuning UI/UX berdasarkan feedback user
