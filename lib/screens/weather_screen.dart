import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late Future<Map<String, dynamic>> weatherFuture;

  final TextEditingController cityController = TextEditingController();
  String selectedCity = 'Pale';

  @override
  void initState() {
    super.initState();
    weatherFuture = WeatherService.getWeather();
    _loadSavedCity();
  }

  Future<void> _loadSavedCity() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCity = prefs.getString('weather_selected_city') ?? 'Pale';

    try {
      final cityData = await WeatherService.searchCity(savedCity);

      if (!mounted) return;

      setState(() {
        selectedCity = savedCity;
        cityController.text = savedCity;
        weatherFuture = WeatherService.getWeather(
          latitude: cityData['latitude'],
          longitude: cityData['longitude'],
        );
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        selectedCity = savedCity;
        cityController.text = savedCity;
        weatherFuture = WeatherService.getWeather();
      });
    }
  }

  Future<void> _saveSelectedCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weather_selected_city', city);
  }

  @override
  void dispose() {
    cityController.dispose();
    super.dispose();
  }

  Future<void> searchWeather() async {
    final city = cityController.text.trim();
    if (city.isEmpty) return;

    try {
      final cityData = await WeatherService.searchCity(city);
      final cityName = cityData['name'] ?? city;

      await _saveSelectedCity(cityName);

      setState(() {
        selectedCity = cityName;
        cityController.text = cityName;
        weatherFuture = WeatherService.getWeather(
          latitude: cityData['latitude'],
          longitude: cityData['longitude'],
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  IconData getWeatherIcon(num weatherCode) {
    if (weatherCode == 0) return Icons.wb_sunny;
    if ([1, 2].contains(weatherCode)) return Icons.wb_cloudy;
    if (weatherCode == 3) return Icons.cloud;
    if ([45, 48].contains(weatherCode)) return Icons.foggy;

    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82]
        .contains(weatherCode)) {
      return Icons.thunderstorm;
    }

    if ([71, 73, 75, 77, 85, 86].contains(weatherCode)) {
      return Icons.ac_unit;
    }

    if ([95, 96, 99].contains(weatherCode)) return Icons.bolt;

    return Icons.cloud;
  }

  String getWeatherText(num weatherCode) {
    if (weatherCode == 0) return 'Sunčano';
    if (weatherCode == 1) return 'Pretežno sunčano';
    if (weatherCode == 2) return 'Djelimično oblačno';
    if (weatherCode == 3) return 'Oblačno';
    if ([45, 48].contains(weatherCode)) return 'Magla';
    if ([51, 53, 55, 56, 57].contains(weatherCode)) return 'Rosulja';
    if ([61, 63, 65].contains(weatherCode)) return 'Kiša';
    if ([66, 67].contains(weatherCode)) return 'Ledena kiša';
    if ([71, 73, 75, 77].contains(weatherCode)) return 'Snijeg';
    if ([80, 81, 82].contains(weatherCode)) return 'Pljuskovi';
    if ([85, 86].contains(weatherCode)) return 'Snježni pljuskovi';
    if ([95, 96, 99].contains(weatherCode)) return 'Grmljavina';

    return 'Promjenljivo';
  }

  Color getIconColor(IconData icon) {
    if (icon == Icons.wb_sunny) return Colors.amberAccent;
    if (icon == Icons.ac_unit) return Colors.lightBlueAccent;
    if (icon == Icons.bolt) return Colors.yellowAccent;
    if (icon == Icons.thunderstorm) return Colors.lightBlueAccent;
    return Colors.cyanAccent;
  }

  String dayName(int index) {
    if (index == 0) return 'Danas';

    final days = [
      'Ponedjeljak',
      'Utorak',
      'Srijeda',
      'Četvrtak',
      'Petak',
      'Subota',
      'Nedjelja',
    ];

    final date = DateTime.now().add(Duration(days: index));
    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050814),
      appBar: AppBar(
        title: const Text(
          'Vremenska prognoza',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: weatherFuture,
        builder: (context, snapshot) {
          return Stack(
            children: [
              Positioned(
                top: -80,
                right: -80,
                child: _GlowCircle(color: Colors.cyanAccent.withValues(alpha: 0.28)),
              ),
              Positioned(
                bottom: -110,
                left: -80,
                child: _GlowCircle(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.30),
                ),
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SearchWeatherPanel(
                    controller: cityController,
                    onSearch: searchWeather,
                  ),
                  const SizedBox(height: 18),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.only(top: 120),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.cyanAccent,
                        ),
                      ),
                    )
                  else if (snapshot.hasError)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(
                        child: Text(
                          'Greška pri učitavanju vremenske prognoze',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    _WeatherContent(
                      data: snapshot.data!,
                      selectedCity: selectedCity,
                      dayName: dayName,
                      getWeatherIcon: getWeatherIcon,
                      getWeatherText: getWeatherText,
                      getIconColor: getIconColor,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WeatherContent extends StatelessWidget {
  final Map<String, dynamic> data;
  final String selectedCity;
  final String Function(int index) dayName;
  final IconData Function(num code) getWeatherIcon;
  final String Function(num code) getWeatherText;
  final Color Function(IconData icon) getIconColor;

  const _WeatherContent({
    required this.data,
    required this.selectedCity,
    required this.dayName,
    required this.getWeatherIcon,
    required this.getWeatherText,
    required this.getIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final current = data['current'];
    final daily = data['daily'];

    final todayCode = daily['weather_code'][0];
    final todayIcon = getWeatherIcon(todayCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CurrentWeatherCard(
          current: current,
          cityName: selectedCity,
          icon: todayIcon,
          description: getWeatherText(todayCode),
          iconColor: getIconColor(todayIcon),
        ),
        const SizedBox(height: 24),
        const Row(
          children: [
            Icon(Icons.calendar_month, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Text(
              'Prognoza narednih 7 dana',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < 7; i++)
          _DailyWeatherCard(
            day: dayName(i),
            date: daily['time'][i].toString(),
            minTemp: daily['temperature_2m_min'][i],
            maxTemp: daily['temperature_2m_max'][i],
            rain: daily['precipitation_sum'][i],
            icon: getWeatherIcon(daily['weather_code'][i]),
            iconColor: getIconColor(getWeatherIcon(daily['weather_code'][i])),
            description: getWeatherText(daily['weather_code'][i]),
          ),
      ],
    );
  }
}

class _SearchWeatherPanel extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;

  const _SearchWeatherPanel({
    required this.controller,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: [
                Colors.cyanAccent.withValues(alpha: 0.18),
                Colors.blueAccent.withValues(alpha: 0.08),
                Colors.deepPurpleAccent.withValues(alpha: 0.16),
              ],
            ),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.cyanAccent),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Pretraži grad...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              IconButton(
                onPressed: onSearch,
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentWeatherCard extends StatelessWidget {
  final Map<String, dynamic> current;
  final String cityName;
  final IconData icon;
  final String description;
  final Color iconColor;

  const _CurrentWeatherCard({
    required this.current,
    required this.cityName,
    required this.icon,
    required this.description,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final temperature = current['temperature_2m'];
    final feelsLike = current['apparent_temperature'];
    final precipitation = current['precipitation'];
    final wind = current['wind_speed_10m'];

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.cyanAccent.withValues(alpha: 0.28),
                Colors.blueAccent.withValues(alpha: 0.15),
                Colors.deepPurpleAccent.withValues(alpha: 0.25),
              ],
            ),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.25),
                blurRadius: 35,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.purpleAccent.withValues(alpha: 0.18),
                blurRadius: 45,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cityName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 72),
                  const SizedBox(width: 22),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$temperature°C',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Osjeća se kao $feelsLike°C',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _WeatherInfoRow(
                icon: Icons.water_drop_outlined,
                label: 'Padavine',
                value: '$precipitation mm',
              ),
              _WeatherInfoRow(
                icon: Icons.air,
                label: 'Vjetar',
                value: '$wind km/h',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyWeatherCard extends StatelessWidget {
  final String day;
  final String date;
  final num minTemp;
  final num maxTemp;
  final num rain;
  final IconData icon;
  final Color iconColor;
  final String description;

  const _DailyWeatherCard({
    required this.day,
    required this.date,
    required this.minTemp,
    required this.maxTemp,
    required this.rain,
    required this.icon,
    required this.iconColor,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.cyanAccent.withValues(alpha: 0.18),
            Colors.blueAccent.withValues(alpha: 0.10),
            Colors.deepPurpleAccent.withValues(alpha: 0.18),
          ],
        ),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withValues(alpha: 0.16),
            blurRadius: 22,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.purpleAccent.withValues(alpha: 0.14),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: iconColor, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${minTemp.round()}° / ${maxTemp.round()}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.water_drop_outlined,
                color: Colors.lightBlueAccent,
                size: 19,
              ),
              const SizedBox(width: 6),
              Text(
                'Padavine: $rain mm',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 24),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;

  const _GlowCircle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      height: 230,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}