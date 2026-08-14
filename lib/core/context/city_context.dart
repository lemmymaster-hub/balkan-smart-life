import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bsl_administrative_area.dart';
import '../models/bsl_administrative_area_geocoding.dart';
import '../models/bsl_city.dart';
import '../services/address_geocoding_service.dart';

class CityContext extends ChangeNotifier {
  static const String _storageKey = 'bsl_selected_city';
  static const String _resolvedNameKey = 'bsl_selected_city_resolved_name';
  static const String _resolvedLatitudeKey =
      'bsl_selected_city_resolved_latitude';
  static const String _resolvedLongitudeKey =
      'bsl_selected_city_resolved_longitude';
  static const Duration _geocodingTimeout = Duration(seconds: 4);

  final AddressGeocodingService _addressService;

  CityContext({
    AddressGeocodingService addressService = const AddressGeocodingService(),
  }) : _addressService = addressService;

  String _selectedCity = 'Pale';

  String get selectedCity => _selectedCity;

  List<String> get cities => BslAdministrativeAreas.displayNames;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCity = prefs.getString(_storageKey);
    final area = BslAdministrativeAreas.findExact(savedCity ?? '');

    if (area == null) return;

    _restoreResolvedCoordinates(area, prefs);
    _selectedCity = area.displayName;
    notifyListeners();

    if (BslCities.findExact(area.displayName) == null) {
      await _resolveAndCacheArea(area, prefs);
    }
  }

  Future<void> setCity(String city) async {
    final selectedArea = BslAdministrativeAreas.findExact(city);

    if (selectedArea == null || selectedArea.displayName == _selectedCity) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, selectedArea.displayName);

    // Koordinate se rješavaju prije nego što novi izbor postane aktivan. Tako
    // svaki map modul odmah dobija pravi centar umjesto BiH overview fallbacka.
    await _resolveAndCacheArea(selectedArea, prefs);

    _selectedCity = selectedArea.displayName;
    notifyListeners();
  }

  void _restoreResolvedCoordinates(
    BslAdministrativeArea area,
    SharedPreferences prefs,
  ) {
    final resolvedName = prefs.getString(_resolvedNameKey);
    final latitude = prefs.getDouble(_resolvedLatitudeKey);
    final longitude = prefs.getDouble(_resolvedLongitudeKey);

    if (resolvedName == null ||
        latitude == null ||
        longitude == null ||
        !BslAdministrativeAreas.same(resolvedName, area.displayName) ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return;
    }

    BslCities.cacheResolvedCity(
      BslCity(
        name: area.displayName,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  Future<void> _resolveAndCacheArea(
    BslAdministrativeArea area,
    SharedPreferences prefs,
  ) async {
    final existing = BslCities.findExact(area.displayName);
    if (existing != null) {
      await _persistResolvedCoordinates(existing, prefs);
      return;
    }

    try {
      final result = await _addressService
          .searchAddress(input: area.geocodingQuery)
          .timeout(_geocodingTimeout, onTimeout: () => null);

      if (result == null) {
        debugPrint('BSL CITY GEOCODING: nema rezultata za ${area.displayName}');
        return;
      }

      final resolvedCity = BslCity(
        name: area.displayName,
        latitude: result.location.latitude,
        longitude: result.location.longitude,
      );

      BslCities.cacheResolvedCity(resolvedCity);
      await _persistResolvedCoordinates(resolvedCity, prefs);
    } catch (error, stackTrace) {
      // Izbor grada i dalje radi ako sistemski geocoder trenutno nije dostupan;
      // tada ostaje postojeći sigurni BiH fallback.
      debugPrint('BSL CITY GEOCODING ERROR (${area.displayName}): $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _persistResolvedCoordinates(
    BslCity city,
    SharedPreferences prefs,
  ) async {
    await prefs.setString(_resolvedNameKey, city.name);
    await prefs.setDouble(_resolvedLatitudeKey, city.latitude);
    await prefs.setDouble(_resolvedLongitudeKey, city.longitude);
  }
}
