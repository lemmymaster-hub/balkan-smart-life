import 'package:google_navigation_flutter/google_navigation_flutter.dart';

class AtmLocation {
  final String id;
  final String bankName;
  final String name;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final bool cashDeposit;
  final bool is24h;
  final String source;

  const AtmLocation({
    required this.id,
    required this.bankName,
    required this.name,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.cashDeposit = false,
    this.is24h = false,
    this.source = 'OpenStreetMap',
  });

  LatLng get position => LatLng(latitude: latitude, longitude: longitude);

  String get displayName {
    if (name.trim().isNotEmpty && name.trim() != bankName.trim()) return name;
    return '$bankName bankomat';
  }

  String get subtitle {
    final value = address.trim();
    return value.isEmpty ? city : value;
  }
}
