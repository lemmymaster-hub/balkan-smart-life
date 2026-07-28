import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/context/bsl_location_context.dart';
import '../../../core/models/address_search_result.dart';
import '../../../core/models/bsl_city.dart';
import '../../../core/models/bsl_location_result.dart';
import '../../../core/navigation/bsl_navigation_controller.dart';
import '../../../core/navigation/bsl_navigation_destination.dart';
import '../../../core/navigation/bsl_navigation_vehicle_asset.dart';
import '../../../core/services/address_geocoding_service.dart';
import '../../../core/services/bsl_nearest_place_selector.dart';
import '../../../core/theme/bsl_design_system.dart';
import '../../../core/widgets/bsl_map_location_button.dart';
import '../../../core/widgets/bsl_module_top_bar.dart';
import '../../../core/widgets/bsl_navigation_panel.dart';
import '../../../core/widgets/bsl_progress_bar.dart';
import '../models/parking_location.dart';
import '../services/parking_service.dart';

class ParkingMapScreen extends StatefulWidget {
  final String city;
  final String? initialSearchQuery;
  final bool selectNearestOnOpen;

  const ParkingMapScreen({
    super.key,
    required this.city,
    this.initialSearchQuery,
    this.selectNearestOnOpen = false,
  });

  @override
  State<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final ParkingService _parkingService = ParkingService();
  final AddressGeocodingService _addressGeocodingService =
      const AddressGeocodingService();
  final BslNavigationController _parkingNavigation = BslNavigationController();

  GoogleNavigationViewController? _mapController;
  ImageDescriptor? _greenParkingMarker;
  ImageDescriptor? _orangeParkingMarker;
  ImageDescriptor? _redParkingMarker;

  ImageDescriptor? _selectedGreenParkingMarker;
  ImageDescriptor? _selectedOrangeParkingMarker;
  ImageDescriptor? _selectedRedParkingMarker;
  ImageDescriptor? _navigationVehicleMarker;
  StreamSubscription<List<ParkingLocation>>? _parkingsSubscription;
  Map<String, ParkingLocation> _parkingByMarkerId = const {};
  List<Marker> _parkingMarkers = const <Marker>[];
  bool _markerSyncInProgress = false;
  bool _markerSyncPending = false;
  bool _navigationVehicleMarkerLoadRequested = false;
  bool? _nativeLocationIndicatorEnabled;

  String? _darkMapStyle;
  bool _isLoading = true;
  Object? _error;

  List<ParkingLocation> _parkings = [];
  ParkingLocation? _selectedParking;
  late String _displayedCity;
  BslLocationContext? _locationContext;

  bool _hasCenteredOnUser = false;
  bool _isCenteringOnUser = false;
  bool _userChangedMapTarget = false;
  bool _requestedFreshLocation = false;
  bool _lastHasUserLocation = false;
  bool _lastLocationIsLoading = false;
  bool _lastLocationNeedsAttention = false;
  bool _initialRequestStarted = false;

  CameraPosition get _initialCameraPosition {
    final userLocation = _locationContext?.location;

    if (userLocation != null) {
      return CameraPosition(
        target: LatLng(
          latitude: userLocation.latitude,
          longitude: userLocation.longitude,
        ),
        zoom: 15.5,
      );
    }

    final city = BslCities.byName(widget.city);

    return CameraPosition(
      target: LatLng(latitude: city.latitude, longitude: city.longitude),
      zoom: city.mapZoom,
    );
  }

  @override
  void initState() {
    super.initState();
    _displayedCity = BslCities.byName(widget.city).name;
    _searchController.text = widget.initialSearchQuery?.trim() ?? '';
    _parkingNavigation.addListener(_handleParkingNavigationChanged);
    _loadMapStyle();
    _loadParkingMarker();
    _listenParkings();
  }

  void _handleParkingNavigationChanged() {
    if (!mounted) return;
    setState(() {
      final destination = _parkingNavigation.destination;
      if (_parkingNavigation.shouldShowPanel && destination != null) {
        final destinationParking = _parkingForId(destination.id);
        if (destinationParking != null) {
          _selectedParking = destinationParking;
        }
      }
    });
    unawaited(_setMapLocationEnabled(_locationContext?.hasLocation ?? false));
  }

  ParkingLocation? _parkingForId(String id) {
    for (final parking in _parkings) {
      if (parking.id == id) return parking;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_navigationVehicleMarkerLoadRequested) {
      _navigationVehicleMarkerLoadRequested = true;
      unawaited(_loadNavigationVehicleMarker());
    }

    final nextLocationContext = context.read<BslLocationContext>();

    if (!identical(_locationContext, nextLocationContext)) {
      _locationContext?.removeListener(_handleLocationContextChanged);
      _locationContext = nextLocationContext;
      nextLocationContext.addListener(_handleLocationContextChanged);
      _lastHasUserLocation = nextLocationContext.hasLocation;
      _lastLocationIsLoading = nextLocationContext.isLoading;
      _lastLocationNeedsAttention = nextLocationContext.shouldOpenSettings;
    }

    final location = nextLocationContext.location;
    if (!_userChangedMapTarget && location != null) {
      _setDisplayedCityFromLocation(location);
    }

    if (!_requestedFreshLocation) {
      _requestedFreshLocation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        nextLocationContext.refresh();
        _centerMapOnUser();
      });
    }
  }

  void _handleLocationContextChanged() {
    if (!mounted) return;

    final locationContext = _locationContext;
    if (locationContext == null) return;

    final location = locationContext.location;
    final detectedCity = !_userChangedMapTarget && location != null
        ? _displayedCityFromLocation(location)
        : null;
    final shouldRebuild =
        _lastHasUserLocation != locationContext.hasLocation ||
        _lastLocationIsLoading != locationContext.isLoading ||
        _lastLocationNeedsAttention != locationContext.shouldOpenSettings ||
        (detectedCity != null && detectedCity != _displayedCity);

    if (shouldRebuild) {
      setState(() {
        _lastHasUserLocation = locationContext.hasLocation;
        _lastLocationIsLoading = locationContext.isLoading;
        _lastLocationNeedsAttention = locationContext.shouldOpenSettings;

        if (detectedCity != null) {
          _displayedCity = detectedCity;
        }
      });

      unawaited(_setMapLocationEnabled(locationContext.hasLocation));
    }

    if (location != null && !_hasCenteredOnUser && !_userChangedMapTarget) {
      _centerMapOnUser();
    }

    _tryRunInitialRequest();
  }

  void _setDisplayedCityFromLocation(BslLocationResult location) {
    final detectedCity = _displayedCityFromLocation(location);
    if (detectedCity != null) {
      _displayedCity = detectedCity;
    }
  }

  String? _displayedCityFromLocation(BslLocationResult location) {
    final detectedCity = location.city.isNotEmpty
        ? location.city
        : location.municipality;

    if (detectedCity.isEmpty) {
      return BslCities.nearestTo(
        latitude: location.latitude,
        longitude: location.longitude,
      ).name;
    }

    return BslCities.findExact(detectedCity)?.name ??
        BslCities.nearestTo(
          latitude: location.latitude,
          longitude: location.longitude,
        ).name;
  }

  Future<void> _loadMapStyle() async {
    final style = await rootBundle.loadString(
      'assets/maps/bsl_dark_map_style.json',
    );

    if (!mounted) return;

    setState(() {
      _darkMapStyle = style;
    });

    final controller = _mapController;
    if (controller != null) {
      await _applyMapStyle(controller);
    }
  }

  Future<void> _loadNavigationVehicleMarker() async {
    ImageDescriptor? registeredMarker;

    try {
      registeredMarker = await BslNavigationVehicleAsset.register(context);

      if (!mounted) {
        await unregisterImage(registeredMarker);
        return;
      }

      _navigationVehicleMarker = registeredMarker;
      await _parkingNavigation.setVehicleMarkerIcon(registeredMarker);
    } catch (error, stackTrace) {
      if (registeredMarker?.registeredImageId != null) {
        try {
          await unregisterImage(registeredMarker!);
        } catch (_) {
          // Primarna greška se prijavljuje ispod.
        }
      }
      debugPrint('BSL NAVIGATION VEHICLE ASSET ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
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

    if (!mounted) {
      await _unregisterParkingImages(results);
      return;
    }

    setState(() {
      _greenParkingMarker = results[0];
      _orangeParkingMarker = results[1];
      _redParkingMarker = results[2];

      _selectedGreenParkingMarker = results[3];
      _selectedOrangeParkingMarker = results[4];
      _selectedRedParkingMarker = results[5];
    });

    _scheduleParkingMarkerSync();
  }

  Future<ImageDescriptor> _createParkingMarker({
    required Color statusColor,
    required int width,
    required int height,
    bool selected = false,
  }) async {
    try {
      return await _buildParkingMarker(
        statusColor: statusColor,
        width: width,
        height: height,
        selected: selected,
      );
    } catch (error, stackTrace) {
      debugPrint('BSL PARKING MARKER BUILD ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      return ImageDescriptor.defaultImage;
    }
  }

  Future<ImageDescriptor> _buildParkingMarker({
    required Color statusColor,
    required int width,
    required int height,
    required bool selected,
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

    canvas.drawImage(sourceImage, Offset.zero, Paint()..isAntiAlias = true);
    if (selected) {
      final glowPaint = Paint()
        ..colorFilter = ColorFilter.mode(
          BslColors.cyan.withValues(alpha: 0.70),
          BlendMode.srcATop,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
        ..isAntiAlias = true;

      canvas.drawImage(sourceImage, Offset.zero, glowPaint);

      canvas.drawImage(sourceImage, Offset.zero, Paint()..isAntiAlias = true);
    }
    final statusCenter = Offset(width * 0.79, height * 0.19);

    final statusRadius = width * 0.075;

    // Vanjski glow statusa.
    canvas.drawCircle(
      statusCenter,
      statusRadius * 1.75,
      Paint()
        ..color = statusColor.withValues(alpha: selected ? 0.45 : 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
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

    final outputImage = await picture.toImage(width, height);

    final outputData = await outputImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (outputData == null) {
      throw StateError('Nije moguće kreirati parking marker.');
    }

    return registerBitmapImage(
      bitmap: outputData,
      width: width.toDouble(),
      height: height.toDouble(),
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

        _scheduleParkingMarkerSync();
        _tryRunInitialRequest();
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
    _locationContext?.removeListener(_handleLocationContextChanged);
    _parkingNavigation.removeListener(_handleParkingNavigationChanged);
    _parkingNavigation.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    final controller = _mapController;
    _mapController = null;
    unawaited(_disposeMapResources(controller));
    super.dispose();
  }

  Future<void> _handleLocationButton() async {
    if (_parkingNavigation.isGuidanceActive) {
      await _parkingNavigation.recenter();
      return;
    }

    final locationContext = _locationContext;
    if (locationContext == null) return;

    if (locationContext.location != null) {
      await _centerMapOnUser(force: true);
      return;
    }

    if (locationContext.shouldOpenSettings) {
      final openedSettings = await locationContext.openRelevantSettings();
      if (openedSettings) return;
      if (!mounted) return;
    }

    await locationContext.refresh();

    if (!mounted) return;

    if (locationContext.location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locationContext.statusMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _centerMapOnUser(force: true);
  }

  Future<void> _startParkingNavigation(ParkingLocation parking) async {
    final locationContext = _locationContext;
    if (locationContext == null) return;

    if (locationContext.shouldOpenSettings) {
      final openedSettings = await locationContext.openRelevantSettings();
      if (openedSettings) return;
      if (!mounted) return;
    }

    final currentLocation = locationContext.location;
    if (currentLocation == null ||
        currentLocation.isFromCache ||
        !locationContext.isTracking) {
      await locationContext.refresh();
    }

    if (!mounted) return;

    if (locationContext.shouldOpenSettings) {
      final openedSettings = await locationContext.openRelevantSettings();
      if (openedSettings) return;
      if (!mounted) return;
    }

    if (locationContext.location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locationContext.statusMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _selectedParking = parking;
      _userChangedMapTarget = false;
      _hasCenteredOnUser = true;
    });
    _searchFocusNode.unfocus();
    _scheduleParkingMarkerSync();

    await _parkingNavigation.start(
      destination: BslNavigationDestination(
        id: parking.id,
        title: parking.name,
        latitude: parking.lat,
        longitude: parking.lng,
      ),
      mapPadding: _navigationMapPadding(),
    );

    final controller = _mapController;
    if (controller != null) {
      await _applyMapStyle(controller);
    }
  }

  Future<void> _stopParkingNavigation() async {
    await _parkingNavigation.stop();
    final controller = _mapController;
    if (controller != null) {
      try {
        await controller.setPadding(EdgeInsets.zero);
      } on ViewNotFoundException {
        return;
      }
      await _applyMapStyle(controller);
    }
  }

  Future<void> _retryParkingNavigation() async {
    await _parkingNavigation.retry(mapPadding: _navigationMapPadding());

    final controller = _mapController;
    if (controller != null) {
      await _applyMapStyle(controller);
    }
  }

  Future<void> _closeParkingCard() async {
    if (_parkingNavigation.shouldShowPanel) {
      await _stopParkingNavigation();
    }

    if (!mounted) return;

    setState(() {
      _selectedParking = null;
    });
    _scheduleParkingMarkerSync();
  }

  EdgeInsets _navigationMapPadding() {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return EdgeInsets.fromLTRB(
      14 * pixelRatio,
      170 * pixelRatio,
      14 * pixelRatio,
      285 * pixelRatio,
    );
  }

  Future<void> _centerMapOnUser({bool force = false}) async {
    if (_isCenteringOnUser || _mapController == null) return;
    if (!force && (_hasCenteredOnUser || _userChangedMapTarget)) return;

    final location = _locationContext?.location;
    if (location == null) return;

    _isCenteringOnUser = true;

    try {
      if (mounted) {
        setState(() {
          _userChangedMapTarget = false;
          _selectedParking = null;
          _setDisplayedCityFromLocation(location);
        });
        _scheduleParkingMarkerSync();
      }

      await _animateTo(
        target: LatLng(
          latitude: location.latitude,
          longitude: location.longitude,
        ),
        zoom: 15.5,
      );

      _hasCenteredOnUser = true;
    } finally {
      _isCenteringOnUser = false;
    }
  }

  Future<void> _searchParkingOrAddress(
    String value, {
    bool selectNearestToResult = false,
  }) async {
    if (_parkingNavigation.shouldShowPanel) {
      _searchFocusNode.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zaustavi navigaciju prije nove pretrage.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final rawQuery = value.trim();

    if (rawQuery.length < 2) return;

    final query = BslCities.normalize(rawQuery);

    debugPrint('BSL SEARCH START: $rawQuery');

    final searchedCity = BslCities.findExact(rawQuery);

    if (searchedCity != null) {
      _userChangedMapTarget = true;
      _hasCenteredOnUser = true;

      await _animateTo(
        target: LatLng(
          latitude: searchedCity.latitude,
          longitude: searchedCity.longitude,
        ),
        zoom: searchedCity.mapZoom,
      );

      if (!mounted) return;

      setState(() {
        _displayedCity = searchedCity.name;
        _selectedParking = null;
      });
      _scheduleParkingMarkerSync();

      _searchFocusNode.unfocus();
      return;
    }

    final parkingMatches = _parkings.where((parking) {
      final name = BslCities.normalize(parking.name);
      final address = BslCities.normalize(parking.address);
      final city = BslCities.normalize(parking.city);

      return name.contains(query) ||
          address.contains(query) ||
          city.contains(query);
    }).toList();

    if (parkingMatches.isNotEmpty) {
      final parking = parkingMatches.first;

      debugPrint('BSL SEARCH PARKING MATCH: ${parking.name}');

      _userChangedMapTarget = true;
      _hasCenteredOnUser = true;

      await _animateTo(target: parking.position, zoom: 17);

      if (!mounted) return;

      setState(() {
        _displayedCity = parking.resolvedBslCity.name;
        _selectedParking = parking;
      });
      _scheduleParkingMarkerSync();

      _searchFocusNode.unfocus();
      return;
    }

    debugPrint('BSL SEARCH ADDRESS QUERY: $rawQuery');

    final mentionedCity = BslCities.findMentionedIn(rawQuery);
    final AddressSearchResult? address;

    try {
      address = await _addressGeocodingService.searchAddress(
        input: rawQuery,
        city: mentionedCity?.name ?? _displayedCity,
      );
    } on AddressGeocodingException catch (error) {
      if (!mounted) return;

      debugPrint('BSL SEARCH ADDRESS ERROR: $error');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pretraga adrese trenutno nije dostupna.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    if (!mounted) return;

    if (address == null) {
      debugPrint('BSL SEARCH NO RESULTS: $rawQuery');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nema rezultata za "$rawQuery"'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final addressLocation = address.location;

    debugPrint('BSL SEARCH ADDRESS MATCH: ${address.label} $addressLocation');

    _userChangedMapTarget = true;
    _hasCenteredOnUser = true;

    final resultCity =
        mentionedCity?.name ??
        BslCities.nearestTo(
          latitude: addressLocation.latitude,
          longitude: addressLocation.longitude,
        ).name;
    final nearestParking = selectNearestToResult
        ? _nearestParkingTo(
            latitude: addressLocation.latitude,
            longitude: addressLocation.longitude,
            city: resultCity,
          )
        : null;

    await _animateTo(
      target: nearestParking?.position ?? addressLocation,
      zoom: nearestParking == null ? 16 : 17,
    );

    if (!mounted) return;

    setState(() {
      _displayedCity = resultCity;
      _selectedParking = nearestParking;
    });
    _scheduleParkingMarkerSync();

    if (selectNearestToResult && nearestParking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nema mapiranog parkinga u blizini tražene lokacije.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _searchFocusNode.unfocus();
  }

  ParkingLocation? _nearestParkingTo({
    required double latitude,
    required double longitude,
    required String city,
  }) {
    final cityCandidates = _parkings
        .where((parking) => parking.belongsToBslCity(city))
        .toList(growable: false);
    if (cityCandidates.isEmpty) return null;

    final availableCandidates = cityCandidates
        .where((parking) => parking.freeSpots > 0 || parking.totalSpots <= 0)
        .toList(growable: false);
    final candidates = availableCandidates.isNotEmpty
        ? availableCandidates
        : cityCandidates;

    return BslNearestPlaceSelector.find(
      items: candidates,
      latitude: latitude,
      longitude: longitude,
      latitudeOf: (parking) => parking.lat,
      longitudeOf: (parking) => parking.lng,
      maxDistanceKilometers: 8,
    );
  }

  void _tryRunInitialRequest() {
    if (_initialRequestStarted ||
        _mapController == null ||
        _isLoading ||
        !mounted) {
      return;
    }

    final query = widget.initialSearchQuery?.trim() ?? '';
    if (query.isEmpty && !widget.selectNearestOnOpen) return;

    final selectedCity = BslCities.byName(widget.city);
    final location = _locationContext?.location;
    final locationCity = location == null
        ? null
        : BslCities.nearestTo(
            latitude: location.latitude,
            longitude: location.longitude,
          );
    final canUseUserLocation =
        location != null &&
        locationCity != null &&
        BslCities.same(locationCity.name, selectedCity.name);

    if (query.isEmpty &&
        widget.selectNearestOnOpen &&
        location == null &&
        (_locationContext?.isLoading ?? false)) {
      return;
    }

    _initialRequestStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (query.isNotEmpty) {
        await _searchParkingOrAddress(
          query,
          selectNearestToResult: widget.selectNearestOnOpen,
        );
        return;
      }

      final targetLatitude = canUseUserLocation
          ? location.latitude
          : selectedCity.latitude;
      final targetLongitude = canUseUserLocation
          ? location.longitude
          : selectedCity.longitude;
      final nearestParking = _nearestParkingTo(
        latitude: targetLatitude,
        longitude: targetLongitude,
        city: selectedCity.name,
      );

      if (nearestParking == null) return;

      _userChangedMapTarget = true;
      _hasCenteredOnUser = true;
      await _animateTo(target: nearestParking.position, zoom: 17);
      if (!mounted) return;

      setState(() {
        _displayedCity = selectedCity.name;
        _selectedParking = nearestParking;
      });
      _scheduleParkingMarkerSync();
    });
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

    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: zoom),
        ),
        duration: const Duration(milliseconds: 520),
      );
    } on ViewNotFoundException {
      // Ekran je zatvoren prije završetka animacije.
    }
  }

  Future<void> _onMapViewCreated(
    GoogleNavigationViewController controller,
  ) async {
    _mapController = controller;
    _nativeLocationIndicatorEnabled = null;

    await _parkingNavigation.attachMapController(controller);
    await _applyMapStyle(controller);
    await _setMapLocationEnabled(_locationContext?.hasLocation ?? false);

    if (!mounted || !identical(_mapController, controller)) return;

    _scheduleParkingMarkerSync();
    await _centerMapOnUser();
    _tryRunInitialRequest();
  }

  Future<void> _applyMapStyle(GoogleMapViewController controller) async {
    final style = _darkMapStyle;
    if (style == null) return;

    try {
      await controller.setMapStyle(style);
    } on ViewNotFoundException {
      // Ekran je zatvoren prije završetka nativnog poziva.
    } on MapStyleException catch (error) {
      debugPrint('BSL PARKING MAP STYLE ERROR: $error');
    }
  }

  Future<void> _setMapLocationEnabled(bool enabled) async {
    final controller = _mapController;
    if (controller == null) return;

    final showNativeLocation =
        enabled && !_parkingNavigation.isVehicleMarkerVisible;
    if (_nativeLocationIndicatorEnabled == showNativeLocation) return;

    _nativeLocationIndicatorEnabled = showNativeLocation;

    try {
      await controller.setMyLocationEnabled(showNativeLocation);
    } on ViewNotFoundException {
      if (identical(_mapController, controller)) {
        _nativeLocationIndicatorEnabled = null;
      }
      // Ekran je zatvoren prije završetka nativnog poziva.
    } catch (error) {
      if (identical(_mapController, controller)) {
        _nativeLocationIndicatorEnabled = null;
      }
      debugPrint('BSL PARKING LOCATION INDICATOR ERROR: $error');
    }
  }

  void _scheduleParkingMarkerSync() {
    _markerSyncPending = true;
    if (_markerSyncInProgress) return;
    unawaited(_drainParkingMarkerSync());
  }

  Future<void> _drainParkingMarkerSync() async {
    _markerSyncInProgress = true;

    try {
      while (mounted && _markerSyncPending) {
        _markerSyncPending = false;
        await _syncParkingMarkers();
      }
    } finally {
      _markerSyncInProgress = false;
      if (mounted && _markerSyncPending) {
        _scheduleParkingMarkerSync();
      }
    }
  }

  Future<void> _syncParkingMarkers() async {
    final controller = _mapController;
    if (controller == null) return;

    final parkings = List<ParkingLocation>.of(_parkings);
    final markerOptions = parkings
        .map((parking) {
          final occupancyPercent = parking.totalSpots <= 0
              ? 0.0
              : 1 - (parking.freeSpots / parking.totalSpots);
          final isSelected = _selectedParking?.id == parking.id;

          return MarkerOptions(
            position: parking.position,
            icon: _getParkingMarkerIcon(
              occupancyPercent: occupancyPercent,
              isSelected: isSelected,
            ),
            anchor: const MarkerAnchor(u: 0.5, v: 1.0),
            consumeTapEvents: true,
            zIndex: isSelected ? 2 : 1,
            infoWindow: InfoWindow(
              title: parking.name,
              snippet: '${parking.freeSpots}/${parking.totalSpots} slobodno',
            ),
          );
        })
        .toList(growable: false);

    try {
      _parkingByMarkerId = const {};
      await _removeParkingMarkers(controller);

      if (!mounted || !identical(_mapController, controller)) return;

      final markers = await controller.addMarkers(markerOptions);

      if (!mounted || !identical(_mapController, controller)) return;

      final parkingByMarkerId = <String, ParkingLocation>{};
      final activeParkingMarkers = <Marker>[];
      for (var index = 0; index < markers.length; index++) {
        final marker = markers[index];
        if (marker != null && index < parkings.length) {
          activeParkingMarkers.add(marker);
          parkingByMarkerId[marker.markerId] = parkings[index];
        }
      }
      _parkingMarkers = activeParkingMarkers;
      _parkingByMarkerId = parkingByMarkerId;
    } on ViewNotFoundException {
      // Ekran je zatvoren prije završetka nativnog poziva.
    } catch (error, stackTrace) {
      debugPrint('BSL PARKING MARKER SYNC ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _removeParkingMarkers(
    GoogleNavigationViewController controller,
  ) async {
    final markers = _parkingMarkers;
    _parkingMarkers = const <Marker>[];
    if (markers.isEmpty) return;

    try {
      await controller.removeMarkers(markers);
    } on MarkerNotFoundException {
      // Markeri su već uklonjeni pri ponovnom kreiranju mape.
    } on ViewNotFoundException {
      // Ekran je zatvoren prije završetka nativnog poziva.
    }
  }

  void _handleParkingMarkerTap(String markerId) {
    final parking = _parkingByMarkerId[markerId];
    if (parking == null) return;
    unawaited(_selectParkingFromMap(parking));
  }

  Future<void> _selectParkingFromMap(ParkingLocation parking) async {
    if (_parkingNavigation.shouldShowPanel) return;

    _userChangedMapTarget = true;
    _hasCenteredOnUser = true;

    await _animateTo(target: parking.position, zoom: 17);

    if (!mounted) return;

    setState(() {
      _displayedCity = parking.resolvedBslCity.name;
      _selectedParking = parking;
    });
    _scheduleParkingMarkerSync();
  }

  ImageDescriptor _getParkingMarkerIcon({
    required double occupancyPercent,
    required bool isSelected,
  }) {
    if (occupancyPercent >= 0.85) {
      return isSelected
          ? _selectedRedParkingMarker ?? ImageDescriptor.defaultImage
          : _redParkingMarker ?? ImageDescriptor.defaultImage;
    }

    if (occupancyPercent >= 0.60) {
      return isSelected
          ? _selectedOrangeParkingMarker ?? ImageDescriptor.defaultImage
          : _orangeParkingMarker ?? ImageDescriptor.defaultImage;
    }

    return isSelected
        ? _selectedGreenParkingMarker ?? ImageDescriptor.defaultImage
        : _greenParkingMarker ?? ImageDescriptor.defaultImage;
  }

  Future<void> _unregisterParkingMarkerImages() async {
    final images = <ImageDescriptor?>{
      _greenParkingMarker,
      _orangeParkingMarker,
      _redParkingMarker,
      _selectedGreenParkingMarker,
      _selectedOrangeParkingMarker,
      _selectedRedParkingMarker,
      _navigationVehicleMarker,
    };

    await _unregisterParkingImages(images.whereType<ImageDescriptor>());
  }

  Future<void> _unregisterParkingImages(
    Iterable<ImageDescriptor> images,
  ) async {
    for (final image in images.toSet()) {
      if (image.registeredImageId == null) continue;
      try {
        await unregisterImage(image);
      } catch (error) {
        debugPrint('BSL PARKING MARKER CLEANUP ERROR: $error');
      }
    }
  }

  Future<void> _disposeMapResources(GoogleMapViewController? controller) async {
    _parkingMarkers = const <Marker>[];
    _parkingByMarkerId = const {};

    if (controller != null) {
      try {
        await controller.clearMarkers();
      } on ViewNotFoundException {
        // Nativni prikaz je već uklonjen.
      } catch (error) {
        debugPrint('BSL PARKING MAP CLEANUP ERROR: $error');
      }
    }

    await _unregisterParkingMarkerImages();
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
                        value:
                            '${parking.pricePerHour.toStringAsFixed(2)} KM/h',
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final displayedParkingCount = _parkings
        .where((parking) => parking.belongsToBslCity(_displayedCity))
        .length;
    final locationContext = _locationContext;
    final hasUserLocation = locationContext?.hasLocation ?? false;
    final selectedParking = _selectedParking;
    final navigationVisible =
        selectedParking != null &&
        _parkingNavigation.shouldShowPanel &&
        _parkingNavigation.destination?.id == selectedParking.id;
    final isSelectedDestinationNavigating =
        selectedParking != null &&
        _parkingNavigation.isGuidanceActive &&
        _parkingNavigation.destination?.id == selectedParking.id;

    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: Stack(
        children: [
          GoogleMapsNavigationView(
            onViewCreated: (controller) {
              unawaited(_onMapViewCreated(controller));
            },
            initialCameraPosition: _initialCameraPosition,
            initialNavigationUIEnabledPreference:
                NavigationUIEnabledPreference.disabled,
            initialZoomControlsEnabled: false,
            initialMapToolbarEnabled: false,
            initialMapType: MapType.normal,
            initialMapColorScheme: MapColorScheme.dark,
            onMarkerClicked: _handleParkingMarkerTap,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BslModuleTopBar(
              title: 'Parkiraj.ba',
              subtitle: _displayedCity,
              badge: '$displayedParkingCount na mapi',
              searchHint: 'Pretraži parking, adresu ili grad...',
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              onSearchSubmitted: _searchParkingOrAddress,
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            right: 16,
            bottom: _selectedParking == null ? 24 : 230,
            child: BslMapLocationButton(
              isLoading: locationContext?.isLoading ?? false,
              hasLocation: hasUserLocation,
              needsAttention: locationContext?.shouldOpenSettings ?? false,
              onTap: _handleLocationButton,
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
                        navigationVisible: navigationVisible,
                        navigationActive: isSelectedDestinationNavigating,
                        navigationBusy:
                            _parkingNavigation.isBusy &&
                            _parkingNavigation.destination?.id ==
                                _selectedParking!.id,
                        navigationStage: _parkingNavigation.stage,
                        navigationStatusMessage:
                            _parkingNavigation.statusMessage,
                        navigationInfo: _parkingNavigation.navInfo,
                        navigationCanRetry: _parkingNavigation.canRetry,
                        onRecenter: () {
                          unawaited(_parkingNavigation.recenter());
                        },
                        onNavigate: () {
                          if (!navigationVisible) {
                            unawaited(
                              _startParkingNavigation(_selectedParking!),
                            );
                          } else if (_parkingNavigation.stage ==
                                  BslNavigationStage.error &&
                              _parkingNavigation.canRetry) {
                            unawaited(_retryParkingNavigation());
                          } else {
                            unawaited(_stopParkingNavigation());
                          }
                        },
                        onClose: () {
                          unawaited(_closeParkingCard());
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
  final bool navigationVisible;
  final bool navigationActive;
  final bool navigationBusy;
  final BslNavigationStage navigationStage;
  final String navigationStatusMessage;
  final NavInfo? navigationInfo;
  final bool navigationCanRetry;
  final VoidCallback onRecenter;
  final VoidCallback onNavigate;
  final VoidCallback onClose;
  final VoidCallback onDetails;

  const _ParkingBottomCard({
    required this.parking,
    required this.navigationVisible,
    required this.navigationActive,
    required this.navigationBusy,
    required this.navigationStage,
    required this.navigationStatusMessage,
    required this.navigationInfo,
    required this.navigationCanRetry,
    required this.onRecenter,
    required this.onNavigate,
    required this.onClose,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final occupancyPercent = parking.totalSpots == 0
        ? 0.0
        : 1 - (parking.freeSpots / parking.totalSpots);
    final navigationNeedsRetry =
        navigationVisible &&
        navigationStage == BslNavigationStage.error &&
        navigationCanRetry;
    final navigationArrived =
        navigationVisible && navigationStage == BslNavigationStage.arrived;
    late final IconData navigationActionIcon;
    late final String navigationActionLabel;

    if (navigationBusy) {
      navigationActionIcon = Icons.navigation_rounded;
      navigationActionLabel = 'Pokrećem...';
    } else if (navigationNeedsRetry) {
      navigationActionIcon = Icons.refresh_rounded;
      navigationActionLabel = 'Ponovi';
    } else if (navigationArrived) {
      navigationActionIcon = Icons.check_rounded;
      navigationActionLabel = 'Završi';
    } else if (navigationVisible) {
      navigationActionIcon = Icons.stop_circle_outlined;
      navigationActionLabel = 'Zaustavi';
    } else {
      navigationActionIcon = Icons.navigation_rounded;
      navigationActionLabel = 'Navigacija';
    }

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
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
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
          AnimatedSwitcher(
            duration: BslDurations.normal,
            child: navigationVisible
                ? BslNavigationPanel(
                    key: const ValueKey('parking-navigation'),
                    stage: navigationStage,
                    statusMessage: navigationStatusMessage,
                    navInfo: navigationInfo,
                    onRecenter: onRecenter,
                    destinationIcon: Icons.local_parking_rounded,
                  )
                : Column(
                    key: const ValueKey('parking-availability'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                              label:
                                  '${parking.freeSpots}/${parking.totalSpots} slobodno',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _InfoPill(
                              icon: Icons.payments_rounded,
                              label:
                                  '${parking.pricePerHour.toStringAsFixed(2)} KM/h',
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
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ParkingActionButton(
                  icon: navigationActionIcon,
                  label: navigationActionLabel,
                  onTap: navigationBusy ? null : onNavigate,
                  danger:
                      navigationVisible &&
                      !navigationNeedsRetry &&
                      !navigationArrived &&
                      navigationActive,
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

  const _InfoPill({required this.icon, required this.label});

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
          Icon(icon, color: BslColors.cyan, size: 16),
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
  final VoidCallback? onTap;
  final bool secondary;
  final bool danger;

  const _ParkingActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.secondary = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = danger
        ? BslColors.danger.withValues(alpha: 0.16)
        : secondary
        ? Colors.white.withValues(alpha: 0.07)
        : BslColors.cyan.withValues(alpha: 0.18);

    final borderColor = danger
        ? BslColors.danger.withValues(alpha: 0.42)
        : secondary
        ? Colors.white.withValues(alpha: 0.10)
        : BslColors.cyan.withValues(alpha: 0.35);

    final textColor = danger
        ? BslColors.danger
        : secondary
        ? Colors.white
        : BslColors.cyan;

    return AnimatedOpacity(
      duration: BslDurations.fast,
      opacity: onTap == null ? 0.60 : 1,
      child: Material(
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
                Icon(icon, color: textColor, size: 18),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: BslColors.cyan, size: 19),
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
