# Manual Generator Switch Feature

## Overview
Mengubah sistem switch on/off generator dari otomatis (berdasarkan logsheet) menjadi manual dengan sinkronisasi antar device.

## Changes Made

### 1. Model Baru: `GeneratorStatus`
- **File**: `lib/models/generator_status.dart`
- **Fungsi**: Model untuk menyimpan status generator manual dengan metadata sync
- **Properties**:
  - `generatorName`: Nama generator
  - `isActive`: Status aktif/standby
  - `lastUpdated`: Waktu update terakhir
  - `updatedBy`: User yang melakukan update
  - `deviceId`: ID device yang melakukan update

### 2. Service Baru: `GeneratorStatusSyncService`
- **File**: `lib/services/generator_status_sync_service.dart`
- **Fungsi**: Menangani sinkronisasi status generator manual antar device
- **Features**:
  - Upload status ke Firestore
  - Download status terbaru dari Firestore
  - Real-time listener untuk perubahan status
  - Batch upload untuk multiple generators
  - Device ID management untuk conflict resolution

### 3. Dashboard Updates
- **File**: `lib/screens/dashboard_screen.dart`
- **Changes**:
  - Setup real-time sync untuk generator status
  - Modifikasi `_updateGeneratorStatus()` untuk menggunakan sync manual
  - Update `_loadStoredFileIds()` untuk mempertahankan status manual
  - Enhanced dialog konfirmasi dengan informasi manual control

### 4. UI/UX Improvements
- **Switch Description**: Mengubah deskripsi status dari "Genset mesin aktif" menjadi "Mesin dinyalakan secara manual"
- **Dialog Enhancement**: Menambahkan informasi bahwa switch bersifat manual dan tidak dipengaruhi logsheet
- **Visual Indicators**: Menambahkan info box yang menjelaskan kontrol manual

## Key Features

### Manual Control
✅ Switch on/off tidak bergantung pada keberadaan logsheet  
✅ Status disimpan secara persisten di local storage (SQLite + SharedPreferences)  
✅ User dapat mengontrol status generator secara manual  

### Multi-Device Sync
✅ Status disinkronkan ke Firestore untuk sharing antar device  
✅ Real-time listener untuk update dari device lain  
✅ Conflict resolution berdasarkan timestamp dan device ID  
✅ Auto-sync saat ada perubahan status  

### Data Integrity
✅ Fallback system: SQLite → SharedPreferences → Firestore  
✅ Konsistensi data antar storage systems  
✅ Error handling untuk sync failures  

## User Experience
1. **Manual Switch**: User dapat toggle on/off kapan saja
2. **Konfirmasi Dialog**: Dialog informatif sebelum mengubah status
3. **Real-time Update**: Status berubah instant di semua device
4. **Visual Feedback**: Status indicator yang jelas (ON/OFF dengan warna)
5. **Logsheet Independence**: Switch tidak terpengaruh ada/tidaknya logsheet

## Technical Architecture
```
User Action → Dashboard UI → Local Storage → Sync Service → Firestore → Other Devices
```

1. User toggle switch di dashboard
2. Status disimpan ke SQLite dan SharedPreferences
3. GeneratorStatusSyncService upload ke Firestore
4. Device lain receive real-time update
5. Status otomatis tersinkron di semua device

## Testing Checklist
- [ ] Manual toggle switch works
- [ ] Status persisted after app restart
- [ ] Multi-device sync functional
- [ ] Dialog shows correct information
- [ ] No interference from logsheet status
- [ ] Real-time updates working
- [ ] Error handling works properly

## Future Enhancements
- Add status history/audit trail
- Implement user permission levels
- Add batch toggle for multiple generators
- Enhanced conflict resolution
- Status change notifications
