import 'package:flutter_test/flutter_test.dart';
import 'package:bsl_app/modules/public_transport/models/transit_models.dart';
import 'package:bsl_app/modules/public_transport/models/transit_route_path.dart';

void main() {
  final route = TransitRoutePath(
    const TransitRoute(
      [
        TransitStop(1, 'Origin', TransitPoint(43, 18)),
        TransitStop(2, 'Corner', TransitPoint(43, 18.001)),
        TransitStop(3, 'End', TransitPoint(43.001, 18.001)),
      ],
      [
        TransitPoint(43, 18),
        TransitPoint(43, 18.001),
        TransitPoint(43.001, 18.001),
      ],
    ),
  );
  test(
    'movement follows the route corner, never a diagonal or extrapolation',
    () {
      final now = DateTime.utc(2026, 10, 15, 22);
      final motion = TransitVehicleMotion(route);
      motion.observe(const TransitPoint(43, 18), now);
      motion.observe(
        const TransitPoint(43.0005, 18.001),
        now.add(const Duration(seconds: 5)),
      );
      final middle = motion.pose(now.add(const Duration(milliseconds: 7500)));
      expect(middle.point.latitude, closeTo(43, 1e-7));
      expect(middle.point.longitude, greaterThan(18));
      final end = motion.pose(now.add(const Duration(seconds: 10)));
      final frozen = motion.pose(now.add(const Duration(seconds: 100)));
      expect(end.point.latitude, closeTo(43.0005, 1e-7));
      expect(frozen.point.latitude, end.point.latitude);
      expect(frozen.point.longitude, end.point.longitude);
    },
  );
  test('identical observations do not manufacture continued movement', () {
    final now = DateTime.utc(2026, 10, 15, 22);
    final motion = TransitVehicleMotion(route);
    motion.observe(const TransitPoint(43, 18.0004), now);
    motion.observe(
      const TransitPoint(43, 18.0004),
      now.add(const Duration(seconds: 5)),
    );
    expect(motion.moving(now.add(const Duration(seconds: 10))), isFalse);
  });
  test(
    'next station comes from directional route progress; off-route is unknown',
    () {
      expect(route.nextStop(const TransitPoint(43, 18.0004))?.id, 2);
      expect(route.nextStop(const TransitPoint(43.0003, 18.001))?.id, 3);
      expect(route.nextStop(const TransitPoint(43.001, 18.001)), isNull);
      expect(route.nextStop(const TransitPoint(44, 19)), isNull);
    },
  );
  test(
    'long gaps reset to observed position instead of an implausible fly-through',
    () {
      final now = DateTime.utc(2026, 10, 15, 22);
      final motion = TransitVehicleMotion(route);
      motion.observe(const TransitPoint(43, 18), now);
      motion.observe(
        const TransitPoint(43.0005, 18.001),
        now.add(const Duration(seconds: 40)),
      );
      expect(motion.moving(now.add(const Duration(seconds: 40))), isFalse);
      expect(
        motion.pose(now.add(const Duration(seconds: 40))).point.latitude,
        closeTo(43.0005, 1e-7),
      );
    },
  );
}
