import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/bsl_location_result.dart';
import '../services/bsl_location_service.dart';

enum BslLocationStatus {
  idle,
  loading,
  available,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class BslLocationContext extends ChangeNotifier {
  final BslLocationGateway _locationGateway;

  BslLocationContext({BslLocationGateway? locationGateway})
    : _locationGateway = locationGateway ?? BslLocationService();

  BslLocationStatus _status = BslLocationStatus.idle;
  BslLocationResult? _location;
  Object? _error;
  bool _isLoading = false;
  Future<void>? _activeRequest;
  StreamSubscription<BslLocationResult>? _trackingSubscription;

  BslLocationStatus get status => _status;

  BslLocationResult? get location => _location;

  Object? get error => _error;

  bool get isLoading => _isLoading;

  bool get hasLocation => _location != null;

  bool get isTracking => _trackingSubscription != null;

  BslLocationFailure? get failure {
    final currentError = _error;
    return currentError is BslLocationException ? currentError.failure : null;
  }

  bool get shouldOpenSettings {
    return _status == BslLocationStatus.serviceDisabled ||
        _status == BslLocationStatus.permissionDeniedForever ||
        failure == BslLocationFailure.serviceDisabled ||
        failure == BslLocationFailure.permissionDeniedForever;
  }

  String get statusMessage {
    if (_isLoading && _location == null) {
      return 'Određujem tvoju lokaciju...';
    }

    if (_location != null) {
      if (_location!.isFromCache && _error != null) {
        if (failure == BslLocationFailure.serviceDisabled) {
          return '${_location!.displayLabel} • uključi GPS';
        }
        if (failure == BslLocationFailure.permissionDeniedForever) {
          return '${_location!.displayLabel} • provjeri dozvolu';
        }
        return '${_location!.displayLabel} • čeka se precizna lokacija';
      }
      return _location!.displayLabel;
    }

    switch (_status) {
      case BslLocationStatus.serviceDisabled:
        return 'Uključi lokaciju na uređaju';
      case BslLocationStatus.permissionDenied:
        return 'Dozvoli pristup lokaciji';
      case BslLocationStatus.permissionDeniedForever:
        return 'Omogući lokaciju u postavkama aplikacije';
      case BslLocationStatus.unavailable:
        return 'Lokacija trenutno nije dostupna';
      case BslLocationStatus.idle:
        return 'Lokacija još nije pokrenuta';
      case BslLocationStatus.loading:
        return 'Određujem tvoju lokaciju...';
      case BslLocationStatus.available:
        return 'Lokacija je spremna';
    }
  }

  Future<void> initialize({bool force = false}) {
    final activeRequest = _activeRequest;
    if (activeRequest != null) return activeRequest;

    if (!force && _status == BslLocationStatus.available) {
      _startTracking();
      return Future<void>.value();
    }

    final request = _loadLocation();
    _activeRequest = request;

    return request.whenComplete(() {
      if (identical(_activeRequest, request)) {
        _activeRequest = null;
      }
    });
  }

  Future<void> refresh() => initialize(force: true);

  Future<bool> openRelevantSettings() async {
    try {
      if (_status == BslLocationStatus.serviceDisabled ||
          failure == BslLocationFailure.serviceDisabled) {
        return await _locationGateway.openLocationSettings();
      }

      if (_status == BslLocationStatus.permissionDeniedForever ||
          failure == BslLocationFailure.permissionDeniedForever) {
        return await _locationGateway.openAppSettings();
      }
    } catch (error) {
      debugPrint('BSL LOCATION SETTINGS ERROR: $error');
    }

    return false;
  }

  Future<void> _loadLocation() async {
    _isLoading = true;
    _error = null;
    _status = _location == null
        ? BslLocationStatus.loading
        : BslLocationStatus.available;
    notifyListeners();

    try {
      if (_location == null) {
        final cachedLocation = await _locationGateway.getLastKnownLocation();

        if (cachedLocation != null) {
          _location = cachedLocation;
          _status = BslLocationStatus.available;
          notifyListeners();
        }
      }

      final currentLocation = await _locationGateway.getCurrentLocation();
      _location = currentLocation;
      _status = BslLocationStatus.available;
      _error = null;
      notifyListeners();

      final resolvedLocation = await _locationGateway.resolvePlace(
        currentLocation,
      );
      _location = resolvedLocation;
      notifyListeners();
    } catch (error) {
      _error = error;

      if (_location != null) {
        _status = BslLocationStatus.available;
      } else {
        _status = _statusFromError(error);
      }

      debugPrint('BSL LOCATION ERROR: $error');
    } finally {
      _isLoading = false;
      notifyListeners();

      if (_status == BslLocationStatus.available) {
        _startTracking();
      }
    }
  }

  void _startTracking() {
    if (_trackingSubscription != null) return;

    late final StreamSubscription<BslLocationResult> subscription;
    subscription = _locationGateway.watchLocation().listen(
      _handleTrackedLocation,
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_trackingSubscription, subscription)) {
          _trackingSubscription = null;
        }
        _handleTrackingError(error);
      },
      onDone: () {
        if (identical(_trackingSubscription, subscription)) {
          _trackingSubscription = null;
        }
      },
      cancelOnError: true,
    );
    _trackingSubscription = subscription;
  }

  void _handleTrackedLocation(BslLocationResult nextLocation) {
    final previousLocation = _location;

    _location = nextLocation.copyWith(
      city: nextLocation.city.isNotEmpty
          ? nextLocation.city
          : previousLocation?.city,
      municipality: nextLocation.municipality.isNotEmpty
          ? nextLocation.municipality
          : previousLocation?.municipality,
      country: nextLocation.country.isNotEmpty
          ? nextLocation.country
          : previousLocation?.country,
    );
    _status = BslLocationStatus.available;
    _error = null;
    notifyListeners();
  }

  void _handleTrackingError(Object error) {
    _error = error;
    _status = _location == null
        ? _statusFromError(error)
        : BslLocationStatus.available;
    debugPrint('BSL LOCATION TRACKING ERROR: $error');
    notifyListeners();
  }

  BslLocationStatus _statusFromError(Object error) {
    if (error is! BslLocationException) {
      return BslLocationStatus.unavailable;
    }

    switch (error.failure) {
      case BslLocationFailure.serviceDisabled:
        return BslLocationStatus.serviceDisabled;
      case BslLocationFailure.permissionDenied:
        return BslLocationStatus.permissionDenied;
      case BslLocationFailure.permissionDeniedForever:
        return BslLocationStatus.permissionDeniedForever;
      case BslLocationFailure.unavailable:
        return BslLocationStatus.unavailable;
    }
  }

  @override
  void dispose() {
    final trackingSubscription = _trackingSubscription;
    _trackingSubscription = null;

    if (trackingSubscription != null) {
      unawaited(trackingSubscription.cancel());
    }

    super.dispose();
  }
}
