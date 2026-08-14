import 'bsl_administrative_area.dart';

extension BslAdministrativeAreaGeocoding on BslAdministrativeArea {
  String get geocodingQuery {
    switch (entity) {
      case BslAdministrativeEntity.federation:
        return '$geocodingName, Federacija Bosne i Hercegovine';
      case BslAdministrativeEntity.republikaSrpska:
        return '$geocodingName, Republika Srpska';
      case BslAdministrativeEntity.brcko:
        return '$geocodingName, Brčko distrikt';
    }
  }
}
