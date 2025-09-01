# REST API Endpoints Documentation
## Power Plant Logsheet Firebase Functions

### 📋 Ringkasan Implementation

Implementasi lengkap REST API dengan HTTP methods yang sesuai untuk aplikasi Power Plant Logsheet. API ini menggunakan Firebase Functions dan Google Drive/Sheets API untuk mengelola data logsheet generator.

---

## 🛠️ HTTP Methods yang Diimplementasikan

### 1. **GET** - Mengambil Data

#### 🔧 **GET** `/health`
- **Fungsi**: Health check API
- **Response**: Status API dan daftar endpoint yang tersedia

#### 🏭 **GET** `/generators`
- **Fungsi**: Mendapatkan daftar semua generator yang ada
- **Response**: Array generator dengan informasi file count dan file terbaru

#### 🏭 **GET** `/generators/:generatorName`
- **Fungsi**: Mendapatkan detail generator tertentu
- **Parameters**: 
  - `generatorName` (path): Nama generator
  - `limit` (query): Jumlah file yang diambil (default: 10)

#### 📖 **GET** `/logsheets/:fileId`
- **Fungsi**: Membaca data logsheet tertentu
- **Parameters**:
  - `fileId` (path): ID file Google Sheets
  - `range` (query): Range data (default: 'Sheet1!D13:AC36')
  - `includeMetadata` (query): Include file metadata (default: true)

#### 📊 **GET** `/analytics/summary`
- **Fungsi**: Analisis data logsheet untuk dashboard
- **Parameters**:
  - `days` (query): Rentang hari analisis (default: 30)

#### 🔍 **GET** `/search-files`
- **Fungsi**: Mencari file berdasarkan nama generator
- **Parameters**:
  - `generatorName` (query): Nama generator
  - `daysBack` (query): Hari ke belakang (default: 7)

#### 📋 **GET** `/list-files`
- **Fungsi**: Mendapatkan semua file logsheet

#### 🎯 **GET** `/find-file`
- **Fungsi**: Mencari file berdasarkan nama atau tanggal
- **Parameters**:
  - `fileName` (query): Nama file exact
  - `generatorName` (query): Nama generator
  - `date` (query): Tanggal target

#### ℹ️ **GET** `/file-info/:fileId`
- **Fungsi**: Mendapatkan informasi detail file
- **Parameters**:
  - `fileId` (path): ID file

#### 📊 **GET** `/folder-stats`
- **Fungsi**: Statistik folder logsheet (jumlah file, ukuran, dll)

---

### 2. **POST** - Membuat Data Baru

#### 📝 **POST** `/logsheets`
- **Fungsi**: Membuat logsheet baru dari template
- **Body**:
  ```json
  {
    "templateFileId": "string",
    "targetFolderId": "string", 
    "generatorName": "string",
    "date": "string (optional)"
  }
  ```

#### 🔄 **POST** `/logsheets/:fileId/restore`
- **Fungsi**: Restore logsheet dari trash
- **Parameters**:
  - `fileId` (path): ID file yang akan di-restore

#### 📖 **POST** `/read-logsheet`
- **Fungsi**: Membaca data spreadsheet (legacy compatibility)
- **Body**:
  ```json
  {
    "fileId": "string"
  }
  ```

#### 📝 **POST** `/create-logsheet`
- **Fungsi**: Membuat logsheet baru (legacy compatibility)
- **Body**:
  ```json
  {
    "templateFileId": "string",
    "targetFolderId": "string",
    "newFileName": "string"
  }
  ```

#### 📝 **POST** `/update-logsheet`
- **Fungsi**: Update data logsheet (legacy compatibility)
- **Body**:
  ```json
  {
    "fileId": "string",
    "data": {
      "D13": "value1",
      "E13": "value2"
    }
  }
  ```

---

### 3. **PUT** - Replace Seluruh Data

#### ✏️ **PUT** `/logsheets/:fileId`
- **Fungsi**: Replace seluruh data logsheet dalam range tertentu
- **Parameters**:
  - `fileId` (path): ID file logsheet
- **Body**:
  ```json
  {
    "range": "Sheet1!D13:AC36",
    "values": [
      ["header1", "header2", "header3"],
      ["value1", "value2", "value3"],
      ["value4", "value5", "value6"]
    ]
  }
  ```

---

### 4. **PATCH** - Update Sebagian Data

#### 🔧 **PATCH** `/logsheets/:fileId`
- **Fungsi**: Update sebagian data logsheet (partial update)
- **Parameters**:
  - `fileId` (path): ID file logsheet
- **Body**:
  ```json
  {
    "updates": {
      "D13": "120",
      "E13": "1500", 
      "F13": "85.5",
      "G13": "4.2"
    }
  }
  ```

---

### 5. **DELETE** - Hapus Data

#### 🗑️ **DELETE** `/logsheets/:fileId`
- **Fungsi**: Hapus logsheet (move to trash atau permanent)
- **Parameters**:
  - `fileId` (path): ID file logsheet
  - `permanent` (query): true untuk hapus permanen, false untuk move to trash (default: false)

---

## 🎯 Use Cases per HTTP Method

### **GET** - Untuk Menampilkan Data
- ✅ Dashboard: Load generator list, statistics, analytics
- ✅ History Screen: Baca data historical logsheet
- ✅ Detail Screen: Load data logsheet specific
- ✅ Settings: Health check, folder stats

### **POST** - Untuk Membuat Data Baru
- ✅ Create Logsheet: Buat logsheet baru dari template
- ✅ Restore Feature: Restore file dari trash
- ✅ Import Data: Import data dari sumber lain

### **PUT** - Untuk Replace Seluruh Data
- ✅ Bulk Update: Update seluruh range data sekaligus
- ✅ Template Application: Apply template data ke logsheet
- ✅ Data Migration: Migrasi data dari format lama

### **PATCH** - Untuk Update Partial
- ✅ Form Input: Update field-field specific di logsheet
- ✅ Quick Edit: Edit beberapa cell tanpa mengubah semua data
- ✅ Auto Update: Update otomatis berdasarkan sensor data

### **DELETE** - Untuk Hapus Data
- ✅ File Management: Hapus logsheet yang tidak diperlukan
- ✅ Cleanup: Bulk delete file lama
- ✅ Error Recovery: Hapus file yang corrupt

---

## 📱 Flutter Service Implementation

### RestApiService Class
```dart
// GET examples
final generators = await RestApiService.getGenerators();
final logsheet = await RestApiService.getLogsheet(fileId);
final analytics = await RestApiService.getAnalyticsSummary(days: 30);

// POST examples  
final newLogsheet = await RestApiService.createLogsheet(
  templateFileId: templateId,
  targetFolderId: folderId,
  generatorName: generatorName,
);

// PATCH example
await RestApiService.updateLogsheetData(fileId, updates: {
  'D13': '120',
  'E13': '1500',
});

// DELETE example
await RestApiService.deleteLogsheet(fileId, permanent: false);
```

---

## 🔄 Migration Path

### 1. **Immediate** (Untuk Testing)
- ✅ Gunakan GET endpoints untuk read operations
- ✅ Test PATCH untuk form updates
- ✅ Implement health check di dashboard

### 2. **Short Term** (1-2 minggu)
- 🔄 Migrate form submission dari legacy ke PATCH
- 🔄 Replace file creation dengan POST /logsheets
- 🔄 Update dashboard dengan GET /generators

### 3. **Long Term** (1 bulan)
- 🔄 Implement analytics dashboard dengan GET /analytics
- 🔄 Add bulk operations dengan PUT
- 🔄 Implement file management dengan DELETE

---

## 🚀 Benefits

### ✅ **Semantic Clarity**
- HTTP methods yang sesuai dengan operasinya
- Easier untuk debugging dan monitoring
- RESTful design yang standard

### ✅ **Better Error Handling**
- Status codes yang sesuai (200, 201, 400, 404, 500)
- Specific error messages per operation
- Proper validation per method

### ✅ **Scalability**
- Mudah untuk add caching per method
- Rate limiting per operation type
- Monitoring yang lebih granular

### ✅ **Developer Experience**
- Predictable API behavior
- Self-documenting endpoints
- Easy testing dengan tools seperti Postman

---

## 🧪 Testing Recommendations

### 1. **Unit Testing**
```bash
# Test individual endpoints
GET /health
GET /generators
POST /logsheets (with valid data)
PATCH /logsheets/:id (with partial data)
DELETE /logsheets/:id?permanent=false
```

### 2. **Integration Testing**
```bash
# Test full workflows
1. GET /generators → Select generator
2. POST /logsheets → Create new logsheet  
3. PATCH /logsheets/:id → Update data
4. GET /logsheets/:id → Verify update
5. DELETE /logsheets/:id → Cleanup
```

### 3. **Flutter Testing**
- Unit test untuk RestApiService methods
- Widget test untuk screens yang menggunakan API
- Integration test untuk complete user flows

---

## 💡 Next Steps

1. **Deploy Firebase Functions** dengan endpoints baru ✅
2. **Update Flutter App** untuk menggunakan REST API ✅
3. **Add Monitoring** untuk track usage per endpoint
4. **Implement Caching** untuk GET endpoints yang sering diakses
5. **Add Rate Limiting** untuk protect API dari abuse
6. **Create API Documentation** untuk team collaboration
