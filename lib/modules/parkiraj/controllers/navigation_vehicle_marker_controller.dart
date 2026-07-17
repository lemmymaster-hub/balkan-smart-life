import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../services/navigation_vehicle_motion.dart';

class NavigationVehicleMarkerController {
  static const Duration _animationInterval = Duration(milliseconds: 80);

  final VoidCallback onVisibilityChanged;
  final NavigationVehicleMotion _motion = NavigationVehicleMotion();

  GoogleNavigationViewController? _mapController;
  ImageDescriptor? _markerIcon;
  Marker? _marker;
  Timer? _animationTimer;
  Future<void>? _markerSetupFuture;

  bool _active = false;
  bool _closed = false;
  bool _updateInProgress = false;
  int _generation = 0;

  NavigationVehicleMarkerController({required this.onVisibilityChanged});

  bool get isVisible => _active && _marker != null;

  Future<void> attachMapController(
    GoogleNavigationViewController controller,
  ) async {
    if (_closed) return;

    if (!identical(_mapController, controller)) {
      final wasVisible = isVisible;
      _generation++;
      _marker = null;
      _stopAnimation();
      _mapController = controller;

      if (wasVisible) onVisibilityChanged();
    }

    if (_active) {
      await _ensureMarker();
    }
  }

  Future<void> setIcon(ImageDescriptor icon) async {
    if (_closed) return;
    _markerIcon = icon;

    if (_active) {
      await _ensureMarker();
      await _renderFrame(force: true);
    }
  }

  Future<void> start({
    required LatLng position,
    required double initialBearing,
  }) async {
    if (_closed) return;

    _active = true;
    _motion.reset(
      _toNavigationGeoPoint(position),
      initialBearing: initialBearing,
    );
    await _ensureMarker();
  }

  void updateLocation(LatLng position) {
    if (_closed || !_active) return;

    _motion.updateTarget(_toNavigationGeoPoint(position));
    unawaited(_ensureMarker());
    unawaited(_renderFrame());
  }

  Future<void> updatePreferredBearing(double bearing) async {
    if (_closed || !_active) return;

    _motion.updatePreferredBearing(bearing);
    await _renderFrame();
  }

  Future<void> stop() async {
    if (_closed && _marker == null) return;

    _active = false;
    await _removeMarker();
  }

  Future<void> _ensureMarker() {
    if (_marker != null || !_active || _closed) {
      return Future<void>.value();
    }

    final pendingSetup = _markerSetupFuture;
    if (pendingSetup != null) return pendingSetup;

    final setup = _createMarker();
    late final Future<void> trackedSetup;
    trackedSetup = setup.whenComplete(() {
      if (identical(_markerSetupFuture, trackedSetup)) {
        _markerSetupFuture = null;
      }
    });
    _markerSetupFuture = trackedSetup;
    return trackedSetup;
  }

  Future<void> _createMarker() async {
    final controller = _mapController;
    final markerIcon = _markerIcon;
    final pose = _motion.pose;

    if (controller == null ||
        markerIcon == null ||
        markerIcon.registeredImageId == null ||
        pose == null ||
        !_active ||
        _closed) {
      return;
    }

    final generation = _generation;

    try {
      final addedMarkers = await controller.addMarkers(<MarkerOptions>[
        MarkerOptions(
          position: _toLatLng(pose.position),
          icon: markerIcon,
          anchor: const MarkerAnchor(u: 0.5, v: 0.5),
          consumeTapEvents: true,
          flat: true,
          rotation: pose.bearing,
          zIndex: 100,
        ),
      ]);
      final addedMarker = addedMarkers.isEmpty ? null : addedMarkers.first;

      final markerIsStillValid =
          !_closed &&
          _active &&
          generation == _generation &&
          identical(_mapController, controller);

      if (!markerIsStillValid) {
        if (addedMarker != null) {
          await _removeMarkerFromMap(controller, addedMarker);
        }
        return;
      }

      if (addedMarker == null) {
        debugPrint('BSL NAVIGATION VEHICLE MARKER WAS NOT CREATED');
        return;
      }

      _marker = addedMarker;
      _startAnimation();
      onVisibilityChanged();
    } on ViewNotFoundException {
      // Mapa je uklonjena prije završetka nativnog poziva.
    } catch (error, stackTrace) {
      debugPrint('BSL NAVIGATION VEHICLE MARKER CREATE ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _startAnimation() {
    _animationTimer ??= Timer.periodic(_animationInterval, (_) {
      if (_closed || !_active || _motion.isSettled) return;
      unawaited(_renderFrame());
    });
  }

  void _stopAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
  }

  Future<void> _renderFrame({bool force = false}) async {
    if (_updateInProgress ||
        _closed ||
        !_active ||
        (!force && _motion.isSettled)) {
      return;
    }

    final controller = _mapController;
    final marker = _marker;
    final icon = _markerIcon;
    final pose = _motion.advance();
    if (controller == null || marker == null || icon == null || pose == null) {
      return;
    }

    final generation = _generation;
    final updatedMarker = marker.copyWith(
      options: marker.options.copyWith(
        position: _toLatLng(pose.position),
        rotation: pose.bearing,
        icon: icon,
      ),
    );

    _updateInProgress = true;
    try {
      final updatedMarkers = await controller.updateMarkers(<Marker>[
        updatedMarker,
      ]);

      if (!_closed &&
          _active &&
          generation == _generation &&
          identical(_mapController, controller) &&
          updatedMarkers.isNotEmpty &&
          updatedMarkers.first != null) {
        _marker = updatedMarkers.first;
      }
    } on MarkerNotFoundException {
      if (generation == _generation) {
        final wasVisible = isVisible;
        _marker = null;
        if (wasVisible) onVisibilityChanged();
        unawaited(_ensureMarker());
      }
    } on ViewNotFoundException {
      // Mapa je uklonjena prije završetka nativnog poziva.
    } catch (error) {
      debugPrint('BSL NAVIGATION VEHICLE MARKER UPDATE ERROR: $error');
    } finally {
      _updateInProgress = false;
    }
  }

  Future<void> _removeMarker() async {
    final hadMarker = _marker != null;
    _generation++;
    _stopAnimation();
    _motion.clear();

    final controller = _mapController;
    final marker = _marker;
    _marker = null;

    if (controller != null && marker != null) {
      await _removeMarkerFromMap(controller, marker);
    }

    if (hadMarker) onVisibilityChanged();
  }

  Future<void> _removeMarkerFromMap(
    GoogleNavigationViewController controller,
    Marker marker,
  ) async {
    try {
      await controller.removeMarkers(<Marker>[marker]);
    } on MarkerNotFoundException {
      // Marker je već uklonjen pri ponovnom kreiranju ili gašenju mape.
    } on ViewNotFoundException {
      // Mapa je uklonjena prije završetka nativnog poziva.
    } catch (error) {
      debugPrint('BSL NAVIGATION VEHICLE MARKER REMOVE ERROR: $error');
    }
  }

  NavigationGeoPoint _toNavigationGeoPoint(LatLng point) {
    return NavigationGeoPoint(
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }

  LatLng _toLatLng(NavigationGeoPoint point) {
    return LatLng(latitude: point.latitude, longitude: point.longitude);
  }

  void dispose() {
    _closed = true;
    _active = false;
    _generation++;
    _stopAnimation();
    _motion.clear();
    _marker = null;
    _markerIcon = null;
    _mapController = null;
  }
}
