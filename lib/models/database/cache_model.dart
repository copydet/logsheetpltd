import 'dart:convert';

/// ============================================================================
/// LOGSHEET CACHE MODEL
/// ============================================================================
/// Model untuk cache logsheet data di SQLite database
/// ============================================================================

class LogsheetCache {
  final int? id;
  final String fileId;
  final String generatorName;
  final int hour;
  final String date; // YYYYMMDD format
  final bool hasData;
  final Map<String, dynamic>? dataJson;
  final DateTime? cachedAt;
  final DateTime? expiresAt;

  LogsheetCache({
    this.id,
    required this.fileId,
    required this.generatorName,
    required this.hour,
    required this.date,
    this.hasData = false,
    this.dataJson,
    this.cachedAt,
    this.expiresAt,
  });

  factory LogsheetCache.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? parsedDataJson;
    if (map['data_json'] != null) {
      try {
        parsedDataJson = json.decode(map['data_json'] as String);
      } catch (e) {
        print(' parsing data_json: $e');
        parsedDataJson = null;
      }
    }

    return LogsheetCache(
      id: map['id'] as int?,
      fileId: map['file_id'] as String,
      generatorName: map['generator_name'] as String,
      hour: map['hour'] as int,
      date: map['date'] as String,
      hasData: (map['has_data'] as int) == 1,
      dataJson: parsedDataJson,
      cachedAt: map['cached_at'] != null
          ? DateTime.parse(map['cached_at'] as String)
          : null,
      expiresAt: map['expires_at'] != null
          ? DateTime.parse(map['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'file_id': fileId,
      'generator_name': generatorName,
      'hour': hour,
      'date': date,
      'has_data': hasData ? 1 : 0,
      'data_json': dataJson != null ? json.encode(dataJson) : null,
    };

    if (id != null) {
      map['id'] = id;
    }

    if (cachedAt != null) {
      map['cached_at'] = cachedAt!.toIso8601String();
    }

    if (expiresAt != null) {
      map['expires_at'] = expiresAt!.toIso8601String();
    }

    return map;
  }

  /// Cek if cache is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Cek if cache is valid
  bool get isValid => !isExpired && hasData;

  LogsheetCache copyWith({
    int? id,
    String? fileId,
    String? generatorName,
    int? hour,
    String? date,
    bool? hasData,
    Map<String, dynamic>? dataJson,
    DateTime? cachedAt,
    DateTime? expiresAt,
  }) {
    return LogsheetCache(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
      generatorName: generatorName ?? this.generatorName,
      hour: hour ?? this.hour,
      date: date ?? this.date,
      hasData: hasData ?? this.hasData,
      dataJson: dataJson ?? this.dataJson,
      cachedAt: cachedAt ?? this.cachedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  String toString() {
    return 'LogsheetCache(fileId: $fileId, generator: $generatorName, hour: $hour, date: $date, hasData: $hasData, isExpired: $isExpired)';
  }
}

/// ============================================================================
/// AturTINGS MODEL
/// ============================================================================

class Setting {
  final String key;
  final String value;
  final DateTime? updatedAt;

  Setting({required this.key, required this.value, this.updatedAt});

  factory Setting.fromMap(Map<String, dynamic> map) {
    return Setting(
      key: map['key'] as String,
      value: map['value'] as String,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'key': key, 'value': value};

    if (updatedAt != null) {
      map['updated_at'] = updatedAt!.toIso8601String();
    }

    return map;
  }

  /// Parse value as bool
  bool get boolValue {
    return value.toLowerCase() == 'true' || value == '1';
  }

  /// Parse value as int
  int? get intValue {
    return int.tryParse(value);
  }

  /// Parse value as double
  double? get doubleValue {
    return double.tryParse(value);
  }

  /// Parse value as JSON
  Map<String, dynamic>? get jsonValue {
    try {
      return json.decode(value);
    } catch (e) {
      return null;
    }
  }

  Setting copyWith({String? key, String? value, DateTime? updatedAt}) {
    return Setting(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Setting(key: $key, value: $value)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Setting && other.key == key && other.value == value;
  }

  @override
  int get hashCode {
    return key.hashCode ^ value.hashCode;
  }
}
