/// ============================================================================
/// TEMPERATURE DATA MODEL
/// ============================================================================
/// Model untuk temperature data di SQLite database
/// ============================================================================

class TemperatureData {
  final int? id;
  final String fileId;
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
  final DateTime? updatedAt;

  TemperatureData({
    this.id,
    required this.fileId,
    required this.hour,
    required this.date,
    required this.waterTemp,
    required this.lubeOilTemp,
    required this.tempBearing,
    required this.tempWindingU,
    required this.tempWindingV,
    required this.tempWindingW,
    required this.engineTempExhaust,
    this.createdAt,
    this.updatedAt,
  });

  factory TemperatureData.fromMap(Map<String, dynamic> map) {
    return TemperatureData(
      id: map['id'] as int?,
      fileId: map['file_id'] as String,
      hour: map['hour'] as int,
      date: map['date'] as String,
      waterTemp: (map['water_temp'] as num).toDouble(),
      lubeOilTemp: (map['lube_oil_temp'] as num).toDouble(),
      tempBearing: (map['temp_bearing'] as num).toDouble(),
      tempWindingU: (map['temp_winding_u'] as num).toDouble(),
      tempWindingV: (map['temp_winding_v'] as num).toDouble(),
      tempWindingW: (map['temp_winding_w'] as num).toDouble(),
      engineTempExhaust: (map['engine_temp_exhaust'] as num).toDouble(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_id': fileId,
      'hour': hour,
      'date': date,
      'water_temp': waterTemp,
      'lube_oil_temp': lubeOilTemp,
      'temp_bearing': tempBearing,
      'temp_winding_u': tempWindingU,
      'temp_winding_v': tempWindingV,
      'temp_winding_w': tempWindingW,
      'engine_temp_exhaust': engineTempExhaust,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      // Remove updated_at since table doesn't have this column
    };
  }

  // ========================================================================
  // UTILITY METHODS
  // ========================================================================

  /// Create copy dengan updated values
  TemperatureData copyWith({
    int? id,
    String? fileId,
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
    DateTime? updatedAt,
  }) {
    return TemperatureData(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
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
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted date untuk display
  String get formattedDate {
    if (date.length >= 8) {
      return '${date.substring(6, 8)}/${date.substring(4, 6)}/${date.substring(0, 4)}';
    }
    return date;
  }

  /// Check if temperature values are valid
  bool get isValid {
    return waterTemp >= 0 &&
        lubeOilTemp >= 0 &&
        tempBearing >= 0 &&
        tempWindingU >= 0 &&
        tempWindingV >= 0 &&
        tempWindingW >= 0 &&
        engineTempExhaust >= 0 &&
        fileId.isNotEmpty &&
        hour >= 0 &&
        hour <= 23 &&
        date.isNotEmpty;
  }

  /// Get average winding temperature
  double get averageWindingTemp {
    return (tempWindingU + tempWindingV + tempWindingW) / 3;
  }

  /// Get highest temperature value
  double get maxTemperature {
    return [
      waterTemp,
      lubeOilTemp,
      tempBearing,
      tempWindingU,
      tempWindingV,
      tempWindingW,
      engineTempExhaust,
    ].reduce((a, b) => a > b ? a : b);
  }

  /// Get lowest temperature value
  double get minTemperature {
    return [
      waterTemp,
      lubeOilTemp,
      tempBearing,
      tempWindingU,
      tempWindingV,
      tempWindingW,
      engineTempExhaust,
    ].reduce((a, b) => a < b ? a : b);
  }

  /// Convert to JSON string
  String toJson() {
    return '''
{
  "fileId": "$fileId",
  "hour": $hour,
  "date": "$date",
  "waterTemp": $waterTemp,
  "lubeOilTemp": $lubeOilTemp,
  "tempBearing": $tempBearing,
  "tempWindingU": $tempWindingU,
  "tempWindingV": $tempWindingV,
  "tempWindingW": $tempWindingW,
  "engineTempExhaust": $engineTempExhaust
}''';
  }

  @override
  String toString() {
    return 'TemperatureData(fileId: $fileId, hour: $hour, date: $date, waterTemp: $waterTemp°C, maxTemp: ${maxTemperature.toStringAsFixed(1)}°C)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TemperatureData &&
        other.fileId == fileId &&
        other.hour == hour &&
        other.date == date;
  }

  @override
  int get hashCode {
    return fileId.hashCode ^ hour.hashCode ^ date.hashCode;
  }
}
