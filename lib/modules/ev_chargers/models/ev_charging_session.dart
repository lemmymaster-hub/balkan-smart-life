enum EvChargingSessionSource { estimated, operatorLive }

enum EvChargingSessionStatus { preparing, charging, paused, completed, failed }

class EvChargingSession {
  final String id;
  final String chargerId;
  final String chargerName;
  final String city;
  final String connectorLabel;
  final String providerName;
  final String message;
  final EvChargingSessionSource source;
  final EvChargingSessionStatus status;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? endedAt;
  final double? ratedPowerKw;
  final double? powerKw;
  final double? energyKwh;
  final double? batteryPercent;

  const EvChargingSession({
    required this.id,
    required this.chargerId,
    required this.chargerName,
    required this.city,
    required this.connectorLabel,
    required this.source,
    required this.status,
    required this.startedAt,
    required this.updatedAt,
    this.providerName = '',
    this.message = '',
    this.endedAt,
    this.ratedPowerKw,
    this.powerKw,
    this.energyKwh,
    this.batteryPercent,
  });

  bool get isActive =>
      status == EvChargingSessionStatus.preparing ||
      status == EvChargingSessionStatus.charging ||
      status == EvChargingSessionStatus.paused;

  bool get isEstimated => source == EvChargingSessionSource.estimated;

  Duration elapsedAt(DateTime now) {
    final effectiveEnd = endedAt ?? now;
    if (!effectiveEnd.isAfter(startedAt)) return Duration.zero;
    return effectiveEnd.difference(startedAt);
  }

  double energyAt(DateTime now) {
    if (!isEstimated || !isActive) return energyKwh ?? 0;

    final nominalPower = ratedPowerKw ?? powerKw;
    if (nominalPower == null || nominalPower <= 0) return energyKwh ?? 0;

    final elapsedHours = elapsedAt(now).inSeconds / 3600;
    return nominalPower * elapsedHours;
  }

  EvChargingSession complete(DateTime endedAt) {
    return copyWith(
      status: EvChargingSessionStatus.completed,
      updatedAt: endedAt,
      endedAt: endedAt,
      energyKwh: energyAt(endedAt),
      message: 'Procijenjeno praćenje je završeno.',
    );
  }

  EvChargingSession copyWith({
    String? id,
    String? chargerId,
    String? chargerName,
    String? city,
    String? connectorLabel,
    String? providerName,
    String? message,
    EvChargingSessionSource? source,
    EvChargingSessionStatus? status,
    DateTime? startedAt,
    DateTime? updatedAt,
    DateTime? endedAt,
    double? ratedPowerKw,
    double? powerKw,
    double? energyKwh,
    double? batteryPercent,
  }) {
    return EvChargingSession(
      id: id ?? this.id,
      chargerId: chargerId ?? this.chargerId,
      chargerName: chargerName ?? this.chargerName,
      city: city ?? this.city,
      connectorLabel: connectorLabel ?? this.connectorLabel,
      providerName: providerName ?? this.providerName,
      message: message ?? this.message,
      source: source ?? this.source,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      endedAt: endedAt ?? this.endedAt,
      ratedPowerKw: ratedPowerKw ?? this.ratedPowerKw,
      powerKw: powerKw ?? this.powerKw,
      energyKwh: energyKwh ?? this.energyKwh,
      batteryPercent: batteryPercent ?? this.batteryPercent,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'chargerId': chargerId,
      'chargerName': chargerName,
      'city': city,
      'connectorLabel': connectorLabel,
      'providerName': providerName,
      'message': message,
      'source': source.name,
      'status': status.name,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
      if (ratedPowerKw != null) 'ratedPowerKw': ratedPowerKw,
      if (powerKw != null) 'powerKw': powerKw,
      if (energyKwh != null) 'energyKwh': energyKwh,
      if (batteryPercent != null) 'batteryPercent': batteryPercent,
    };
  }

  factory EvChargingSession.fromMap(
    Map<String, dynamic> data, {
    EvChargingSessionSource? forcedSource,
  }) {
    final startedAt = _dateTime(data['startedAt']);
    final updatedAt = _dateTime(data['updatedAt']) ?? startedAt;

    if (startedAt == null || updatedAt == null) {
      throw const FormatException('Sesija punjenja nema ispravno vrijeme.');
    }

    final chargerId = (data['chargerId'] ?? '').toString().trim();
    if (chargerId.isEmpty) {
      throw const FormatException('Sesija punjenja nema ID punjača.');
    }

    return EvChargingSession(
      id: (data['id'] ?? data['sessionId'] ?? chargerId).toString(),
      chargerId: chargerId,
      chargerName: (data['chargerName'] ?? 'EL punjač').toString(),
      city: (data['city'] ?? '').toString(),
      connectorLabel: (data['connectorLabel'] ?? data['connectorId'] ?? '')
          .toString(),
      providerName: (data['providerName'] ?? data['provider'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      source: forcedSource ?? _source(data['source']),
      status: _status(data['status']),
      startedAt: startedAt,
      updatedAt: updatedAt,
      endedAt: _dateTime(data['endedAt'] ?? data['stoppedAt']),
      ratedPowerKw: _number(data['ratedPowerKw']),
      powerKw: _number(data['powerKw'] ?? data['currentPowerKw']),
      energyKwh: _number(data['energyKwh']),
      batteryPercent: _percent(data['batteryPercent'] ?? data['stateOfCharge']),
    );
  }

  static EvChargingSessionSource _source(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'operatorlive' ||
        normalized == 'operator_live' ||
        normalized == 'live') {
      return EvChargingSessionSource.operatorLive;
    }
    return EvChargingSessionSource.estimated;
  }

  static EvChargingSessionStatus _status(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'preparing':
      case 'pending':
      case 'starting':
        return EvChargingSessionStatus.preparing;
      case 'paused':
      case 'suspended':
      case 'suspended_ev':
      case 'suspended_evse':
        return EvChargingSessionStatus.paused;
      case 'completed':
      case 'finished':
      case 'stopped':
        return EvChargingSessionStatus.completed;
      case 'failed':
      case 'error':
      case 'invalid':
        return EvChargingSessionStatus.failed;
      default:
        return EvChargingSessionStatus.charging;
    }
  }

  static DateTime? _dateTime(Object? value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static double? _percent(Object? value) {
    final parsed = _number(value);
    if (parsed == null) return null;
    return parsed.clamp(0, 100).toDouble();
  }
}
