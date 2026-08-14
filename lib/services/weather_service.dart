import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/bsl_administrative_area.dart';
import '../core/models/bsl_city.dart';

class WeatherLocation {
  final String name;
  final String country;
  final String countryCode;
  final double latitude;
  final double longitude;

  const WeatherLocation({
    required this.name,
    required this.country,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
  });

  factory WeatherLocation.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      throw const FormatException('Grad nema ispravne koordinate.');
    }

    return WeatherLocation(
      name: json['name']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      countryCode: json['country_code']?.toString() ?? '',
      latitude: latitude,
      longitude: longitude,
    );
  }

  String get displayName {
    if (country.isEmpty) return name;
    return '$name, $country';
  }
}

class WeatherForecast {
  final WeatherLocation location;
  final Map<String, dynamic> data;

  const WeatherForecast({required this.location, required this.data});

  num? get currentTemperature {
    final current = data['current'];
    if (current is! Map<String, dynamic>) return null;
    return current['temperature_2m'] as num?;
  }

  num? get currentWeatherCode {
    final current = data['current'];
    if (current is Map<String, dynamic>) {
      final code = current['weather_code'];
      if (code is num) return code;
    }

    final daily = data['daily'];
    if (daily is! Map<String, dynamic>) return null;

    final codes = daily['weather_code'];
    if (codes is! List || codes.isEmpty) return null;

    final code = codes.first;
    return code is num ? code : null;
  }
}

class WeatherService {
  static Future<WeatherForecast> getWeatherForCity(
    String cityName, {
    String? preferredCountryCode = 'BA',
  }) async {
    final bslCity = BslCities.findExact(cityName);
    late WeatherLocation location;

    if (bslCity != null) {
      location = WeatherLocation(
        name: bslCity.name,
        country: 'Bosna i Hercegovina',
        countryCode: 'BA',
        latitude: bslCity.latitude,
        longitude: bslCity.longitude,
      );
    } else {
      final searchName = BslAdministrativeAreas.geocodingNameFor(cityName);
      try {
        location = await searchCity(
          searchName,
          countryCode: preferredCountryCode,
        );
      } on WeatherCityNotFoundException {
        if (preferredCountryCode == null) rethrow;
        location = await searchCity(searchName);
      }
    }

    final data = await getWeather(
      latitude: location.latitude,
      longitude: location.longitude,
    );

    return WeatherForecast(location: location, data: data);
  }

  static Future<Map<String, dynamic>> getWeather({
    double latitude = 43.816,
    double longitude = 18.569,
  }) async {
    final url = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': [
        'temperature_2m',
        'apparent_temperature',
        'precipitation',
        'wind_speed_10m',
        'weather_code',
      ].join(','),
      'daily': [
        'weather_code',
        'temperature_2m_max',
        'temperature_2m_min',
        'precipitation_sum',
      ].join(','),
      'timezone': 'Europe/Sarajevo',
    });

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Greška pri učitavanju vremenske prognoze');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Neispravan odgovor vremenskog servisa.');
    }

    return decoded;
  }

  static Future<WeatherLocation> searchCity(
    String cityName, {
    String? countryCode,
  }) async {
    final query = cityName.trim();

    if (query.length < 2) {
      throw const WeatherCityNotFoundException();
    }

    final parameters = <String, String>{
      'name': query,
      'count': '10',
      'language': 'hr',
      'format': 'json',
      if (countryCode != null && countryCode.isNotEmpty)
        'countryCode': countryCode,
    };
    final url = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      parameters,
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Greška pri pretrazi grada');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Neispravan odgovor pretrage gradova.');
    }

    final results = decoded['results'];

    if (results is! List || results.isEmpty) {
      throw const WeatherCityNotFoundException();
    }

    final locations = results
        .whereType<Map<String, dynamic>>()
        .map(WeatherLocation.fromJson)
        .toList(growable: false);

    if (locations.isEmpty) {
      throw const WeatherCityNotFoundException();
    }

    final normalizedQuery = _normalize(query);

    for (final location in locations) {
      if (_normalize(location.name) == normalizedQuery) return location;
    }

    return locations.first;
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('š', 's')
        .replaceAll('ž', 'z')
        .replaceAll('đ', 'dj');
  }
}

class WeatherCityNotFoundException implements Exception {
  final String message;

  const WeatherCityNotFoundException([this.message = 'Grad nije pronađen']);

  @override
  String toString() => message;
}
