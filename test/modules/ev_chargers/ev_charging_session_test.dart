import 'package:bsl_app/modules/ev_chargers/controllers/ev_charging_session_controller.dart';
import 'package:bsl_app/modules/ev_chargers/models/ev_charger.dart';
import 'package:bsl_app/modules/ev_chargers/models/ev_charging_session.dart';
import 'package:bsl_app/modules/ev_chargers/services/ev_charging_live_session_service.dart';
import 'package:bsl_app/modules/ev_chargers/services/ev_charging_session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvChargingSession', () {
    test('računa jasno označenu procjenu iz nazivne snage i vremena', () {
      final startedAt = DateTime.utc(2026, 7, 17, 10);
      final session = EvChargingSession(
        id: 'estimated-1',
        chargerId: 'osm_node_1',
        chargerName: 'Gradski punjač',
        city: 'Banja Luka',
        connectorLabel: 'Type 2',
        source: EvChargingSessionSource.estimated,
        status: EvChargingSessionStatus.charging,
        startedAt: startedAt,
        updatedAt: startedAt,
        ratedPowerKw: 22,
      );

      expect(
        session.energyAt(startedAt.add(const Duration(minutes: 90))),
        closeTo(33, 0.0001),
      );
      expect(session.isActive, isTrue);
      expect(session.isEstimated, isTrue);
    });

    test('završena procjena zamrzava energiju i trajanje', () {
      final startedAt = DateTime.utc(2026, 7, 17, 10);
      final session = EvChargingSession(
        id: 'estimated-2',
        chargerId: 'osm_node_2',
        chargerName: 'Punjač',
        city: 'Sarajevo',
        connectorLabel: 'Type 2',
        source: EvChargingSessionSource.estimated,
        status: EvChargingSessionStatus.charging,
        startedAt: startedAt,
        updatedAt: startedAt,
        ratedPowerKw: 11,
      );
      final endedAt = startedAt.add(const Duration(hours: 2));
      final completed = session.complete(endedAt);

      expect(completed.status, EvChargingSessionStatus.completed);
      expect(completed.energyAt(endedAt.add(const Duration(hours: 5))), 22);
      expect(
        completed.elapsedAt(DateTime.utc(2026, 7, 18)),
        const Duration(hours: 2),
      );
    });

    test('operatorski dokument koristi stvarne mjerne vrijednosti', () {
      final session = EvChargingLiveSessionService.parseDocument(
        documentId: 'user-1',
        data: <String, dynamic>{
          'sessionId': 'operator-44',
          'chargerId': 'osm_node_44',
          'chargerName': 'e-GO punjač',
          'city': 'Sarajevo',
          'status': 'CHARGING',
          'startedAt': DateTime.utc(2026, 7, 17, 12),
          'updatedAt': DateTime.utc(2026, 7, 17, 12, 15),
          'powerKw': 47.2,
          'energyKwh': 11.8,
          'batteryPercent': 54,
          'provider': 'Test operator',
        },
      );

      expect(session.source, EvChargingSessionSource.operatorLive);
      expect(session.energyAt(DateTime.utc(2026, 7, 17, 13)), 11.8);
      expect(session.powerKw, 47.2);
      expect(session.batteryPercent, 54);
      expect(session.providerName, 'Test operator');
    });
  });

  group('EvChargingSessionController', () {
    test('čuva, završava i uklanja lokalnu procjenu', () async {
      final store = _MemoryChargingSessionStore();
      var now = DateTime.utc(2026, 7, 17, 14);
      final controller = EvChargingSessionController(
        store: store,
        now: () => now,
        enableTicker: false,
      );
      await controller.initialize(userId: 'user-7');

      const charger = EvCharger(
        id: 'osm_node_7',
        source: 'OpenStreetMap',
        sourceId: 'node/7',
        name: 'Testni punjač',
        city: 'Mostar',
        latitude: 43.34,
        longitude: 17.81,
      );
      const connector = EvConnector(type: 'CCS2', powerKw: 50);

      await controller.startEstimated(charger: charger, connector: connector);
      expect(controller.activeSession?.chargerId, charger.id);
      expect(store.saved?.chargerId, charger.id);

      now = now.add(const Duration(minutes: 30));
      await controller.completeEstimated();
      expect(
        controller.displaySession?.status,
        EvChargingSessionStatus.completed,
      );
      expect(controller.displaySession?.energyKwh, 25);

      await controller.dismissEstimated();
      expect(controller.displaySession, isNull);
      expect(store.saved, isNull);
      controller.dispose();
    });
  });
}

class _MemoryChargingSessionStore implements EvChargingSessionStore {
  EvChargingSession? saved;

  @override
  Future<void> clear({required String userId}) async {
    saved = null;
  }

  @override
  Future<EvChargingSession?> load({required String userId}) async => saved;

  @override
  Future<void> save({
    required String userId,
    required EvChargingSession session,
  }) async {
    saved = session;
  }
}
