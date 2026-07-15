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
  });
}
