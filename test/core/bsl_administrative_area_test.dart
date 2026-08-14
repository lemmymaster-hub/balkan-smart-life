import 'package:bsl_app/core/models/bsl_administrative_area.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BslAdministrativeAreas', () {
    test('sadrži kompletan BiH skup lokalnih područja', () {
      expect(BslAdministrativeAreas.values, hasLength(145));
      expect(BslAdministrativeAreas.displayNames, hasLength(145));
      expect(BslAdministrativeAreas.displayNames, contains('Pale'));
      expect(BslAdministrativeAreas.displayNames, contains('Pale-Prača'));
      expect(BslAdministrativeAreas.displayNames, contains('Prijedor'));
      expect(BslAdministrativeAreas.displayNames, contains('Trnovo (FBiH)'));
      expect(BslAdministrativeAreas.displayNames, contains('Trnovo (RS)'));
      expect(BslAdministrativeAreas.displayNames, contains('Brčko distrikt'));
    });

    test('nema duplih display naziva', () {
      final normalized = BslAdministrativeAreas.displayNames
          .map(BslAdministrativeAreas.normalize)
          .toSet();
      expect(normalized, hasLength(BslAdministrativeAreas.displayNames.length));
    });

    test('razlikuje istoimena administrativna područja', () {
      expect(
        BslAdministrativeAreas.findExact('Trnovo (FBiH)')?.entity,
        BslAdministrativeEntity.federation,
      );
      expect(
        BslAdministrativeAreas.findExact('Trnovo (RS)')?.entity,
        BslAdministrativeEntity.republikaSrpska,
      );
      expect(
        BslAdministrativeAreas.findExact('Kupres (FBiH)')?.entity,
        BslAdministrativeEntity.federation,
      );
      expect(
        BslAdministrativeAreas.findExact('Kupres (RS)')?.entity,
        BslAdministrativeEntity.republikaSrpska,
      );
    });
  });
}
