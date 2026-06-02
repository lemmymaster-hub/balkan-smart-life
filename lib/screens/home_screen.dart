import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/animated_logo.dart';
import 'weather_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCity = 'Sarajevo';

  final List<String> cities = [
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

  final List<MenuItemData> menuItems = [
    MenuItemData('Parkiraj.ba', Icons.local_parking),
    MenuItemData('Gradski prevoz', Icons.tram),
    MenuItemData('Taxi', Icons.local_taxi),
    MenuItemData('Vremenska prognoza', Icons.cloud),
    MenuItemData('Benzinske pumpe', Icons.local_gas_station),
    MenuItemData('Plati račun', Icons.receipt_long),
    MenuItemData('Novčanik', Icons.account_balance_wallet),
  ];

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
                        color: Colors.white.withOpacity(0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.35),
                          blurRadius: 26,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xFF00E5FF),
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'BSL korisnik',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
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
              style: TextStyle(
                color: color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    color: Colors.cyanAccent.withOpacity(0.25),
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
                    value: selectedCity,
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
                          color: Colors.white.withOpacity(0.22),
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
                      final active = city == 'Sarajevo';

                      return DropdownMenuItem<String>(
                        value: active ? city : null,
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
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedCity = value;
                        });
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
                    return MetroTile(item: item);
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

class MetroTile extends StatelessWidget {
  final MenuItemData item;

  const MetroTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        if (item.title == 'Vremenska prognoza') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WeatherScreen(),
            ),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.title} modul uskoro dolazi')),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.cyanAccent.withOpacity(0.35),
              Colors.blueAccent.withOpacity(0.25),
              Colors.deepPurpleAccent.withOpacity(0.28),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.22),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
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
                      Colors.white.withOpacity(0.22),
                      Colors.white.withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon, size: 42, color: Colors.white),
                  const Spacer(),
                  Text(
                    item.title,
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
      ),
    );
  }
}