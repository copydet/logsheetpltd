# 📊 Logsheet Pembangkit Listrik

Aplikasi monitoring dan pencatatan data operasional generator pembangkit listrik secara real-time. Dikembangkan dengan Flutter menggunakan arsitektur hybrid (SQLite + Firestore + Google Sheets).

## 🚀 Quick Start

```bash
# Clone dan setup
git clone [repository-url]
cd flutter_coba3
flutter pub get

# Konfigurasi Firebase
# 1. Setup Firebase project
# 2. Download google-services.json (Android)
# 3. Update firebase_options.dart

# Run aplikasi
flutter run
```

## 🏗️ Arsitektur

```
📱 Flutter App
├── 🗄️ SQLite (Local Storage)
├── ☁️ Firestore (Cloud Sync)  
├── 📊 Google Sheets (Export)
└── 💾 Google Drive (Files)
```

## 📱 Fitur Utama

- **Dashboard Real-time** - Monitoring 4 generator Mitsubishi
- **Input Logsheet** - Form input dengan validasi otomatis
- **Grafik Suhu** - Chart real-time parameter kritis
- **Riwayat Data** - Historical dengan filter dan search
- **Download Export** - Excel & PDF via Google Drive
- **Multi-user** - Role-based access (Manager/Leader/Operator)

## 🛠️ Tech Stack

- **Frontend**: Flutter 3.x, Dart, fl_chart
- **Database**: SQLite (local) + Firestore (cloud)
- **APIs**: Google Sheets API, Google Drive API
- **State**: Provider pattern
- **Architecture**: Clean Architecture + Repository pattern

## 📂 Struktur Kode

```
lib/
├── 📱 screens/          # UI Screens
├── 🔧 services/         # Business Logic
├── 📊 models/           # Data Models  
├── 🧩 widgets/          # Reusable Components
├── 🛠️ utils/            # Helper Functions
├── ⚙️ config/           # App Configuration
└── 📋 constants/        # App Constants
```

## 🔐 User Authentication

**Firebase Authentication + Firestore Profiles**

| Role | Username | Email | Access |
|------|----------|-------|---------|
| Operator | dimas | dimas@pltd.com | Edit logsheets, Export data, View all generators |

**Authentication Method:**
- Firebase Auth dengan email/password
- User profile tersimpan di Firestore
- Login menggunakan username (converted ke email format)
- Role-based permissions dari Firestore

## 📊 Data Generator

Aplikasi monitoring 4 unit generator:
- **Mitsubishi #1** - Primary unit
- **Mitsubishi #2** - Secondary unit  
- **Mitsubishi #3** - Backup unit
- **Mitsubishi #4** - Reserve unit

## 🔄 Data Flow

1. **Input** → Form logsheet dengan validasi
2. **Local** → Simpan di SQLite untuk offline access
3. **Sync** → Upload ke Firestore untuk backup
4. **Export** → Generate Google Sheets untuk audit
5. **Download** → Export Excel/PDF via Google Drive

## 🐛 Troubleshooting

### Common Issues
```bash
# Build issues
flutter clean && flutter pub get

# Firebase connection
# Periksa google-services.json dan firebase_options.dart

# Download error di emulator
# Gunakan copy URL manual untuk testing

# Database migration
# Hapus app data dan reinstall
```

## 📝 Development

```bash
# Debug mode
flutter run --debug

# Release build  
flutter build apk --release

# Analyze code
flutter analyze

# Run tests
flutter test
```