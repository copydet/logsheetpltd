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
    for (int i = 0; i < _generators.length; i++) {
      final name = _generators[i]['name'];
      final fileId = await StorageService.getActiveFileId(name) ?? '';
      final isActive = await StorageService.getGeneratorStatus(name) ?? false;

      _generators[i]['fileId'] = fileId;
      _generators[i]['isActive'] = isActive;
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
}
