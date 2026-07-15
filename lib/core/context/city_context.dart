import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CityContext extends ChangeNotifier {
  static const String _storageKey = 'bsl_selected_city';

  String _selectedCity = 'Pale';

  String get selectedCity => _selectedCity;

  final List<String> cities = const [
    'Sarajevo',
    'Banja Luka',
    'Mostar',
    'Tuzla',
    'Zenica',
    'Bihać',
    'Trebinje',
    'Pale',
    'Istočno Sarajevo',
  ];

  bool isCityEnabled(String city) {
    return city == 'Sarajevo' || city == 'Pale';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCity = prefs.getString(_storageKey);

    if (savedCity != null && cities.contains(savedCity)) {
      _selectedCity = savedCity;
      notifyListeners();
    }
  }

  Future<void> setCity(String city) async {
    if (!cities.contains(city)) return;
    if (!isCityEnabled(city)) return;

    _selectedCity = city;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, city);

    notifyListeners();
  }
}