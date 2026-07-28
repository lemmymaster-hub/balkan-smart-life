import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
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
import '../controllers/ev_charging_session_controller.dart';
import '../models/ev_charger.dart';
import '../models/ev_charger_map_policy.dart';
import '../models/ev_charging_session.dart';
import '../services/ev_charger_service.dart';
import '../services/ev_charging_live_session_service.dart';
import '../widgets/ev_charger_map_overlays.dart';
import '../widgets/ev_charger_marker_factory.dart';

class EvChargersMapScreen extends StatefulWidget {
  final String city;
  final String? initialSearchQuery;
  final bool selectNearestOnOpen;

  const EvChargersMapScreen({
    super.key,
    required this.city,
    this.initialSearchQuery,
    this.selectNearestOnOpen = false,
  });

  @override
  State<EvChargersMapScreen> createState() => _EvChargersMapScreenState();
}

class _EvChargersMapScreenState extends State<EvChargersMapScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final AddressGeocodingService _addressService =
      const AddressGeocodingService();
  final EvChargerService _chargerService = EvChargerService();
  final BslNavigationController _chargerNavigation = BslNavigationController();
  final EvChargingSessionController _chargingSession =
      EvChargingSessionController();
  final EvChargingLiveSessionService _liveChargingSessionService =
      EvChargingLiveSessionService();

  GoogleNavigationViewController? _mapController;
  BslLocationContext? _locationContext;
  StreamSubscription<List<EvCharger>>? _chargersSubscription;
  StreamSubscription<EvChargingSession?>? _liveChargingSessionSubscription;
  late BslCity _activeCity;

  String? _darkMapStyle;
  List<EvCharger> _chargers = const [];
  EvCharger? _selectedCharger;
  Object? _error;
  bool _isLoading = true;

  bool _hasCenteredOnUser = false;
  bool _isCenteringOnUser = false;
  bool _userChangedMapTarget = false;
  bool _requestedFreshLocation = false;
  bool _hasStartedCityListener = false;
  bool _lastHasUserLocation = false;
  bool _lastLocationIsLoading = false;
  bool _lastLocationNeedsAttention = false;
  int _cityRequestId = 0;
  int _markerBuildId = 0;

  final Map<String, ImageDescriptor> _markerIcons = {};
  ImageDescriptor? _navigationVehicleMarker;
  Map<String, EvCharger> _chargerByMarkerId = const {};
  List<Marker> _chargerMarkers = const <Marker>[];
  bool _markerSyncInProgress = false;
  bool _markerSyncPending = false;
  bool _navigationVehicleMarkerLoadRequested = false;
  bool? _nativeLocationIndicatorEnabled;
  String? _lastChargingSessionId;
  bool _initialRequestStarted = false;

  CameraPosition get _initialCameraPosition {
    final location = _locationContext?.location;
    final detectedCity = location == null ? null : _cityFromLocation(location);

    if (location != null &&
        EvChargerMapPolicy.shouldAutoCenterOnLocation(
          selectedCity: _activeCity,
          detectedCity: detectedCity,
        )) {
      return CameraPosition(
        target: LatLng(
          latitude: location.latitude,
          longitude: location.longitude,
        ),
        zoom: 15.5,
      );
    }

    return CameraPosition(
      target: LatLng(
        latitude: _activeCity.latitude,
        longitude: _activeCity.longitude,
      ),
      zoom: _activeCity.mapZoom,
    );
  }

  @override
  void initState() {
    super.initState();
    _activeCity = BslCities.byName(widget.city);
    _searchController.text = widget.initialSearchQuery?.trim() ?? '';
    _chargerNavigation.addListener(_handleChargerNavigationChanged);
    _chargingSession.addListener(_handleChargingSessionChanged);
    unawaited(_loadMapStyle());
    unawaited(_initializeChargingSessions());
  }

  Future<void> _initializeChargingSessions() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

    try {
      await _chargingSession.initialize(userId: userId);
    } catch (error, stackTrace) {
      debugPrint('EV CHARGING SESSION RESTORE ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (userId == 'guest') return;

    _liveChargingSessionSubscription = _liveChargingSessionService
        .watchForUser(userId)
        .listen(
          _chargingSession.setLiveSession,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('EV CHARGING LIVE SESSION ERROR: $error');
            debugPrintStack(stackTrace: stackTrace);
          },
        );
  }

  void _handleChargingSessionChanged() {
    if (!mounted) return;

    final session = _chargingSession.displaySession;
    final sessionCharger = session == null
        ? null
        : _chargerForId(session.chargerId);
    final shouldSelectSession =
        session?.isActive == true && session?.id != _lastChargingSessionId;
    _lastChargingSessionId = session?.id;

    setState(() {
      if (sessionCharger != null && shouldSelectSession) {
        _selectedCharger = sessionCharger;
      }
    });

    if (sessionCharger != null) _scheduleChargerMarkerSync();
  }

  void _handleChargerNavigationChanged() {
    if (!mounted) return;

    setState(() {
      final destination = _chargerNavigation.destination;
      if (_chargerNavigation.shouldShowPanel && destination != null) {
        final destinationCharger = _chargerForId(destination.id);
        if (destinationCharger != null) {
          _selectedCharger = destinationCharger;
        }
      }
    });

    unawaited(_setMapLocationEnabled(_locationContext?.hasLocation ?? false));
  }

  EvCharger? _chargerForId(String id) {
    for (final charger in _chargers) {
      if (charger.id == id) return charger;
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

    if (!_hasStartedCityListener) {
      _hasStartedCityListener = true;
      unawaited(_listenForCity(_activeCity));
    }

    if (!_requestedFreshLocation) {
      _requestedFreshLocation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        nextLocationContext.refresh();
        unawaited(_centerMapOnUser());
      });
    }
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await rootBundle.loadString(
        'assets/maps/bsl_dark_map_style.json',
      );

      if (!mounted) return;
      setState(() => _darkMapStyle = style);

      final controller = _mapController;
      if (controller != null) {
        await _applyMapStyle(controller);
      }
    } catch (error) {
      debugPrint('EV CHARGERS MAP STYLE ERROR: $error');
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
      await _chargerNavigation.setVehicleMarkerIcon(registeredMarker);
    } catch (error, stackTrace) {
      if (registeredMarker?.registeredImageId != null) {
        try {
          await unregisterImage(registeredMarker!);
        } catch (_) {
          // Primarna greška se prijavljuje ispod.
        }
      }
      debugPrint('BSL EV NAVIGATION VEHICLE ASSET ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _listenForCity(BslCity city, {bool forceRefresh = false}) async {
    final requestId = ++_cityRequestId;
    await _chargersSubscription?.cancel();

    if (!mounted || requestId != _cityRequestId) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _chargers = const [];
      _selectedCharger = null;
    });
    _scheduleChargerMarkerSync();

    _chargersSubscription = _chargerService
        .watchForCity(city, forceRefresh: forceRefresh)
        .listen(
          (chargers) {
            if (!mounted || requestId != _cityRequestId) return;

            setState(() {
              _chargers = chargers;
              _isLoading = false;
              _error = null;

              final selectedId = _selectedCharger?.id;
              if (selectedId != null) {
                _selectedCharger = _firstWhereOrNull(
                  chargers,
                  (charger) => charger.id == selectedId,
                );
              }

              final chargingSession = _chargingSession.displaySession;
              if (_selectedCharger == null && chargingSession != null) {
                _selectedCharger = _firstWhereOrNull(
                  chargers,
                  (charger) => charger.id == chargingSession.chargerId,
                );
              }
            });

            _scheduleChargerMarkerSync();

            unawaited(_prepareMarkerIcons(chargers));
            _tryRunInitialRequest();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted || requestId != _cityRequestId) return;
            debugPrint('EV CHARGERS LOAD ERROR: $error');
            debugPrintStack(stackTrace: stackTrace);

            setState(() {
              _error = error;
              _isLoading = false;
            });
          },
        );
  }

  Future<void> _prepareMarkerIcons(List<EvCharger> chargers) async {
    final buildId = ++_markerBuildId;
    final requiredKeys = <String>{};

    for (final charger in chargers) {
      requiredKeys.add(_markerKey(charger, selected: false));
      requiredKeys.add(_markerKey(charger, selected: true));
    }

    final missingKeys = requiredKeys
        .where((key) => !_markerIcons.containsKey(key))
        .toList(growable: false);

    if (missingKeys.isEmpty) return;

    final createdIcons = await Future.wait(
      missingKeys.map((key) async {
        final parts = key.split('|');
        final fee = EvChargingFee.values.byName(parts[0]);
        final selected = parts[1] == 'selected';
        final label = parts.length > 2 && parts[2].isNotEmpty
            ? parts.sublist(2).join('|')
            : null;
        final ImageDescriptor icon;
        try {
          icon = await EvChargerMarkerFactory.create(
            fee: fee,
            label: label,
            isSelected: selected,
          );
        } catch (error, stackTrace) {
          debugPrint('EV CHARGERS MARKER BUILD ERROR: $error');
          debugPrintStack(stackTrace: stackTrace);
          return MapEntry(key, ImageDescriptor.defaultImage);
        }
        return MapEntry(key, icon);
      }),
    );

    if (!mounted || buildId != _markerBuildId) {
      await _unregisterChargerMarkerImages(
        createdIcons.map((entry) => entry.value),
      );
      return;
    }

    setState(() {
      _markerIcons.addEntries(createdIcons);
    });
    _scheduleChargerMarkerSync();
  }

  void _handleLocationContextChanged() {
    if (!mounted) return;

    final locationContext = _locationContext;
    if (locationContext == null) return;

    final shouldRebuild =
        _lastHasUserLocation != locationContext.hasLocation ||
        _lastLocationIsLoading != locationContext.isLoading ||
        _lastLocationNeedsAttention != locationContext.shouldOpenSettings;

    if (shouldRebuild) {
      setState(() {
        _lastHasUserLocation = locationContext.hasLocation;
        _lastLocationIsLoading = locationContext.isLoading;
        _lastLocationNeedsAttention = locationContext.shouldOpenSettings;
      });

      unawaited(_setMapLocationEnabled(locationContext.hasLocation));
    }

    if (locationContext.location != null &&
        !_hasCenteredOnUser &&
        !_userChangedMapTarget) {
      unawaited(_centerMapOnUser());
    }

    _tryRunInitialRequest();
  }

  BslCity? _cityFromLocation(BslLocationResult location) {
    return BslCities.findExact(location.city) ??
        BslCities.findExact(location.municipality) ??
        BslCities.findMentionedIn(location.displayLabel);
  }

  Future<void> _handleLocationButton() async {
    if (_chargerNavigation.isGuidanceActive) {
      await _chargerNavigation.recenter();
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

  Future<void> _centerMapOnUser({bool force = false}) async {
    if (_isCenteringOnUser || _mapController == null) return;
    if (!force && (_hasCenteredOnUser || _userChangedMapTarget)) return;

    final location = _locationContext?.location;
    if (location == null) return;

    final detectedCity = _cityFromLocation(location);

    // Grad odabran na BSL početnom ekranu ima prednost pri prvom ulasku.
    // GPS automatski centrira mapu samo kada pripada istom gradu. Korisnik
    // uvijek može pritisnuti dugme lokacije i tada namjerno preći na GPS grad.
    if (!force) {
      if (!EvChargerMapPolicy.shouldAutoCenterOnLocation(
        selectedCity: _activeCity,
        detectedCity: detectedCity,
      )) {
        if (detectedCity == null) return;
        _hasCenteredOnUser = true;
        return;
      }
    }

    _isCenteringOnUser = true;

    try {
      if (force &&
          detectedCity != null &&
          !BslCities.same(detectedCity.name, _activeCity.name)) {
        await _activateCity(detectedCity, moveToCity: false);
      }

      if (mounted) {
        setState(() {
          _userChangedMapTarget = false;
          _selectedCharger = null;
        });
        _scheduleChargerMarkerSync();
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

  Future<void> _activateCity(BslCity city, {required bool moveToCity}) async {
    final cityChanged = !BslCities.same(city.name, _activeCity.name);

    if (cityChanged && mounted) {
      setState(() {
        _activeCity = city;
        _selectedCharger = null;
      });
      _scheduleChargerMarkerSync();
      unawaited(_listenForCity(city));
    }

    if (moveToCity) {
      _userChangedMapTarget = true;
      _hasCenteredOnUser = true;
      await _animateTo(
        target: LatLng(latitude: city.latitude, longitude: city.longitude),
        zoom: city.mapZoom,
      );
    }
  }

  Future<void> _searchChargerOrAddress(
    String value, {
    bool selectNearestToResult = false,
  }) async {
    if (_chargerNavigation.shouldShowPanel) {
      _searchFocusNode.unfocus();
      _showMessage('Zaustavi navigaciju prije nove pretrage.');
      return;
    }

    final rawQuery = value.trim();
    if (rawQuery.length < 2) return;

    final normalizedQuery = BslCities.normalize(rawQuery);
    final exactCity = BslCities.findExact(rawQuery);

    if (exactCity != null) {
      await _activateCity(exactCity, moveToCity: true);
      if (mounted) _searchFocusNode.unfocus();
      return;
    }

    final charger = _firstWhereOrNull(_chargers, (candidate) {
      final searchable = BslCities.normalize(
        [
          candidate.name,
          candidate.address,
          candidate.city,
          candidate.operatorName,
        ].join(' '),
      );
      return searchable.contains(normalizedQuery);
    });

    if (charger != null) {
      _userChangedMapTarget = true;
      _hasCenteredOnUser = true;
      await _animateTo(target: charger.position, zoom: 17);

      if (!mounted) return;
      setState(() => _selectedCharger = charger);
      _scheduleChargerMarkerSync();
      _searchFocusNode.unfocus();
      return;
    }

    final mentionedCity = BslCities.findMentionedIn(rawQuery);
    if (mentionedCity != null &&
        !BslCities.same(mentionedCity.name, _activeCity.name)) {
      await _activateCity(mentionedCity, moveToCity: false);
    }

    final AddressSearchResult? address;

    try {
      address = await _addressService.searchAddress(
        input: rawQuery,
        city: mentionedCity?.name ?? _activeCity.name,
      );
    } on AddressGeocodingException {
      if (!mounted) return;
      _showMessage('Pretraga adrese trenutno nije dostupna.');
      return;
    }

    if (!mounted) return;

    if (address == null) {
      _showMessage('Nema rezultata za "$rawQuery"');
      return;
    }

    _userChangedMapTarget = true;
    _hasCenteredOnUser = true;
    final nearestCharger = selectNearestToResult
        ? _nearestChargerTo(
            latitude: address.location.latitude,
            longitude: address.location.longitude,
          )
        : null;
    await _animateTo(
      target: nearestCharger?.position ?? address.location,
      zoom: nearestCharger == null ? 16 : 17,
    );

    if (!mounted) return;
    setState(() => _selectedCharger = nearestCharger);
    _scheduleChargerMarkerSync();

    if (selectNearestToResult && nearestCharger == null) {
      _showMessage('Nema mapiranog punjača u blizini tražene lokacije.');
    }

    _searchFocusNode.unfocus();
  }

  EvCharger? _nearestChargerTo({
    required double latitude,
    required double longitude,
  }) {
    final candidates = _chargers
        .where((charger) => charger.isActive)
        .toList(growable: false);
    if (candidates.isEmpty) return null;

    return BslNearestPlaceSelector.find(
      items: candidates,
      latitude: latitude,
      longitude: longitude,
      latitudeOf: (charger) => charger.latitude,
      longitudeOf: (charger) => charger.longitude,
      maxDistanceKilometers: 20,
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

    final location = _locationContext?.location;
    final locationCity = location == null ? null : _cityFromLocation(location);
    final canUseUserLocation =
        location != null &&
        locationCity != null &&
        BslCities.same(locationCity.name, _activeCity.name);

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
        await _searchChargerOrAddress(
          query,
          selectNearestToResult: widget.selectNearestOnOpen,
        );
        return;
      }

      final targetLatitude = canUseUserLocation
          ? location.latitude
          : _activeCity.latitude;
      final targetLongitude = canUseUserLocation
          ? location.longitude
          : _activeCity.longitude;
      final nearestCharger = _nearestChargerTo(
        latitude: targetLatitude,
        longitude: targetLongitude,
      );

      if (nearestCharger == null) return;

      _userChangedMapTarget = true;
      _hasCenteredOnUser = true;
      await _animateTo(target: nearestCharger.position, zoom: 17);
      if (!mounted) return;

      setState(() => _selectedCharger = nearestCharger);
      _scheduleChargerMarkerSync();
    });
  }

  Future<void> _animateTo({
    required LatLng target,
    required double zoom,
  }) async {
    final controller = _mapController;
    if (controller == null) return;

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

    await _chargerNavigation.attachMapController(controller);
    await _applyMapStyle(controller);
    await _setMapLocationEnabled(_locationContext?.hasLocation ?? false);

    if (!mounted || !identical(_mapController, controller)) return;

    _scheduleChargerMarkerSync();
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
      debugPrint('EV CHARGERS MAP STYLE ERROR: $error');
    }
  }

  Future<void> _setMapLocationEnabled(bool enabled) async {
    final controller = _mapController;
    if (controller == null) return;

    final showNativeLocation =
        enabled && !_chargerNavigation.isVehicleMarkerVisible;
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
      debugPrint('EV CHARGERS LOCATION INDICATOR ERROR: $error');
    }
  }

  void _scheduleChargerMarkerSync() {
    _markerSyncPending = true;
    if (_markerSyncInProgress) return;
    unawaited(_drainChargerMarkerSync());
  }

  Future<void> _drainChargerMarkerSync() async {
    _markerSyncInProgress = true;

    try {
      while (mounted && _markerSyncPending) {
        _markerSyncPending = false;
        await _syncChargerMarkers();
      }
    } finally {
      _markerSyncInProgress = false;
      if (mounted && _markerSyncPending) {
        _scheduleChargerMarkerSync();
      }
    }
  }

  Future<void> _syncChargerMarkers() async {
    final controller = _mapController;
    if (controller == null) return;

    final chargers = List<EvCharger>.of(_chargers);
    final markerOptions = chargers
        .map((charger) {
          final selected = charger.id == _selectedCharger?.id;
          final key = _markerKey(charger, selected: selected);

          return MarkerOptions(
            position: charger.position,
            icon: _markerIcons[key] ?? ImageDescriptor.defaultImage,
            anchor: const MarkerAnchor(u: 0.5, v: 1),
            consumeTapEvents: true,
            zIndex: selected ? 2 : 1,
            infoWindow: InfoWindow(
              title: charger.name,
              snippet: _markerSnippet(charger),
            ),
          );
        })
        .toList(growable: false);

    try {
      _chargerByMarkerId = const {};
      await _removeChargerMarkers(controller);

      if (!mounted || !identical(_mapController, controller)) return;

      final markers = await controller.addMarkers(markerOptions);

      if (!mounted || !identical(_mapController, controller)) return;

      final chargerByMarkerId = <String, EvCharger>{};
      final activeChargerMarkers = <Marker>[];
      for (var index = 0; index < markers.length; index++) {
        final marker = markers[index];
        if (marker != null && index < chargers.length) {
          activeChargerMarkers.add(marker);
          chargerByMarkerId[marker.markerId] = chargers[index];
        }
      }
      _chargerMarkers = activeChargerMarkers;
      _chargerByMarkerId = chargerByMarkerId;
    } on ViewNotFoundException {
      // Ekran je zatvoren prije završetka nativnog poziva.
    } catch (error, stackTrace) {
      debugPrint('EV CHARGERS MARKER SYNC ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _removeChargerMarkers(
    GoogleNavigationViewController controller,
  ) async {
    final markers = _chargerMarkers;
    _chargerMarkers = const <Marker>[];
    if (markers.isEmpty) return;

    try {
      await controller.removeMarkers(markers);
    } on MarkerNotFoundException {
      // Markeri su već uklonjeni pri ponovnom kreiranju mape.
    } on ViewNotFoundException {
      // Ekran je zatvoren prije završetka nativnog poziva.
    }
  }

  void _handleChargerMarkerTap(String markerId) {
    final charger = _chargerByMarkerId[markerId];
    if (charger == null) return;
    unawaited(_selectChargerFromMap(charger));
  }

  Future<void> _selectChargerFromMap(EvCharger charger) async {
    if (_chargerNavigation.shouldShowPanel) return;

    _userChangedMapTarget = true;
    _hasCenteredOnUser = true;
    await _animateTo(target: charger.position, zoom: 17);

    if (!mounted) return;
    setState(() => _selectedCharger = charger);
    _scheduleChargerMarkerSync();
  }

  List<EvConnector> _trackableConnectors(EvCharger charger) {
    final byIdentity = <String, EvConnector>{};

    for (final connector in charger.connectors) {
      final powerKw = connector.powerKw;
      if (powerKw == null || powerKw <= 0) continue;
      byIdentity['${connector.type}|$powerKw'] = connector;
    }

    return byIdentity.values.toList(growable: false);
  }

  Future<void> _startChargingTracking(EvCharger charger) async {
    if (_chargerNavigation.shouldShowPanel) {
      _showMessage('Prvo završi navigaciju, zatim pokreni praćenje punjenja.');
      return;
    }

    final activeSession = _chargingSession.activeSession;
    if (activeSession != null) {
      _showMessage(
        activeSession.source == EvChargingSessionSource.operatorLive
            ? 'Operator već prijavljuje aktivnu sesiju.'
            : 'Jedno punjenje se već prati.',
      );
      return;
    }

    final connectors = _trackableConnectors(charger);
    if (connectors.isEmpty) {
      _showMessage('Za ovaj punjač nije potvrđena snaga potrebna za procjenu.');
      return;
    }

    EvConnector? connector;
    if (connectors.length == 1) {
      connector = connectors.single;
    } else {
      connector = await showModalBottomSheet<EvConnector>(
        context: context,
        backgroundColor: BslColors.bgDark,
        showDragHandle: true,
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Izaberi priključak',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Procjena će koristiti nazivnu snagu izabranog priključka.',
                    style: TextStyle(
                      color: BslColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...connectors.map(
                    (candidate) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0x332FE6FF),
                        child: Icon(
                          Icons.electrical_services_rounded,
                          color: BslColors.cyan,
                        ),
                      ),
                      title: Text(
                        candidate.type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        '${_formatPower(candidate.powerKw!)} kW',
                        style: const TextStyle(color: BslColors.textSecondary),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: BslColors.cyan,
                      ),
                      onTap: () => Navigator.pop(sheetContext, candidate),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (!mounted) return;
    final selectedConnector = connector;
    if (selectedConnector == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111A33),
          title: const Text('Pokrenuti BSL praćenje?'),
          content: Text(
            'Prvo pokreni fizičko punjenje na stanici ili u aplikaciji '
            'operatora. BSL će zatim procjenjivati energiju prema nazivnoj '
            'snazi od ${_formatPower(selectedConnector.powerKw!)} kW. Ovo '
            'dugme ne '
            'uključuje punjač i nije mjerenje uživo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Odustani'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.battery_charging_full_rounded),
              label: const Text('Počni praćenje'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    try {
      await _chargingSession.startEstimated(
        charger: charger,
        connector: selectedConnector,
      );
    } on EvChargingSessionException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _handleChargingAction(EvChargingSession session) async {
    if (!session.isEstimated) return;

    if (!session.isActive) {
      await _chargingSession.dismissEstimated();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111A33),
          title: const Text('Završiti praćenje?'),
          content: const Text(
            'BSL će sačuvati završnu procjenu trajanja i isporučene energije. '
            'Zaustavljanje praćenja ne šalje komandu fizičkom punjaču.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Nastavi pratiti'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Završi'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;
    await _chargingSession.completeEstimated();
  }

  Future<void> _startChargerNavigation(EvCharger charger) async {
    if (_chargingSession.activeSession != null) {
      _showMessage('Završi aktivno praćenje punjenja prije navigacije.');
      return;
    }

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
      _selectedCharger = charger;
      _userChangedMapTarget = false;
      _hasCenteredOnUser = true;
    });
    _searchFocusNode.unfocus();
    _scheduleChargerMarkerSync();

    await _chargerNavigation.start(
      destination: BslNavigationDestination(
        id: charger.id,
        title: charger.name,
        latitude: charger.latitude,
        longitude: charger.longitude,
      ),
      mapPadding: _navigationMapPadding(),
    );

    final controller = _mapController;
    if (controller != null) {
      await _applyMapStyle(controller);
    }
  }

  Future<void> _stopChargerNavigation() async {
    await _chargerNavigation.stop();
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

  Future<void> _retryChargerNavigation() async {
    await _chargerNavigation.retry(mapPadding: _navigationMapPadding());

    final controller = _mapController;
    if (controller != null) {
      await _applyMapStyle(controller);
    }
  }

  Future<void> _closeChargerCard() async {
    if (_chargerNavigation.shouldShowPanel) {
      await _stopChargerNavigation();
    }

    if (!mounted) return;

    setState(() => _selectedCharger = null);
    _scheduleChargerMarkerSync();
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

  String _markerKey(EvCharger charger, {required bool selected}) {
    return '${charger.fee.name}|${selected ? 'selected' : 'normal'}|'
        '${charger.markerLabel ?? ''}';
  }

  String _markerSnippet(EvCharger charger) {
    switch (charger.fee) {
      case EvChargingFee.free:
        return 'Besplatno punjenje';
      case EvChargingFee.paid:
        return charger.priceLabel.isEmpty
            ? 'Punjenje se naplaćuje'
            : charger.priceLabel;
      case EvChargingFee.unknown:
        return 'Cijena nije potvrđena';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _retry() async {
    _chargerService.clearCache(_activeCity);
    await _listenForCity(_activeCity, forceRefresh: true);
  }

  Future<void> _unregisterChargerMarkerImages(
    Iterable<ImageDescriptor> images,
  ) async {
    for (final image in images.toSet()) {
      if (image.registeredImageId == null) continue;
      try {
        await unregisterImage(image);
      } catch (error) {
        debugPrint('EV CHARGERS MARKER CLEANUP ERROR: $error');
      }
    }
  }

  Future<void> _disposeMapResources(
    GoogleNavigationViewController? controller,
    List<ImageDescriptor> images,
  ) async {
    _chargerMarkers = const <Marker>[];
    _chargerByMarkerId = const {};

    if (controller != null) {
      try {
        await controller.clearMarkers();
      } on ViewNotFoundException {
        // Nativni prikaz je već uklonjen.
      } catch (error) {
        debugPrint('EV CHARGERS MAP CLEANUP ERROR: $error');
      }
    }

    await _unregisterChargerMarkerImages(images);
  }

  @override
  void dispose() {
    _chargersSubscription?.cancel();
    _liveChargingSessionSubscription?.cancel();
    _locationContext?.removeListener(_handleLocationContextChanged);
    _chargerNavigation.removeListener(_handleChargerNavigationChanged);
    _chargingSession.removeListener(_handleChargingSessionChanged);
    _chargerNavigation.dispose();
    _chargingSession.dispose();
    _chargerService.dispose();
    final controller = _mapController;
    _mapController = null;
    final markerImages = List<ImageDescriptor>.of(_markerIcons.values);
    final navigationVehicleMarker = _navigationVehicleMarker;
    if (navigationVehicleMarker != null) {
      markerImages.add(navigationVehicleMarker);
    }
    _markerIcons.clear();
    _navigationVehicleMarker = null;
    unawaited(_disposeMapResources(controller, markerImages));
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationContext = _locationContext;
    final hasUserLocation = locationContext?.hasLocation ?? false;
    final selectedCharger = _selectedCharger;
    final hasSelectedCharger = selectedCharger != null;
    final navigationVisible =
        selectedCharger != null &&
        _chargerNavigation.shouldShowPanel &&
        _chargerNavigation.destination?.id == selectedCharger.id;
    final isSelectedDestinationNavigating =
        selectedCharger != null &&
        _chargerNavigation.isGuidanceActive &&
        _chargerNavigation.destination?.id == selectedCharger.id;
    final displayedChargingSession = _chargingSession.displaySession;
    final selectedChargingSession =
        selectedCharger != null &&
            displayedChargingSession?.chargerId == selectedCharger.id
        ? displayedChargingSession
        : null;
    final chargingTrackingAvailable =
        selectedCharger != null &&
        _trackableConnectors(selectedCharger).isNotEmpty;
    final selectedCardOffset = navigationVisible
        ? 302.0
        : selectedChargingSession != null
        ? 384.0
        : 254.0;

    return Scaffold(
      backgroundColor: BslColors.bgDark,
      body: Stack(
        children: [
          GoogleMapsNavigationView(
            onViewCreated: (controller) {
              unawaited(_onMapViewCreated(controller));
            },
            initialCameraPosition: _initialCameraPosition,
            initialNavigationUIEnabledPreference:
                NavigationUIEnabledPreference.disabled,
            initialMapColorScheme: MapColorScheme.dark,
            initialZoomControlsEnabled: false,
            initialMapToolbarEnabled: false,
            initialMapType: MapType.normal,
            onMarkerClicked: _handleChargerMarkerTap,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BslModuleTopBar(
              title: 'EL Punjači',
              subtitle: _activeCity.name,
              badge: '${_chargers.length} punjača',
              searchHint: 'Nađi punjač',
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              onSearchSubmitted: _searchChargerOrAddress,
            ),
          ),
          if (_isLoading)
            const Positioned(
              top: 154,
              left: 0,
              right: 0,
              child: Center(
                child: EvMapStatusPill(
                  icon: Icons.sync_rounded,
                  text: 'Učitavam OSM punjače...',
                  showProgress: true,
                ),
              ),
            ),
          if (_error != null && !_isLoading)
            Positioned(
              top: 154,
              left: 18,
              right: 18,
              child: EvChargerErrorCard(error: _error!, onRetry: _retry),
            ),
          AnimatedPositioned(
            duration: BslDurations.normal,
            curve: Curves.easeOutCubic,
            right: 16,
            bottom: hasSelectedCharger ? selectedCardOffset : 28,
            child: BslMapLocationButton(
              isLoading: locationContext?.isLoading ?? false,
              hasLocation: hasUserLocation,
              needsAttention: locationContext?.shouldOpenSettings ?? false,
              onTap: _handleLocationButton,
            ),
          ),
          AnimatedPositioned(
            duration: BslDurations.normal,
            curve: Curves.easeOutCubic,
            left: 14,
            bottom: hasSelectedCharger ? selectedCardOffset - 2 : 18,
            child: const EvOsmAttribution(),
          ),
          AnimatedPositioned(
            duration: BslDurations.normal,
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: hasSelectedCharger ? 0 : -460,
            child: AnimatedOpacity(
              duration: BslDurations.fast,
              opacity: hasSelectedCharger ? 1 : 0,
              child: IgnorePointer(
                ignoring: !hasSelectedCharger,
                child: _selectedCharger == null
                    ? const SizedBox.shrink()
                    : EvChargerBottomCard(
                        charger: _selectedCharger!,
                        navigationVisible: navigationVisible,
                        navigationActive: isSelectedDestinationNavigating,
                        navigationBusy:
                            _chargerNavigation.isBusy &&
                            _chargerNavigation.destination?.id ==
                                _selectedCharger!.id,
                        navigationStage: _chargerNavigation.stage,
                        navigationStatusMessage:
                            _chargerNavigation.statusMessage,
                        navigationInfo: _chargerNavigation.navInfo,
                        navigationCanRetry: _chargerNavigation.canRetry,
                        chargingSession: selectedChargingSession,
                        chargingNow: _chargingSession.currentTime,
                        chargingTrackingAvailable: chargingTrackingAvailable,
                        onRecenter: () {
                          unawaited(_chargerNavigation.recenter());
                        },
                        onNavigate: () {
                          if (!navigationVisible) {
                            unawaited(
                              _startChargerNavigation(_selectedCharger!),
                            );
                          } else if (_chargerNavigation.stage ==
                                  BslNavigationStage.error &&
                              _chargerNavigation.canRetry) {
                            unawaited(_retryChargerNavigation());
                          } else {
                            unawaited(_stopChargerNavigation());
                          }
                        },
                        onTrackCharging: () {
                          unawaited(_startChargingTracking(_selectedCharger!));
                        },
                        onChargingAction: () {
                          final session = selectedChargingSession;
                          if (session != null) {
                            unawaited(_handleChargingAction(session));
                          }
                        },
                        onClose: () {
                          unawaited(_closeChargerCard());
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

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}

String _formatPower(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
