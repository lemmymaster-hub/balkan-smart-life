import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/widgets/bsl_progress_bar.dart';
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
  BitmapDescriptor? _greenParkingMarker;
BitmapDescriptor? _orangeParkingMarker;
BitmapDescriptor? _redParkingMarker;

BitmapDescriptor? _selectedGreenParkingMarker;
BitmapDescriptor? _selectedOrangeParkingMarker;
BitmapDescriptor? _selectedRedParkingMarker;
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
    _loadParkingMarker();
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
Future<void> _loadParkingMarker() async {
  final results = await Future.wait([
  _createParkingMarker(
    statusColor: const Color(0xFF22C55E),
    width: 42,
    height: 46,
  ),
  _createParkingMarker(
    statusColor: const Color(0xFFF59E0B),
    width: 42,
    height: 46,
  ),
  _createParkingMarker(
    statusColor: const Color(0xFFEF4444),
    width: 42,
    height: 46,
  ),
  _createParkingMarker(
    statusColor: const Color(0xFF22C55E),
    width: 42,
    height: 46,
    selected: true,
  ),
  _createParkingMarker(
    statusColor: const Color(0xFFF59E0B),
    width: 42,
    height: 46,
    selected: true,
  ),
  _createParkingMarker(
    statusColor: const Color(0xFFEF4444),
    width: 42,
    height: 46,
    selected: true,
  ),
]);

  if (!mounted) return;

  setState(() {
    _greenParkingMarker = results[0];
    _orangeParkingMarker = results[1];
    _redParkingMarker = results[2];

    _selectedGreenParkingMarker = results[3];
    _selectedOrangeParkingMarker = results[4];
    _selectedRedParkingMarker = results[5];
  });
}

Future<BitmapDescriptor> _createParkingMarker({
  required Color statusColor,
  required int width,
  required int height,
  bool selected = false,
}) async {
  final assetData = await rootBundle.load(
    'assets/markers/bsl_parking_marker.png',
  );

  final Uint8List assetBytes = assetData.buffer.asUint8List();

  final codec = await ui.instantiateImageCodec(
    assetBytes,
    targetWidth: width,
    targetHeight: height,
  );

  final frame = await codec.getNextFrame();
  final sourceImage = frame.image;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  canvas.drawImage(
    sourceImage,
    Offset.zero,
    Paint()..isAntiAlias = true,
  );
if (selected) {
  final glowPaint = Paint()
    ..colorFilter = ColorFilter.mode(
      BslColors.cyan.withValues(alpha: 0.70),
      BlendMode.srcATop,
    )
    ..maskFilter = const MaskFilter.blur(
      BlurStyle.normal,
      7,
    )
    ..isAntiAlias = true;

  canvas.drawImage(
    sourceImage,
    Offset.zero,
    glowPaint,
  );

 if (selected) {
  canvas.drawImage(
    sourceImage,
    Offset.zero,
    Paint()
      ..colorFilter = ColorFilter.mode(
        BslColors.cyan.withValues(alpha: 0.70),
        BlendMode.srcATop,
      )
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        7,
      )
      ..isAntiAlias = true,
  );
}

canvas.drawImage(
  sourceImage,
  Offset.zero,
  Paint()..isAntiAlias = true,
);
}
  final statusCenter = Offset(
    width * 0.79,
    height * 0.19,
  );

  final statusRadius = width * 0.075;

  // Vanjski glow statusa.
  canvas.drawCircle(
    statusCenter,
    statusRadius * 1.75,
    Paint()
      ..color = statusColor.withValues(alpha: selected ? 0.45 : 0.30)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        8,
      ),
  );

  // Bijeli vanjski prsten.
  canvas.drawCircle(
    statusCenter,
    statusRadius * 1.25,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true,
  );

  // Obojeni prsten.
  canvas.drawCircle(
    statusCenter,
    statusRadius,
    Paint()
      ..color = statusColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true,
  );

  // Svjetliji centar za blagi 3D efekat.
  canvas.drawCircle(
    Offset(
      statusCenter.dx - statusRadius * 0.22,
      statusCenter.dy - statusRadius * 0.22,
    ),
    statusRadius * 0.45,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true,
  );

  final picture = recorder.endRecording();

  final outputImage = await picture.toImage(
    width,
    height,
  );

  final outputData = await outputImage.toByteData(
  format: ui.ImageByteFormat.png,
);

if (outputData == null) {
  throw StateError('Nije moguće kreirati parking marker.');
}

return BitmapDescriptor.bytes(
  outputData.buffer.asUint8List(),
);
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
    final occupancyPercent = parking.totalSpots <= 0
        ? 0.0
        : 1 - (parking.freeSpots / parking.totalSpots);

    final isSelected = _selectedParking?.id == parking.id;

    final markerIcon = _getParkingMarkerIcon(
      occupancyPercent: occupancyPercent,
      isSelected: isSelected,
    );

    return Marker(
      markerId: MarkerId(parking.id),
      position: parking.position,
      icon: markerIcon,
      anchor: const Offset(0.5, 1.0),
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
BitmapDescriptor _getParkingMarkerIcon({
  required double occupancyPercent,
  required bool isSelected,
}) {
  if (occupancyPercent >= 0.85) {
    return isSelected
        ? _selectedRedParkingMarker ?? BitmapDescriptor.defaultMarker
        : _redParkingMarker ?? BitmapDescriptor.defaultMarker;
  }

  if (occupancyPercent >= 0.60) {
    return isSelected
        ? _selectedOrangeParkingMarker ?? BitmapDescriptor.defaultMarker
        : _orangeParkingMarker ?? BitmapDescriptor.defaultMarker;
  }

  return isSelected
      ? _selectedGreenParkingMarker ?? BitmapDescriptor.defaultMarker
      : _greenParkingMarker ?? BitmapDescriptor.defaultMarker;
}
void _showParkingDetails(ParkingLocation parking) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: false,
    builder: (context) {
      return SafeArea(
        child: Container(
  constraints: BoxConstraints(
    maxHeight: MediaQuery.of(context).size.height * 0.45,
  ),
  margin: const EdgeInsets.all(16),
  padding: const EdgeInsets.all(20),
          decoration: BslDecorations.bottomPanel(),
          child: Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    ),
    const SizedBox(height: 18),

    Row(
      children: [
        const Icon(
          Icons.local_parking_rounded,
          color: BslColors.cyan,
          size: 30,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            parking.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),

    const SizedBox(height: 8),

    Text(
      parking.address.isNotEmpty ? parking.address : parking.city,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.68),
        fontSize: 14,
      ),
    ),

    const SizedBox(height: 18),

    Row(
      children: [
        Expanded(
          child: _DetailMiniCard(
            icon: Icons.event_available_rounded,
            title: 'Slobodno',
            value: '${parking.freeSpots}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DetailMiniCard(
            icon: Icons.local_parking_rounded,
            title: 'Ukupno',
            value: '${parking.totalSpots}',
          ),
        ),
      ],
    ),

    const SizedBox(height: 10),

    Row(
      children: [
        Expanded(
          child: _DetailMiniCard(
            icon: Icons.payments_rounded,
            title: 'Cijena',
            value: '${parking.pricePerHour.toStringAsFixed(2)} KM/h',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DetailMiniCard(
            icon: Icons.schedule_rounded,
            title: 'Vrijeme',
            value: parking.workingHours.isNotEmpty
                ? parking.workingHours
                : 'Nije uneseno',
          ),
        ),
      ],
    ),
  ],
),
        ),
      );
    },
  );
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
  mapToolbarEnabled: false,
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
          AnimatedPositioned(
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeOutCubic,
  left: 0,
  right: 0,
  bottom: _selectedParking == null ? -220 : 0,
  child: AnimatedOpacity(
    duration: const Duration(milliseconds: 220),
    opacity: _selectedParking == null ? 0 : 1,
    child: IgnorePointer(
      ignoring: _selectedParking == null,
      child: _selectedParking == null
          ? const SizedBox.shrink()
          : _ParkingBottomCard(
              parking: _selectedParking!,
              onClose: () {
                setState(() {
                  _selectedParking = null;
                });
              },
              onDetails: () {
                _showParkingDetails(_selectedParking!);
              },
            ),
    ),
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
  final VoidCallback onDetails;

 const _ParkingBottomCard({
  required this.parking,
  required this.onClose,
  required this.onDetails,
});

  @override
  Widget build(BuildContext context) {
    final occupancyPercent = parking.totalSpots == 0
        ? 0.0
        : 1 - (parking.freeSpots / parking.totalSpots);

    return Container(
  padding: const EdgeInsets.all(18),
  decoration: BslDecorations.bottomDock(),
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

BslProgressBar(
  value: occupancyPercent,
  label: 'Popunjenost',
  totalSegments: parking.totalSpots,
  filledSegments: parking.totalSpots - parking.freeSpots,
  subtitle:
      '${parking.freeSpots} slobodnih od ${parking.totalSpots} mjesta',
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
                  onTap: onDetails,
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
class _DetailMiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailMiniCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: BslColors.cyan,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}