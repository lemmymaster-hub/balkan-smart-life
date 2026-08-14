import 'package:bsl_app/core/context/city_context.dart';
import 'package:bsl_app/core/models/address_search_result.dart';
import 'package:bsl_app/core/models/bsl_administrative_area.dart';
import 'package:bsl_app/core/models/bsl_administrative_area_geocoding.dart';
import 'package:bsl_app/core/models/bsl_city.dart';
import 'package:bsl_app/core/services/address_geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAddressGeocodingService extends AddressGeocodingService {
  final AddressSearchResult? result;

  _FakeAddressGeocodingService(this.result);

  @override
  Future<AddressSearchResult?> searchAddress({
    required String input,
    String? city,
    String country = 'Bosnia and Herzegovina',
  }) async {
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CityContext map centering', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('izabrana opština dobija razriješene koordinate prije aktivacije', () async {
      final resolvedLocation = AddressSearchResult(
        label: 'Mrkonjić Grad',
        location: LatLng(latitude: 44.417, longitude: 17.086),
      );
      final context = CityContext(
        addressService: _FakeAddressGeocodingService(resolvedLocation),
      );

      await context.setCity('Mrkonjić Grad');

      expect(context.selectedCity, 'Mrkonjić Grad');
      final resolvedCity = BslCities.byName('Mrkonjić Grad');
      expect(resolvedCity.latitude, resolvedLocation.location.latitude);
      expect(resolvedCity.longitude, resolvedLocation.location.longitude);
      expect(resolvedCity.mapZoom, 13.5);
      expect(resolvedCity.mapZoom, isNot(BslCities.bosniaAndHerzegovina.mapZoom));
    });

    test('odbacuje geokoderski rezultat izvan Bosne i Hercegovine', () async {
      final outsideBosnia = AddressSearchResult(
        label: 'Teslić',
        location: LatLng(latitude: 50.0, longitude: 14.0),
      );
      final context = CityContext(
        addressService: _FakeAddressGeocodingService(outsideBosnia),
      );

      await context.setCity('Teslić');

      final unresolvedCity = BslCities.byName('Teslić');
      expect(unresolvedCity.latitude, BslCities.bosniaAndHerzegovina.latitude);
      expect(unresolvedCity.longitude, BslCities.bosniaAndHerzegovina.longitude);
      expect(unresolvedCity.mapZoom, BslCities.bosniaAndHerzegovina.mapZoom);
    });
  });

  group('entity-aware geocoding query', () {
    test('razlikuje dva Trnova', () {
      final fbih = BslAdministrativeAreas.findExact('Trnovo (FBiH)');
      final rs = BslAdministrativeAreas.findExact('Trnovo (RS)');

      expect(fbih, isNotNull);
      expect(rs, isNotNull);
      expect(fbih!.geocodingQuery, contains('Federacija Bosne i Hercegovine'));
      expect(rs!.geocodingQuery, contains('Republika Srpska'));
      expect(fbih.geocodingQuery, isNot(rs.geocodingQuery));
    });
  });
}
