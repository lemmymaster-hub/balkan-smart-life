import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/context/bsl_location_context.dart';
import '../../../core/models/address_search_result.dart';
import '../../../core/models/bsl_city.dart';
import '../../../core/models/bsl_location_result.dart';
import '../../../core/services/address_geocoding_service.dart';
import '../../../core/theme/bsl_design_system.dart';
import '../../../core/widgets/bsl_map_location_button.dart';
import '../../../core/widgets/bsl_module_top_bar.dart';
import '../models/ev_charger.dart';
import '../models/ev_charger_map_policy.dart';
import '../services/ev_charger_service.dart';
import '../widgets/ev_charger_map_overlays.dart';
import '../widgets/ev_charger_marker_factory.dart';

class EvChargersMapScreen extends StatefulWidget {
  final String city;

  const EvChargersMapScreen({super.key, required this.city});

  @override
  State<EvChargersMapScreen> createState() => _EvChargersMapScreenState();
}

class _EvChargersMapScreenState extends State<EvChargersMapScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final AddressGeocodingService _addressService =
      const AddressGeocodingService();
  final EvChargerService _chargerService = EvChargerService();

  GoogleMapController? _mapController;
  BslLocationContext? _locationContext;
  StreamSubscription<List<EvCharger>>? _chargersSubscription;
  late BslCity _activeCity;

  String? _darkMapStyle;
  List<EvCharger> _chargers = const [];
  EvCharger? _selectedCharger;
  Object? _error;
  bool _isLoading = true;

  bool _hasCenteredOnUser = false;
  bool _isCenteringOnUser = false;
  bool _userChangedMapTarget = false;
  bool _requestedFreshLocation = false;
  bool _hasStartedCityListener = false;
  bool _lastHasUserLocation = false;
  bool _lastLocationIsLoading = false;
  bool _lastLocationNeedsAttention = false;
  int _cityRequestId = 0;
  int _markerBuildId = 0;

  final Map<String, BitmapDescriptor> _markerIcons = {};

  CameraPosition get _initialCameraPosition {
    final location = _locationContext?.location;
    final detectedCity = location == null ? null : _cityFromLocation(location);

    if (location != null &&
        EvChargerMapPolicy.shouldAutoCenterOnLocation(
          selectedCity: _activeCity,
          detectedCity: detectedCity,
        )) {
      return CameraPosition(
        target: LatLng(location.latitude, location.longitude),
        zoom: 15.5,
      );
    }

    return CameraPosition(
      target: LatLng(_activeCity.latitude, _activeCity.longitude),
      zoom: _activeCity.mapZoom,
    );
  }

  @override
  void initState() {
    super.initState();
    _activeCity = BslCities.byName(widget.city);
    unawaited(_loadMapStyle());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextLocationContext = context.read<BslLocationContext>();

    if (!identical(_locationContext, nextLocationContext)) {
      _locationContext?.removeListener(_handleLocationContextChanged);
      _locationContext = nextLocationContext;
      nextLocationContext.addListener(_handleLocationContextChanged);
      _lastHasUserLocation = nextLocationContext.hasLocation;
      _lastLocationIsLoading = nextLocationContext.isLoading;
      _lastLocationNeedsAttention = nextLocationContext.shouldOpenSettings;
    }

    if (!_hasStartedCityListener) {
      _hasStartedCityListener = true;
      unawaited(_listenForCity(_activeCity));
    }

    if (!_requestedFreshLocation) {
      _requestedFreshLocation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        nextLocationContext.refresh();
        unawaited(_centerMapOnUser());
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
    } catch (error) {
      debugPrint('EV CHARGERS MAP STYLE ERROR: $error');
    }
  }

  Future<void> _listenForCity(BslCity city, {bool forceRefresh = false}) async {
    final requestId = ++_cityRequestId;
    await _chargersSubscription?.cancel();

    if (!mounted || requestId != _cityRequestId) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _chargers = const [];
      _selectedCharger = null;
    });

    _chargersSubscription = _chargerService
        .watchForCity(city, forceRefresh: forceRefresh)
        .listen(
          (chargers) {
            if (!mounted || requestId != _cityRequestId) return;

            setState(() {
              _chargers = chargers;
              _isLoading = false;
              _error = null;

              final selectedId = _selectedCharger?.id;
              if (selectedId != null) {
                _selectedCharger = _firstWhereOrNull(
                  chargers,
                  (charger) => charger.id == selectedId,
                );
              }
            });

            unawaited(_prepareMarkerIcons(chargers));
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted || requestId != _cityRequestId) return;
            debugPrint('EV CHARGERS LOAD ERROR: $error');
            debugPrintStack(stackTrace: stackTrace);

            setState(() {
              _error = error;
              _isLoading = false;
            });
          },
        );
  }

  Future<void> _prepareMarkerIcons(List<EvCharger> chargers) async {
    final buildId = ++_markerBuildId;
    final requiredKeys = <String>{};

    for (final charger in chargers) {
      requiredKeys.add(_markerKey(charger, selected: false));
      requiredKeys.add(_markerKey(charger, selected: true));
    }

    final missingKeys = requiredKeys
        .where((key) => !_markerIcons.containsKey(key))
        .toList(growable: false);

    if (missingKeys.isEmpty) return;

    final createdIcons = await Future.wait(
      missingKeys.map((key) async {
        final parts = key.split('|');
        final fee = EvChargingFee.values.byName(parts[0]);
        final selected = parts[1] == 'selected';
        final label = parts.length > 2 && parts[2].isNotEmpty
            ? parts.sublist(2).join('|')
            : null;
        final icon = await EvChargerMarkerFactory.create(
          fee: fee,
          label: label,
          isSelected: selected,
        );
        return MapEntry(key, icon);
      }),
    );

    if (!mounted || buildId != _markerBuildId) return;

    setState(() {
      _markerIcons.addEntries(createdIcons);
    });
  }

  void _handleLocationContextChanged() {
    if (!mounted) return;

    final locationContext = _locationContext;
    if (locationContext == null) return;

    final shouldRebuild =
        _lastHasUserLocation != locationContext.hasLocation ||
        _lastLocationIsLoading != locationContext.isLoading ||
        _lastLocationNeedsAttention != locationContext.shouldOpenSettings;

    if (shouldRebuild) {
      setState(() {
        _lastHasUserLocation = locationContext.hasLocation;
        _lastLocationIsLoading = locationContext.isLoading;
        _lastLocationNeedsAttention = locationContext.shouldOpenSettings;
      });
    }

    if (locationContext.location != null &&
        !_hasCenteredOnUser &&
        !_userChangedMapTarget) {
      unawaited(_centerMapOnUser());
    }
  }

  BslCity? _cityFromLocation(BslLocationResult location) {
    return BslCities.findExact(location.city) ??
        BslCities.findExact(location.municipality) ??
        BslCities.findMentionedIn(location.displayLabel);
  }

  Future<void> _handleLocationButton() async {
    final locationContext = _locationContext;
    if (locationContext == null) return;

    if (locationContext.location != null) {
      await _centerMapOnUser(force: true);
      return;
    }

    if (locationContext.shouldOpenSettings) {
      final openedSettings = await locationContext.openRelevantSettings();
      if (openedSettings) return;
    }

    await locationContext.refresh();
    if (!mounted) return;

    if (locationContext.location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locationContext.statusMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _centerMapOnUser(force: true);
  }

  Future<void> _centerMapOnUser({bool force = false}) async {
    if (_isCenteringOnUser || _mapController == null) return;
    if (!force && (_hasCenteredOnUser || _userChangedMapTarget)) return;

    final location = _locationContext?.location;
    if (location == null) return;

    final detectedCity = _cityFromLocation(location);

    // Grad odabran na BSL početnom ekranu ima prednost pri prvom ulasku.
    // GPS automatski centrira mapu samo kada pripada istom gradu. Korisnik
    // uvijek može pritisnuti dugme lokacije i tada namjerno preći na GPS grad.
    if (!force) {
      if (!EvChargerMapPolicy.shouldAutoCenterOnLocation(
        selectedCity: _activeCity,
        detectedCity: detectedCity,
      )) {
        if (detectedCity == null) return;
        _hasCenteredOnUser = true;
        return;
      }
    }

    _isCenteringOnUser = true;

    try {
      if (force &&
          detectedCity != null &&
          !BslCities.same(detectedCity.name, _activeCity.name)) {
        await _activateCity(detectedCity, moveToCity: false);
      }

      if (mounted) {
        setState(() {
          _userChangedMapTarget = false;
          _selectedCharger = null;
        });
      }

      await _animateTo(
        target: LatLng(location.latitude, location.longitude),
        zoom: 15.5,
      );
      _hasCenteredOnUser = true;
    } finally {
      _isCenteringOnUser = false;
    }
  }

  Future<void> _activateCity(BslCity city, {required bool moveToCity}) async {
    final cityChanged = !BslCities.same(city.name, _activeCity.name);

    if (cityChanged && mounted) {
      setState(() {
        _activeCity = city;
        _selectedCharger = null;
      });
      unawaited(_listenForCity(city));
    }

    if (moveToCity) {
      _userChangedMapTarget = true;
      _hasCenteredOnUser = true;
      await _animateTo(
        target: LatLng(city.latitude, city.longitude),
        zoom: city.mapZoom,
      );
    }
  }

  Future<void> _searchChargerOrAddress(String value) async {
    final rawQuery = value.trim();
    if (rawQuery.length < 2) return;

    final normalizedQuery = BslCities.normalize(rawQuery);
    final exactCity = BslCities.findExact(rawQuery);

    if (exactCity != null) {
      await _activateCity(exactCity, moveToCity: true);
      if (mounted) _searchFocusNode.unfocus();
      return;
    }

    final charger = _firstWhereOrNull(_chargers, (candidate) {
      final searchable = BslCities.normalize(
        [
          candidate.name,
          candidate.address,
          candidate.city,
          candidate.operatorName,
        ].join(' '),
      );
      return searchable.contains(normalizedQuery);
    });

    if (charger != null) {
      _userChangedMapTarget = true;
      _hasCenteredOnUser = true;
      await _animateTo(target: charger.position, zoom: 17);

      if (!mounted) return;
      setState(() => _selectedCharger = charger);
      _searchFocusNode.unfocus();
      return;
    }

    final mentionedCity = BslCities.findMentionedIn(rawQuery);
    if (mentionedCity != null &&
        !BslCities.same(mentionedCity.name, _activeCity.name)) {
      await _activateCity(mentionedCity, moveToCity: false);
    }

    final AddressSearchResult? address;

    try {
      address = await _addressService.searchAddress(
        input: rawQuery,
        city: mentionedCity?.name ?? _activeCity.name,
      );
    } on AddressGeocodingException {
      if (!mounted) return;
      _showMessage('Pretraga adrese trenutno nije dostupna.');
      return;
    }

    if (!mounted) return;

    if (address == null) {
      _showMessage('Nema rezultata za "$rawQuery"');
      return;
    }

    _userChangedMapTarget = true;
    _hasCenteredOnUser = true;
    await _animateTo(target: address.location, zoom: 16);

    if (!mounted) return;
    setState(() => _selectedCharger = null);
    _searchFocusNode.unfocus();
  }

  Future<void> _animateTo({
    required LatLng target,
    required double zoom,
  }) async {
    final controller = _mapController;
    if (controller == null) return;

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom),
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    return _chargers.map((charger) {
      final selected = charger.id == _selectedCharger?.id;
      final key = _markerKey(charger, selected: selected);

      return Marker(
        markerId: MarkerId(charger.id),
        position: charger.position,
        icon: _markerIcons[key] ?? _fallbackMarker(charger.fee),
        anchor: const Offset(0.5, 1),
        infoWindow: InfoWindow(
          title: charger.name,
          snippet: _markerSnippet(charger),
        ),
        onTap: () async {
          _userChangedMapTarget = true;
          _hasCenteredOnUser = true;
          await _animateTo(target: charger.position, zoom: 17);

          if (!mounted) return;
          setState(() => _selectedCharger = charger);
        },
      );
    }).toSet();
  }

  String _markerKey(EvCharger charger, {required bool selected}) {
    return '${charger.fee.name}|${selected ? 'selected' : 'normal'}|'
        '${charger.markerLabel ?? ''}';
  }

  BitmapDescriptor _fallbackMarker(EvChargingFee fee) {
    switch (fee) {
      case EvChargingFee.free:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case EvChargingFee.paid:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case EvChargingFee.unknown:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        );
    }
  }

  String _markerSnippet(EvCharger charger) {
    switch (charger.fee) {
      case EvChargingFee.free:
        return 'Besplatno punjenje';
      case EvChargingFee.paid:
        return charger.priceLabel.isEmpty
            ? 'Punjenje se naplaćuje'
            : charger.priceLabel;
      case EvChargingFee.unknown:
        return 'Cijena nije potvrđena';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _retry() async {
    _chargerService.clearCache(_activeCity);
    await _listenForCity(_activeCity, forceRefresh: true);
  }

  @override
  void dispose() {
    _chargersSubscription?.cancel();
    _locationContext?.removeListener(_handleLocationContextChanged);
    _chargerService.dispose();
    _mapController?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationContext = _locationContext;
    final hasUserLocation = locationContext?.hasLocation ?? false;
    final hasSelectedCharger = _selectedCharger != null;

    return Scaffold(
      backgroundColor: BslColors.bgDark,
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              unawaited(_centerMapOnUser());
            },
            initialCameraPosition: _initialCameraPosition,
            style: _darkMapStyle,
            markers: _buildMarkers(),
            myLocationEnabled: hasUserLocation,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BslModuleTopBar(
              title: 'EL Punjači',
              subtitle: _activeCity.name,
              badge: '${_chargers.length} punjača',
              searchHint: 'Nađi punjač',
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              onSearchSubmitted: _searchChargerOrAddress,
            ),
          ),
          if (_isLoading)
            const Positioned(
              top: 154,
              left: 0,
              right: 0,
              child: Center(
                child: EvMapStatusPill(
                  icon: Icons.sync_rounded,
                  text: 'Učitavam OSM punjače...',
                  showProgress: true,
                ),
              ),
            ),
          if (_error != null && !_isLoading)
            Positioned(
              top: 154,
              left: 18,
              right: 18,
              child: EvChargerErrorCard(error: _error!, onRetry: _retry),
            ),
          AnimatedPositioned(
            duration: BslDurations.normal,
            curve: Curves.easeOutCubic,
            right: 16,
            bottom: hasSelectedCharger ? 254 : 28,
            child: BslMapLocationButton(
              isLoading: locationContext?.isLoading ?? false,
              hasLocation: hasUserLocation,
              needsAttention: locationContext?.shouldOpenSettings ?? false,
              onTap: _handleLocationButton,
            ),
          ),
          AnimatedPositioned(
            duration: BslDurations.normal,
            curve: Curves.easeOutCubic,
            left: 14,
            bottom: hasSelectedCharger ? 252 : 18,
            child: const EvOsmAttribution(),
          ),
          AnimatedPositioned(
            duration: BslDurations.normal,
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: hasSelectedCharger ? 0 : -250,
            child: AnimatedOpacity(
              duration: BslDurations.fast,
              opacity: hasSelectedCharger ? 1 : 0,
              child: IgnorePointer(
                ignoring: !hasSelectedCharger,
                child: _selectedCharger == null
                    ? const SizedBox.shrink()
                    : EvChargerBottomCard(
                        charger: _selectedCharger!,
                        onClose: () {
                          setState(() => _selectedCharger = null);
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

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}
