import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bsl_city.dart';

class CityContext extends ChangeNotifier {
  static const String _storageKey = 'bsl_selected_city';

  String _selectedCity = 'Pale';

  String get selectedCity => _selectedCity;

  List<String> get cities =>
      BslCities.values.map((city) => city.name).toList(growable: false);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCity = prefs.getString(_storageKey);

    final city = BslCities.findExact(savedCity ?? '');

    if (city != null) {
      _selectedCity = city.name;
      notifyListeners();
    }
  }

  Future<void> setCity(String city) async {
    final selectedCity = BslCities.findExact(city);

    if (selectedCity == null || selectedCity.name == _selectedCity) return;

    _selectedCity = selectedCity.name;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, selectedCity.name);
  }
}
