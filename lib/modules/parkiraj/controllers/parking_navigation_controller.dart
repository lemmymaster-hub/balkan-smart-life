import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../../../core/theme/bsl_design_system.dart';
import '../models/parking_location.dart';
import '../services/parking_navigation_messages.dart';

enum ParkingNavigationStage {
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

class ParkingNavigationController extends ChangeNotifier {
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

  ParkingNavigationStage _stage = ParkingNavigationStage.idle;
  ParkingLocation? _destination;
  NavInfo? _navInfo;
  String? _errorMessage;

  bool _sessionInitialized = false;
  bool _guidanceStarted = false;
  bool _starting = false;
  bool _stopping = false;
  bool _closed = false;
  bool _canRetry = false;

  ParkingNavigationStage get stage => _stage;
  ParkingLocation? get destination => _destination;
  NavInfo? get navInfo => _navInfo;
  bool get canRetry => _canRetry;

  bool get isBusy {
    return _starting ||
        _stage == ParkingNavigationStage.preparing ||
        _stage == ParkingNavigationStage.waitingForGps ||
        _stage == ParkingNavigationStage.calculatingRoute;
  }

  bool get isGuidanceActive => _guidanceStarted;
  bool get shouldShowPanel => _stage != ParkingNavigationStage.idle;

  String get statusMessage {
    switch (_stage) {
      case ParkingNavigationStage.idle:
        return '';
      case ParkingNavigationStage.preparing:
        return 'Pripremam BSL navigaciju...';
      case ParkingNavigationStage.waitingForGps:
        return 'Tražim precizan GPS signal...';
      case ParkingNavigationStage.calculatingRoute:
        return 'Računam najbolju rutu...';
      case ParkingNavigationStage.guiding:
        return 'Navigacija je aktivna';
      case ParkingNavigationStage.rerouting:
        return 'Prilagođavam rutu tvom kretanju...';
      case ParkingNavigationStage.gpsLost:
        return 'Tražim GPS signal...';
      case ParkingNavigationStage.arrived:
        return 'Stigli ste na odabrani parking.';
      case ParkingNavigationStage.error:
        return _errorMessage ?? 'Navigacija trenutno nije dostupna.';
    }
  }

  Future<void> attachMapController(
    GoogleNavigationViewController controller,
  ) async {
    if (_closed) return;
    _mapController = controller;

    if (_sessionInitialized) {
      await _configureCustomNavigationMap(controller, EdgeInsets.zero);
    }
  }

  Future<void> start({
    required ParkingLocation parking,
    required EdgeInsets mapPadding,
  }) async {
    if (_closed || _starting || _stopping) return;

    final controller = _mapController;
    if (controller == null) {
      _destination = parking;
      _showError('BSL mapa još nije spremna.', canRetry: true);
      return;
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _destination = parking;
      _showError('Vođena navigacija je trenutno dostupna na Androidu.');
      return;
    }

    if (_guidanceStarted && _destination?.id == parking.id) {
      await recenter();
      return;
    }

    _starting = true;
    _destination = parking;
    _navInfo = null;
    _errorMessage = null;
    _canRetry = false;
    _setStage(ParkingNavigationStage.preparing);

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

      _setStage(ParkingNavigationStage.waitingForGps);
      await _waitForRoadSnappedLocation();
      if (_closed) return;

      if (_guidanceStarted) {
        await GoogleMapsNavigator.stopGuidance();
        _guidanceStarted = false;
      }
      await GoogleMapsNavigator.clearDestinations();

      _setStage(ParkingNavigationStage.calculatingRoute);

      final routeStatus = await GoogleMapsNavigator.setDestinations(
        Destinations(
          waypoints: <NavigationWaypoint>[
            NavigationWaypoint.withLatLngTarget(
              title: parking.name,
              target: LatLng(latitude: parking.lat, longitude: parking.lng),
            ),
          ],
          displayOptions: NavigationDisplayOptions(
            showDestinationMarkers: false,
          ),
          routingOptions: RoutingOptions(
            travelMode: NavigationTravelMode.driving,
            routingStrategy: NavigationRoutingStrategy.defaultBest,
            alternateRoutesStrategy: NavigationAlternateRoutesStrategy.one,
            locationTimeoutMs: 30000,
          ),
        ),
      );

      if (routeStatus != NavigationRouteStatus.statusOk) {
        _showError(
          ParkingNavigationMessages.forRouteStatus(routeStatus),
          canRetry: true,
        );
        return;
      }

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
      _setStage(ParkingNavigationStage.guiding);
      await recenter();
    } on SessionInitializationException catch (error) {
      _showError(ParkingNavigationMessages.forInitializationError(error.code));
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
    final parking = _destination;
    if (parking == null || _closed) return;
    await start(parking: parking, mapPadding: mapPadding);
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
      _destination = null;
      _navInfo = null;
      _errorMessage = null;
      _canRetry = false;
      _stage = ParkingNavigationStage.idle;
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
  }

  void _handleNavInfo(NavInfoEvent event) {
    if (_closed || !_guidanceStarted) return;
    _navInfo = event.navInfo;

    if (_stage != ParkingNavigationStage.arrived &&
        _stage != ParkingNavigationStage.gpsLost) {
      switch (event.navInfo.navState) {
        case NavState.enroute:
          _stage = ParkingNavigationStage.guiding;
          break;
        case NavState.rerouting:
          _stage = ParkingNavigationStage.rerouting;
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
    _setStage(ParkingNavigationStage.rerouting);
  }

  void _handleRouteChanged() {
    if (_closed || !_guidanceStarted) return;
    _setStage(ParkingNavigationStage.guiding);
    unawaited(recenter());
  }

  void _handleGpsAvailability(GpsAvailabilityChangeEvent event) {
    if (_closed || !_guidanceStarted) return;

    if (event.isGpsLost || !event.isGpsValidForNavigation) {
      _setStage(ParkingNavigationStage.gpsLost);
    } else if (_stage == ParkingNavigationStage.gpsLost) {
      _setStage(ParkingNavigationStage.guiding);
    }
  }

  void _handleArrival(OnArrivalEvent event) {
    if (_closed || !_guidanceStarted) return;
    _setStage(ParkingNavigationStage.arrived);
  }

  void _showError(String message, {bool canRetry = false}) {
    if (_closed) return;
    _errorMessage = message;
    _canRetry = canRetry;
    _stage = ParkingNavigationStage.error;
    _notifySafely();
  }

  void _setStage(ParkingNavigationStage stage) {
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
    _mapController = null;
    unawaited(_shutdownSession());
    super.dispose();
  }
}
