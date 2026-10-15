import 'package:flutter_test/flutter_test.dart';
import 'package:bsl_app/modules/public_transport/models/transit_models.dart';

void main() {
  test(
    'near-term ETA uses station arrival_minutes even if expected time disagrees',
    () {
      final now = DateTime.utc(2026, 10, 15, 22);
      final row = TransitArrival.fromJson({
        'travel_order_id': 1,
        'line_id': 130,
        'destination_station': 149,
        'arrival_minutes': 2,
        'expected_arrival': '2026-10-15T22:20:00Z',
      }, now);
      expect(row.minutesFrom(now), 2);
    },
  );
  test(
    'zero-minute arrivals remain visible as arriving rather than disappearing',
    () {
      final now = DateTime.utc(2026, 10, 15, 22);
      final row = TransitArrival.fromJson({
        'travel_order_id': 1,
        'line_id': 130,
        'destination_station': 149,
        'arrival_minutes': 0,
      }, now);
      expect(
        selectTransitArrivals(
          [row],
          lineId: 130,
          destinationId: 149,
          now: now.add(const Duration(seconds: 1)),
        ),
        hasLength(1),
      );
    },
  );

  test('API stations are ordered by geometry, not alphabetical name', () {
    final route = TransitRoute.ordered(
      [
        const TransitStop(2, 'A middle', TransitPoint(43, 18.01)),
        const TransitStop(3, 'B end', TransitPoint(43, 18.02)),
        const TransitStop(1, 'Z start', TransitPoint(43, 18)),
      ],
      const [TransitPoint(43, 18), TransitPoint(43, 18.02)],
    );
    expect(route.stops.map((s) => s.id), [1, 2, 3]);
  });

  test(
    'filters wrong line/destination, duplicate trips and expired predictions',
    () {
      final now = DateTime.utc(2026, 10, 15, 20);
      TransitArrival row(int trip, int line, int destination, int minutes) =>
          TransitArrival(
            tripId: trip,
            lineId: line,
            destinationStation: destination,
            operatorName: 'GRAS',
            expectedAt: now.add(Duration(minutes: minutes)),
          );
      final result = selectTransitArrivals(
        [
          row(1, 130, 149, 5),
          row(1, 130, 149, 6),
          row(2, 130, 1454, 3),
          row(3, 225, 149, 2),
          row(4, 130, 149, -1),
          row(5, 130, 149, 2),
        ],
        lineId: 130,
        destinationId: 149,
        now: now,
      );
      expect(result.map((r) => r.tripId), [5, 1]);
    },
  );

  test(
    'fallback ETA advances with time and does not depend on phone timezone',
    () {
      final now = DateTime.utc(2026, 10, 15, 20);
      final row = TransitArrival.fromJson({
        'travel_order_id': 1,
        'line_id': 130,
        'destination_station': 149,
        'arrival_minutes': 5,
        'expected_arrival': 'invalid',
        'latitude': null,
        'longitude': null,
      }, now);
      expect(row.minutesFrom(now.add(const Duration(minutes: 2))), 3);
      expect(row.point, isNull);
      expect(
        () => TransitPoint.fromJson({'latitude': 100, 'longitude': 18}),
        throwsFormatException,
      );
    },
  );

  test(
    'Sarajevo DST switches at UTC boundary, including repeated October hour',
    () {
      expect(sarajevoTime(DateTime.utc(2026, 3, 29, 0, 59)).hour, 1);
      expect(sarajevoTime(DateTime.utc(2026, 3, 29, 1)).hour, 3);
      expect(sarajevoTime(DateTime.utc(2026, 10, 25, 0, 59)).hour, 2);
      expect(sarajevoTime(DateTime.utc(2026, 10, 25, 1)).hour, 2);
      expect(sarajevoTime(DateTime.utc(2026, 1, 1, 23)).day, 2);
    },
  );

  test(
    'timetable respects validity, service weekday, holidays and passenger flag',
    () {
      final departure = TransitDeparture.fromJson({
        'start_time': '05:30:00',
        'days_of_week': [1, 2, 3, 4, 5],
        'valid_from': '2026-09-30T22:00:00Z',
        'valid_to': '2027-12-30T23:00:00Z',
        'rides_on_holidays': true,
        'receives_passengers': true,
      });
      expect(
        departure.validOn(DateTime.utc(2026, 10, 15, 10), holiday: false),
        isTrue,
      );
      expect(
        departure.validOn(DateTime.utc(2026, 10, 17, 10), holiday: false),
        isFalse,
      );
      expect(
        departure.validOn(DateTime.utc(2026, 10, 17, 10), holiday: true),
        isTrue,
      );
      expect(
        departure.validOn(DateTime.utc(2026, 9, 30, 10), holiday: false),
        isFalse,
      );
    },
  );
}
