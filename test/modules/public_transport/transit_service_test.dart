import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bsl_app/modules/public_transport/models/transit_models.dart';
import 'package:bsl_app/modules/public_transport/services/transit_service.dart';

void main() {
  test(
    'requests Ministry arrivals with exact snake_case IDs, not Arrivo proxy',
    () async {
      final service = MinistryTransitService(
        client: MockClient((r) async {
          expect(r.url.host, 'javniprevozks.ba');
          expect(r.url.path, '/api/public/lines/upcoming-arrivals');
          expect(r.method, 'POST');
          expect(r.headers['Content-Type'], 'application/json');
          expect(r.headers.containsKey('Authorization'), isFalse);
          expect(jsonDecode(r.body), {
            'line_id': 225,
            'terminus_line_id': 1132,
            'station_id': 171,
            'limit': 20,
          });
          return http.Response('[]', 200);
        }),
      );
      addTearDown(service.dispose);
      expect(
        await service.arrivals(
          TransitLine.supported.first,
          const TransitDirection(1132, 'Otoka - Vogošća'),
          const TransitStop(171, 'Otoka', TransitPoint(43.8476, 18.3675)),
        ),
        isEmpty,
      );
    },
  );

  test(
    'timetable endpoint uses line ID and selects chosen direction',
    () async {
      final service = MinistryTransitService(
        client: MockClient((r) async {
          expect(r.url.path, '/api/public/lines/timetables/225/list');
          return http.Response(
            jsonEncode([
              {'id': 1133, 'timetable': []},
              {
                'id': 1132,
                'timetable': [
                  {
                    'start_time': '05:30:00',
                    'days_of_week': [1, 2, 3, 4, 5, 6, 7],
                    'rides_on_holidays': true,
                    'receives_passengers': true,
                  },
                ],
              },
            ]),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      final rows = await service.timetable(
        TransitLine.supported.first,
        const TransitDirection(1132, 'Otoka'),
      );
      expect(rows.single.time, '05:30:00');
    },
  );

  test('an HTTP error is not silently converted into no arrivals', () async {
    final service = MinistryTransitService(
      client: MockClient((_) async => http.Response('Forbidden', 403)),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.directions(TransitLine.supported.first),
      throwsA(isA<TransitApiException>()),
    );
  });
}
