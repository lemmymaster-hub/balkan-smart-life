import 'bsl_administrative_area.dart';

extension BslAdministrativeAreaGeocoding on BslAdministrativeArea {
  String get geocodingQuery {
    final qualifier = BslAdministrativeAreas.entityQualifier(this);
    return '$geocodingName, $qualifier';
  }
}
