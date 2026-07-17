import 'dart:math' as math;

class NavigationGeoPoint {
  final double latitude;
  final double longitude;

  const NavigationGeoPoint({required this.latitude, required this.longitude});
}

class NavigationVehiclePose {
  final NavigationGeoPoint position;
  final double bearing;

  const NavigationVehiclePose({required this.position, required this.bearing});
}

/// Shared BSL filter that turns road-snapped GPS updates into smooth vehicle
/// positions and headings suitable for every map-based navigation module.
class NavigationVehicleMotion {
  static const double _earthRadiusMeters = 6371000;

  final double minimumHeadingDistanceMeters;
  final double minimumPositionDistanceMeters;
  final double positionSmoothingFactor;
  final double bearingSmoothingFactor;

  NavigationGeoPoint? _targetPosition;
  NavigationGeoPoint? _lastHeadingPosition;
  NavigationVehiclePose? _pose;
  double _targetBearing = 0;

  NavigationVehicleMotion({
    this.minimumHeadingDistanceMeters = 1.8,
    this.minimumPositionDistanceMeters = 0.25,
    this.positionSmoothingFactor = 0.78,
    this.bearingSmoothingFactor = 0.38,
  }) : assert(minimumHeadingDistanceMeters >= 0),
       assert(minimumPositionDistanceMeters >= 0),
       assert(positionSmoothingFactor > 0 && positionSmoothingFactor <= 1),
       assert(bearingSmoothingFactor > 0 && bearingSmoothingFactor <= 1);

  NavigationVehiclePose? get pose => _pose;
  double? get targetBearing => _pose == null ? null : _targetBearing;

  bool get isSettled {
    final pose = _pose;
    final target = _targetPosition;
    if (pose == null || target == null) return true;

    return distanceMeters(pose.position, target) < 0.08 &&
        shortestBearingDelta(pose.bearing, _targetBearing).abs() < 0.15;
  }

  void reset(NavigationGeoPoint position, {double initialBearing = 0}) {
    final normalizedBearing = normalizeBearing(initialBearing);
    _targetPosition = position;
    _lastHeadingPosition = position;
    _targetBearing = normalizedBearing;
    _pose = NavigationVehiclePose(
      position: position,
      bearing: normalizedBearing,
    );
  }

  void clear() {
    _targetPosition = null;
    _lastHeadingPosition = null;
    _pose = null;
    _targetBearing = 0;
  }

  void updateTarget(NavigationGeoPoint position) {
    if (_pose == null || _targetPosition == null) {
      reset(position);
      return;
    }

    final headingReference = _lastHeadingPosition!;
    final headingDistance = distanceMeters(headingReference, position);

    if (headingDistance >= minimumHeadingDistanceMeters) {
      _targetBearing = bearingBetween(headingReference, position);
      _lastHeadingPosition = position;
    }

    if (distanceMeters(_targetPosition!, position) >=
        minimumPositionDistanceMeters) {
      _targetPosition = position;
    }
  }

  void updatePreferredBearing(double bearing) {
    if (_pose == null) return;
    _targetBearing = normalizeBearing(bearing);
  }

  NavigationVehiclePose? advance() {
    final pose = _pose;
    final target = _targetPosition;
    if (pose == null || target == null) return null;

    final remainingDistance = distanceMeters(pose.position, target);
    final nextPosition = remainingDistance < 0.12
        ? target
        : NavigationGeoPoint(
            latitude:
                pose.position.latitude +
                (target.latitude - pose.position.latitude) *
                    positionSmoothingFactor,
            longitude:
                pose.position.longitude +
                (target.longitude - pose.position.longitude) *
                    positionSmoothingFactor,
          );

    final bearingDelta = shortestBearingDelta(pose.bearing, _targetBearing);
    final nextBearing = bearingDelta.abs() < 0.15
        ? _targetBearing
        : normalizeBearing(
            pose.bearing + bearingDelta * bearingSmoothingFactor,
          );

    return _pose = NavigationVehiclePose(
      position: nextPosition,
      bearing: nextBearing,
    );
  }

  static double normalizeBearing(double bearing) {
    final normalized = bearing % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  static double shortestBearingDelta(double from, double to) {
    return (normalizeBearing(to) - normalizeBearing(from) + 540) % 360 - 180;
  }

  static double distanceMeters(NavigationGeoPoint from, NavigationGeoPoint to) {
    final latitudeDelta = _toRadians(to.latitude - from.latitude);
    final longitudeDelta = _toRadians(to.longitude - from.longitude);
    final fromLatitude = _toRadians(from.latitude);
    final toLatitude = _toRadians(to.latitude);

    final haversine =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(fromLatitude) *
            math.cos(toLatitude) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    final clampedHaversine = haversine.clamp(0.0, 1.0).toDouble();

    return _earthRadiusMeters *
        2 *
        math.atan2(
          math.sqrt(clampedHaversine),
          math.sqrt(1 - clampedHaversine),
        );
  }

  static double bearingBetween(NavigationGeoPoint from, NavigationGeoPoint to) {
    final fromLatitude = _toRadians(from.latitude);
    final toLatitude = _toRadians(to.latitude);
    final longitudeDelta = _toRadians(to.longitude - from.longitude);

    final y = math.sin(longitudeDelta) * math.cos(toLatitude);
    final x =
        math.cos(fromLatitude) * math.sin(toLatitude) -
        math.sin(fromLatitude) *
            math.cos(toLatitude) *
            math.cos(longitudeDelta);

    return normalizeBearing(_toDegrees(math.atan2(y, x)));
  }

  static double? bearingAlongPath({
    required NavigationGeoPoint currentPosition,
    required Iterable<NavigationGeoPoint> path,
    double minimumSegmentDistanceMeters = 2,
  }) {
    final points = path.toList(growable: false);
    if (points.length < 2) return null;

    var nearestIndex = 0;
    var nearestDistance = double.infinity;

    for (var index = 0; index < points.length; index++) {
      final distance = distanceMeters(currentPosition, points[index]);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }

    final origin = points[nearestIndex];
    for (var index = nearestIndex + 1; index < points.length; index++) {
      if (distanceMeters(origin, points[index]) >=
          minimumSegmentDistanceMeters) {
        return bearingBetween(origin, points[index]);
      }
    }

    for (var index = nearestIndex - 1; index >= 0; index--) {
      if (distanceMeters(points[index], origin) >=
          minimumSegmentDistanceMeters) {
        return bearingBetween(points[index], origin);
      }
    }

    return null;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
  static double _toDegrees(double radians) => radians * 180 / math.pi;
}
