import 'package:bsl_app/modules/parkiraj/services/parking_navigation_messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

void main() {
  group('ParkingNavigationMessages', () {
    test('svaka greška rute ima poruku za korisnika', () {
      for (final status in NavigationRouteStatus.values) {
        final message = ParkingNavigationMessages.forRouteStatus(status);

        if (status == NavigationRouteStatus.statusOk) {
          expect(message, isEmpty);
        } else {
          expect(message, isNotEmpty, reason: status.name);
        }
      }
    });

    test('greška API ključa jasno navodi Navigation SDK', () {
      expect(
        ParkingNavigationMessages.forRouteStatus(
          NavigationRouteStatus.apiKeyNotAuthorized,
        ),
        contains('Navigation SDK'),
      );
      expect(
        ParkingNavigationMessages.forInitializationError(
          SessionInitializationError.notAuthorized,
        ),
        contains('Navigation SDK'),
      );
    });

    test('svaka greška inicijalizacije ima poruku za korisnika', () {
      for (final error in SessionInitializationError.values) {
        expect(
          ParkingNavigationMessages.forInitializationError(error),
          isNotEmpty,
          reason: error.name,
        );
      }
    });
  });
}
