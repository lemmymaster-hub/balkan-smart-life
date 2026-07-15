import 'dart:async';

import 'package:bsl_app/core/context/bsl_location_context.dart';
import 'package:bsl_app/core/models/bsl_location_result.dart';
import 'package:bsl_app/core/services/bsl_location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BslLocationContext', () {
    test('odmah objavljuje keširanu pa preciznu lokaciju', () async {
      final currentLocationCompleter = Completer<BslLocationResult>();
      final gateway = _FakeLocationGateway(
        lastKnownLocation: () async =>
            _location(latitude: 43.82, longitude: 18.37, isFromCache: true),
        currentLocation: () => currentLocationCompleter.future,
        resolvedLocation: (location) async => location.copyWith(
          city: 'Istočno Sarajevo',
          municipality: 'Istočna Ilidža',
          country: 'Bosna i Hercegovina',
        ),
      );
      final locationContext = BslLocationContext(locationGateway: gateway);

      final initialization = locationContext.initialize();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(locationContext.location?.isFromCache, isTrue);
      expect(locationContext.isLoading, isTrue);
      expect(locationContext.status, BslLocationStatus.available);

      currentLocationCompleter.complete(
        _location(latitude: 43.821, longitude: 18.361, isFromCache: false),
      );
      await initialization;

      expect(locationContext.location?.isFromCache, isFalse);
      expect(locationContext.location?.city, 'Istočno Sarajevo');
      expect(locationContext.isLoading, isFalse);
      expect(locationContext.status, BslLocationStatus.available);
    });

    test('mapira odbijenu dozvolu u jasno stanje', () async {
      final gateway = _FakeLocationGateway(
        lastKnownLocation: () async => throw const BslLocationException(
          BslLocationFailure.permissionDenied,
          'Dozvola nije odobrena.',
        ),
      );
      final locationContext = BslLocationContext(locationGateway: gateway);

      await locationContext.initialize();

      expect(locationContext.location, isNull);
      expect(locationContext.status, BslLocationStatus.permissionDenied);
      expect(locationContext.statusMessage, 'Dozvoli pristup lokaciji');
    });

    test('zadržava keširanu lokaciju ako precizna nije dostupna', () async {
      final gateway = _FakeLocationGateway(
        lastKnownLocation: () async =>
            _location(latitude: 43.82, longitude: 18.37, isFromCache: true),
        currentLocation: () async => throw const BslLocationException(
          BslLocationFailure.unavailable,
          'Lokacija nije dostupna.',
        ),
      );
      final locationContext = BslLocationContext(locationGateway: gateway);

      await locationContext.initialize();

      expect(locationContext.location, isNotNull);
      expect(locationContext.location?.isFromCache, isTrue);
      expect(locationContext.status, BslLocationStatus.available);
      expect(locationContext.error, isNotNull);
    });

    test('otvara postavke lokacije kada je servis isključen', () async {
      final gateway = _FakeLocationGateway(
        lastKnownLocation: () async => throw const BslLocationException(
          BslLocationFailure.serviceDisabled,
          'Lokacija je isključena.',
        ),
      );
      final locationContext = BslLocationContext(locationGateway: gateway);

      await locationContext.initialize();
      final opened = await locationContext.openRelevantSettings();

      expect(opened, isTrue);
      expect(gateway.openedLocationSettings, isTrue);
      expect(gateway.openedAppSettings, isFalse);
    });

    test('otvara postavke aplikacije za trajno odbijenu dozvolu', () async {
      final gateway = _FakeLocationGateway(
        lastKnownLocation: () async => throw const BslLocationException(
          BslLocationFailure.permissionDeniedForever,
          'Dozvola je trajno odbijena.',
        ),
      );
      final locationContext = BslLocationContext(locationGateway: gateway);

      await locationContext.initialize();
      final opened = await locationContext.openRelevantSettings();

      expect(opened, isTrue);
      expect(gateway.openedAppSettings, isTrue);
      expect(gateway.openedLocationSettings, isFalse);
    });

    test(
      'objavljuje kontinuirane lokacije bez gubitka naziva mjesta',
      () async {
        final locationUpdates = StreamController<BslLocationResult>();
        final gateway = _FakeLocationGateway(
          currentLocation: () async =>
              _location(latitude: 43.82, longitude: 18.37, isFromCache: false),
          resolvedLocation: (location) async => location.copyWith(
            city: 'Istočno Sarajevo',
            municipality: 'Istočna Ilidža',
            country: 'Bosna i Hercegovina',
          ),
          locationUpdates: () => locationUpdates.stream,
        );
        final locationContext = BslLocationContext(locationGateway: gateway);
        addTearDown(() async {
          locationContext.dispose();
          await locationUpdates.close();
        });

        await locationContext.initialize();

        locationUpdates.add(
          _location(latitude: 43.821, longitude: 18.371, isFromCache: false),
        );
        await Future<void>.delayed(Duration.zero);

        expect(locationContext.location?.latitude, 43.821);
        expect(locationContext.location?.longitude, 18.371);
        expect(locationContext.location?.city, 'Istočno Sarajevo');
        expect(locationContext.isTracking, isTrue);
      },
    );
  });
}

BslLocationResult _location({
  required double latitude,
  required double longitude,
  required bool isFromCache,
}) {
  return BslLocationResult(
    latitude: latitude,
    longitude: longitude,
    accuracy: 8,
    timestamp: DateTime(2026, 7, 15),
    isFromCache: isFromCache,
  );
}

class _FakeLocationGateway implements BslLocationGateway {
  final Future<BslLocationResult?> Function()? lastKnownLocation;
  final Future<BslLocationResult> Function()? currentLocation;
  final Stream<BslLocationResult> Function()? locationUpdates;
  final Future<BslLocationResult> Function(BslLocationResult location)?
  resolvedLocation;

  bool openedAppSettings = false;
  bool openedLocationSettings = false;

  _FakeLocationGateway({
    this.lastKnownLocation,
    this.currentLocation,
    this.locationUpdates,
    this.resolvedLocation,
  });

  @override
  Future<BslLocationResult?> getLastKnownLocation() {
    return lastKnownLocation?.call() ?? Future<BslLocationResult?>.value();
  }

  @override
  Future<BslLocationResult> getCurrentLocation() {
    final callback = currentLocation;
    if (callback != null) return callback();

    return Future<BslLocationResult>.error(
      const BslLocationException(
        BslLocationFailure.unavailable,
        'Lokacija nije dostupna.',
      ),
    );
  }

  @override
  Stream<BslLocationResult> watchLocation() {
    return locationUpdates?.call() ?? const Stream<BslLocationResult>.empty();
  }

  @override
  Future<BslLocationResult> resolvePlace(BslLocationResult location) {
    return resolvedLocation?.call(location) ??
        Future<BslLocationResult>.value(location);
  }

  @override
  Future<bool> openAppSettings() async {
    openedAppSettings = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openedLocationSettings = true;
    return true;
  }
}
