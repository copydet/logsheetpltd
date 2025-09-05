/// ============================================================================
/// GENERATOR MODEL
/// ============================================================================
/// Model untuk generator data di SQLite database
/// ============================================================================

class Generator {
  final int? id;
  final String name;
  final bool isActive;
  final String? activeFileId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Generator({
    this.id,
    required this.name,
    this.isActive = false,
    this.activeFileId,
    this.createdAt,
    this.updatedAt,
  });

  factory Generator.fromMap(Map<String, dynamic> map) {
    return Generator(
      id: map['id'] as int?,
      name: map['name'] as String,
      isActive: (map['is_active'] as int) == 1,
      activeFileId: map['active_file_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'is_active': isActive ? 1 : 0,
      'active_file_id': activeFileId,
    };

    if (id != null) {
      map['id'] = id;
    }

    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }

    if (updatedAt != null) {
      map['updated_at'] = updatedAt!.toIso8601String();
    }

    return map;
  }

  Generator copyWith({
    int? id,
    String? name,
    bool? isActive,
    String? activeFileId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Generator(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      activeFileId: activeFileId ?? this.activeFileId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Generator(id: $id, name: $name, isActive: $isActive, activeFileId: $activeFileId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Generator &&
        other.id == id &&
        other.name == name &&
        other.isActive == isActive &&
        other.activeFileId == activeFileId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        isActive.hashCode ^
        activeFileId.hashCode;
  }
}

/// ============================================================================
/// TEMPERATURE DATA MODEL
/// ============================================================================

class TemperatureData {
  final int? id;
  final String fileId;
  final int? generatorId;
  final int hour;
  final String date; // YYYYMMDD format
  final double waterTemp;
  final double lubeOilTemp;
  final double tempBearing;
  final double tempWindingU;
  final double tempWindingV;
  final double tempWindingW;
  final double engineTempExhaust;
  final DateTime? createdAt;

  TemperatureData({
    this.id,
    required this.fileId,
    this.generatorId,
    required this.hour,
    required this.date,
    this.waterTemp = 0.0,
    this.lubeOilTemp = 0.0,
    this.tempBearing = 0.0,
    this.tempWindingU = 0.0,
    this.tempWindingV = 0.0,
    this.tempWindingW = 0.0,
    this.engineTempExhaust = 0.0,
    this.createdAt,
  });

  factory TemperatureData.fromMap(Map<String, dynamic> map) {
    return TemperatureData(
      id: map['id'] as int?,
      fileId: map['file_id'] as String,
      generatorId: map['generator_id'] as int?,
      hour: map['hour'] as int,
      date: map['date'] as String,
      waterTemp: (map['water_temp'] as num?)?.toDouble() ?? 0.0,
      lubeOilTemp: (map['lube_oil_temp'] as num?)?.toDouble() ?? 0.0,
      tempBearing: (map['temp_bearing'] as num?)?.toDouble() ?? 0.0,
      tempWindingU: (map['temp_winding_u'] as num?)?.toDouble() ?? 0.0,
      tempWindingV: (map['temp_winding_v'] as num?)?.toDouble() ?? 0.0,
      tempWindingW: (map['temp_winding_w'] as num?)?.toDouble() ?? 0.0,
      engineTempExhaust:
          (map['engine_temp_exhaust'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'file_id': fileId,
      'generator_id': generatorId,
      'hour': hour,
      'date': date,
      'water_temp': waterTemp,
      'lube_oil_temp': lubeOilTemp,
      'temp_bearing': tempBearing,
      'temp_winding_u': tempWindingU,
      'temp_winding_v': tempWindingV,
      'temp_winding_w': tempWindingW,
      'engine_temp_exhaust': engineTempExhaust,
    };

    if (id != null) {
      map['id'] = id;
    }

    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }

    return map;
  }

  /// Ambil temperature map untuk kompatibilitas dengan existing code
  Map<String, double> get temperatureMap => {
    'waterTemp': waterTemp,
    'lubeOilTemp': lubeOilTemp,
    'tempBearing': tempBearing,
    'tempWindingU': tempWindingU,
    'tempWindingV': tempWindingV,
    'tempWindingW': tempWindingW,
    'engineTempExhaust': engineTempExhaust,
  };

  /// Calculate winding average temperature
  double get tempWindingAvg => (tempWindingU + tempWindingV + tempWindingW) / 3;

  TemperatureData copyWith({
    int? id,
    String? fileId,
    int? generatorId,
    int? hour,
    String? date,
    double? waterTemp,
    double? lubeOilTemp,
    double? tempBearing,
    double? tempWindingU,
    double? tempWindingV,
    double? tempWindingW,
    double? engineTempExhaust,
    DateTime? createdAt,
  }) {
    return TemperatureData(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
      generatorId: generatorId ?? this.generatorId,
      hour: hour ?? this.hour,
      date: date ?? this.date,
      waterTemp: waterTemp ?? this.waterTemp,
      lubeOilTemp: lubeOilTemp ?? this.lubeOilTemp,
      tempBearing: tempBearing ?? this.tempBearing,
      tempWindingU: tempWindingU ?? this.tempWindingU,
      tempWindingV: tempWindingV ?? this.tempWindingV,
      tempWindingW: tempWindingW ?? this.tempWindingW,
      engineTempExhaust: engineTempExhaust ?? this.engineTempExhaust,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'TemperatureData(fileId: $fileId, hour: $hour, date: $date, waterTemp: $waterTemp°C)';
  }
}
