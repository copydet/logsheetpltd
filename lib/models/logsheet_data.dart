class LogsheetData {
  final String generatorName;
  final double jamOperasi;
  final double rpm;
  final double lubeOilTemp;
  final double oilPressure;
  final double waterTemp;
  final double teganganAccu;
  final double beban;
  final double voltageR;
  final double voltageS;
  final double voltageT;
  final double ampereR;
  final double ampereS;
  final double ampereT;
  final double kvar;
  final double hz;
  final double cosPhi;
  final double tempWindingU;
  final double tempWindingV;
  final double tempWindingW;
  final double tempBearing;
  final double enginePressureCrankcase;
  final double engineTempExhaust;
  final DateTime timestamp;

  LogsheetData({
    required this.generatorName,
    required this.jamOperasi,
    required this.rpm,
    required this.lubeOilTemp,
    required this.oilPressure,
    required this.waterTemp,
    required this.teganganAccu,
    required this.beban,
    required this.voltageR,
    required this.voltageS,
    required this.voltageT,
    required this.ampereR,
    required this.ampereS,
    required this.ampereT,
    required this.kvar,
    required this.hz,
    required this.cosPhi,
    required this.tempWindingU,
    required this.tempWindingV,
    required this.tempWindingW,
    required this.tempBearing,
    required this.enginePressureCrankcase,
    required this.engineTempExhaust,
    required this.timestamp,
  });

  LogsheetData copyWith({
    String? generatorName,
    double? jamOperasi,
    double? rpm,
    double? lubeOilTemp,
    double? oilPressure,
    double? waterTemp,
    double? teganganAccu,
    double? beban,
    double? voltageR,
    double? voltageS,
    double? voltageT,
    double? ampereR,
    double? ampereS,
    double? ampereT,
    double? kvar,
    double? hz,
    double? cosPhi,
    double? tempWindingU,
    double? tempWindingV,
    double? tempWindingW,
    double? tempBearing,
    double? enginePressureCrankcase,
    double? engineTempExhaust,
    DateTime? timestamp,
  }) {
    return LogsheetData(
      generatorName: generatorName ?? this.generatorName,
      jamOperasi: jamOperasi ?? this.jamOperasi,
      rpm: rpm ?? this.rpm,
      lubeOilTemp: lubeOilTemp ?? this.lubeOilTemp,
      oilPressure: oilPressure ?? this.oilPressure,
      waterTemp: waterTemp ?? this.waterTemp,
      teganganAccu: teganganAccu ?? this.teganganAccu,
      beban: beban ?? this.beban,
      voltageR: voltageR ?? this.voltageR,
      voltageS: voltageS ?? this.voltageS,
      voltageT: voltageT ?? this.voltageT,
      ampereR: ampereR ?? this.ampereR,
      ampereS: ampereS ?? this.ampereS,
      ampereT: ampereT ?? this.ampereT,
      kvar: kvar ?? this.kvar,
      hz: hz ?? this.hz,
      cosPhi: cosPhi ?? this.cosPhi,
      tempWindingU: tempWindingU ?? this.tempWindingU,
      tempWindingV: tempWindingV ?? this.tempWindingV,
      tempWindingW: tempWindingW ?? this.tempWindingW,
      tempBearing: tempBearing ?? this.tempBearing,
      enginePressureCrankcase:
          enginePressureCrankcase ?? this.enginePressureCrankcase,
      engineTempExhaust: engineTempExhaust ?? this.engineTempExhaust,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'generatorName': generatorName,
      'jamOperasi': jamOperasi.toString(),
      'rpm': rpm.toString(),
      'lubeOilTemp': lubeOilTemp.toString(),
      'oilPressure': oilPressure.toString(),
      'waterTemp': waterTemp.toString(),
      'teganganAccu': teganganAccu.toString(),
      'beban': beban.toString(),
      'voltageR': voltageR.toString(),
      'voltageS': voltageS.toString(),
      'voltageT': voltageT.toString(),
      'ampereR': ampereR.toString(),
      'ampereS': ampereS.toString(),
      'ampereT': ampereT.toString(),
      'kvar': kvar.toString(),
      'hz': hz.toString(),
      'cosPhi': cosPhi.toString(),
      'tempWindingU': tempWindingU.toString(),
      'tempWindingV': tempWindingV.toString(),
      'tempWindingW': tempWindingW.toString(),
      'tempBearing': tempBearing.toString(),
      'enginePressureCrankcase': enginePressureCrankcase.toString(),
      'engineTempExhaust': engineTempExhaust.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LogsheetData.fromJson(Map<String, dynamic> json) {
    return LogsheetData(
      generatorName: json['generatorName'] ?? '',
      jamOperasi: double.tryParse(json['jamOperasi']?.toString() ?? '0') ?? 0,
      rpm: double.tryParse(json['rpm']?.toString() ?? '0') ?? 0,
      lubeOilTemp: double.tryParse(json['lubeOilTemp']?.toString() ?? '0') ?? 0,
      oilPressure: double.tryParse(json['oilPressure']?.toString() ?? '0') ?? 0,
      waterTemp: double.tryParse(json['waterTemp']?.toString() ?? '0') ?? 0,
      teganganAccu:
          double.tryParse(json['teganganAccu']?.toString() ?? '0') ?? 0,
      beban: double.tryParse(json['beban']?.toString() ?? '0') ?? 0,
      voltageR: double.tryParse(json['voltageR']?.toString() ?? '0') ?? 0,
      voltageS: double.tryParse(json['voltageS']?.toString() ?? '0') ?? 0,
      voltageT: double.tryParse(json['voltageT']?.toString() ?? '0') ?? 0,
      ampereR: double.tryParse(json['ampereR']?.toString() ?? '0') ?? 0,
      ampereS: double.tryParse(json['ampereS']?.toString() ?? '0') ?? 0,
      ampereT: double.tryParse(json['ampereT']?.toString() ?? '0') ?? 0,
      kvar: double.tryParse(json['kvar']?.toString() ?? '0') ?? 0,
      hz: double.tryParse(json['hz']?.toString() ?? '0') ?? 0,
      cosPhi: double.tryParse(json['cosPhi']?.toString() ?? '0') ?? 0,
      tempWindingU:
          double.tryParse(json['tempWindingU']?.toString() ?? '0') ?? 0,
      tempWindingV:
          double.tryParse(json['tempWindingV']?.toString() ?? '0') ?? 0,
      tempWindingW:
          double.tryParse(json['tempWindingW']?.toString() ?? '0') ?? 0,
      tempBearing: double.tryParse(json['tempBearing']?.toString() ?? '0') ?? 0,
      enginePressureCrankcase:
          double.tryParse(json['enginePressureCrankcase']?.toString() ?? '0') ??
          0,
      engineTempExhaust:
          double.tryParse(json['engineTempExhaust']?.toString() ?? '0') ?? 0,
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  factory LogsheetData.empty(String generatorName) {
    return LogsheetData(
      generatorName: generatorName,
      jamOperasi: 0,
      rpm: 0,
      lubeOilTemp: 0,
      oilPressure: 0,
      waterTemp: 0,
      teganganAccu: 0,
      beban: 0,
      voltageR: 0,
      voltageS: 0,
      voltageT: 0,
      ampereR: 0,
      ampereS: 0,
      ampereT: 0,
      kvar: 0,
      hz: 0,
      cosPhi: 0,
      tempWindingU: 0,
      tempWindingV: 0,
      tempWindingW: 0,
      tempBearing: 0,
      enginePressureCrankcase: 0,
      engineTempExhaust: 0,
      timestamp: DateTime.now(),
    );
  }

  bool get hasData {
    return jamOperasi > 0 ||
        rpm > 0 ||
        lubeOilTemp > 0 ||
        oilPressure > 0 ||
        waterTemp > 0 ||
        teganganAccu > 0 ||
        beban > 0;
  }
}
