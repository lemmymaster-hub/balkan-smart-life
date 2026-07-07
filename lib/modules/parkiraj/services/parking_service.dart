import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/parking_location.dart';

class ParkingService {
  final FirebaseFirestore _firestore;

  ParkingService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<ParkingLocation>> watchActiveParkings({String? city}) {
    Query<Map<String, dynamic>> query = _firestore.collection('parkings');

    if (city != null && city.trim().isNotEmpty) {
      query = query.where('city', isEqualTo: city.trim());
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ParkingLocation.fromFirestore(doc))
          .where((parking) => parking.isActive)
          .toList();
    });
  }

  Future<List<ParkingLocation>> getActiveParkings({String? city}) async {
    Query<Map<String, dynamic>> query = _firestore.collection('parkings');

    if (city != null && city.trim().isNotEmpty) {
      query = query.where('city', isEqualTo: city.trim());
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => ParkingLocation.fromFirestore(doc))
        .where((parking) => parking.isActive)
        .toList();
  }

  List<ParkingLocation> getFallbackParkings() {
    return [
      ParkingLocation(
        id: 'sarajevo-demo-1',
        name: 'BBI Centar Parking',
        city: 'Sarajevo',
        address: 'Trg djece Sarajeva',
        lat: 43.8581,
        lng: 18.4214,
        totalSpots: 120,
        freeSpots: 37,
        pricePerHour: 2.0,
        workingHours: '00:00 - 24:00',
        parkingTags: const ['centar', 'garaža', '24h'],
        isActive: true,
      ),
      ParkingLocation(
        id: 'sarajevo-demo-2',
        name: 'Skenderija Parking',
        city: 'Sarajevo',
        address: 'Skenderija',
        lat: 43.8546,
        lng: 18.4166,
        totalSpots: 90,
        freeSpots: 22,
        pricePerHour: 1.5,
        workingHours: '00:00 - 24:00',
        parkingTags: const ['otvoreni parking'],
        isActive: true,
      ),
    ];
  }
}
