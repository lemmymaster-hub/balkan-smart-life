import 'package:bsl_app/core/navigation/bsl_navigation_messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

void main() {
  group('BslNavigationMessages', () {
    test('svaka greška zajedničke BSL rute ima poruku za korisnika', () {
      for (final status in NavigationRouteStatus.values) {
        final message = BslNavigationMessages.forRouteStatus(status);

        if (status == NavigationRouteStatus.statusOk) {
          expect(message, isEmpty);
        } else {
          expect(message, isNotEmpty, reason: status.name);
        }
      }
    });

    test('greška API ključa jasno navodi Navigation SDK', () {
      expect(
        BslNavigationMessages.forRouteStatus(
          NavigationRouteStatus.apiKeyNotAuthorized,
        ),
        contains('Navigation SDK'),
      );
      expect(
        BslNavigationMessages.forInitializationError(
          SessionInitializationError.notAuthorized,
        ),
        contains('Navigation SDK'),
      );
    });

    test('svaka greška inicijalizacije ima poruku za korisnika', () {
      for (final error in SessionInitializationError.values) {
        expect(
          BslNavigationMessages.forInitializationError(error),
          isNotEmpty,
          reason: error.name,
        );
      }
    });
  });
}
