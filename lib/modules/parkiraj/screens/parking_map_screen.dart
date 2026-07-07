import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/parking_location.dart';
import '../services/parking_service.dart';

class ParkingMapScreen extends StatefulWidget {
  const ParkingMapScreen({super.key});

  @override
  State<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  final ParkingService _parkingService = ParkingService();

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(43.8563, 18.4131),
    zoom: 14,
  );

  ParkingLocation? _selectedParking;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: StreamBuilder<List<ParkingLocation>>(
        stream: _parkingService.watchActiveParkings(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Firestore greška:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final parkings = snapshot.data ?? [];

          if (parkings.isEmpty) {
            return const Center(
              child: Text(
                'Nema parkinga u bazi',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _initialCameraPosition,
                myLocationButtonEnabled: true,
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                mapType: MapType.normal,
                markers: parkings.map((parking) {
                  return Marker(
                    markerId: MarkerId(parking.id),
                    position: parking.position,
                    infoWindow: InfoWindow(
                      title: parking.name,
                      snippet:
                          '${parking.freeSpots}/${parking.totalSpots} slobodno',
                    ),
                    onTap: () {
                      setState(() {
                        _selectedParking = parking;
                      });
                    },
                  );
                }).toSet(),
              ),

              Positioned(
                top: 48,
                left: 16,
                right: 16,
                child: _TopBar(totalParkings: parkings.length),
              ),

              if (_selectedParking != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: _ParkingBottomCard(
                    parking: _selectedParking!,
                    onClose: () {
                      setState(() {
                        _selectedParking = null;
                      });
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int totalParkings;

  const _TopBar({required this.totalParkings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1226).withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_parking_rounded, color: Colors.lightBlueAccent),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Parkiraj.ba',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$totalParkings parkinga',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParkingBottomCard extends StatelessWidget {
  final ParkingLocation parking;
  final VoidCallback onClose;

  const _ParkingBottomCard({
    required this.parking,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final occupancyPercent = parking.totalSpots == 0
        ? 0.0
        : 1 - (parking.freeSpots / parking.totalSpots);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1226).withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_parking_rounded,
                color: Colors.lightBlueAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  parking.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            parking.address.isNotEmpty ? parking.address : parking.city,
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: occupancyPercent.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.10),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _InfoPill(
                icon: Icons.event_available_rounded,
                label: '${parking.freeSpots}/${parking.totalSpots} slobodno',
              ),
              const SizedBox(width: 8),
              _InfoPill(
                icon: Icons.payments_rounded,
                label: '${parking.pricePerHour.toStringAsFixed(2)} KM/h',
              ),
            ],
          ),
          if (parking.workingHours.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoPill(
              icon: Icons.schedule_rounded,
              label: parking.workingHours,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.lightBlueAccent, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}