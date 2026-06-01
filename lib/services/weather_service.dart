import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static Future<Map<String, dynamic>> getWeather({
    double latitude = 43.816,
    double longitude = 18.569,
  }) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&current=temperature_2m,apparent_temperature,precipitation,wind_speed_10m'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum'
      '&timezone=Europe%2FSarajevo',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Greška pri učitavanju vremenske prognoze');
    }

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> searchCity(String cityName) async {
    final url = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search'
      '?name=${Uri.encodeComponent(cityName)}'
      '&count=1'
      '&language=hr'
      '&format=json',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Greška pri pretrazi grada');
    }

    final data = jsonDecode(response.body);

    if (data['results'] == null || data['results'].isEmpty) {
      throw Exception('Grad nije pronađen');
    }

    return data['results'][0];
  }
}