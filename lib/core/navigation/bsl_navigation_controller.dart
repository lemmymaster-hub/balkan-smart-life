import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../theme/bsl_design_system.dart';
import 'bsl_navigation_destination.dart';
import 'bsl_navigation_messages.dart';
import 'navigation_vehicle_marker_controller.dart';
import 'navigation_vehicle_motion.dart';

enum BslNavigationStage {
  idle,
  preparing,
  waitingForGps,
  calculatingRoute,
  guiding,
  rerouting,
  gpsLost,
  arrived,
  error,
}

enum BslNavigationTravelMode { driving, walking }

class BslNavigationController extends ChangeNotifier {
  GoogleNavigationViewController? _mapController;

  StreamSubscription<RoadSnappedLocationUpdatedEvent>? _locationSubscription;
  StreamSubscription<NavInfoEvent>? _navInfoSubscription;
  StreamSubscription<void>? _reroutingSubscription;
  StreamSubscription<void>? _routeChangedSubscription;
  StreamSubscription<OnArrivalEvent>? _arrivalSubscription;
  StreamSubscription<GpsAvailabilityChangeEvent>? _gpsSubscription;

  Completer<LatLng> _locationFixCompleter = Completer<LatLng>();
  LatLng? _latestRoadSnappedLocation;
  Future<void>? _cleanupFuture;

  late final NavigationVehicleMarkerController _vehicleMarkerController;

  BslNavigationStage _stage = BslNavigationStage.idle;
  BslNavigationDestination? _destination;
  NavInfo? _navInfo;
  String? _errorMessage;
  BslNavigationTravelMode _travelMode = BslNavigationTravelMode.driving;

  bool _sessionInitialized = false;
  bool _guidanceStarted = false;
  bool _starting = false;
  bool _stopping = false;
  bool _closed = false;
  bool _canRetry = false;

  BslNavigationController() {
    _vehicleMarkerController = NavigationVehicleMarkerController(
      onVisibilityChanged: _notifySafely,
    );
  }

  BslNavigationStage get stage => _stage;
  BslNavigationDestination? get destination => _destination;
  NavInfo? get navInfo => _navInfo;
  bool get canRetry => _canRetry;
  BslNavigationTravelMode get travelMode => _travelMode;

  bool get isBusy {
    return _starting ||
        _stage == BslNavigationStage.preparing ||
        _stage == BslNavigationStage.waitingForGps ||
        _stage == BslNavigationStage.calculatingRoute;
  }

  bool get isGuidanceActive => _guidanceStarted;
  bool get isVehicleMarkerVisible => _vehicleMarkerController.isVisible;
  bool get shouldShowPanel => _stage != BslNavigationStage.idle;

  String get statusMessage {
    switch (_stage) {
      case BslNavigationStage.idle:
        return '';
      case BslNavigationStage.preparing:
        return 'Pripremam BSL navigaciju...';
      case BslNavigationStage.waitingForGps:
        return 'Tražim precizan GPS signal...';
      case BslNavigationStage.calculatingRoute:
        return 'Računam najbolju rutu...';
      case BslNavigationStage.guiding:
        return _travelMode == BslNavigationTravelMode.walking
            ? 'Pješačka navigacija je aktivna'
            : 'Navigacija je aktivna';
      case BslNavigationStage.rerouting:
        return 'Prilagođavam rutu tvom kretanju...';
      case BslNavigationStage.gpsLost:
        return 'Tražim GPS signal...';
      case BslNavigationStage.arrived:
        final destinationTitle = _destination?.title.trim();
        return destinationTitle == null || destinationTitle.isEmpty
            ? 'Stigli ste na odredište.'
            : 'Stigli ste: $destinationTitle.';
      case BslNavigationStage.error:
        return _errorMessage ?? 'Navigacija trenutno nije dostupna.';
    }
  }

  Future<void> attachMapController(
    GoogleNavigationViewController controller,
  ) async {
    if (_closed) return;
    _mapController = controller;
    await _vehicleMarkerController.attachMapController(controller);

    if (_sessionInitialized) {
      await _configureCustomNavigationMap(controller, EdgeInsets.zero);
    }
  }

  Future<void> setVehicleMarkerIcon(ImageDescriptor icon) async {
    if (_closed) return;
    await _vehicleMarkerController.setIcon(icon);
  }

  Future<void> start({
    required BslNavigationDestination destination,
    required EdgeInsets mapPadding,
    BslNavigationTravelMode travelMode = BslNavigationTravelMode.driving,
  }) async {
    if (_closed || _starting || _stopping) return;

    final controller = _mapController;
    if (controller == null) {
      _destination = destination;
      _showError('BSL mapa još nije spremna.', canRetry: true);
      return;
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _destination = destination;
      _showError('Vođena navigacija je trenutno dostupna na Androidu.');
      return;
    }

    if (_guidanceStarted &&
        _destination?.id == destination.id &&
        _travelMode == travelMode) {
      await recenter();
      return;
    }

    _starting = true;
    _destination = destination;
    _travelMode = travelMode;
    _navInfo = null;
    _errorMessage = null;
    _canRetry = false;
    _setStage(BslNavigationStage.preparing);

    try {
      final termsAccepted = await _ensureTermsAccepted();
      if (_closed) return;

      if (!termsAccepted) {
        _showError(
          'Za korištenje navigacije potrebno je prihvatiti Google uslove.',
        );
        return;
      }

      await _ensureNavigationSession();
      if (_closed) return;

      await _configureCustomNavigationMap(controller, mapPadding);

      _setStage(BslNavigationStage.waitingForGps);
      await _waitForRoadSnappedLocation();
      if (_closed) return;

      if (_guidanceStarted) {
        await GoogleMapsNavigator.stopGuidance();
        _guidanceStarted = false;
        await _vehicleMarkerController.stop();
      }
      await GoogleMapsNavigator.clearDestinations();

      _setStage(BslNavigationStage.calculatingRoute);

      final routeStatus = await GoogleMapsNavigator.setDestinations(
        Destinations(
          waypoints: <NavigationWaypoint>[
            NavigationWaypoint.withLatLngTarget(
              title: destination.title,
              target: LatLng(
                latitude: destination.latitude,
                longitude: destination.longitude,
              ),
            ),
          ],
          displayOptions: NavigationDisplayOptions(
            showDestinationMarkers: false,
          ),
          routingOptions: RoutingOptions(
            travelMode: travelMode == BslNavigationTravelMode.walking
                ? NavigationTravelMode.walking
                : NavigationTravelMode.driving,
            routingStrategy: NavigationRoutingStrategy.defaultBest,
            alternateRoutesStrategy: NavigationAlternateRoutesStrategy.one,
            locationTimeoutMs: 30000,
          ),
        ),
      );

      if (routeStatus != NavigationRouteStatus.statusOk) {
        _showError(
          BslNavigationMessages.forRouteStatus(routeStatus),
          canRetry: true,
        );
        return;
      }

      final snappedLocation = _latestRoadSnappedLocation!;
      final initialVehicleBearing = travelMode == BslNavigationTravelMode.driving
          ? await _resolveInitialVehicleBearing(snappedLocation)
          : null;

      await GoogleMapsNavigator.setAudioGuidance(
        NavigationAudioGuidanceSettings(
          isBluetoothAudioEnabled: true,
          isVibrationEnabled: true,
          guidanceType: NavigationAudioGuidanceType.alertsAndGuidance,
        ),
      );

      await controller.setNavigationUIEnabled(false);
      await GoogleMapsNavigator.startGuidance();
      _guidanceStarted = true;
      _setStage(BslNavigationStage.guiding);
      if (travelMode == BslNavigationTravelMode.driving) {
        await _vehicleMarkerController.start(
          position: snappedLocation,
          initialBearing: initialVehicleBearing ?? 0,
        );
      } else {
        await _vehicleMarkerController.stop();
      }
      await recenter();
    } on SessionInitializationException catch (error) {
      _showError(BslNavigationMessages.forInitializationError(error.code));
    } on TimeoutException {
      _showError(
        'Nije dobijen dovoljno precizan GPS signal. Izađi na otvoreno i pokušaj ponovo.',
        canRetry: _sessionInitialized,
      );
    } on ViewNotFoundException {
      _showError('BSL mapa više nije dostupna.', canRetry: true);
    } catch (error, stackTrace) {
      debugPrint('BSL IN-MAP NAVIGATION START ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showError('Navigacija se trenutno ne može pokrenuti.', canRetry: true);
    } finally {
      _starting = false;
      _notifySafely();
    }
  }

  Future<void> retry({required EdgeInsets mapPadding}) async {
    final destination = _destination;
    if (destination == null || _closed) return;
    await start(
      destination: destination,
      mapPadding: mapPadding,
      travelMode: _travelMode,
    );
  }

  Future<void> recenter() async {
    final controller = _mapController;
    if (controller == null || !_guidanceStarted || _closed) return;

    try {
      await controller.followMyLocation(CameraPerspective.tilted);
    } on ViewNotFoundException {
      // Mapa je uklonjena prije završetka nativnog poziva.
    } catch (error) {
      debugPrint('BSL IN-MAP NAVIGATION CAMERA ERROR: $error');
    }
  }

  Future<void> stop() async {
    if (_closed || _stopping) return;
    _stopping = true;

    try {
      if (_sessionInitialized) {
        if (_guidanceStarted) {
          await GoogleMapsNavigator.stopGuidance();
        }
        await GoogleMapsNavigator.clearDestinations();
      }
    } on SessionNotInitializedException {
      // Sesija je već ugašena.
    } catch (error) {
      debugPrint('BSL IN-MAP NAVIGATION STOP ERROR: $error');
    } finally {
      _guidanceStarted = false;
      await _vehicleMarkerController.stop();
      _destination = null;
      _navInfo = null;
      _errorMessage = null;
      _canRetry = false;
      _stage = BslNavigationStage.idle;
      _stopping = false;
      _notifySafely();
    }
  }

  Future<bool> _ensureTermsAccepted() async {
    var accepted = await GoogleMapsNavigator.areTermsAccepted();
    if (accepted) return true;

    accepted = await GoogleMapsNavigator.showTermsAndConditionsDialog(
      'Balkan Smart Life navigacija',
      'Balkan Smart Life',
      uiParams: const TermsAndConditionsUIParams(
        backgroundColor: BslColors.bgDark,
        titleColor: Colors.white,
        mainTextColor: BslColors.textSecondary,
        acceptButtonTextColor: BslColors.cyan,
        cancelButtonTextColor: BslColors.danger,
      ),
    );

    return accepted;
  }

  Future<void> _ensureNavigationSession() async {
    if (_sessionInitialized) return;

    await GoogleMapsNavigator.initializeNavigationSession(
      taskRemovedBehavior: TaskRemovedBehavior.quitService,
    );
    _sessionInitialized = true;
    _latestRoadSnappedLocation = null;
    _locationFixCompleter = Completer<LatLng>();
    await _setupListeners();
  }

  Future<void> _configureCustomNavigationMap(
    GoogleNavigationViewController controller,
    EdgeInsets mapPadding,
  ) async {
    try {
      await controller.setNavigationUIEnabled(false);
      await controller.setNavigationHeaderEnabled(false);
      await controller.setNavigationFooterEnabled(false);
      await controller.setRecenterButtonEnabled(false);
      await controller.setSpeedLimitIconEnabled(false);
      await controller.setSpeedometerEnabled(false);
      await controller.setTrafficIncidentCardsEnabled(false);
      await controller.setTrafficPromptsEnabled(false);
      await controller.setReportIncidentButtonEnabled(false);
      if (mapPadding != EdgeInsets.zero) {
        await controller.setPadding(mapPadding);
      }
    } on ViewNotFoundException {
      // Mapa je uklonjena prije završetka nativnog poziva.
    }
  }

  Future<void> _setupListeners() async {
    await _cancelListeners();

    _locationSubscription =
        await GoogleMapsNavigator.setRoadSnappedLocationUpdatedListener(
          _handleRoadSnappedLocation,
        );
    _navInfoSubscription = GoogleMapsNavigator.setNavInfoListener(
      _handleNavInfo,
      numNextStepsToPreview: 1,
    );
    _routeChangedSubscription = GoogleMapsNavigator.setOnRouteChangedListener(
      _handleRouteChanged,
    );
    _arrivalSubscription = GoogleMapsNavigator.setOnArrivalListener(
      _handleArrival,
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      _reroutingSubscription = GoogleMapsNavigator.setOnReroutingListener(
        _handleRerouting,
      );
      _gpsSubscription =
          await GoogleMapsNavigator.setOnGpsAvailabilityChangeListener(
            _handleGpsAvailability,
          );
    }
  }

  Future<void> _waitForRoadSnappedLocation() async {
    if (_latestRoadSnappedLocation != null) return;
    await _locationFixCompleter.future.timeout(const Duration(seconds: 30));
  }

  void _handleRoadSnappedLocation(RoadSnappedLocationUpdatedEvent event) {
    _latestRoadSnappedLocation = event.location;

    if (!_locationFixCompleter.isCompleted) {
      _locationFixCompleter.complete(event.location);
    }

    if (_guidanceStarted &&
        !_closed &&
        _travelMode == BslNavigationTravelMode.driving) {
      _vehicleMarkerController.updateLocation(event.location);
    }
  }

  Future<double?> _resolveInitialVehicleBearing(LatLng currentLocation) async {
    try {
      final routeSegments = await GoogleMapsNavigator.getRouteSegments();
      final routePath = <NavigationGeoPoint>[];

      for (final segment in routeSegments) {
        final points = segment.latLngs;
        if (points == null) continue;

        for (final point in points) {
          if (point != null) {
            routePath.add(_toNavigationGeoPoint(point));
          }
        }
      }

      return NavigationVehicleMotion.bearingAlongPath(
        currentPosition: _toNavigationGeoPoint(currentLocation),
        path: routePath,
      );
    } catch (error) {
      debugPrint('BSL NAVIGATION INITIAL VEHICLE BEARING ERROR: $error');
      return null;
    }
  }

  Future<void> _refreshVehicleBearingFromRoute() async {
    if (_travelMode != BslNavigationTravelMode.driving) return;
    final location = _latestRoadSnappedLocation;
    if (location == null || !_guidanceStarted || _closed) return;

    final bearing = await _resolveInitialVehicleBearing(location);
    if (bearing == null || !_guidanceStarted || _closed) return;

    await _vehicleMarkerController.updatePreferredBearing(bearing);
  }

  NavigationGeoPoint _toNavigationGeoPoint(LatLng point) {
    return NavigationGeoPoint(
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }

  void _handleNavInfo(NavInfoEvent event) {
    if (_closed || !_guidanceStarted) return;
    _navInfo = event.navInfo;

    if (_stage != BslNavigationStage.arrived &&
        _stage != BslNavigationStage.gpsLost) {
      switch (event.navInfo.navState) {
        case NavState.enroute:
          _stage = BslNavigationStage.guiding;
          break;
        case NavState.rerouting:
          _stage = BslNavigationStage.rerouting;
          break;
        case NavState.stopped:
        case NavState.unknown:
          break;
      }
    }

    _notifySafely();
  }

  void _handleRerouting() {
    if (_closed || !_guidanceStarted) return;
    _setStage(BslNavigationStage.rerouting);
  }

  void _handleRouteChanged() {
    if (_closed || !_guidanceStarted) return;
    _setStage(BslNavigationStage.guiding);
    unawaited(_refreshVehicleBearingFromRoute());
    unawaited(recenter());
  }

  void _handleGpsAvailability(GpsAvailabilityChangeEvent event) {
    if (_closed || !_guidanceStarted) return;

    if (event.isGpsLost || !event.isGpsValidForNavigation) {
      _setStage(BslNavigationStage.gpsLost);
    } else if (_stage == BslNavigationStage.gpsLost) {
      _setStage(BslNavigationStage.guiding);
    }
  }

  void _handleArrival(OnArrivalEvent event) {
    if (_closed || !_guidanceStarted) return;
    _setStage(BslNavigationStage.arrived);
  }

  void _showError(String message, {bool canRetry = false}) {
    if (_closed) return;
    _errorMessage = message;
    _canRetry = canRetry;
    _stage = BslNavigationStage.error;
    _notifySafely();
  }

  void _setStage(BslNavigationStage stage) {
    if (_closed) return;
    _stage = stage;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_closed) notifyListeners();
  }

  Future<void> _cancelListeners() async {
    final subscriptions = <StreamSubscription<dynamic>?>[
      _locationSubscription,
      _navInfoSubscription,
      _reroutingSubscription,
      _routeChangedSubscription,
      _arrivalSubscription,
      _gpsSubscription,
    ];

    _locationSubscription = null;
    _navInfoSubscription = null;
    _reroutingSubscription = null;
    _routeChangedSubscription = null;
    _arrivalSubscription = null;
    _gpsSubscription = null;

    for (final subscription in subscriptions) {
      if (subscription == null) continue;
      try {
        await subscription.cancel();
      } catch (error) {
        debugPrint('BSL IN-MAP NAVIGATION LISTENER CLEANUP ERROR: $error');
      }
    }
  }

  Future<void> _shutdownSession() {
    final cleanup = _cleanupFuture;
    if (cleanup != null) return cleanup;

    final nextCleanup = _performSessionCleanup();
    _cleanupFuture = nextCleanup;
    return nextCleanup;
  }

  Future<void> _performSessionCleanup() async {
    await _cancelListeners();
    await _vehicleMarkerController.stop();
    if (!_sessionInitialized) return;

    try {
      await GoogleMapsNavigator.cleanup();
    } on SessionNotInitializedException {
      // Sesija je već ugašena.
    } catch (error) {
      debugPrint('BSL IN-MAP NAVIGATION CLEANUP ERROR: $error');
    } finally {
      _sessionInitialized = false;
      _guidanceStarted = false;
    }
  }

  @override
  void dispose() {
    _closed = true;
    _vehicleMarkerController.dispose();
    _mapController = null;
    unawaited(_shutdownSession());
    super.dispose();
  }
}
