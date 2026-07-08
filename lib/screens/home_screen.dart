import 'dart:async';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../core/context/city_context.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


import '../widgets/animated_logo.dart';
import 'weather_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import '../modules/parkiraj/screens/parkiraj_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<MenuItemData> menuItems = [
    MenuItemData('Parkiraj.ba', Icons.local_parking),
    MenuItemData('Gradski prevoz', Icons.tram),
    MenuItemData('Taxi', Icons.local_taxi),
    MenuItemData('Vremenska prognoza', Icons.cloud),
    MenuItemData('Benzinske pumpe', Icons.local_gas_station),
    MenuItemData('Plati račun', Icons.receipt_long),
    MenuItemData('Novčanik', Icons.account_balance_wallet),
  ];

  @override
  void initState() {
    super.initState();
  }
  Future<void> _openWeatherScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WeatherScreen(),
      ),
    );

  
  }

  void _showUserMenu() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'User menu',
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 32, right: 6),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 210,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xBB0D1428),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.35),
                          blurRadius: 26,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xFF00E5FF),
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'BSL korisnik',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    FirebaseAuth.instance.currentUser?.email ??
                                        'Nema emaila',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _menuItem(
                          icon: Icons.settings,
                          text: 'User Settings',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                              ),
                            );
                          },
                        ),
                        _menuItem(
                          icon: Icons.language,
                          text: 'Language',
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                        const Divider(color: Colors.white24),
                        _menuItem(
                          icon: Icons.logout,
                          text: 'Logout',
                          color: Colors.redAccent,
                          onTap: () async {
                            Navigator.pop(context);
                            await FirebaseAuth.instance.signOut();

                            if (!mounted) return;

                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.10),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(color: color, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

 @override
Widget build(BuildContext context) {
  final cityContext = context.watch<CityContext>();
  final selectedCity = cityContext.selectedCity;
  final cities = cityContext.cities;
  final dropdownValue = cities.contains(selectedCity) ? selectedCity : 'Pale';

    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B18),
        elevation: 0,
        title: const Text('Balkan Smart Life'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              size: 32,
              color: Colors.cyanAccent,
              shadows: [
                Shadow(
                  color: Colors.cyanAccent,
                  blurRadius: 12,
                ),
              ],
            ),
            onPressed: _showUserMenu,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1428),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.25),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AnimatedBslLogo(
                        height: 85,
                        repeatDelay: Duration(minutes: 1),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Balkan Smart Life',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: dropdownValue,
                    dropdownColor: const Color(0xFF111A33),
                    decoration: InputDecoration(
                      labelText: 'Izaberi grad',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(
                        Icons.location_city,
                        color: Colors.white70,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    items: cities.map((city) {
                      final active = city == selectedCity || city == 'Sarajevo';

                      return DropdownMenuItem<String>(
                        value: city,
                        enabled: active,
                        child: Row(
                          children: [
                            Text(
                              city,
                              style: TextStyle(
                                color: active ? Colors.white : Colors.white38,
                              ),
                            ),
                            if (!active) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.lock,
                                size: 15,
                                color: Colors.white38,
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                   onChanged: (value) async {
  if (value != null) {
    await context.read<CityContext>().setCity(value);
  }
},
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  itemCount: menuItems.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.15,
                  ),
                  itemBuilder: (context, index) {
                    final item = menuItems[index];

                    return MetroTile(
                      item: item,
                      selectedCity: selectedCity,
                      onOpenWeather: _openWeatherScreen,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MenuItemData {
  final String title;
  final IconData icon;

  MenuItemData(this.title, this.icon);
}

class MetroTile extends StatefulWidget {
  final MenuItemData item;
  final String selectedCity;
  final Future<void> Function()? onOpenWeather;

  const MetroTile({
    super.key,
    required this.item,
    required this.selectedCity,
    this.onOpenWeather,
  });

  @override
  State<MetroTile> createState() => _MetroTileState();
}

class _MetroTileState extends State<MetroTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _refreshTimer;

  int temperature = 18;
  String weatherType = 'sun';

  bool get isWeatherTile => widget.item.title == 'Vremenska prognoza';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    if (isWeatherTile) {
      _setWeatherData();
      _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
        if (!mounted) return;
        _setWeatherData();
      });
    }
  }

  @override
  void didUpdateWidget(covariant MetroTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedCity != widget.selectedCity && isWeatherTile) {
      _setWeatherData();
    }
  }

  void _setWeatherData() {
    final hour = DateTime.now().hour;

    setState(() {
      if (hour >= 6 && hour < 12) {
        temperature = 16;
        weatherType = 'sun';
      } else if (hour >= 12 && hour < 18) {
        temperature = 22;
        weatherType = 'cloud';
      } else if (hour >= 18 && hour < 23) {
        temperature = 14;
        weatherType = 'rain';
      } else {
        temperature = 8;
        weatherType = 'snow';
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  IconData _weatherIcon() {
    switch (weatherType) {
      case 'rain':
        return Icons.water_drop_rounded;
      case 'snow':
        return Icons.ac_unit_rounded;
      case 'cloud':
        return Icons.cloud_rounded;
      default:
        return Icons.wb_sunny_rounded;
    }
  }

  String _weatherText() {
    switch (weatherType) {
      case 'rain':
        return 'Kiša';
      case 'snow':
        return 'Snijeg';
      case 'cloud':
        return 'Oblačno';
      default:
        return 'Sunčano';
    }
  }

  List<Color> _tileColors() {
    if (!isWeatherTile) {
      return [
        Colors.cyanAccent.withValues(alpha: 0.35),
        Colors.blueAccent.withValues(alpha: 0.25),
        Colors.deepPurpleAccent.withValues(alpha: 0.28),
      ];
    }

    switch (weatherType) {
      case 'rain':
        return [
          Colors.blueGrey.withValues(alpha: 0.55),
          Colors.blueAccent.withValues(alpha: 0.35),
          Colors.indigo.withValues(alpha: 0.34),
        ];
      case 'snow':
        return [
          Colors.white.withValues(alpha: 0.38),
          Colors.lightBlueAccent.withValues(alpha: 0.35),
          Colors.blueGrey.withValues(alpha: 0.25),
        ];
      case 'cloud':
        return [
          Colors.blueGrey.withValues(alpha: 0.45),
          Colors.cyanAccent.withValues(alpha: 0.25),
          Colors.deepPurpleAccent.withValues(alpha: 0.24),
        ];
      default:
        return [
          Colors.orangeAccent.withValues(alpha: 0.45),
          Colors.cyanAccent.withValues(alpha: 0.28),
          Colors.blueAccent.withValues(alpha: 0.22),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () async {
        if (widget.item.title == 'Parkiraj.ba') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParkirajHomeScreen(
  city: widget.selectedCity,
),
            ),
          );
          return;
        }

        if (widget.item.title == 'Vremenska prognoza') {
          await widget.onOpenWeather?.call();
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.item.title} modul uskoro dolazi')),
        );
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _tileColors(),
              ),
              boxShadow: [
                BoxShadow(
                  color: isWeatherTile
                      ? Colors.cyanAccent.withValues(alpha: 0.30)
                      : Colors.cyanAccent.withValues(alpha: 0.22),
                  blurRadius: isWeatherTile ? 34 : 28,
                  spreadRadius: 1,
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Stack(
              children: [
                if (isWeatherTile) _weatherAnimatedBackground(),
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 95,
                    height: 95,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isWeatherTile)
                  _weatherTileContent()
                else
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(widget.item.icon, size: 42, color: Colors.white),
                        const Spacer(),
                        Text(
                          widget.item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _weatherTileContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _weatherIcon(),
                color: Colors.white,
                size: 38,
                shadows: const [
                  Shadow(
                    color: Colors.white,
                    blurRadius: 14,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '$temperature°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            widget.selectedCity,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_weatherText()} • Vrijeme',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherAnimatedBackground() {
    if (weatherType == 'rain') {
      return Stack(
        children: List.generate(9, (index) {
          final offset =
              ((_controller.value + index * 0.13) % 1.0) * 150 - 30;

          return Positioned(
            top: offset,
            left: 18.0 + index * 18,
            child: Container(
              width: 2,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }),
      );
    }

    if (weatherType == 'snow') {
      return Stack(
        children: List.generate(11, (index) {
          final offset =
              ((_controller.value + index * 0.11) % 1.0) * 150 - 20;

          return Positioned(
            top: offset,
            left: 14.0 + index * 17,
            child: Text(
              '❄',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 11 + (index % 3) * 3,
              ),
            ),
          );
        }),
      );
    }

    if (weatherType == 'cloud') {
      return Positioned(
        right: -10 + (_controller.value * 18),
        top: 34,
        child: Icon(
          Icons.cloud,
          size: 82,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      );
    }

    return Positioned(
      right: -22,
      top: -22,
      child: Transform.rotate(
        angle: _controller.value * 6.28,
        child: Icon(
          Icons.wb_sunny_rounded,
          size: 105,
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
    );
  }
}