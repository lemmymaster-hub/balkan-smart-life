import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bsl_administrative_area.dart';

class CityContext extends ChangeNotifier {
  static const String _storageKey = 'bsl_selected_city';

  String _selectedCity = 'Pale';

  String get selectedCity => _selectedCity;

  List<String> get cities => BslAdministrativeAreas.displayNames;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCity = prefs.getString(_storageKey);
    final area = BslAdministrativeAreas.findExact(savedCity ?? '');

    if (area != null) {
      _selectedCity = area.displayName;
      notifyListeners();
    }
  }

  Future<void> setCity(String city) async {
    final selectedArea = BslAdministrativeAreas.findExact(city);

    if (selectedArea == null || selectedArea.displayName == _selectedCity) {
      return;
    }

    _selectedCity = selectedArea.displayName;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, selectedArea.displayName);
  }
}
