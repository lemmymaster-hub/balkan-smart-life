import 'package:flutter/material.dart';
import '../widgets/animated_logo.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
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
                      prefixIcon: const Icon(Icons.location_city),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
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
