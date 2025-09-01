# 📱 APK Uji Lapangan - Logsheet PLTD App

## 📋 Informasi Build

| Detail | Value |
|--------|-------|
| **Versi App** | Release Build |
| **Tanggal Build** | 2 September 2025 |
| **File APK** | `app-release.apk` |
| **Ukuran File** | 52.6 MB |
| **Lokasi** | `build/app/outputs/flutter-apk/app-release.apk` |
| **Commit** | Latest (187c3ae) |

## 🎯 Fitur Utama untuk Testing

### ✅ Fitur yang Siap di Test:
1. **Login & Authentication**
   - Login dengan email/password
   - Auto-login jika sudah tersimpan
   - Logout functionality

2. **Dashboard Real-time**
   - Monitoring 4 Generator (Mitsubishi #1-4)
   - Real-time data dari Firestore
   - Pull-to-refresh untuk update data
   - Status sync indicator

3. **Input Logsheet**
   - Form input parameter mesin
   - Auto-save draft
   - Upload foto shift
   - Validasi data input

4. **Historical Data**
   - Riwayat logsheet
   - Filter by date/generator
   - Export to Excel/PDF
   - Detail view logsheet

5. **Real-time Monitoring**
   - Temperature charts
   - Engine parameters
   - Electrical data
   - Line charts with live data

6. **Collaboration Features**
   - Multi-user editing
   - Form status indicator
   - Conflict resolution

7. **Offline Capability**
   - SQLite local storage
   - Auto-sync when online
   - Draft saving
   - Background sync

## 🧪 Test Scenarios

### 1. **Basic Functionality Test**
- [ ] Install APK di device
- [ ] Launch aplikasi
- [ ] Login dengan credentials
- [ ] Navigate semua menu
- [ ] Test pull-to-refresh

### 2. **Network Connectivity Test**
- [ ] Test dengan WiFi
- [ ] Test dengan mobile data
- [ ] Test offline mode
- [ ] Test reconnection sync

### 3. **Data Input Test**
- [ ] Input logsheet baru
- [ ] Upload foto shift
- [ ] Save as draft
- [ ] Submit final logsheet
- [ ] Edit existing logsheet

### 4. **Multi-device Test**
- [ ] Login dari 2 device berbeda
- [ ] Test collaborative editing
- [ ] Test data sync across devices
- [ ] Test conflict resolution

### 5. **Performance Test**
- [ ] Memory usage monitoring
- [ ] Battery usage
- [ ] Loading time
- [ ] Scroll performance charts
- [ ] Large dataset handling

## 📱 Device Requirements

### Minimum Requirements:
- **Android Version**: 6.0+ (API 23+)
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 100MB free space
- **Network**: WiFi or Mobile data

### Recommended Devices:
- Android 8.0+ untuk performa optimal
- 4GB+ RAM untuk smooth operation
- Stable internet connection

## 🔧 Installation Guide

1. **Enable Unknown Sources**:
   - Settings → Security → Unknown Sources → Enable

2. **Install APK**:
   ```
   adb install app-release.apk
   ```
   atau copy file ke device dan install manual

3. **First Launch Setup**:
   - Allow permissions (Camera, Storage, Location)
   - Login dengan credentials
   - Wait for initial data sync

## 🐛 Known Issues & Workarounds

### Minor Issues:
1. **Google Play Services warnings** - Normal di emulator, ignored
2. **Print statements** - Debug logs, tidak affect functionality
3. **Deprecated APIs** - Flutter framework, sudah handled

### Workarounds:
- Jika sync lambat: Pull-to-refresh manual
- Jika foto tidak upload: Check network connection
- Jika app crash: Restart app (auto-recovery)

## 📊 Testing Checklist

### Pre-Installation:
- [ ] Device memenuhi minimum requirements
- [ ] Unknown sources enabled
- [ ] Stable network connection

### Post-Installation:
- [ ] App launch successfully
- [ ] Login berhasil
- [ ] Dashboard load data
- [ ] Real-time updates working
- [ ] Forms dapat diisi
- [ ] Foto dapat diupload
- [ ] Sync indicator working

### Stress Testing:
- [ ] Multiple logsheet entries
- [ ] Large file uploads
- [ ] Extended usage (2+ hours)
- [ ] Background app switching
- [ ] Network interruption recovery

## 📞 Contact untuk Bug Reports

**Developer**: GitHub Copilot Assistant
**Repository**: https://github.com/copydet/logsheetpltd.git
**Issue Tracking**: Create GitHub Issues

### Bug Report Format:
```
**Device**: [Model, Android Version]
**Steps to Reproduce**: [Detailed steps]
**Expected Result**: [What should happen]
**Actual Result**: [What actually happened]
**Screenshots**: [If applicable]
**Network**: [WiFi/Mobile/Offline]
```

## 🚀 Ready for Field Testing!

APK ini siap untuk uji lapangan dengan semua fitur utama yang telah ditest dan verified. Fokus testing pada:
1. **Real-world usage scenarios**
2. **Network connectivity variations**
3. **Multi-user collaboration**
4. **Data accuracy & sync**
5. **Performance under load**

---
*Generated: 2 September 2025*
*Build: Release (187c3ae)*
