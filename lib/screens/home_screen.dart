import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/context/bsl_location_context.dart';
import '../core/context/city_context.dart';
import '../core/services/home_tile_order_service.dart';
import '../core/widgets/bsl_reorderable_grid.dart';
import '../modules/ai_assistant/services/bsl_ai_service.dart';
import '../modules/ai_assistant/widgets/bsl_ai_ask_field.dart';
import '../modules/ev_chargers/screens/ev_chargers_map_screen.dart';
import '../modules/parkiraj/screens/parkiraj_home_screen.dart';
import '../modules/wallet/screens/wallet_home_screen.dart';
import '../services/weather_service.dart';
import '../widgets/animated_logo.dart';
import '../widgets/home_layout_editor.dart';
import 'profile_screen.dart';
import 'weather_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const List<MenuItemData> _defaultMenuItems = [
    MenuItemData(HomeModuleIds.parking, 'Parkiraj.ba', Icons.local_parking),
    MenuItemData(
      HomeModuleIds.evChargers,
      'EL Punjači',
      Icons.ev_station_rounded,
    ),
    MenuItemData(HomeModuleIds.publicTransport, 'Gradski prevoz', Icons.tram),
    MenuItemData(HomeModuleIds.taxi, 'Taxi', Icons.local_taxi),
    MenuItemData(HomeModuleIds.weather, 'Vremenska prognoza', Icons.cloud),
    MenuItemData(
      HomeModuleIds.fuelStations,
      'Benzinske pumpe',
      Icons.local_gas_station,
    ),
    MenuItemData(HomeModuleIds.payBill, 'Plati račun', Icons.receipt_long),
    MenuItemData(
      HomeModuleIds.wallet,
      'Novčanik',
      Icons.account_balance_wallet,
    ),
  ];

  final HomeTileOrderService _tileOrderService = HomeTileOrderService();
  final BslAiService _aiService = BslAiService();
  late List<MenuItemData> _menuItems;
  Future<void> _tileOrderSaveQueue = Future<void>.value();
  bool _isTileOrderLoaded = false;
  bool _isEditingTileOrder = false;

  @override
  void initState() {
    super.initState();
    _menuItems = List<MenuItemData>.of(_defaultMenuItems);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadTileOrder());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BslLocationContext>().initialize();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<BslLocationContext>().refresh();
    } else if (_isEditingTileOrder &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      _queueTileOrderSave();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aiService.dispose();
    super.dispose();
  }

  String get _tileOrderUserId {
    return FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  }

  List<String> get _availableTileIds {
    return _defaultMenuItems.map((item) => item.id).toList(growable: false);
  }

  Future<void> _loadTileOrder() async {
    var orderedItems = List<MenuItemData>.of(_defaultMenuItems);

    try {
      final orderedIds = await _tileOrderService.loadOrder(
        userId: _tileOrderUserId,
        availableIds: _availableTileIds,
      );
      final itemsById = <String, MenuItemData>{
        for (final item in _defaultMenuItems) item.id: item,
      };
      orderedItems = orderedIds
          .map((id) => itemsById[id])
          .whereType<MenuItemData>()
          .toList(growable: true);
    } catch (error, stackTrace) {
      debugPrint('BSL HOME TILE ORDER LOAD ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted) return;
    setState(() {
      _menuItems = orderedItems;
      _isTileOrderLoaded = true;
    });
  }

  void _setTileOrderEditing(bool value) {
    if (_isEditingTileOrder == value) return;

    setState(() {
      _isEditingTileOrder = value;
    });

    if (!value) {
      _queueTileOrderSave();
    }
  }

  void _reorderTile(int oldIndex, int newIndex) {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _menuItems.length ||
        newIndex >= _menuItems.length) {
      return;
    }

    setState(() {
      final item = _menuItems.removeAt(oldIndex);
      _menuItems.insert(newIndex, item);
    });
  }

  void _queueTileOrderSave() {
    final userId = _tileOrderUserId;
    final orderedIds = _menuItems
        .map((item) => item.id)
        .toList(growable: false);
    final availableIds = _availableTileIds;

    _tileOrderSaveQueue = _tileOrderSaveQueue.then((_) async {
      try {
        await _tileOrderService.saveOrder(
          userId: userId,
          orderedIds: orderedIds,
          availableIds: availableIds,
        );
      } catch (error, stackTrace) {
        debugPrint('BSL HOME TILE ORDER SAVE ERROR: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    });
  }

  void _resetTileOrder() {
    setState(() {
      _menuItems = List<MenuItemData>.of(_defaultMenuItems);
    });
    _queueTileOrderSave();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vraćen je početni raspored modula.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openWeatherScreen() async {
    final selectedCity = context.read<CityContext>().selectedCity;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeatherScreen(initialCity: selectedCity),
      ),
    );
  }

  void _showLegalNotices() {
    showLicensePage(
      context: context,
      applicationName: 'Balkan Smart Life',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 Balkan Smart Life • Google Navigation SDK',
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
                        _menuItem(
                          icon: Icons.gavel_rounded,
                          text: 'Pravne napomene',
                          onTap: () {
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _showLegalNotices();
                            });
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
            position:
                Tween<Offset>(
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
            Text(text, style: TextStyle(color: color, fontSize: 14)),
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

    return PopScope<void>(
      canPop: !_isEditingTileOrder,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isEditingTileOrder) {
          _setTileOrderEditing(false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF070B18),
        appBar: AppBar(
          backgroundColor: const Color(0xFF070B18),
          elevation: 0,
          titleSpacing: 18,
          title: const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'BALKAN',
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: ' SMART LIFE',
                  style: TextStyle(color: Color(0xFF58E7FF)),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
              shadows: [
                Shadow(color: Color(0x6600D9FF), blurRadius: 12),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.menu_rounded,
                size: 32,
                color: Colors.cyanAccent,
                shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 12)],
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
                          height: 82,
                          repeatDelay: Duration(minutes: 1),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BslAiAskField(
                            city: selectedCity,
                            onAsk: ({
                              required String question,
                              required String city,
                            }) {
                              return _aiService.ask(
                                question: question,
                                city: city,
                              );
                            },
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
                      items: cities
                          .map(
                            (city) => DropdownMenuItem<String>(
                              value: city,
                              child: Text(city),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          await context.read<CityContext>().setCity(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (_isEditingTileOrder)
                HomeLayoutEditorBar(
                  onReset: _resetTileOrder,
                  onDone: () => _setTileOrderEditing(false),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: !_isTileOrderLoaded
                      ? const Center(
                          key: ValueKey<String>('tile-order-loading'),
                          child: CircularProgressIndicator(
                            color: Colors.cyanAccent,
                          ),
                        )
                      : BslReorderableGrid<MenuItemData>(
                          key: const ValueKey<String>('home-module-grid'),
                          items: _menuItems,
                          itemId: (item) => item.id,
                          isEditing: _isEditingTileOrder,
                          onEditingChanged: _setTileOrderEditing,
                          onReorder: _reorderTile,
                          onReorderEnd: _queueTileOrderSave,
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 1.15,
                              ),
                          feedbackBuilder: (context, item) {
                            return HomeTileDragFeedback(
                              title: item.title,
                              icon: item.icon,
                            );
                          },
                          itemBuilder:
                              (
                                context,
                                item, {
                                required bool isEditing,
                                required bool isDragging,
                                required bool isDropTarget,
                              }) {
                                return AnimatedScale(
                                  duration: const Duration(milliseconds: 140),
                                  scale: isDropTarget ? 0.94 : 1,
                                  child: MetroTile(
                                    item: item,
                                    selectedCity: selectedCity,
                                    onOpenWeather: _openWeatherScreen,
                                    interactionEnabled: !isEditing,
                                    isEditing: isEditing,
                                    isDragging: isDragging,
                                    isDropTarget: isDropTarget,
                                  ),
                                );
                              },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

abstract final class HomeModuleIds {
  static const String parking = 'parking';
  static const String evChargers = 'ev_chargers';
  static const String publicTransport = 'public_transport';
  static const String taxi = 'taxi';
  static const String weather = 'weather';
  static const String fuelStations = 'fuel_stations';
  static const String payBill = 'pay_bill';
  static const String wallet = 'wallet';
}

class MenuItemData {
  final String id;
  final String title;
  final IconData icon;

  const MenuItemData(this.id, this.title, this.icon);
}

class MetroTile extends StatefulWidget {
  final MenuItemData item;
  final String selectedCity;
  final Future<void> Function()? onOpenWeather;
  final bool interactionEnabled;
  final bool isEditing;
  final bool isDragging;
  final bool isDropTarget;

  const MetroTile({
    super.key,
    required this.item,
    required this.selectedCity,
    this.onOpenWeather,
    this.interactionEnabled = true,
    this.isEditing = false,
    this.isDragging = false,
    this.isDropTarget = false,
  });

  @override
  State<MetroTile> createState() => _MetroTileState();
}

class _MetroTileState extends State<MetroTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _refreshTimer;

  int? temperature;
  String weatherType = 'cloud';
  int _weatherRequestId = 0;

  bool get isWeatherTile => widget.item.id == HomeModuleIds.weather;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    if (isWeatherTile) {
      _loadWeatherData();
      _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
        if (!mounted) return;
        _loadWeatherData();
      });
    }
  }

  @override
  void didUpdateWidget(covariant MetroTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedCity != widget.selectedCity && isWeatherTile) {
      setState(() {
        temperature = null;
      });
      _loadWeatherData();
    }
  }

  Future<void> _loadWeatherData() async {
    final requestId = ++_weatherRequestId;
    final requestedCity = widget.selectedCity;

    try {
      final forecast = await WeatherService.getWeatherForCity(requestedCity);

      if (!mounted || requestId != _weatherRequestId) return;

      setState(() {
        temperature = forecast.currentTemperature?.round();
        weatherType = _weatherTypeForCode(forecast.currentWeatherCode ?? 3);
      });
    } catch (error) {
      debugPrint('BSL WEATHER TILE ERROR: $error');

      if (!mounted || requestId != _weatherRequestId) return;

      setState(() {
        temperature = null;
        weatherType = 'cloud';
      });
    }
  }

  String _weatherTypeForCode(num weatherCode) {
    if ([71, 73, 75, 77, 85, 86].contains(weatherCode)) return 'snow';
    if ([
      51,
      53,
      55,
      56,
      57,
      61,
      63,
      65,
      66,
      67,
      80,
      81,
      82,
      95,
      96,
      99,
    ].contains(weatherCode)) {
      return 'rain';
    }
    if ([1, 2, 3, 45, 48].contains(weatherCode)) return 'cloud';
    return 'sun';
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
      onTap: !widget.interactionEnabled
          ? null
          : () async {
              if (widget.item.id == HomeModuleIds.parking) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ParkirajHomeScreen(city: widget.selectedCity),
                  ),
                );
                return;
              }

              if (widget.item.id == HomeModuleIds.evChargers) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EvChargersMapScreen(city: widget.selectedCity),
                  ),
                );
                return;
              }

              if (widget.item.id == HomeModuleIds.weather) {
                await widget.onOpenWeather?.call();
                return;
              }

              if (widget.item.id == HomeModuleIds.wallet) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WalletHomeScreen(),
                  ),
                );
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.item.title} modul uskoro dolazi'),
                ),
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
                  color: widget.isDropTarget
                      ? Colors.cyanAccent.withValues(alpha: 0.56)
                      : isWeatherTile
                      ? Colors.cyanAccent.withValues(alpha: 0.30)
                      : Colors.cyanAccent.withValues(alpha: 0.22),
                  blurRadius: widget.isDropTarget
                      ? 40
                      : isWeatherTile
                      ? 34
                      : 28,
                  spreadRadius: widget.isDropTarget ? 2 : 1,
                ),
              ],
              border: Border.all(
                color: widget.isDragging
                    ? Colors.white.withValues(alpha: 0.70)
                    : widget.isEditing
                    ? Colors.cyanAccent.withValues(alpha: 0.56)
                    : Colors.white.withValues(alpha: 0.18),
                width: widget.isDragging || widget.isEditing ? 1.4 : 1,
              ),
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
                if (widget.isEditing)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xDD0D1428),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.cyanAccent.withValues(alpha: 0.65),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withValues(alpha: 0.30),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.drag_indicator_rounded,
                        size: 20,
                        color: Colors.cyanAccent,
                      ),
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
                shadows: const [Shadow(color: Colors.white, blurRadius: 14)],
              ),
              const Spacer(),
              Text(
                temperature == null ? '--°' : '$temperature°',
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
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _weatherAnimatedBackground() {
    if (weatherType == 'rain') {
      return Stack(
        children: List.generate(9, (index) {
          final offset = ((_controller.value + index * 0.13) % 1.0) * 150 - 30;

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
          final offset = ((_controller.value + index * 0.11) % 1.0) * 150 - 20;

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
