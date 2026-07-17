import 'package:bsl_app/modules/parkiraj/services/navigation_vehicle_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sarajevo = NavigationGeoPoint(latitude: 43.8563, longitude: 18.4131);

  group('NavigationVehicleMotion', () {
    test('računa osnovne pravce kretanja', () {
      expect(
        NavigationVehicleMotion.bearingBetween(
          sarajevo,
          const NavigationGeoPoint(latitude: 43.8663, longitude: 18.4131),
        ),
        closeTo(0, 0.1),
      );
      expect(
        NavigationVehicleMotion.bearingBetween(
          sarajevo,
          const NavigationGeoPoint(latitude: 43.8563, longitude: 18.4231),
        ),
        closeTo(90, 0.1),
      );
      expect(
        NavigationVehicleMotion.bearingBetween(
          sarajevo,
          const NavigationGeoPoint(latitude: 43.8463, longitude: 18.4131),
        ),
        closeTo(180, 0.1),
      );
    });

    test('rotira marker najkraćim putem preko sjevera', () {
      expect(
        NavigationVehicleMotion.shortestBearingDelta(350, 10),
        closeTo(20, 0.001),
      );
      expect(
        NavigationVehicleMotion.shortestBearingDelta(10, 350),
        closeTo(-20, 0.001),
      );

      final motion = NavigationVehicleMotion()
        ..reset(sarajevo, initialBearing: 350);
      motion.updatePreferredBearing(10);

      expect(motion.advance()!.bearing, greaterThan(350));
    });

    test('ignoriše mali GPS šum pri određivanju smjera', () {
      final motion = NavigationVehicleMotion(minimumHeadingDistanceMeters: 2)
        ..reset(sarajevo, initialBearing: 35);

      motion.updateTarget(
        const NavigationGeoPoint(latitude: 43.856303, longitude: 18.413103),
      );

      expect(motion.targetBearing, closeTo(35, 0.001));
    });

    test('prihvata stvarni smjer nakon dovoljnog pomjeranja', () {
      final motion = NavigationVehicleMotion(minimumHeadingDistanceMeters: 1)
        ..reset(sarajevo);

      motion.updateTarget(
        const NavigationGeoPoint(latitude: 43.8563, longitude: 18.4132),
      );

      expect(motion.targetBearing, closeTo(90, 0.1));
      final firstFrame = motion.advance()!;
      expect(firstFrame.position.longitude, greaterThan(sarajevo.longitude));
      expect(firstFrame.position.longitude, lessThan(18.4132));
    });

    test('određuje početni pravac iz najbližeg dijela rute', () {
      final bearing = NavigationVehicleMotion.bearingAlongPath(
        currentPosition: sarajevo,
        path: const <NavigationGeoPoint>[
          NavigationGeoPoint(latitude: 43.8563, longitude: 18.4130),
          NavigationGeoPoint(latitude: 43.8563, longitude: 18.4132),
          NavigationGeoPoint(latitude: 43.8563, longitude: 18.4134),
        ],
      );

      expect(bearing, isNotNull);
      expect(bearing!, closeTo(90, 0.1));
    });
  });
}
