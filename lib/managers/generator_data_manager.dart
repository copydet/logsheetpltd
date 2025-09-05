import '../app_exports.dart';

class GeneratorDataManager {
  static final List<Map<String, dynamic>> _generators = [
    {'name': 'Mitsubishi #1', 'fileId': '', 'isActive': false},
    {'name': 'Mitsubishi #2', 'fileId': '', 'isActive': false},
    {'name': 'Mitsubishi #3', 'fileId': '', 'isActive': false},
    {'name': 'Mitsubishi #4', 'fileId': '', 'isActive': false},
  ];

  static List<Map<String, dynamic>> get generators =>
      List.unmodifiable(_generators);

  static Future<void> loadGeneratorData() async {
    print('🔄 GENERATOR_DATA: Loading generator data...');

    for (int i = 0; i < _generators.length; i++) {
      final name = _generators[i]['name'];

      // Bersihkanup file ID lama dulu
      await StorageService.cleanupOldFileIds(name);

      final fileId = await StorageService.getActiveFileId(name) ?? '';
      final isActive = await StorageService.getGeneratorStatus(name) ?? false;

      _generators[i]['fileId'] = fileId;
      _generators[i]['isActive'] = isActive;

      print(
        '🔄 GENERATOR_DATA: $name -> fileId: ${fileId.isEmpty ? "EMPTY" : fileId.substring(0, 10)}..., active: $isActive',
      );
    }
  }

  static Map<String, dynamic>? getGeneratorByName(String name) {
    try {
      return _generators.firstWhere((gen) => gen['name'] == name);
    } catch (e) {
      return null;
    }
  }

  static bool hasDataForGenerator(String name) {
    final generator = getGeneratorByName(name);
    return generator != null && generator['fileId'].toString().isNotEmpty;
  }

  // Update file ID untuk generator tertentu
  static Future<void> updateGeneratorFileId(String name, String fileId) async {
    await StorageService.saveActiveFileId(name, fileId);

    // Update in-memory data
    final generator = getGeneratorByName(name);
    if (generator != null) {
      final index = _generators.indexWhere((gen) => gen['name'] == name);
      if (index != -1) {
        _generators[index]['fileId'] = fileId;
        print(
          '🔄 GENERATOR_DATA: Updated $name fileId to ${fileId.substring(0, 10)}...',
        );
      }
    }
  }

  // Pastikan file ID konsisten untuk hari ini (SEMUA MESIN SAMA)
  static Future<void> ensureConsistentFileId(String name) async {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    print(
      '🔍 GENERATOR_DATA: Ensuring consistent fileId for $name on $dateKey',
    );

    final currentFileId = await StorageService.getActiveFileId(name);
    if (currentFileId == null || currentFileId.isEmpty) {
      print(
        '⚠️ GENERATOR_DATA: No fileId found for $name, need to create new spreadsheet',
      );
      return;
    }

    // Update in-memory data dengan file ID yang konsisten
    final generator = getGeneratorByName(name);
    if (generator != null) {
      final index = _generators.indexWhere((gen) => gen['name'] == name);
      if (index != -1) {
        _generators[index]['fileId'] = currentFileId;
        print(
          '✅ GENERATOR_DATA: Ensured consistent fileId for $name: ${currentFileId.substring(0, 10)}...',
        );
      }
    }
  }
}
