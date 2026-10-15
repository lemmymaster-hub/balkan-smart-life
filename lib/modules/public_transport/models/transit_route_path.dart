import 'dart:math' as math;
import 'transit_models.dart';

class TransitPathPosition {
  final TransitPoint point;
  final double meters;
  final double distance;
  final double bearing;
  const TransitPathPosition(
    this.point,
    this.meters,
    this.distance,
    this.bearing,
  );
}

/// Direction-specific geometry, used for station ordering and map interpolation.
class TransitRoutePath {
  final TransitRoute route;
  late final List<double> lengths;
  late final List<double> stopMeters;
  TransitRoutePath(this.route) {
    lengths = [0];
    for (var i = 1; i < route.points.length; i++) {
      lengths.add(
        lengths.last + route.points[i - 1].distanceTo(route.points[i]),
      );
    }
    stopMeters = route.stops.map((s) => project(s.point).meters).toList();
  }

  TransitPathPosition project(TransitPoint point) {
    if (route.points.length < 2) {
      return TransitPathPosition(point, 0, double.infinity, 0);
    }
    var best = TransitPathPosition(route.points.first, 0, double.infinity, 0);
    final scale = math.cos(point.latitude * math.pi / 180);
    for (var i = 1; i < route.points.length; i++) {
      final a = route.points[i - 1], b = route.points[i];
      final dx = (b.longitude - a.longitude) * scale;
      final dy = b.latitude - a.latitude;
      final size = dx * dx + dy * dy;
      if (size < 1e-18) continue;
      final t =
          (((point.longitude - a.longitude) * scale * dx +
                      (point.latitude - a.latitude) * dy) /
                  size)
              .clamp(0.0, 1.0);
      final projected = TransitPoint(
        a.latitude + dy * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      final distance = point.distanceTo(projected);
      if (distance < best.distance) {
        best = TransitPathPosition(
          projected,
          lengths[i - 1] + (lengths[i] - lengths[i - 1]) * t,
          distance,
          bearing(a, b),
        );
      }
    }
    return best;
  }

  TransitPathPosition at(double meters) {
    final target = meters.clamp(0.0, lengths.last);
    for (var i = 1; i < lengths.length; i++) {
      final length = lengths[i] - lengths[i - 1];
      if (length <= .01) continue;
      if (target <= lengths[i] || i == lengths.length - 1) {
        final t = ((target - lengths[i - 1]) / length).clamp(0.0, 1.0);
        final a = route.points[i - 1], b = route.points[i];
        return TransitPathPosition(
          TransitPoint(
            a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t,
          ),
          target,
          0,
          bearing(a, b),
        );
      }
    }
    return TransitPathPosition(route.points.last, lengths.last, 0, 0);
  }

  TransitStop? nextStop(TransitPoint point) {
    final position = project(point);
    if (position.distance > 100) return null;
    for (var i = 0; i < route.stops.length; i++) {
      // Skip a stop underneath/just behind the GPS position, including origin.
      if (stopMeters[i] > position.meters + 15) return route.stops[i];
    }
    return null;
  }

  static double bearing(TransitPoint a, TransitPoint b) {
    const rad = math.pi / 180;
    final latA = a.latitude * rad, latB = b.latitude * rad;
    final delta = (b.longitude - a.longitude) * rad;
    return (math.atan2(
                  math.sin(delta) * math.cos(latB),
                  math.cos(latA) * math.sin(latB) -
                      math.sin(latA) * math.cos(latB) * math.cos(delta),
                ) /
                rad +
            360) %
        360;
  }
}

/// Linear time interpolation along the route between received GPS observations.
/// Never extrapolates beyond the latest observation or advances a stopped feed.
class TransitVehicleMotion {
  final TransitRoutePath path;
  double _from = 0, _to = 0;
  TransitPoint? _raw;
  DateTime? _received;
  DateTime? _started;
  Duration _duration = const Duration(seconds: 5);
  bool _onRoute = true;
  TransitVehicleMotion(this.path);

  void observe(TransitPoint point, DateTime received) {
    final target = path.project(point);
    final previous = _received;
    final current = progress(received);
    final gap = previous == null
        ? const Duration(seconds: 5)
        : received.difference(previous);
    final reset =
        previous == null ||
        gap > const Duration(seconds: 20) ||
        target.distance > 100 ||
        !_onRoute ||
        (target.meters - current).abs() > 300 ||
        target.meters < current - 30;
    _received = received;
    _onRoute = target.distance <= 100;
    if (reset) {
      _from = _to = target.meters;
      _raw = point;
      _started = received;
      return;
    }
    if (_raw != null && _raw!.distanceTo(point) < .5) return;
    _from = current;
    _to = target.meters;
    _raw = point;
    _started = received;
    _duration = Duration(milliseconds: gap.inMilliseconds.clamp(1000, 7000));
  }

  double progress(DateTime now) {
    if (_started == null) return _to;
    final t =
        (now.difference(_started!).inMicroseconds / _duration.inMicroseconds)
            .clamp(0.0, 1.0);
    return _from + (_to - _from) * t;
  }

  bool moving(DateTime now) =>
      _started != null && (_to - progress(now)).abs() > .1;
  TransitPathPosition pose(DateTime now) => _onRoute
      ? path.at(progress(now))
      : TransitPathPosition(_raw!, _to, 0, path.at(_to).bearing);
}
