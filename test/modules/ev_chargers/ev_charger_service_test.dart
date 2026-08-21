import 'package:bsl_app/core/models/bsl_city.dart';
import 'package:bsl_app/modules/ev_chargers/models/ev_charger.dart';
import 'package:bsl_app/modules/ev_chargers/models/ev_charger_map_policy.dart';
import 'package:bsl_app/modules/ev_chargers/models/ev_charger_verification.dart';
import 'package:bsl_app/modules/ev_chargers/services/ev_charger_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('EvChargerService', () {
    test('koristi aktivni Overpass endpoint umjesto ugašenog Mail.ru', () async {
      final requestedHosts = <String>[];
      final service = EvChargerService(
        httpClient: MockClient((request) async {
          requestedHosts.add(request.url.host);
          return http.Response('{"elements": []}', 200);
        }),
      );

      addTearDown(service.dispose);
      await service.fetchForCity(BslCities.byName('Prijedor'));

      expect(requestedHosts, ['lz4.overpass-api.de']);
    });

    test('prelazi na rezervni endpoint nakon HTTP greške', () async {
      final requestedHosts = <String>[];
      final service = EvChargerService(
        httpClient: MockClient((request) async {
          requestedHosts.add(request.url.host);
          if (request.url.host == 'primary.example') {
            return http.Response('privremeno nedostupno', 503);
          }
          return http.Response('{"elements": []}', 200);
        }),
        overpassEndpoints: const [
          'https://primary.example/api/interpreter',
          'https://fallback.example/api/interpreter',
        ],
      );

      addTearDown(service.dispose);
      await service.fetchForCity(BslCities.byName('Prijedor'));

      expect(requestedHosts, ['primary.example', 'fallback.example']);
    });

    test('nacionalno osvježavanje šalje jedan ograničen OSM upit', () async {
      var requestCount = 0;
      String? requestBody;
      final service = EvChargerService(
        httpClient: MockClient((request) async {
          requestCount++;
          requestBody = request.body;
          return http.Response('''
{
  "elements": [
    {
      "type": "node",
      "id": 502,
      "lat": 44.9799,
      "lon": 16.7140,
      "tags": {"amenity": "charging_station"}
    }
  ]
}
''', 200);
        }),
        overpassEndpoints: const [
          'https://overpass.private.coffee/api/interpreter',
        ],
      );

      addTearDown(service.dispose);
      await service.fetchNationwide();

      expect(requestCount, 1);
      expect(requestBody, contains('3602528142'));
    });

    test('ugrađeni OSM snapshot prikazuje punjače prije mreže', () async {
      final service = EvChargerService(
        httpClient: MockClient((request) async {
          throw StateError('Mreža se ne smije čekati prije prvog rezultata.');
        }),
        bundledSnapshotLoader: () async => '''
{
  "osm3s": {"timestamp_osm_base": "2026-08-21T18:00:10Z"},
  "elements": [
    {
      "type": "node",
      "id": 501,
      "lat": 44.9799,
      "lon": 16.7140,
      "tags": {
        "amenity": "charging_station",
        "name": "Prijedor test punjač",
        "addr:city": "Prijedor"
      }
    }
  ]
}
''',
      );

      addTearDown(service.dispose);
      final firstResult = await service
          .watchForCity(BslCities.byName('Prijedor'))
          .first;

      expect(firstResult.single.name, 'Prijedor test punjač');
      expect(
        firstResult.single.sourceUpdatedAt,
        DateTime.parse('2026-08-21T18:00:10Z'),
      );
    });

    test('pretvara OSM elemente u punjače za izabrani grad', () {
      final chargers = EvChargerService.parseOverpassResponse(
        '''
{
  "elements": [
    {
      "type": "node",
      "id": 101,
      "lat": 43.856,
      "lon": 18.413,
      "tags": {
        "amenity": "charging_station",
        "name": "Centar punjač",
        "addr:street": "Maršala Tita",
        "addr:housenumber": "12",
        "fee": "no",
        "socket:type2": "2",
        "socket:type2:output": "22 kW"
      }
    },
    {
      "type": "way",
      "id": 202,
      "center": {"lat": 43.86, "lon": 18.42},
      "tags": {
        "amenity": "charging_station",
        "operator": "BSL Charge",
        "fee": "yes",
        "charge": "0.50 KM/kWh"
      }
    },
    {
      "type": "node",
      "id": 303,
      "lat": 43.85,
      "lon": 18.41,
      "tags": {
        "amenity": "charging_station",
        "motorcar": "no"
      }
    }
  ]
}
''',
        requestedCity: BslCities.byName('Sarajevo'),
        sourceUpdatedAt: DateTime(2026, 7, 15),
      );

      expect(chargers, hasLength(2));

      final freeCharger = chargers.firstWhere(
        (charger) => charger.id == 'osm_node_101',
      );
      expect(freeCharger.fee, EvChargingFee.free);
      expect(freeCharger.markerLabel, 'free');
      expect(freeCharger.address, 'Maršala Tita 12');
      expect(freeCharger.connectors.single.type, 'Type 2');
      expect(freeCharger.connectors.single.count, 2);
      expect(freeCharger.connectors.single.powerKw, 22);

      final paidCharger = chargers.firstWhere(
        (charger) => charger.id == 'osm_way_202',
      );
      expect(paidCharger.fee, EvChargingFee.paid);
      expect(paidCharger.markerLabel, '0.50 KM/kWh');
      expect(paidCharger.name, 'BSL Charge');
    });

    test('Firestore verifikacija ispravlja OSM podatke', () {
      const charger = EvCharger(
        id: 'osm_node_101',
        source: 'OpenStreetMap',
        sourceId: 'node/101',
        name: 'Stari naziv',
        city: 'Sarajevo',
        latitude: 43.856,
        longitude: 18.413,
      );
      final verifiedAt = DateTime(2026, 7, 15);
      final verification =
          EvChargerVerification.fromMap('osm_node_101', <String, dynamic>{
            'verified': true,
            'name': 'Potvrđeni punjač',
            'feeStatus': 'free',
            'priceLabel': '0 KM',
            'capacity': 4,
            'verifiedAt': verifiedAt.toIso8601String(),
          });

      final result = EvChargerService.mergeVerifications(
        chargers: const [charger],
        verifications: [verification],
        requestedCity: BslCities.byName('Sarajevo'),
      );

      expect(result.single.name, 'Potvrđeni punjač');
      expect(result.single.fee, EvChargingFee.free);
      expect(result.single.capacity, 4);
      expect(result.single.isVerified, isTrue);
      expect(result.single.verifiedAt, verifiedAt);
    });

    test('ne prikazuje punjač koji je verifikacijom ugašen', () {
      const charger = EvCharger(
        id: 'osm_node_101',
        source: 'OpenStreetMap',
        sourceId: 'node/101',
        name: 'Ugašeni punjač',
        city: 'Sarajevo',
        latitude: 43.856,
        longitude: 18.413,
      );
      final verification = EvChargerVerification.fromMap(
        'osm_node_101',
        const <String, dynamic>{'verified': true, 'isActive': false},
      );

      final result = EvChargerService.mergeVerifications(
        chargers: const [charger],
        verifications: [verification],
        requestedCity: BslCities.byName('Sarajevo'),
      );

      expect(result, isEmpty);
    });

    test('ne primjenjuje Firestore zapis koji još nije potvrđen', () {
      const charger = EvCharger(
        id: 'osm_node_101',
        source: 'OpenStreetMap',
        sourceId: 'node/101',
        name: 'OSM naziv',
        city: 'Sarajevo',
        latitude: 43.856,
        longitude: 18.413,
      );
      final pendingVerification = EvChargerVerification.fromMap(
        'osm_node_101',
        const <String, dynamic>{'verified': false, 'name': 'Nepotvrđeni naziv'},
      );

      final result = EvChargerService.mergeVerifications(
        chargers: const [charger],
        verifications: [pendingVerification],
        requestedCity: BslCities.byName('Sarajevo'),
      );

      expect(result.single.name, 'OSM naziv');
      expect(result.single.isVerified, isFalse);
    });

    test('Overpass upit koristi koordinate grada i charging_station', () {
      final city = BslCities.byName('Mostar');
      final query = EvChargerService.buildOverpassQuery(city);

      expect(query, contains('charging_station'));
      expect(query, contains('${city.latitude},${city.longitude}'));
      expect(query, contains('access'));
    });

    test('koristi ukupnu OSM snagu kada socket izlaz nije naveden', () {
      final chargers = EvChargerService.parseOverpassResponse('''
{
  "elements": [
    {
      "type": "node",
      "id": 404,
      "lat": 44.773,
      "lon": 17.190,
      "tags": {
        "amenity": "charging_station",
        "capacity": "3",
        "charging_station:output": "22 kW"
      }
    }
  ]
}
''', requestedCity: BslCities.byName('Banja Luka'));

      expect(chargers.single.connectors.single.type, 'Nazivna snaga');
      expect(chargers.single.connectors.single.powerKw, 22);
      expect(chargers.single.connectors.single.count, 3);
      expect(chargers.single.maxPowerKw, 22);
    });
  });

  group('EvChargerMapPolicy', () {
    test('čuva grad odabran na početnom ekranu', () {
      final shouldCenter = EvChargerMapPolicy.shouldAutoCenterOnLocation(
        selectedCity: BslCities.byName('Banja Luka'),
        detectedCity: BslCities.byName('Sarajevo'),
      );

      expect(shouldCenter, isFalse);
    });

    test('automatski centrira GPS kada je korisnik u odabranom gradu', () {
      final shouldCenter = EvChargerMapPolicy.shouldAutoCenterOnLocation(
        selectedCity: BslCities.byName('Mostar'),
        detectedCity: BslCities.byName('Mostar'),
      );

      expect(shouldCenter, isTrue);
    });
  });
}
