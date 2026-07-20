import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../../../core/models/bsl_city.dart';

enum EvChargingFee { free, paid, unknown }

class EvConnector {
  final String type;
  final int? count;
  final double? powerKw;

  const EvConnector({required this.type, this.count, this.powerKw});

  EvConnector copyWith({String? type, int? count, double? powerKw}) {
    return EvConnector(
      type: type ?? this.type,
      count: count ?? this.count,
      powerKw: powerKw ?? this.powerKw,
    );
  }

  factory EvConnector.fromMap(Map<String, dynamic> data) {
    return EvConnector(
      type: (data['type'] ?? data['name'] ?? 'Nepoznat').toString(),
      count: (data['count'] as num?)?.toInt(),
      powerKw: (data['powerKw'] as num?)?.toDouble(),
    );
  }
}

class EvCharger {
  final String id;
  final String source;
  final String sourceId;
  final String name;
  final String city;
  final String address;
  final String operatorName;
  final String access;
  final String openingHours;
  final String priceLabel;
  final String note;
  final double latitude;
  final double longitude;
  final EvChargingFee fee;
  final List<EvConnector> connectors;
  final int? capacity;
  final bool isActive;
  final bool isVerified;
  final DateTime? sourceUpdatedAt;
  final DateTime? verifiedAt;

  const EvCharger({
    required this.id,
    required this.source,
    required this.sourceId,
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.operatorName = '',
    this.access = '',
    this.openingHours = '',
    this.priceLabel = '',
    this.note = '',
    this.fee = EvChargingFee.unknown,
    this.connectors = const [],
    this.capacity,
    this.isActive = true,
    this.isVerified = false,
    this.sourceUpdatedAt,
    this.verifiedAt,
  });

  LatLng get position => LatLng(latitude: latitude, longitude: longitude);

  double? get maxPowerKw {
    final values = connectors
        .map((connector) => connector.powerKw)
        .whereType<double>();

    if (values.isEmpty) return null;

    return values.reduce((current, next) => next > current ? next : current);
  }

  String? get markerLabel {
    switch (fee) {
      case EvChargingFee.free:
        return 'free';
      case EvChargingFee.paid:
        final price = priceLabel.trim();
        return price.isEmpty ? null : price;
      case EvChargingFee.unknown:
        return null;
    }
  }

  EvCharger copyWith({
    String? id,
    String? source,
    String? sourceId,
    String? name,
    String? city,
    String? address,
    String? operatorName,
    String? access,
    String? openingHours,
    String? priceLabel,
    String? note,
    double? latitude,
    double? longitude,
    EvChargingFee? fee,
    List<EvConnector>? connectors,
    int? capacity,
    bool? isActive,
    bool? isVerified,
    DateTime? sourceUpdatedAt,
    DateTime? verifiedAt,
  }) {
    return EvCharger(
      id: id ?? this.id,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      name: name ?? this.name,
      city: city ?? this.city,
      address: address ?? this.address,
      operatorName: operatorName ?? this.operatorName,
      access: access ?? this.access,
      openingHours: openingHours ?? this.openingHours,
      priceLabel: priceLabel ?? this.priceLabel,
      note: note ?? this.note,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      fee: fee ?? this.fee,
      connectors: connectors ?? this.connectors,
      capacity: capacity ?? this.capacity,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      sourceUpdatedAt: sourceUpdatedAt ?? this.sourceUpdatedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }

  factory EvCharger.fromOverpassElement({
    required Map<String, dynamic> element,
    required BslCity requestedCity,
    DateTime? sourceUpdatedAt,
  }) {
    final tags = Map<String, dynamic>.from(
      element['tags'] as Map? ?? const <String, dynamic>{},
    );
    final type = (element['type'] ?? 'node').toString();
    final rawId = (element['id'] ?? '').toString();
    final center = element['center'] as Map?;
    final latitude = _asDouble(element['lat'] ?? center?['lat']);
    final longitude = _asDouble(element['lon'] ?? center?['lon']);

    if (latitude == null || longitude == null || rawId.isEmpty) {
      throw const FormatException('OSM punjač nema ispravne koordinate.');
    }

    final operatorName = _firstNotEmpty([
      tags['operator'],
      tags['brand'],
      tags['network'],
    ]);
    final name = _firstNotEmpty([
      tags['name'],
      tags['brand'],
      tags['operator'],
      'EL punjač',
    ]);
    final priceLabel = _firstNotEmpty([
      tags['charge'],
      tags['charging:fee'],
      tags['fee:conditional'],
    ]);
    final fee = _feeFromTags(tags, priceLabel: priceLabel);
    final address = _addressFromTags(tags);
    final cityFromOsm = _firstNotEmpty([tags['addr:city']]);
    final matchedCity = BslCities.findExact(cityFromOsm);
    final operationalStatus = BslCities.normalize(
      (tags['operational_status'] ?? '').toString(),
    );

    return EvCharger(
      id: 'osm_${type}_$rawId',
      source: 'OpenStreetMap',
      sourceId: '$type/$rawId',
      name: name,
      city: matchedCity?.name ?? requestedCity.name,
      address: address,
      operatorName: operatorName,
      access: (tags['access'] ?? '').toString().trim(),
      openingHours: (tags['opening_hours'] ?? '').toString().trim(),
      priceLabel: priceLabel,
      note: (tags['description'] ?? tags['note'] ?? '').toString().trim(),
      latitude: latitude,
      longitude: longitude,
      fee: fee,
      connectors: _connectorsFromTags(tags),
      capacity: _asInt(tags['capacity']),
      isActive:
          operationalStatus != 'inactive' &&
          operationalStatus != 'closed' &&
          operationalStatus != 'out of service',
      sourceUpdatedAt: sourceUpdatedAt,
    );
  }

  static EvChargingFee parseFee(Object? value) {
    final normalized = BslCities.normalize(value?.toString() ?? '');

    if (normalized == 'no' ||
        normalized == 'free' ||
        normalized == 'besplatno') {
      return EvChargingFee.free;
    }

    if (normalized == 'yes' ||
        normalized == 'paid' ||
        normalized == 'naplata') {
      return EvChargingFee.paid;
    }

    return EvChargingFee.unknown;
  }

  static EvChargingFee _feeFromTags(
    Map<String, dynamic> tags, {
    required String priceLabel,
  }) {
    final explicitFee = parseFee(tags['fee']);
    if (explicitFee != EvChargingFee.unknown) return explicitFee;

    final normalizedPrice = BslCities.normalize(priceLabel);
    if (normalizedPrice.isEmpty) return EvChargingFee.unknown;

    if (normalizedPrice == 'no' ||
        normalizedPrice == '0' ||
        normalizedPrice == 'free') {
      return EvChargingFee.free;
    }

    return EvChargingFee.paid;
  }

  static String _addressFromTags(Map<String, dynamic> tags) {
    final fullAddress = _firstNotEmpty([tags['addr:full']]);
    if (fullAddress.isNotEmpty) return fullAddress;

    final street = _firstNotEmpty([tags['addr:street'], tags['addr:place']]);
    final houseNumber = _firstNotEmpty([tags['addr:housenumber']]);

    if (street.isEmpty) return '';
    if (houseNumber.isEmpty) return street;

    return '$street $houseNumber';
  }

  static List<EvConnector> _connectorsFromTags(Map<String, dynamic> tags) {
    final connectors = <EvConnector>[];

    for (final entry in tags.entries) {
      final key = entry.key;

      if (!key.startsWith('socket:') ||
          key.endsWith(':output') ||
          key.endsWith(':current') ||
          key.endsWith(':voltage')) {
        continue;
      }

      final type = key.substring('socket:'.length);
      final count = _asInt(entry.value);
      final power = _powerKw(tags['$key:output']);

      connectors.add(
        EvConnector(type: _connectorLabel(type), count: count, powerKw: power),
      );
    }

    final stationPower = _firstPowerKw([
      tags['charging_station:output'],
      tags['output'],
      tags['max_power'],
      tags['charging_station:max_power'],
    ]);

    if (stationPower != null) {
      for (var index = 0; index < connectors.length; index++) {
        final connector = connectors[index];
        if (connector.powerKw == null) {
          connectors[index] = connector.copyWith(powerKw: stationPower);
        }
      }
    }

    if (connectors.isEmpty && stationPower != null) {
      connectors.add(
        EvConnector(
          type: 'Nazivna snaga',
          count: _asInt(tags['capacity']),
          powerKw: stationPower,
        ),
      );
    }

    connectors.sort((first, second) => first.type.compareTo(second.type));
    return List<EvConnector>.unmodifiable(connectors);
  }

  static double? _firstPowerKw(List<Object?> values) {
    for (final value in values) {
      final power = _powerKw(value);
      if (power != null) return power;
    }
    return null;
  }

  static String _connectorLabel(String rawType) {
    switch (rawType) {
      case 'type2':
        return 'Type 2';
      case 'type2_cable':
        return 'Type 2 kabel';
      case 'type2_combo':
        return 'CCS2';
      case 'chademo':
        return 'CHAdeMO';
      case 'tesla_supercharger':
        return 'Tesla Supercharger';
      case 'schuko':
        return 'Schuko';
      default:
        return rawType
            .split('_')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }

  static double? _powerKw(Object? value) {
    if (value == null) return null;

    final raw = value.toString().trim().toLowerCase();
    final match = RegExp(r'([0-9]+(?:[.,][0-9]+)?)').firstMatch(raw);
    final numericValue = double.tryParse(
      (match?.group(1) ?? '').replaceAll(',', '.'),
    );

    if (numericValue == null) return null;
    if (raw.contains(' mw')) return numericValue * 1000;
    if (raw.contains(' w') && !raw.contains('kw')) return numericValue / 1000;

    return numericValue;
  }

  static int? _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String _firstNotEmpty(List<Object?> values) {
    for (final value in values) {
      final normalized = value?.toString().trim() ?? '';
      if (normalized.isNotEmpty) return normalized;
    }

    return '';
  }
}
