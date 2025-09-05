/// Utility functions for Firestore collection management
class FirestoreCollectionUtils {
  /// Ubah generator name to collection name
  /// "Mitsubishi #1" -> "mitsubishi_1"
  /// "Mitsubishi #2" -> "mitsubishi_2"
  static String getCollectionName(String generatorName) {
    return generatorName
        .toLowerCase()
        .replaceAll('#', '')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  /// Ambil all generator collection names
  static List<String> getAllCollectionNames() {
    return ['mitsubishi_1', 'mitsubishi_2', 'mitsubishi_3', 'mitsubishi_4'];
  }

  /// Ubah collection name back to generator name
  /// "mitsubishi_1" -> "Mitsubishi #1"
  static String getGeneratorName(String collectionName) {
    switch (collectionName) {
      case 'mitsubishi_1':
        return 'Mitsubishi #1';
      case 'mitsubishi_2':
        return 'Mitsubishi #2';
      case 'mitsubishi_3':
        return 'Mitsubishi #3';
      case 'mitsubishi_4':
        return 'Mitsubishi #4';
      default:
        // Fallback: convert back from snake_case
        return collectionName
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  /// Ambil collection name for a specific generator ID
  static String getCollectionNameById(int generatorId) {
    switch (generatorId) {
      case 1:
        return 'mitsubishi_1';
      case 2:
        return 'mitsubishi_2';
      case 3:
        return 'mitsubishi_3';
      case 4:
        return 'mitsubishi_4';
      default:
        throw ArgumentError('Unknown generator ID: $generatorId');
    }
  }

  /// Validasi collection name
  static bool isValidCollectionName(String collectionName) {
    return getAllCollectionNames().contains(collectionName);
  }
}
