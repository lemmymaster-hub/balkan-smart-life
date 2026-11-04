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

  final AddressGeocodingService addressService;

  CityContext({
    this.addressService = const AddressGeocodingService(),
  });

  String _selectedCity = 'Pale';
  int _selectionRevision = 0;
  Future<void> _pendingSave = Future<void>.value();

  String get selectedCity => _selectedCity;

  List<String> get cities => BslAdministrativeAreas.displayNames;

  Future<void> load() async {
    final revision = _selectionRevision;
    final prefs = await SharedPreferences.getInstance();
    if (revision != _selectionRevision) return;
    final savedCity = prefs.getString(_storageKey);
    final area = BslAdministrativeAreas.findExact(savedCity ?? '');

    if (area == null) return;

    _restoreResolvedCoordinates(area, prefs);
    _selectedCity = area.displayName;
    notifyListeners();

    if (BslCities.findExact(area.displayName) == null) {
      final resolved = await _resolveArea(area);
      if (revision == _selectionRevision && resolved != null) {
        await _queueSave(() async {
          if (revision == _selectionRevision) {
            BslCities.cacheResolvedCity(resolved);
            await _persistResolvedCoordinates(resolved, prefs);
          }
        });
      }
    }
  }

  Future<void> setCity(String city) async {
    final selectedArea = BslAdministrativeAreas.findExact(city);

    if (selectedArea == null) return;

    final revision = ++_selectionRevision;
    final prefs = await SharedPreferences.getInstance();
    final resolved = await _resolveArea(selectedArea);
    if (revision != _selectionRevision) return;

    await _queueSave(() async {
      if (revision != _selectionRevision) return;
      if (resolved != null) {
        BslCities.cacheResolvedCity(resolved);
        await _persistResolvedCoordinates(resolved, prefs);
      }
      await prefs.setString(_storageKey, selectedArea.displayName);
      if (revision != _selectionRevision) return;
      _selectedCity = selectedArea.displayName;
      notifyListeners();
    });
  }

  Future<void> _queueSave(Future<void> Function() action) {
    final save = _pendingSave.then((_) => action());
    _pendingSave = save.catchError((Object error) {
      debugPrint('BSL CITY STORAGE ERROR: $error');
    });
    return save;
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
        BslAdministrativeAreas.normalize(resolvedName) !=
            BslAdministrativeAreas.normalize(area.displayName) ||
        !_isInsideBosniaAndHerzegovina(latitude, longitude)) {
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

  Future<BslCity?> _resolveArea(BslAdministrativeArea area) async {
    final existing = BslCities.findExact(area.displayName);
    if (existing != null) return existing;

    try {
      final result = await addressService
          .searchAddress(input: area.geocodingQuery)
          .timeout(_geocodingTimeout, onTimeout: () => null);

      if (result == null ||
          !_isInsideBosniaAndHerzegovina(
            result.location.latitude,
            result.location.longitude,
          )) {
        debugPrint(
          'BSL CITY GEOCODING: nema validnog BiH rezultata za ${area.displayName}',
        );
        return null;
      }

      return BslCity(
        name: area.displayName,
        latitude: result.location.latitude,
        longitude: result.location.longitude,
      );

    } catch (error, stackTrace) {
      // Izbor grada i dalje radi ako sistemski geocoder trenutno nije dostupan;
      // tada ostaje postojeći sigurni BiH fallback.
      debugPrint('BSL CITY GEOCODING ERROR (${area.displayName}): $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _persistResolvedCoordinates(
    BslCity city,
    SharedPreferences prefs,
  ) async {
    await prefs.remove(_resolvedNameKey);
    await prefs.setDouble(_resolvedLatitudeKey, city.latitude);
    await prefs.setDouble(_resolvedLongitudeKey, city.longitude);
    await prefs.setString(_resolvedNameKey, city.name);
  }

  static bool _isInsideBosniaAndHerzegovina(
    double latitude,
    double longitude,
  ) {
    if (!latitude.isFinite || !longitude.isFinite) return false;

    // Namjerno malo širi okvir od državne granice zbog centara opština i
    // razlika između geokoderskih izvora.
    return latitude >= 42.45 &&
        latitude <= 45.35 &&
        longitude >= 15.65 &&
        longitude <= 19.70;
  }
}
