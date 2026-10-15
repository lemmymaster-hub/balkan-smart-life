import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bsl_app/modules/public_transport/controllers/transit_controller.dart';
import 'package:bsl_app/modules/public_transport/models/transit_models.dart';
import 'package:bsl_app/modules/public_transport/services/transit_service.dart';

class FakeTransitGateway implements TransitGateway {
  bool fail = false;
  bool failTimetable = false;
  int requests = 0;
  Completer<List<TransitArrival>>? pending;
  @override
  Future<List<TransitDirection>> directions(TransitLine line) async => [
    TransitDirection(line.id == 225 ? 1132 : 1125, line.name),
  ];
  @override
  Future<TransitRoute> route(TransitDirection direction) async =>
      const TransitRoute(
        [
          TransitStop(1, 'Početna stanica', TransitPoint(43, 18)),
          TransitStop(2, 'Završna stanica', TransitPoint(43, 18.1)),
        ],
        [TransitPoint(43, 18), TransitPoint(43, 18.1)],
      );
  @override
  Future<List<TransitArrival>> arrivals(
    TransitLine line,
    TransitDirection direction,
    TransitStop stop,
  ) async {
    requests++;
    if (fail) throw Exception('offline');
    if (pending != null) return pending!.future;
    return [
      TransitArrival(
        tripId: 1,
        lineId: line.id,
        destinationStation: 2,
        operatorName: 'GRAS',
        expectedAt: DateTime.utc(2026, 10, 15, 21),
        point: const TransitPoint(43, 18.02),
      ),
    ];
  }

  @override
  Future<List<TransitDeparture>> timetable(
    TransitLine line,
    TransitDirection direction,
  ) async {
    if (failTimetable) throw Exception('offline');
    return [];
  }

  @override
  void dispose() {}
}

void main() {
  test(
    'expires vehicle positions after 60 seconds and clears on network error',
    () async {
      var now = DateTime.utc(2026, 10, 15, 20);
      final gateway = FakeTransitGateway();
      final c = TransitController(gateway: gateway, now: () => now);
      addTearDown(c.dispose);
      await c.start();
      expect(c.arrivals, hasLength(1));
      now = now.add(const Duration(seconds: 61));
      expect(c.arrivals, isEmpty);
      gateway.fail = true;
      await c.refreshArrivals();
      expect(c.arrivalError, isNotNull);
      expect(c.arrivals, isEmpty);
      expect(c.route, isNotNull);
    },
  );

  test(
    'late response for previous stop cannot overwrite selected stop',
    () async {
      final gateway = FakeTransitGateway();
      final c = TransitController(
        gateway: gateway,
        now: () => DateTime.utc(2026, 10, 15, 20),
      );
      addTearDown(c.dispose);
      await c.start();
      final pending = Completer<List<TransitArrival>>();
      gateway.pending = pending;
      final old = c.refreshArrivals();
      gateway.pending = null;
      await c.selectStop(c.route!.stops.last);
      pending.complete([]);
      await old;
      expect(c.stop!.id, 2);
      expect(c.arrivals, hasLength(1));
    },
  );

  test(
    'no refresh while backgrounded; timetable failure does not hide route',
    () async {
      final gateway = FakeTransitGateway()..failTimetable = true;
      final c = TransitController(
        gateway: gateway,
        now: () => DateTime.utc(2026, 10, 15, 20),
      );
      addTearDown(c.dispose);
      await c.start();
      expect(c.timetableError, isNotNull);
      expect(c.route, isNotNull);
      c.setActive(false);
      final count = gateway.requests;
      await c.refreshArrivals();
      expect(gateway.requests, count);
    },
  );
}
