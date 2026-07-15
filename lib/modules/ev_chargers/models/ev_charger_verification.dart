import 'package:cloud_firestore/cloud_firestore.dart';

import 'ev_charger.dart';

class EvChargerVerification {
  final String chargerId;
  final bool verified;
  final bool? isActive;
  final String? name;
  final String? city;
  final String? address;
  final String? operatorName;
  final String? access;
  final String? openingHours;
  final String? priceLabel;
  final String? note;
  final EvChargingFee? fee;
  final List<EvConnector>? connectors;
  final int? capacity;
  final DateTime? verifiedAt;

  const EvChargerVerification({
    required this.chargerId,
    required this.verified,
    this.isActive,
    this.name,
    this.city,
    this.address,
    this.operatorName,
    this.access,
    this.openingHours,
    this.priceLabel,
    this.note,
    this.fee,
    this.connectors,
    this.capacity,
    this.verifiedAt,
  });

  factory EvChargerVerification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return EvChargerVerification.fromMap(
      document.id,
      document.data() ?? const <String, dynamic>{},
    );
  }

  factory EvChargerVerification.fromMap(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final rawFee = data['feeStatus'] ?? data['fee'];
    final parsedFee = _optionalFee(rawFee);
    final rawConnectors = data['connectors'];
    final connectors = rawConnectors is List
        ? rawConnectors
              .whereType<Map>()
              .map(
                (connector) =>
                    EvConnector.fromMap(Map<String, dynamic>.from(connector)),
              )
              .toList(growable: false)
        : null;
    final rawVerifiedAt = data['verifiedAt'];

    return EvChargerVerification(
      chargerId: (data['chargerId'] ?? documentId).toString(),
      verified: (data['verified'] as bool?) ?? false,
      isActive: data['isActive'] as bool?,
      name: _optionalString(data['name']),
      city: _optionalString(data['city']),
      address: _optionalString(data['address']),
      operatorName: _optionalString(data['operatorName'] ?? data['operator']),
      access: _optionalString(data['access']),
      openingHours: _optionalString(data['openingHours']),
      priceLabel: _optionalString(data['priceLabel'] ?? data['price']),
      note: _optionalString(data['note']),
      fee: parsedFee,
      connectors: connectors,
      capacity: (data['capacity'] as num?)?.toInt(),
      verifiedAt: rawVerifiedAt is Timestamp
          ? rawVerifiedAt.toDate()
          : rawVerifiedAt is DateTime
          ? rawVerifiedAt
          : DateTime.tryParse(rawVerifiedAt?.toString() ?? ''),
    );
  }

  EvCharger applyTo(EvCharger charger) {
    return charger.copyWith(
      name: name,
      city: city,
      address: address,
      operatorName: operatorName,
      access: access,
      openingHours: openingHours,
      priceLabel: priceLabel,
      note: note,
      fee: fee,
      connectors: connectors,
      capacity: capacity,
      isActive: isActive,
      isVerified: verified,
      verifiedAt: verifiedAt,
    );
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static EvChargingFee? _optionalFee(Object? value) {
    if (value == null) return null;

    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'unknown' ||
        normalized == 'nepoznato' ||
        normalized == 'nepoznata') {
      return EvChargingFee.unknown;
    }

    final parsed = EvCharger.parseFee(value);
    return parsed == EvChargingFee.unknown ? null : parsed;
  }
}
