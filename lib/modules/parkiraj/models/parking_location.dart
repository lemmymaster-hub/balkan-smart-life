import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  LatLng get position => LatLng(lat, lng);

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
    final data = doc.data() as Map<String, dynamic>;

    final totalSpots = (data['totalSpots'] as num?)?.toInt() ?? 0;

    return ParkingLocation(
      id: doc.id,
      name: (data['name'] ?? 'Parking').toString(),
      city: (data['city'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      totalSpots: totalSpots,
      freeSpots: (data['freeSpots'] as num?)?.toInt() ?? totalSpots,
      pricePerHour: (data['pricePerHour'] as num?)?.toDouble() ?? 0,
      workingHours: (data['workingHours'] ?? '').toString(),
      parkingTags: List<String>.from(data['parkingTags'] ?? const []),
      isActive: (data['isActive'] as bool?) ?? true,
      note: (data['note'] ?? '').toString(),
    );
  }
}