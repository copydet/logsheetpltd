/// Model untuk sinkronisasi status generator antar device
class GeneratorStatus {
  final String generatorName;
  final bool isActive;
  final DateTime lastUpdated;
  final String updatedBy;
  final String deviceId;

  GeneratorStatus({
    required this.generatorName,
    required this.isActive,
    required this.lastUpdated,
    required this.updatedBy,
    required this.deviceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'generatorName': generatorName,
      'isActive': isActive,
      'lastUpdated': lastUpdated.toIso8601String(),
      'updatedBy': updatedBy,
      'deviceId': deviceId,
      'syncedAt': DateTime.now().toIso8601String(),
    };
  }

  factory GeneratorStatus.fromMap(Map<String, dynamic> map) {
    return GeneratorStatus(
      generatorName: map['generatorName'] ?? '',
      isActive: map['isActive'] ?? false,
      lastUpdated:
          DateTime.tryParse(map['lastUpdated'] ?? '') ?? DateTime.now(),
      updatedBy: map['updatedBy'] ?? '',
      deviceId: map['deviceId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'generatorName': generatorName,
      'isActive': isActive,
      'lastUpdated': lastUpdated,
      'updatedBy': updatedBy,
      'deviceId': deviceId,
      'syncedAt': DateTime.now(),
    };
  }

  factory GeneratorStatus.fromFirestore(Map<String, dynamic> data) {
    return GeneratorStatus(
      generatorName: data['generatorName'] ?? '',
      isActive: data['isActive'] ?? false,
      lastUpdated: (data['lastUpdated'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedBy: data['updatedBy'] ?? '',
      deviceId: data['deviceId'] ?? '',
    );
  }
}
