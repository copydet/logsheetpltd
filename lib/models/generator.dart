class Generator {
  final int id;
  final String name;
  final String status;
  final double temperature;
  final double pressure;
  final double operationHours;
  final String? activeFileId;

  Generator({
    required this.id,
    required this.name,
    required this.status,
    required this.temperature,
    required this.pressure,
    required this.operationHours,
    this.activeFileId,
  });

  Generator copyWith({
    int? id,
    String? name,
    String? status,
    double? temperature,
    double? pressure,
    double? operationHours,
    String? activeFileId,
  }) {
    return Generator(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      temperature: temperature ?? this.temperature,
      pressure: pressure ?? this.pressure,
      operationHours: operationHours ?? this.operationHours,
      activeFileId: activeFileId ?? this.activeFileId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'temperature': temperature,
      'pressure': pressure,
      'operationHours': operationHours,
      'activeFileId': activeFileId,
    };
  }

  factory Generator.fromJson(Map<String, dynamic> json) {
    return Generator(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      status: json['status'] ?? 'OFFLINE',
      temperature: (json['temperature'] ?? 0).toDouble(),
      pressure: (json['pressure'] ?? 0).toDouble(),
      operationHours: (json['operationHours'] ?? 0).toDouble(),
      activeFileId: json['activeFileId'],
    );
  }
}
