import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../../../core/models/bsl_city.dart';

class ParkingLocation {
  final String id;
  final String name;
  final String city;
  final String address;
  final double lat;
  final double lng;
  final int totalSpots;
  final int freeSpots;
  final double pricePerHour;
  final String workingHours;
  final List<String> parkingTags;
  final bool isActive;
  final String note;

  ParkingLocation({
    required this.id,
    required this.name,
    this.city = '',
    this.address = '',
    required this.lat,
    required this.lng,
    required this.totalSpots,
    required this.freeSpots,
    this.pricePerHour = 0,
    this.workingHours = '',
    this.parkingTags = const [],
    this.isActive = true,
    this.note = '',
  });

  LatLng get position => LatLng(latitude: lat, longitude: lng);

  BslCity get resolvedBslCity {
    return BslCities.findExact(city) ??
        BslCities.nearestTo(latitude: lat, longitude: lng);
  }

  bool belongsToBslCity(String cityName) {
    return BslCities.same(resolvedBslCity.name, cityName);
  }

  ParkingLocation copyWith({
    String? id,
    String? name,
    String? city,
    String? address,
    double? lat,
    double? lng,
    int? totalSpots,
    int? freeSpots,
    double? pricePerHour,
    String? workingHours,
    List<String>? parkingTags,
    bool? isActive,
    String? note,
  }) {
    return ParkingLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      totalSpots: totalSpots ?? this.totalSpots,
      freeSpots: freeSpots ?? this.freeSpots,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      workingHours: workingHours ?? this.workingHours,
      parkingTags: parkingTags ?? this.parkingTags,
      isActive: isActive ?? this.isActive,
      note: note ?? this.note,
    );
  }

  factory ParkingLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Parking nema podatke.');
    }
    return ParkingLocation.fromMap(doc.id, data);
  }

  factory ParkingLocation.fromMap(String id, Map<String, dynamic> data) {
    final lat = _number(data['lat']);
    final lng = _number(data['lng']);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      throw const FormatException('Parking nema ispravne koordinate.');
    }

    final reportedTotal = _number(data['totalSpots'])?.toInt() ?? 0;
    final totalSpots = reportedTotal < 0 ? 0 : reportedTotal;
    final freeSpots = (_number(data['freeSpots']) ?? 0)
        .clamp(0, totalSpots)
        .toInt();
    final price = _number(data['pricePerHour']) ?? 0;
    final tags = data['parkingTags'];

    return ParkingLocation(
      id: id,
      name: (data['name'] ?? 'Parking').toString(),
      city: (data['city'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      lat: lat,
      lng: lng,
      totalSpots: totalSpots,
      freeSpots: freeSpots,
      pricePerHour: price < 0 ? 0 : price,
      workingHours: (data['workingHours'] ?? '').toString(),
      parkingTags: tags is List ? tags.whereType<String>().toList() : const [],
      isActive: data['isActive'] == null || data['isActive'] == true,
      note: (data['note'] ?? '').toString(),
    );
  }

  static double? _number(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number.isFinite ? number : null;
  }
}
