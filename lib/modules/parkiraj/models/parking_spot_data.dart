import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum SpotStatus {
  freeConfirmed,
  recentlyFree,
  occupied,
  reserved,
}

class ParkingSpotData {
  final String id;
  final LatLng position;
  final SpotStatus status;
  final String reservedBy;
  final DateTime? reservedUntil;

  ParkingSpotData({
    required this.id,
    required this.position,
    required this.status,
    this.reservedBy = '',
    this.reservedUntil,
  });

  factory ParkingSpotData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final statusText = (data['status'] ?? 'occupied').toString();

    SpotStatus parsedStatus;

    if (statusText == 'freeConfirmed') {
      parsedStatus = SpotStatus.freeConfirmed;
    } else if (statusText == 'recentlyFree') {
      parsedStatus = SpotStatus.recentlyFree;
    } else if (statusText == 'reserved') {
      parsedStatus = SpotStatus.reserved;
    } else {
      parsedStatus = SpotStatus.occupied;
    }

    return ParkingSpotData(
      id: doc.id,
      position: LatLng(
        (data['lat'] as num).toDouble(),
        (data['lng'] as num).toDouble(),
      ),
      status: parsedStatus,
      reservedBy: (data['reservedBy'] ?? '').toString(),
      reservedUntil: data['reservedUntil'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['reservedUntil'])
          : null,
    );
  }
}