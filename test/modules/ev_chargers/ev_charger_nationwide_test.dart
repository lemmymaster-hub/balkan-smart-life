import 'package:bsl_app/modules/ev_chargers/services/ev_charger_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EvChargerService nationwide', () {
    test('ugrađeni BiH snapshot je dostupan i parsira se', () async {
      final responseBody = await rootBundle.loadString(
        'assets/data/bsl_ev_chargers_bih.json',
      );
      final chargers = EvChargerService.parseNationwideOverpassResponse(
        responseBody,
      );

      expect(chargers.length, greaterThan(100));
      expect(
        chargers.every((charger) => charger.sourceUpdatedAt != null),
        isTrue,
      );
    });

    test('Overpass upit obuhvata cijelu Bosnu i Hercegovinu', () {
      final query = EvChargerService.buildNationwideOverpassQuery();

      expect(query, contains('3602528142'));
      expect(query, contains('charging_station'));
      expect(query, isNot(contains('(around:')));
    });

    test('backend sync helper koristi četiri BiH sektora bez radius upita', () {
      final queries = EvChargerService.buildNationwideSectorQueries();

      expect(queries, hasLength(4));
      for (final query in queries) {
        expect(query, contains('3602528142'));
        expect(query, contains('charging_station'));
        expect(query, isNot(contains('(around:')));
      }
    });

    test('parser zadržava aktivne punjače iz više gradova', () {
      final chargers = EvChargerService.parseNationwideOverpassResponse('''
{
  "elements": [
    {
      "type": "node",
      "id": 1001,
      "lat": 43.856,
      "lon": 18.413,
      "tags": {
        "amenity": "charging_station",
        "name": "Sarajevo punjač",
        "addr:city": "Sarajevo"
      }
    },
    {
      "type": "node",
      "id": 1002,
      "lat": 44.772,
      "lon": 17.191,
      "tags": {
        "amenity": "charging_station",
        "name": "Banja Luka punjač",
        "addr:city": "Banja Luka"
      }
    },
    {
      "type": "node",
      "id": 1003,
      "lat": 44.98,
      "lon": 16.71,
      "tags": {
        "amenity": "charging_station",
        "name": "Prijedor punjač",
        "addr:city": "Prijedor"
      }
    }
  ]
}
''');

      expect(chargers, hasLength(3));
      expect(chargers.map((charger) => charger.city), contains('Sarajevo'));
      expect(chargers.map((charger) => charger.city), contains('Banja Luka'));
      expect(chargers.map((charger) => charger.city), contains('Prijedor'));
    });

    test('nacionalni parser ne prikazuje punjače samo za bicikla', () {
      final chargers = EvChargerService.parseNationwideOverpassResponse('''
{
  "elements": [
    {
      "type": "node",
      "id": 2001,
      "lat": 43.856,
      "lon": 18.413,
      "tags": {
        "amenity": "charging_station",
        "motorcar": "no",
        "addr:city": "Sarajevo"
      }
    }
  ]
}
''');

      expect(chargers, isEmpty);
    });
  });
}
