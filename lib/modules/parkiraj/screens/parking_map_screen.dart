import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/google_places_service.dart';
import '../../../core/theme/bsl_design_system.dart';
import '../../../core/widgets/bsl_module_top_bar.dart';
import '../models/parking_location.dart';
import '../services/parking_service.dart';

class ParkingMapScreen extends StatefulWidget {
  final String city;

  const ParkingMapScreen({
    super.key,
    required this.city,
  });

  @override
  State<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final ParkingService _parkingService = ParkingService();
  final GooglePlacesService _placesService = GooglePlacesService();

  GoogleMapController? _mapController;
  StreamSubscription<List<ParkingLocation>>? _parkingsSubscription;

  String? _darkMapStyle;
  bool _isLoading = true;
  Object? _error;

  List<ParkingLocation> _parkings = [];
  ParkingLocation? _selectedParking;

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(43.8563, 18.4131),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _listenParkings();
  }

  Future<void> _loadMapStyle() async {
    _darkMapStyle = await rootBundle.loadString(
      'assets/maps/bsl_dark_map_style.json',
    );

    final controller = _mapController;
    if (controller != null && _darkMapStyle != null) {
      await controller.setMapStyle(_darkMapStyle);
    }
  }

  void _listenParkings() {
    _parkingsSubscription?.cancel();

    _parkingsSubscription = _parkingService.watchActiveParkings().listen(
      (parkings) {
        if (!mounted) return;

        setState(() {
          _parkings = parkings;
          _isLoading = false;
          _error = null;

          if (_selectedParking != null) {
            final selectedStillExists = parkings.any(
              (parking) => parking.id == _selectedParking!.id,
            );

            if (!selectedStillExists) {
              _selectedParking = null;
            }
          }
        });
      },
      onError: (error) {
        if (!mounted) return;

        setState(() {
          _error = error;
          _isLoading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _parkingsSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _searchParkingOrPlace(String value) async {
    final rawQuery = value.trim();

    if (rawQuery.length < 2) return;

    final query = rawQuery.toLowerCase();

    debugPrint('BSL SEARCH START: $rawQuery');

    final parkingMatches = _parkings.where((parking) {
      final name = parking.name.toLowerCase();
      final address = parking.address.toLowerCase();
      final city = parking.city.toLowerCase();

      return name.contains(query) ||
          address.contains(query) ||
          city.contains(query);
    }).toList();

    if (parkingMatches.isNotEmpty) {
      final parking = parkingMatches.first;

      debugPrint('BSL SEARCH PARKING MATCH: ${parking.name}');

      await _animateTo(
        target: parking.position,
        zoom: 17,
      );

      if (!mounted) return;

      setState(() {
        _selectedParking = parking;
      });

      _searchFocusNode.unfocus();
      return;
    }

    debugPrint('BSL SEARCH PLACES QUERY: $rawQuery');

    final places = await _placesService.searchPlaces(
      input: rawQuery,
      language: 'bs',
      country: 'ba',
    );

    if (!mounted) return;

    if (places.isEmpty) {
      debugPrint('BSL SEARCH NO RESULTS: $rawQuery');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nema rezultata za "$rawQuery"'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final place = places.first;

    debugPrint('BSL SEARCH PLACE MATCH: ${place.title} ${place.location}');

    await _animateTo(
      target: place.location,
      zoom: 16,
    );

    if (!mounted) return;

    setState(() {
      _selectedParking = null;
    });

    _searchFocusNode.unfocus();
  }

  Future<void> _animateTo({
    required LatLng target,
    required double zoom,
  }) async {
    final controller = _mapController;

    if (controller == null) {
      debugPrint('BSL MAP CONTROLLER IS NULL');
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: zoom,
        ),
      ),
    );
  }

  Set<Marker> _buildParkingMarkers() {
    return _parkings.map((parking) {
      return Marker(
        markerId: MarkerId(parking.id),
        position: parking.position,
        infoWindow: InfoWindow(
          title: parking.name,
          snippet: '${parking.freeSpots}/${parking.totalSpots} slobodno',
        ),
        onTap: () async {
          await _animateTo(
            target: parking.position,
            zoom: 17,
          );

          if (!mounted) return;

          setState(() {
            _selectedParking = parking;
          });
        },
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B18),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Firestore greška:\n$_error',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF070B18),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_parkings.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF070B18),
        body: Center(
          child: Text(
            'Nema parkinga u bazi',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) async {
              _mapController = controller;

              if (_darkMapStyle != null) {
                await controller.setMapStyle(_darkMapStyle);
              }
            },
            initialCameraPosition: _initialCameraPosition,
            myLocationButtonEnabled: true,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            markers: _buildParkingMarkers(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BslModuleTopBar(
              title: 'Parkiraj.ba',
              subtitle: widget.city,
              badge: '${_parkings.length} parkinga',
              searchHint: 'Pretraži parking ili adresu...',
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              onSearchSubmitted: _searchParkingOrPlace,
            ),
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
      decoration: BslDecorations.bottomPanel(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_parking_rounded,
                color: BslColors.cyan,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  parking.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            parking.address.isNotEmpty ? parking.address : parking.city,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
              Expanded(
                child: _InfoPill(
                  icon: Icons.event_available_rounded,
                  label: '${parking.freeSpots}/${parking.totalSpots} slobodno',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoPill(
                  icon: Icons.payments_rounded,
                  label: '${parking.pricePerHour.toStringAsFixed(2)} KM/h',
                ),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ParkingActionButton(
                  icon: Icons.navigation_rounded,
                  label: 'Navigacija',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ParkingActionButton(
                  icon: Icons.info_outline_rounded,
                  label: 'Detalji',
                  onTap: () {},
                  secondary: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ParkingActionButton(
                  icon: Icons.credit_card_rounded,
                  label: 'Plati',
                  onTap: () {},
                ),
              ),
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: BslColors.cyan,
            size: 16,
          ),
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
    );
  }
}

class _ParkingActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool secondary;

  const _ParkingActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = secondary
        ? Colors.white.withValues(alpha: 0.07)
        : BslColors.cyan.withValues(alpha: 0.18);

    final borderColor = secondary
        ? Colors.white.withValues(alpha: 0.10)
        : BslColors.cyan.withValues(alpha: 0.35);

    final textColor = secondary ? Colors.white : BslColors.cyan;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: textColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}