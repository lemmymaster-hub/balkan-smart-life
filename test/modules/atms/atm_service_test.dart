import 'package:bsl_app/modules/atms/services/atm_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('prazan rezultat pretrage nije greška servisa', () async {
    final service = AtmService(
      client: MockClient((request) async {
        final primary = request.url.path.startsWith('/rest/');
        return http.Response(primary ? '[]' : '{"elements":[]}', 200);
      }),
    );
    addTearDown(service.dispose);

    expect(
      await service.loadNearby(latitude: 43.82, longitude: 18.37),
      isEmpty,
    );
  });

  test('nedostupni izvori se prijavljuju kao greška', () async {
    final service = AtmService(
      client: MockClient((_) async {
        return http.Response('unavailable', 503);
      }),
    );
    addTearDown(service.dispose);

    await expectLater(
      service.loadNearby(latitude: 43.82, longitude: 18.37),
      throwsA(isA<AtmServiceException>()),
    );
  });
}
