import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/context/bsl_location_context.dart';
import '../../../core/models/bsl_city.dart';
import '../../../core/models/bsl_location_result.dart';
import '../../../core/navigation/bsl_navigation_controller.dart';
import '../../../core/navigation/bsl_navigation_destination.dart';
import '../../../core/navigation/bsl_navigation_vehicle_asset.dart';
import '../../../core/theme/bsl_design_system.dart';
import '../../../core/widgets/bsl_map_location_button.dart';
import '../../../core/widgets/bsl_module_top_bar.dart';
import '../../../core/widgets/bsl_navigation_panel.dart';
import '../models/atm_location.dart';
import '../services/atm_service.dart';
import '../widgets/atm_marker_factory.dart';

class AtmMapScreen extends StatefulWidget {
  final String city;

  const AtmMapScreen({super.key, required this.city});

  @override
  State<AtmMapScreen> createState() => _AtmMapScreenState();
}

class _AtmMapScreenState extends State<AtmMapScreen> {
  final AtmService _atmService = AtmService();
  final BslNavigationController _navigation = BslNavigationController();
  final TextEditingController _citySearchController = TextEditingController();
  final TextEditingController _bankSearchController = TextEditingController();
  final FocusNode _citySearchFocus = FocusNode();
  final FocusNode _bankSearchFocus = FocusNode();

  GoogleNavigationViewController? _mapController;
  BslLocationContext? _locationContext;
  StreamSubscription<Position>? _speedSubscription;
  late BslCity _activeCity;

  String? _darkMapStyle;
  List<AtmLocation> _atms = const [];
  AtmLocation? _selectedAtm;
  String? _selectedBank;
  String? _errorMessage;
  bool _isLoading = true;
  bool _initialLoadStarted = false;
  double _speedKmh = 0;
  ImageDescriptor? _navigationVehicleMarker;
  bool _navigationVehicleMarkerLoadRequested = false;

  List<Marker> _markers = const [];
  Map<String, AtmLocation> _atmByMarkerId = const {};
  final Map<String, ImageDescriptor> _markerIcons = {};
  bool _markerSyncRunning = false;
  bool _markerSyncPending = false;

  static const _bankPalette = <Color>[
    Color(0xFF00E5FF),
    Color(0xFF6C8CFF),
    Color(0xFF00D68F),
    Color(0xFFFFB74D),
    Color(0xFFFF5C8A),
    Color(0xFF9C7CFF),
    Color(0xFF42A5F5),
    Color(0xFF26C6DA),
    Color(0xFFAB47BC),
    Color(0xFF66BB6A),
  ];

  @override
  void initState() {
    super.initState();
    _activeCity = BslCities.byName(widget.city);
    _citySearchController.text = _activeCity.name;
    _navigation.addListener(_handleNavigationChanged);
    unawaited(_loadMapStyle());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_navigationVehicleMarkerLoadRequested) {
      _navigationVehicleMarkerLoadRequested = true;
      unawaited(_loadNavigationVehicleMarker());
    }

    final next = context.read<BslLocationContext>();
    if (!identical(next, _locationContext)) {
      _locationContext?.removeListener(_handleLocationChanged);
      _locationContext = next;
      next.addListener(_handleLocationChanged);
    }

    if (!_initialLoadStarted) {
      _initialLoadStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await next.refresh();
        if (!mounted) return;
        await _loadInitialArea();
      });
    }
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await rootBundle.loadString(
        'assets/maps/bsl_dark_map_style.json',
      );
      if (!mounted) return;
      setState(() => _darkMapStyle = style);
      final controller = _mapController;
      if (controller != null) await _applyMapStyle(controller);
    } catch (error) {
      debugPrint('BSL ATM MAP STYLE ERROR: $error');
    }
  }

  Future<void> _loadNavigationVehicleMarker() async {
    try {
      final marker = await BslNavigationVehicleAsset.register(context);
      if (!mounted) {
        await unregisterImage(marker);
        return;
      }
      _navigationVehicleMarker = marker;
      await _navigation.setVehicleMarkerIcon(marker);
    } catch (error, stackTrace) {
      debugPrint('BSL ATM NAVIGATION MARKER ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _handleNavigationChanged() {
    if (!mounted) return;
    setState(() {});
    unawaited(_setMapLocationEnabled(_locationContext?.hasLocation ?? false));
  }

  void _handleLocationChanged() {
    if (!mounted) return;
    setState(() {});
    unawaited(_setMapLocationEnabled(_locationContext?.hasLocation ?? false));
  }

  BslCity? _cityFromLocation(BslLocationResult location) {
    return BslCities.findExact(location.city) ??
        BslCities.findExact(location.municipality) ??
        BslCities.findMentionedIn(location.displayLabel);
  }

  Future<void> _loadInitialArea() async {
    final location = _locationContext?.location;
    if (location != null) {
      final detected = _cityFromLocation(location);
      if (detected != null) _activeCity = detected;
      _citySearchController.text = location.city.isNotEmpty
          ? location.city
          : _activeCity.name;
      await _loadAtms(
        latitude: location.latitude,
        longitude: location.longitude,
        cityHint: location.city.isNotEmpty ? location.city : _activeCity.name,
        moveCamera: true,
      );
      return;
    }

    await _loadAtms(
      latitude: _activeCity.latitude,
      longitude: _activeCity.longitude,
      cityHint: _activeCity.name,
      moveCamera: true,
    );
  }

  Future<void> _loadAtms({
    required double latitude,
    required double longitude,
    required String cityHint,
    required bool moveCamera,
  }) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _selectedAtm = null;
        _selectedBank = null;
        _bankSearchController.clear();
      });
    }

    try {
      final atms = await _atmService.loadNearby(
        latitude: latitude,
        longitude: longitude,
        radiusKilometers: 10,
        cityHint: cityHint,
      );
      if (!mounted) return;
      setState(() {
        _atms = atms;
        _isLoading = false;
      });
      unawaited(_prepareMarkerIcons(atms));
      _scheduleMarkerSync();

      if (moveCamera) {
        await _animateTo(
          LatLng(latitude: latitude, longitude: longitude),
          14.2,
        );
      }
    } on AtmServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
        _atms = const [];
      });
      _scheduleMarkerSync();
    }
  }

  List<AtmLocation> get _visibleAtms {
    final bank = _selectedBank;
    if (bank == null) return _atms;
    return _atms.where((atm) => atm.bankName == bank).toList(growable: false);
  }

  List<String> get _availableBanks {
    final banks = _atms.map((atm) => atm.bankName).toSet().toList();
    banks.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return banks;
  }

  Color _bankColor(String bank) {
    var hash = 0;
    for (final unit in bank.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return _bankPalette[hash % _bankPalette.length];
  }

  String _markerKey(String bank, {required bool selected}) {
    return '$bank|${selected ? 'selected' : 'normal'}';
  }

  Future<void> _prepareMarkerIcons(List<AtmLocation> atms) async {
    final banks = atms.map((atm) => atm.bankName).toSet();

    for (final bank in banks) {
      for (final selected in const [false, true]) {
        final key = _markerKey(bank, selected: selected);
        if (_markerIcons.containsKey(key)) continue;

        try {
          final icon = await AtmMarkerFactory.create(
            accentColor: _bankColor(bank),
            isSelected: selected,
          );
          if (!mounted) {
            if (icon.registeredImageId != null) await unregisterImage(icon);
            return;
          }
          _markerIcons[key] = icon;
        } catch (error, stackTrace) {
          debugPrint('BSL ATM MARKER BUILD ERROR: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    }

    if (mounted) _scheduleMarkerSync();
  }

  Future<void> _searchCity(String raw) async {
    final value = raw.trim();
    if (value.length < 2 || _navigation.shouldShowPanel) return;

    final known = BslCities.findExact(value);
    if (known != null) {
      _activeCity = known;
      _citySearchController.text = known.name;
      await _loadAtms(
        latitude: known.latitude,
        longitude: known.longitude,
        cityHint: known.name,
        moveCamera: true,
      );
      _citySearchFocus.unfocus();
      return;
    }

    try {
      final matches = await geo.locationFromAddress(
        '$value, Bosnia and Herzegovina',
      );
      if (!mounted) return;
      if (matches.isEmpty) {
        _showMessage('Grad "$value" nije pronađen u BiH.');
        return;
      }
      final target = matches.first;
      _citySearchController.text = value;
      await _loadAtms(
        latitude: target.latitude,
        longitude: target.longitude,
        cityHint: value,
        moveCamera: true,
      );
      _citySearchFocus.unfocus();
    } catch (_) {
      if (mounted) _showMessage('Pretraga grada trenutno nije dostupna.');
    }
  }

  void _searchBank(String raw) {
    if (_navigation.shouldShowPanel) return;
    final query = BslCities.normalize(raw);
    if (query.isEmpty) {
      _showAllBanks();
      return;
    }

    String? found;
    for (final bank in _availableBanks) {
      if (BslCities.normalize(bank).contains(query)) {
        found = bank;
        break;
      }
    }
    if (found == null) {
      _showMessage('Nema bankomata tražene banke u ovom području.');
      return;
    }

    setState(() {
      _selectedBank = found;
      _bankSearchController.text = found!;
      _selectedAtm = null;
    });
    _bankSearchFocus.unfocus();
    _scheduleMarkerSync();
  }

  void _showAllBanks() {
    if (!mounted || _navigation.shouldShowPanel) return;
    setState(() {
      _selectedBank = null;
      _selectedAtm = null;
      _bankSearchController.clear();
    });
    _bankSearchFocus.unfocus();
    _scheduleMarkerSync();
  }

  Future<void> _onMapViewCreated(
    GoogleNavigationViewController controller,
  ) async {
    _mapController = controller;
    await _navigation.attachMapController(controller);
    await _applyMapStyle(controller);
    await _setMapLocationEnabled(_locationContext?.hasLocation ?? false);
    _scheduleMarkerSync();

    final location = _locationContext?.location;
    if (location != null) {
      await _animateTo(
        LatLng(latitude: location.latitude, longitude: location.longitude),
        14.2,
      );
    }
  }

  Future<void> _applyMapStyle(GoogleMapViewController controller) async {
    final style = _darkMapStyle;
    if (style == null) return;
    try {
      await controller.setMapStyle(style);
    } catch (error) {
      debugPrint('BSL ATM MAP STYLE APPLY ERROR: $error');
    }
  }

  Future<void> _setMapLocationEnabled(bool enabled) async {
    final controller = _mapController;
    if (controller == null) return;
    try {
      await controller.setMyLocationEnabled(
        enabled && !_navigation.isVehicleMarkerVisible,
      );
    } catch (_) {}
  }

  Future<void> _animateTo(LatLng target, double zoom) async {
    final controller = _mapController;
    if (controller == null) return;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: zoom),
        ),
        duration: const Duration(milliseconds: 500),
      );
    } catch (_) {}
  }

  void _scheduleMarkerSync() {
    _markerSyncPending = true;
    if (_markerSyncRunning) return;
    unawaited(_drainMarkerSync());
  }

  Future<void> _drainMarkerSync() async {
    _markerSyncRunning = true;
    try {
      while (mounted && _markerSyncPending) {
        _markerSyncPending = false;
        await _syncMarkers();
      }
    } finally {
      _markerSyncRunning = false;
    }
  }

  Future<void> _syncMarkers() async {
    final controller = _mapController;
    if (controller == null) return;
    final atms = List<AtmLocation>.of(_visibleAtms);

    try {
      if (_markers.isNotEmpty) await controller.removeMarkers(_markers);
      _markers = const [];
      _atmByMarkerId = const {};

      final created = await controller.addMarkers(
        atms
            .map((atm) {
              final selected = atm.id == _selectedAtm?.id;
              return MarkerOptions(
                position: atm.position,
                icon:
                    _markerIcons[_markerKey(
                      atm.bankName,
                      selected: selected,
                    )] ??
                    ImageDescriptor.defaultImage,
                anchor: const MarkerAnchor(u: 0.5, v: 1),
                consumeTapEvents: true,
                zIndex: selected ? 2 : 1,
                infoWindow: InfoWindow(
                  title: atm.displayName,
                  snippet: atm.subtitle,
                ),
              );
            })
            .toList(growable: false),
      );

      if (!mounted || !identical(controller, _mapController)) return;
      final map = <String, AtmLocation>{};
      final markers = <Marker>[];
      for (var i = 0; i < created.length && i < atms.length; i++) {
        final marker = created[i];
        if (marker == null) continue;
        markers.add(marker);
        map[marker.markerId] = atms[i];
      }
      _markers = markers;
      _atmByMarkerId = map;
    } catch (error, stackTrace) {
      debugPrint('BSL ATM MARKER SYNC ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _handleMarkerTap(String markerId) {
    if (_navigation.shouldShowPanel) return;
    final atm = _atmByMarkerId[markerId];
    if (atm == null) return;
    setState(() => _selectedAtm = atm);
    _scheduleMarkerSync();
    unawaited(_animateTo(atm.position, 17));
  }

  Future<void> _handleLocationButton() async {
    if (_navigation.isGuidanceActive) {
      await _navigation.recenter();
      return;
    }

    final ctx = _locationContext;
    if (ctx == null) return;
    if (ctx.location == null) await ctx.refresh();
    if (!mounted) return;
    final location = ctx.location;
    if (location == null) {
      if (ctx.shouldOpenSettings) await ctx.openRelevantSettings();
      if (mounted) _showMessage(ctx.statusMessage);
      return;
    }

    await _loadAtms(
      latitude: location.latitude,
      longitude: location.longitude,
      cityHint: location.city,
      moveCamera: true,
    );
  }

  Future<void> _chooseNavigation(AtmLocation atm) async {
    final mode = await showModalBottomSheet<BslNavigationTravelMode>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      elevation: 0,
      isScrollControlled: false,
      showDragHandle: false,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          decoration: BslDecorations.bottomDock(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.atm_rounded, color: BslColors.cyan, size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kako ideš do bankomata?',
                      style: BslTextStyles.title,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _TravelChoice(
                      icon: Icons.directions_car_filled_rounded,
                      label: 'Autom',
                      onTap: () => Navigator.pop(
                        sheetContext,
                        BslNavigationTravelMode.driving,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TravelChoice(
                      icon: Icons.directions_walk_rounded,
                      label: 'Pješke',
                      onTap: () => Navigator.pop(
                        sheetContext,
                        BslNavigationTravelMode.walking,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || mode == null) return;
    await _startNavigation(atm, mode);
  }

  Future<void> _startNavigation(
    AtmLocation atm,
    BslNavigationTravelMode mode,
  ) async {
    final ctx = _locationContext;
    if (ctx == null) return;

    if (ctx.location == null || ctx.location!.isFromCache || !ctx.isTracking) {
      await ctx.refresh();
    }
    if (!mounted) return;
    if (ctx.location == null) {
      if (ctx.shouldOpenSettings) await ctx.openRelevantSettings();
      if (mounted) _showMessage(ctx.statusMessage);
      return;
    }

    setState(() => _selectedAtm = atm);
    _citySearchFocus.unfocus();
    _bankSearchFocus.unfocus();
    _startSpeedTracking();

    await _navigation.start(
      destination: BslNavigationDestination(
        id: atm.id,
        title: atm.displayName,
        latitude: atm.latitude,
        longitude: atm.longitude,
      ),
      mapPadding: _navigationMapPadding(),
      travelMode: mode,
    );

    final controller = _mapController;
    if (controller != null) await _applyMapStyle(controller);
  }

  void _startSpeedTracking() {
    _speedSubscription?.cancel();
    _speedSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 2,
          ),
        ).listen((position) {
          if (!mounted) return;
          final kmh = position.speed.isFinite && position.speed > 0
              ? position.speed * 3.6
              : 0.0;
          setState(() => _speedKmh = kmh);
        }, onError: (_) {});
  }

  Future<void> _stopNavigation() async {
    await _speedSubscription?.cancel();
    _speedSubscription = null;
    if (mounted) setState(() => _speedKmh = 0);
    await _navigation.stop();
    final controller = _mapController;
    if (controller != null) {
      try {
        await controller.setPadding(EdgeInsets.zero);
      } catch (_) {}
      await _applyMapStyle(controller);
    }
  }

  EdgeInsets _navigationMapPadding() {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return EdgeInsets.fromLTRB(
      14 * ratio,
      205 * ratio,
      92 * ratio,
      320 * ratio,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _unregisterMarkerImages(Iterable<ImageDescriptor> images) async {
    for (final image in images.toSet()) {
      if (image.registeredImageId == null) continue;
      try {
        await unregisterImage(image);
      } catch (error) {
        debugPrint('BSL ATM MARKER CLEANUP ERROR: $error');
      }
    }
  }

  @override
  void dispose() {
    _locationContext?.removeListener(_handleLocationChanged);
    _navigation.removeListener(_handleNavigationChanged);
    _speedSubscription?.cancel();
    _navigation.dispose();
    _atmService.dispose();
    _citySearchController.dispose();
    _bankSearchController.dispose();
    _citySearchFocus.dispose();
    _bankSearchFocus.dispose();

    final images = List<ImageDescriptor>.of(_markerIcons.values);
    final navigationMarker = _navigationVehicleMarker;
    if (navigationMarker != null) images.add(navigationMarker);
    _markerIcons.clear();
    _navigationVehicleMarker = null;
    unawaited(_unregisterMarkerImages(images));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedAtm;
    final navigationVisible =
        selected != null &&
        _navigation.shouldShowPanel &&
        _navigation.destination?.id == selected.id;
    final locationContext = _locationContext;
    final selectedCardOffset = navigationVisible ? 318.0 : 242.0;

    return Scaffold(
      backgroundColor: BslColors.bgDark,
      body: Stack(
        children: [
          GoogleMapsNavigationView(
            onViewCreated: (controller) {
              unawaited(_onMapViewCreated(controller));
            },
            initialCameraPosition: CameraPosition(
              target: LatLng(
                latitude: _activeCity.latitude,
                longitude: _activeCity.longitude,
              ),
              zoom: _activeCity.mapZoom,
            ),
            initialNavigationUIEnabledPreference:
                NavigationUIEnabledPreference.disabled,
            initialMapColorScheme: MapColorScheme.dark,
            initialZoomControlsEnabled: false,
            initialMapToolbarEnabled: false,
            initialMapType: MapType.normal,
            onMarkerClicked: _handleMarkerTap,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BslModuleTopBar(
              title: 'Bankomati',
              subtitle: _citySearchController.text.trim().isEmpty
                  ? _activeCity.name
                  : _citySearchController.text.trim(),
              badge: '${_visibleAtms.length} / 10 km',
              searchHint: 'Grad u BiH',
              searchController: _citySearchController,
              searchFocusNode: _citySearchFocus,
              onSearchSubmitted: _searchCity,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 142,
            left: 16,
            right: 104,
            child: _GlassSearchField(
              controller: _bankSearchController,
              focusNode: _bankSearchFocus,
              hint: 'Banka',
              icon: Icons.account_balance_rounded,
              onSubmitted: _searchBank,
              onClear: _showAllBanks,
            ),
          ),
          if (_isLoading)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 198,
              left: 18,
              child: const _StatusPill(
                icon: Icons.sync_rounded,
                text: 'Tražim bankomate u krugu 10 km...',
                loading: true,
              ),
            ),
          if (_errorMessage != null && !_isLoading)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 198,
              left: 18,
              right: 104,
              child: _StatusPill(
                icon: Icons.error_outline_rounded,
                text: _errorMessage!,
              ),
            ),
          if (_availableBanks.isNotEmpty && !_navigation.shouldShowPanel)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 198,
              right: 8,
              bottom: selected == null ? 74 : selectedCardOffset + 10,
              child: _BankFilterRail(
                banks: _availableBanks,
                selectedBank: _selectedBank,
                colorForBank: _bankColor,
                onShowAll: _showAllBanks,
                onSelected: (bank) {
                  setState(() {
                    _selectedBank = bank;
                    _bankSearchController.text = bank;
                    _selectedAtm = null;
                  });
                  _scheduleMarkerSync();
                },
              ),
            ),
          AnimatedPositioned(
            duration: BslDurations.normal,
            curve: Curves.easeOutCubic,
            right: 14,
            bottom: selected == null ? 26 : selectedCardOffset + 8,
            child: BslMapLocationButton(
              isLoading: locationContext?.isLoading ?? false,
              hasLocation: locationContext?.hasLocation ?? false,
              needsAttention: locationContext?.shouldOpenSettings ?? false,
              onTap: _handleLocationButton,
            ),
          ),
          AnimatedPositioned(
            duration: BslDurations.normal,
            curve: Curves.easeOutCubic,
            left: 12,
            bottom: selected == null ? 14 : selectedCardOffset + 14,
            child: const _OsmAttribution(),
          ),
          AnimatedPositioned(
            duration: BslDurations.normal,
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: selected == null ? -420 : 0,
            child: AnimatedOpacity(
              duration: BslDurations.fast,
              opacity: selected == null ? 0 : 1,
              child: IgnorePointer(
                ignoring: selected == null,
                child: selected == null
                    ? const SizedBox.shrink()
                    : _AtmBottomCard(
                        atm: selected,
                        bankColor: _bankColor(selected.bankName),
                        navigationVisible: navigationVisible,
                        navigation: _navigation,
                        speedKmh: _speedKmh,
                        onNavigate: () =>
                            unawaited(_chooseNavigation(selected)),
                        onStop: () => unawaited(_stopNavigation()),
                        onRetry: () => unawaited(
                          _navigation.retry(
                            mapPadding: _navigationMapPadding(),
                          ),
                        ),
                        onRecenter: () => unawaited(_navigation.recenter()),
                        onClose: () async {
                          if (_navigation.shouldShowPanel) {
                            await _stopNavigation();
                          }
                          if (mounted) {
                            setState(() => _selectedAtm = null);
                            _scheduleMarkerSync();
                          }
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankFilterRail extends StatelessWidget {
  final List<String> banks;
  final String? selectedBank;
  final Color Function(String bank) colorForBank;
  final VoidCallback onShowAll;
  final ValueChanged<String> onSelected;

  const _BankFilterRail({
    required this.banks,
    required this.selectedBank,
    required this.colorForBank,
    required this.onShowAll,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: banks.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 7),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _BankFilterCard(
              label: 'Svi bankomati',
              icon: Icons.atm_rounded,
              accent: BslColors.cyan,
              selected: selectedBank == null,
              onTap: onShowAll,
            );
          }

          final bank = banks[index - 1];
          return _BankFilterCard(
            label: _compactBank(bank),
            icon: Icons.account_balance_rounded,
            accent: colorForBank(bank),
            selected: bank == selectedBank,
            onTap: () => onSelected(bank),
            tooltip: bank,
          );
        },
      ),
    );
  }

  static String _compactBank(String value) {
    return value
        .replaceAll(' Banka', '')
        .replaceAll(' banka', '')
        .replaceAll(' Bank', '')
        .replaceAll('Bosna Bank International', 'BBI')
        .trim();
  }
}

class _BankFilterCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;

  const _BankFilterCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BslRadius.medium),
        child: AnimatedContainer(
          duration: BslDurations.fast,
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BslColors.glassCyan.withValues(alpha: selected ? 0.90 : 0.74),
                BslColors.glassBlue.withValues(alpha: selected ? 0.88 : 0.70),
                BslColors.glassPurple.withValues(alpha: selected ? 0.90 : 0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(BslRadius.medium),
            border: Border.all(
              color: selected ? Colors.white : accent.withValues(alpha: 0.70),
              width: selected ? 1.8 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: selected ? 0.38 : 0.14),
                blurRadius: selected ? 18 : 10,
                spreadRadius: selected ? 1 : 0,
              ),
              ...BslShadows.deepShadow(),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? Colors.white : accent, size: 18),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: BslTextStyles.subtitle.copyWith(
                  color: Colors.white,
                  fontSize: 9.5,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip == null) return card;
    return Tooltip(message: tooltip!, child: card);
  }
}

class _GlassSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _GlassSearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(BslRadius.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 43,
          padding: const EdgeInsets.only(left: 13, right: 5),
          decoration: BslDecorations.glassCard(radius: BslRadius.pill),
          child: Row(
            children: [
              Icon(icon, color: BslColors.cyan, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onSubmitted: onSubmitted,
                  textInputAction: TextInputAction.search,
                  style: BslTextStyles.body.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: BslTextStyles.subtitle,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white54,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AtmBottomCard extends StatelessWidget {
  final AtmLocation atm;
  final Color bankColor;
  final bool navigationVisible;
  final BslNavigationController navigation;
  final double speedKmh;
  final VoidCallback onNavigate;
  final VoidCallback onStop;
  final VoidCallback onRetry;
  final VoidCallback onRecenter;
  final VoidCallback onClose;

  const _AtmBottomCard({
    required this.atm,
    required this.bankColor,
    required this.navigationVisible,
    required this.navigation,
    required this.speedKmh,
    required this.onNavigate,
    required this.onStop,
    required this.onRetry,
    required this.onRecenter,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final retry =
        navigation.stage == BslNavigationStage.error && navigation.canRetry;

    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(minHeight: 218),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BslDecorations.bottomDock(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xCC07111F),
                    shape: BoxShape.circle,
                    border: Border.all(color: bankColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: bankColor.withValues(alpha: 0.50),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.atm_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        atm.bankName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BslTextStyles.title.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        atm.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BslTextStyles.subtitle.copyWith(
                          color: Colors.white.withValues(alpha: 0.74),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white70,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: BslDurations.normal,
              child: navigationVisible
                  ? Column(
                      key: const ValueKey('atm-navigation'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BslNavigationPanel(
                          stage: navigation.stage,
                          statusMessage: navigation.statusMessage,
                          navInfo: navigation.navInfo,
                          onRecenter: onRecenter,
                          destinationIcon: Icons.atm_rounded,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _Metric(
                                icon:
                                    navigation.travelMode ==
                                        BslNavigationTravelMode.walking
                                    ? Icons.directions_walk_rounded
                                    : Icons.speed_rounded,
                                label:
                                    navigation.travelMode ==
                                        BslNavigationTravelMode.walking
                                    ? 'Pješke'
                                    : '${speedKmh.toStringAsFixed(0)} km/h',
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: _AtmActionButton(
                                icon: retry
                                    ? Icons.refresh_rounded
                                    : Icons.stop_circle_outlined,
                                label: retry ? 'Ponovi' : 'Zaustavi',
                                onTap: retry ? onRetry : onStop,
                                color: retry
                                    ? BslColors.warning
                                    : BslColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('atm-details'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MiniChip(
                              icon: Icons.location_on_outlined,
                              label: atm.city.isEmpty ? 'Bankomat' : atm.city,
                              color: bankColor,
                            ),
                            if (atm.cashDeposit)
                              const _MiniChip(
                                icon: Icons.savings_rounded,
                                label: 'Uplata gotovine',
                                color: BslColors.success,
                              ),
                            if (atm.is24h)
                              const _MiniChip(
                                icon: Icons.schedule_rounded,
                                label: '24/7',
                                color: BslColors.cyan,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _AtmActionButton(
                          icon: Icons.navigation_rounded,
                          label: 'Pokreni navigaciju',
                          onTap: onNavigate,
                          color: BslColors.cyan,
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

class _AtmActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _AtmActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: BslDurations.fast,
      opacity: onTap == null ? 0.60 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(BslRadius.medium),
          child: Container(
            width: double.infinity,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(BslRadius.medium),
              border: Border.all(color: color.withValues(alpha: 0.40)),
              boxShadow: color == BslColors.danger
                  ? null
                  : BslShadows.cyanGlow(alpha: 0.08),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 19),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BslTextStyles.body.copyWith(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TravelChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TravelChoice({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(BslRadius.large),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BslDecorations.glassCard(),
        child: Column(
          children: [
            Icon(icon, color: BslColors.cyan, size: 34),
            const SizedBox(height: 8),
            Text(label, style: BslTextStyles.body),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniChip({
    required this.icon,
    required this.label,
    this.color = BslColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x99111A33),
        borderRadius: BorderRadius.circular(BslRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.54)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: BslTextStyles.subtitle.copyWith(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Metric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BslDecorations.softPill(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: BslColors.cyan, size: 17),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BslTextStyles.body.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool loading;

  const _StatusPill({
    required this.icon,
    required this.text,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BslDecorations.glassCard(radius: BslRadius.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: BslColors.cyan,
              ),
            )
          else
            Icon(icon, color: BslColors.cyan, size: 17),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BslTextStyles.subtitle.copyWith(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'ATM podaci: © OpenStreetMap contributors',
        style: BslTextStyles.subtitle.copyWith(
          color: Colors.white70,
          fontSize: 9,
        ),
      ),
    );
  }
}
