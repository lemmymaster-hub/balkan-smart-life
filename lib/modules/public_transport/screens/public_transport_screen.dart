import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/context/bsl_location_context.dart';
import '../../../core/theme/bsl_design_system.dart';
import '../../../core/widgets/bsl_map_location_button.dart';
import '../../../core/widgets/bsl_module_top_bar.dart';
import '../controllers/transit_controller.dart';
import '../models/transit_models.dart';
import '../widgets/transit_marker_factory.dart';

class PublicTransportScreen extends StatefulWidget {
  final String city;
  final TransitController? controller;

  /// Allows widget verification without a native Google Maps platform view.
  final WidgetBuilder? mapBuilder;
  const PublicTransportScreen({
    super.key,
    required this.city,
    this.controller,
    this.mapBuilder,
  });
  @override
  State<PublicTransportScreen> createState() => _PublicTransportScreenState();
}

class _PublicTransportScreenState extends State<PublicTransportScreen>
    with WidgetsBindingObserver {
  late final TransitController _transit;
  final _search = TextEditingController();
  GoogleNavigationViewController? _map;
  String? _style;
  TransitRoute? _drawnRoute;
  final _icons = <String, ImageDescriptor>{};
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  Map<String, TransitStop> _stopMarkers = {};
  bool _syncing = false;
  bool _pending = false;
  bool _iconsLoading = false;
  String? _mapError;

  LatLng _latLng(TransitPoint point) =>
      LatLng(latitude: point.latitude, longitude: point.longitude);
  Color get _accent => _transit.line.isTram ? BslColors.cyan : BslColors.purple;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transit = widget.controller ?? TransitController();
    _transit.addListener(_changed);
    _search.addListener(_searchChanged);
    unawaited(_loadStyle());
    unawaited(_transit.start());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iconsLoading && widget.mapBuilder == null) {
      _iconsLoading = true;
      unawaited(_loadIcons());
    }
  }

  Future<void> _loadStyle() async {
    try {
      final style = await rootBundle.loadString(
        'assets/maps/bsl_dark_map_style.json',
      );
      if (!mounted) return;
      _style = style;
      await _map?.setMapStyle(style);
    } catch (_) {
      if (mounted)
        setState(() => _mapError = 'Stil mape trenutno nije dostupan.');
    }
  }

  Future<void> _loadIcons() async {
    try {
      for (final tram in [true, false]) {
        for (final vehicle in [true, false]) {
          final icon = await TransitMarkerFactory.create(
            vehicle: vehicle,
            tram: tram,
          );
          if (!mounted) {
            await unregisterImage(icon);
            return;
          }
          _icons['$tram:$vehicle'] = icon;
        }
      }
      _scheduleMapSync();
    } catch (_) {
      if (mounted)
        setState(() => _mapError = 'Oznake mape trenutno nisu dostupne.');
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _scheduleMapSync();
  }

  void _searchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _transit.setActive(state == AppLifecycleState.resumed);
  }

  Future<void> _mapCreated(GoogleNavigationViewController map) async {
    _map = map;
    try {
      if (_style != null) await map.setMapStyle(_style!);
      if (!mounted) return;
      await map.setMyLocationEnabled(
        context.read<BslLocationContext>().hasLocation,
      );
      // Keep Google attribution and map controls outside the BSL panels.
      await map.setPadding(const EdgeInsets.fromLTRB(12, 265, 12, 290));
      _drawnRoute = null;
      _scheduleMapSync();
    } catch (_) {
      if (mounted) setState(() => _mapError = 'Mapa trenutno nije dostupna.');
    }
  }

  void _scheduleMapSync() {
    _pending = true;
    if (!_syncing) unawaited(_syncMap());
  }

  Future<void> _syncMap() async {
    _syncing = true;
    try {
      while (mounted && _pending && _map != null) {
        _pending = false;
        final map = _map!;
        final route = _transit.route;
        final tram = _transit.line.isTram;
        final accent = _accent;
        final arrivals = [..._transit.arrivals];
        if (_markers.isNotEmpty) await map.removeMarkers(_markers);
        _markers = [];
        _stopMarkers = {};
        if (!mounted) return;
        final stops = route?.stops ?? <TransitStop>[];
        final vehicles = arrivals.where((a) => a.point != null).toList();
        final created = await map.addMarkers([
          for (final stop in stops)
            MarkerOptions(
              position: _latLng(stop.point),
              icon: _icons['$tram:false'] ?? ImageDescriptor.defaultImage,
              consumeTapEvents: true,
              zIndex: stop.id == _transit.stop?.id ? 3 : 1,
              infoWindow: InfoWindow(title: stop.name),
            ),
          for (final vehicle in vehicles)
            MarkerOptions(
              position: _latLng(vehicle.point!),
              icon: _icons['$tram:true'] ?? ImageDescriptor.defaultImage,
              zIndex: 4,
              infoWindow: InfoWindow(
                title: '${_transit.line.code} • ${vehicle.operatorName}',
                snippet:
                    'Pozicija uz procjenu dolaska; vrijeme GPS mjerenja nije navedeno',
              ),
            ),
        ]);
        if (!mounted) return;
        _markers = created.whereType<Marker>().toList();
        for (var i = 0; i < stops.length && i < created.length; i++) {
          final marker = created[i];
          if (marker != null) _stopMarkers[marker.markerId] = stops[i];
        }
        if (!identical(route, _drawnRoute)) {
          if (_polylines.isNotEmpty) await map.removePolylines(_polylines);
          _polylines = [];
          if (route != null) {
            final lines = await map.addPolylines([
              PolylineOptions(
                points: route.points.map(_latLng).toList(),
                strokeColor: accent,
                strokeWidth: 5,
              ),
            ]);
            _polylines = lines.whereType<Polyline>().toList();
            await _fitRoute(route);
          }
          _drawnRoute = route;
        }
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _mapError =
              'Prikaz mape nije osvježen. Podaci su dostupni u spisku.',
        );
    } finally {
      _syncing = false;
    }
  }

  Future<void> _fitRoute(TransitRoute route) async {
    if (route.points.isEmpty) return;
    var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
    for (final point in route.points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    await _map?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(latitude: south, longitude: west),
          northeast: LatLng(latitude: north, longitude: east),
        ),
        padding: 28,
      ),
    );
  }

  Future<void> _selectStop(TransitStop stop) async {
    unawaited(_transit.selectStop(stop));
    try {
      await _map?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _latLng(stop.point), zoom: 15.5),
        ),
      );
    } catch (_) {
      /* The stop list remains usable without the native map. */
    }
  }

  Future<void> _nearestStop() async {
    final location = context.read<BslLocationContext>();
    if (location.shouldOpenSettings) {
      await location.openRelevantSettings();
      return;
    }
    await location.refresh();
    if (!mounted) return;
    final current = location.location;
    final stops = _transit.route?.stops;
    if (current == null || stops == null || stops.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(location.statusMessage)));
      return;
    }
    final position = TransitPoint(current.latitude, current.longitude);
    final sorted = [...stops]
      ..sort(
        (a, b) => a.point
            .distanceTo(position)
            .compareTo(b.point.distanceTo(position)),
      );
    try {
      await _map?.setMyLocationEnabled(true);
    } catch (_) {}
    if (mounted) await _selectStop(sorted.first);
  }

  void _showTimetable() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BslColors.bgDark,
      builder: (_) => _TimetableSheet(controller: _transit),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transit.removeListener(_changed);
    if (widget.controller == null) _transit.dispose();
    _search.dispose();
    for (final icon in _icons.values) {
      unawaited(unregisterImage(icon));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<BslLocationContext>();
    final query = _search.text.trim().toLowerCase();
    final stops = (_transit.route?.stops ?? <TransitStop>[])
        .where((s) => s.name.toLowerCase().contains(query))
        .toList();
    return Scaffold(
      backgroundColor: BslColors.bgDark,
      body: Stack(
        children: [
          widget.mapBuilder?.call(context) ??
              GoogleMapsNavigationView(
                onViewCreated: (map) => unawaited(_mapCreated(map)),
                initialCameraPosition: const CameraPosition(
                  target: LatLng(latitude: 43.865, longitude: 18.375),
                  zoom: 11.5,
                ),
                initialNavigationUIEnabledPreference:
                    NavigationUIEnabledPreference.disabled,
                initialMapColorScheme: MapColorScheme.dark,
                initialMapToolbarEnabled: false,
                initialZoomControlsEnabled: false,
                onMarkerClicked: (id) {
                  final stop = _stopMarkers[id];
                  if (stop != null) unawaited(_selectStop(stop));
                },
              ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BslModuleTopBar(
                  title: 'Gradski prevoz',
                  subtitle: 'Sarajevo • linije 106 i 3',
                  badge: _transit.line.code,
                  searchHint: 'Pretraži stanice odabranog smjera',
                  searchController: _search,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BslDecorations.glassCard(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            for (final line in TransitLine.supported)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(
                                      '${line.isTram ? 'Tramvaj' : 'Trolejbus'} ${line.code}',
                                    ),
                                    selected: line.id == _transit.line.id,
                                    selectedColor: BslColors.glassBlue,
                                    backgroundColor: BslColors.bgDark,
                                    labelStyle: const TextStyle(
                                      color: Colors.white,
                                    ),
                                    onSelected: (_) {
                                      _search.clear();
                                      unawaited(_transit.selectLine(line));
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_transit.directions.isNotEmpty)
                          DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _transit.direction?.id,
                              isExpanded: true,
                              dropdownColor: BslColors.bgDark,
                              iconEnabledColor: BslColors.cyan,
                              style: BslTextStyles.body,
                              items: [
                                for (final d in _transit.directions)
                                  DropdownMenuItem(
                                    value: d.id,
                                    child: Text(
                                      d.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (id) {
                                if (id != null) {
                                  _search.clear();
                                  unawaited(
                                    _transit.selectDirection(
                                      _transit.directions.firstWhere(
                                        (d) => d.id == id,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            top: MediaQuery.paddingOf(context).top + 255,
            child: BslMapLocationButton(
              isLoading: location.isLoading,
              hasLocation: location.hasLocation,
              needsAttention: location.shouldOpenSettings,
              onTap: () => unawaited(_nearestStop()),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: .34,
            minChildSize: .20,
            maxChildSize: .72,
            builder: (context, scrollController) => Container(
              decoration: BslDecorations.bottomDock(),
              child: SafeArea(
                top: false,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          _transit.line.isTram
                              ? Icons.tram
                              : Icons.directions_bus,
                          color: _accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _transit.stop?.name ?? _transit.line.name,
                            style: BslTextStyles.body,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Osvježi',
                          onPressed: _transit.refreshing
                              ? null
                              : () {
                                  if (_transit.routeError != null) {
                                    unawaited(
                                      _transit.selectLine(_transit.line),
                                    );
                                  } else {
                                    unawaited(_transit.refreshArrivals());
                                  }
                                },
                          icon: const Icon(
                            Icons.refresh,
                            color: BslColors.cyan,
                          ),
                        ),
                      ],
                    ),
                    if (_transit.loading)
                      const LinearProgressIndicator(color: BslColors.cyan),
                    if (_transit.routeError != null)
                      Text(_transit.routeError!, style: BslTextStyles.body),
                    if (_mapError != null)
                      Text(_mapError!, style: BslTextStyles.subtitle),
                    Text(_transit.liveStatus, style: BslTextStyles.subtitle),
                    if (_transit.receivedAt != null)
                      Text(
                        'Provjereno ${_clock(_transit.receivedAt!)} • izvor: javniprevozks.ba',
                        style: BslTextStyles.subtitle.copyWith(fontSize: 10),
                      ),
                    if (_transit.arrivals.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final arrival in _transit.arrivals.take(5))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _transit.line.isTram
                                ? Icons.tram
                                : Icons.directions_bus,
                            color: _accent,
                          ),
                          title: Text(
                            '${arrival.operatorName} • ${_transit.line.code}',
                            style: BslTextStyles.body,
                          ),
                          subtitle: Text(
                            'Očekivano ${_clock(arrival.expectedAt)}',
                            style: BslTextStyles.subtitle,
                          ),
                          trailing: Text(
                            '${arrival.minutesFrom(_transit.now())} min',
                            style: BslTextStyles.body.copyWith(
                              color: BslColors.cyan,
                            ),
                          ),
                        ),
                      const Text(
                        'Pozicije su iz odgovora za dolaske. Izvor ne navodi vrijeme GPS mjerenja.',
                        style: BslTextStyles.subtitle,
                      ),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _transit.direction == null
                          ? null
                          : _showTimetable,
                      icon: const Icon(Icons.schedule),
                      label: const Text('Red vožnje • polasci s terminala'),
                    ),
                    const SizedBox(height: 8),
                    Text('Stanice u smjeru vožnje', style: BslTextStyles.body),
                    if (stops.isEmpty &&
                        !_transit.loading &&
                        _transit.routeError == null)
                      const Text(
                        'Nema stanica za ovu pretragu.',
                        style: BslTextStyles.subtitle,
                      ),
                    for (final stop in stops)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        selected: stop.id == _transit.stop?.id,
                        selectedTileColor: BslColors.glassBlue,
                        leading: Icon(
                          Icons.trip_origin,
                          color: _accent,
                          size: 18,
                        ),
                        title: Text(stop.name, style: BslTextStyles.body),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          unawaited(_selectStop(stop));
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _clock(DateTime instant) {
  final local = sarajevoTime(instant);
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
}

class _TimetableSheet extends StatefulWidget {
  final TransitController controller;
  const _TimetableSheet({required this.controller});
  @override
  State<_TimetableSheet> createState() => _TimetableSheetState();
}

class _TimetableSheetState extends State<_TimetableSheet> {
  bool holiday = false;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final now = c.now();
      final day = sarajevoTime(now);
      final times =
          c.departures
              .where((d) => d.validOn(now, holiday: holiday))
              .map((d) => d.time.substring(0, 5))
              .toSet()
              .toList()
            ..sort();
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Red vožnje • ${c.line.code}', style: BslTextStyles.title),
              Text(c.direction?.name ?? '', style: BslTextStyles.body),
              Text(
                '${day.day}.${day.month}.${day.year}. • vrijeme u Sarajevu',
                style: BslTextStyles.subtitle,
              ),
              const SizedBox(height: 8),
              const Text(
                'Planirani polasci s početnog terminala. Ovo nisu vremena dolaska na odabranu stanicu.',
                style: BslTextStyles.subtitle,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Praznični red vožnje',
                  style: BslTextStyles.body,
                ),
                value: holiday,
                onChanged: (value) => setState(() => holiday = value),
              ),
              if (c.timetableError != null)
                Text(c.timetableError!, style: BslTextStyles.body)
              else if (c.timetableReceivedAt == null)
                const Center(child: CircularProgressIndicator())
              else if (times.isEmpty)
                const Text(
                  'Izvor nema objavljenih polazaka za ovaj dan.',
                  style: BslTextStyles.body,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final time in times)
                      Chip(
                        label: Text(time, style: BslTextStyles.body),
                        backgroundColor: BslColors.glassBlue,
                      ),
                  ],
                ),
              if (c.timetableReceivedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Izvor: javniprevozks.ba • provjereno ${_clock(c.timetableReceivedAt!)}',
                    style: BslTextStyles.subtitle,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
