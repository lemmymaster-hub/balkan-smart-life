import 'package:bsl_app/modules/parkiraj/models/parking_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParkingLocation city resolution', () {
    test('ne pretpostavlja slobodna mjesta kada broj nedostaje', () {
      final parking = ParkingLocation.fromMap('legacy', {
        'lat': '43.8581',
        'lng': 18.4214,
        'totalSpots': 20,
        'parkingTags': ['garaža', 1],
      });
      expect(parking.freeSpots, 0);
      expect(parking.parkingTags, ['garaža']);
      expect(
        () => ParkingLocation.fromMap('invalid', {'lat': 'NaN', 'lng': 18}),
        throwsFormatException,
      );
    });
    test('koristi koordinate kada Firestore city nedostaje', () {
      final parking = ParkingLocation(
        id: 'sarajevo-without-city',
        name: 'Parking bez grada',
        lat: 43.8581,
        lng: 18.4214,
        totalSpots: 20,
        freeSpots: 5,
      );

      expect(parking.resolvedBslCity.name, 'Sarajevo');
      expect(parking.belongsToBslCity('Sarajevo'), isTrue);
    });

    test('zadržava ispravan eksplicitni BSL grad', () {
      final parking = ParkingLocation(
        id: 'explicit-city',
        name: 'Parking sa gradom',
        city: 'Istočno Sarajevo',
        lat: 43.8581,
        lng: 18.4214,
        totalSpots: 20,
        freeSpots: 5,
      );

      expect(parking.resolvedBslCity.name, 'Istočno Sarajevo');
    });
  });
}
