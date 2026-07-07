import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/bsl_design_system.dart';
import '../models/parking_location.dart';
import '../services/parking_service.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class ParkingMapScreen extends StatefulWidget {
  const ParkingMapScreen({super.key});

  @override
  State<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  final ParkingService _parkingService = ParkingService();
  String? _darkMapStyle;
  Future<void> _loadMapStyle() async {
    _darkMapStyle = await rootBundle.loadString(
      'assets/maps/bsl_dark_map_style.json',
    );
  }

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(43.8563, 18.4131),
    zoom: 14,
  );

  ParkingLocation? _selectedParking;
  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

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
            return const Center(child: CircularProgressIndicator());
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
                onMapCreated: (controller) {
                  if (_darkMapStyle != null) {
                    controller.setMapStyle(_darkMapStyle);
                  }
                },
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
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BslDecorations.glassCard(radius: BslRadius.large),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF245BFF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.35),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_parking_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parkiraj.ba',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Pametno parkiranje u gradu',
                    style: TextStyle(
                      color: Color(0xFF8FA6C8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$totalParkings',
                style: const TextStyle(
                  color: Color(0xFF2FE6FF),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParkingBottomCard extends StatelessWidget {
  final ParkingLocation parking;
  final VoidCallback onClose;

  const _ParkingBottomCard({required this.parking, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final occupancyPercent = parking.totalSpots == 0
        ? 0.0
        : 1 - (parking.freeSpots / parking.totalSpots);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BslDecorations.bottomPanel(),
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
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: occupancyPercent.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
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

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
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
