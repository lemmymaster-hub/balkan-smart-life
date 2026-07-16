import 'package:bsl_app/core/models/bsl_city.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BslCities', () {
    test('sadrži svih devet aktivnih gradova', () {
      expect(
        BslCities.values.map((city) => city.name),
        containsAll(<String>[
          'Sarajevo',
          'Banja Luka',
          'Mostar',
          'Tuzla',
          'Zenica',
          'Bihać',
          'Trebinje',
          'Pale',
          'Istočno Sarajevo',
        ]),
      );
      expect(BslCities.values, hasLength(9));
    });

    test('pronalazi grad i bez dijakritičkih znakova', () {
      expect(BslCities.findExact('Bihac')?.name, 'Bihać');
      expect(BslCities.findExact('Istocno Sarajevo')?.name, 'Istočno Sarajevo');
    });

    test('pronalazi grad unutar adrese', () {
      expect(BslCities.findMentionedIn('Mepas Mall, Mostar')?.name, 'Mostar');
      expect(
        BslCities.findMentionedIn('Spasovdanska, Istočno Sarajevo')?.name,
        'Istočno Sarajevo',
      );
    });

    test('određuje najbliži BSL grad prema koordinatama', () {
      expect(
        BslCities.nearestTo(latitude: 43.8581, longitude: 18.4214).name,
        'Sarajevo',
      );
      expect(
        BslCities.nearestTo(latitude: 44.7725, longitude: 17.1908).name,
        'Banja Luka',
      );
    });

    test('računa udaljenost između koordinata', () {
      final distance = BslCities.distanceInKilometers(
        fromLatitude: 43.8563,
        fromLongitude: 18.4131,
        toLatitude: 43.8581,
        toLongitude: 18.4214,
      );

      expect(distance, greaterThan(0.5));
      expect(distance, lessThan(1));
    });
  });
}
