import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/bsl_location_result.dart';

enum BslLocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class BslLocationException implements Exception {
  final BslLocationFailure failure;
  final String message;

  const BslLocationException(this.failure, this.message);

  @override
  String toString() => message;
}

abstract interface class BslLocationGateway {
  Future<BslLocationResult?> getLastKnownLocation();

  Future<BslLocationResult> getCurrentLocation();

  Stream<BslLocationResult> watchLocation();

  Future<BslLocationResult> resolvePlace(BslLocationResult location);

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

class BslLocationService implements BslLocationGateway {
  static const Duration _currentLocationTimeout = Duration(seconds: 15);
  static const Duration trackingInterval = Duration(seconds: 1);

  @override
  Future<BslLocationResult?> getLastKnownLocation() async {
    await _ensureLocationAccess();

    if (kIsWeb) return null;

    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;

      return _fromPosition(position, isFromCache: true);
    } on UnsupportedError {
      return null;
    }
  }

  @override
  Future<BslLocationResult> getCurrentLocation() async {
    await _ensureLocationAccess();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _currentLocationTimeout,
        ),
      );

      return _fromPosition(position, isFromCache: false);
    } catch (error) {
      if (error is BslLocationException) rethrow;

      throw BslLocationException(
        BslLocationFailure.unavailable,
        'Trenutnu lokaciju nije moguće odrediti. Pokušaj ponovo.',
      );
    }
  }

  @override
  Stream<BslLocationResult> watchLocation() async* {
    await _ensureLocationAccess();

    try {
      await for (final position in Geolocator.getPositionStream(
        locationSettings: _trackingSettings(),
      )) {
        yield _fromPosition(position, isFromCache: false);
      }
    } catch (error) {
      if (error is BslLocationException) rethrow;

      throw const BslLocationException(
        BslLocationFailure.unavailable,
        'Praćenje trenutne lokacije trenutno nije dostupno.',
      );
    }
  }

  @override
  Future<BslLocationResult> resolvePlace(BslLocationResult location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      final placemark = placemarks.isNotEmpty ? placemarks.first : null;

      if (placemark == null) return location;

      return location.copyWith(
        city: _firstNotEmpty([
          placemark.locality,
          placemark.subAdministrativeArea,
          placemark.administrativeArea,
        ]),
        municipality: _firstNotEmpty([
          placemark.subLocality,
          placemark.locality,
          placemark.subAdministrativeArea,
        ]),
        country: placemark.country?.trim() ?? '',
      );
    } catch (error) {
      debugPrint('BSL LOCATION REVERSE GEOCODING ERROR: $error');
      return location;
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } on UnsupportedError {
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } on UnsupportedError {
      return false;
    }
  }

  Future<void> _ensureLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const BslLocationException(
        BslLocationFailure.serviceDisabled,
        'Lokacijske usluge su isključene na uređaju.',
      );
    }

    if (kIsWeb) return;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const BslLocationException(
        BslLocationFailure.permissionDenied,
        'Dozvola za lokaciju nije odobrena.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const BslLocationException(
        BslLocationFailure.permissionDeniedForever,
        'Dozvola za lokaciju je trajno odbijena. Omogući je u postavkama uređaja.',
      );
    }
  }

  LocationSettings _trackingSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: trackingInterval,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  BslLocationResult _fromPosition(
    Position position, {
    required bool isFromCache,
  }) {
    return BslLocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      isFromCache: isFromCache,
    );
  }

  String _firstNotEmpty(List<String?> values) {
    for (final value in values) {
      final normalizedValue = value?.trim() ?? '';
      if (normalizedValue.isNotEmpty) return normalizedValue;
    }

    return '';
  }
}
