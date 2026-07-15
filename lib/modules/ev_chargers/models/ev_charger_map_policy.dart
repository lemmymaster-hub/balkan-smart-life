import '../../../core/models/bsl_city.dart';

abstract final class EvChargerMapPolicy {
  static bool shouldAutoCenterOnLocation({
    required BslCity selectedCity,
    required BslCity? detectedCity,
  }) {
    return detectedCity != null &&
        BslCities.same(selectedCity.name, detectedCity.name);
  }
}
