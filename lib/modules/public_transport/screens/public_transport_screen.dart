import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/context/bsl_location_context.dart';
import '../../../core/theme/bsl_design_system.dart';
import '../../../core/widgets/bsl_map_location_button.dart';
import '../controllers/transit_controller.dart';
import '../map/transit_vehicle_layer.dart';
import '../models/transit_models.dart';
import '../widgets/transit_marker_factory.dart';
import '../widgets/transit_vehicle_model.dart';

class PublicTransportScreen extends StatefulWidget {
  final String city;
  final TransitController? controller;
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
  late final TransitVehicleLayer _vehicles;
  GoogleNavigationViewController? _map;
  final _atlases = <bool, Map<int, ImageDescriptor>>{};
  ImageDescriptor? _stopIcon;
  String? _style;
  TransitRoute? _drawnRoute;
  List<Marker> _stops = [];
  List<Polyline> _lines = [];
  final _stopMarkers = <String, TransitStop>{};
  bool _loadingImages = false, _syncing = false, _pending = false;
  int _lastVehicleRevision = -1;
  bool? _lastFresh, _lastActive;
  TransitRoute? _lastRoute;
  String? _mapError;

  LatLng _latLng(TransitPoint p) =>
      LatLng(latitude: p.latitude, longitude: p.longitude);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transit = widget.controller ?? TransitController();
    _vehicles = TransitVehicleLayer(now: _transit.now);
    _transit.addListener(_changed);
    unawaited(_loadStyle());
    unawaited(_transit.start());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadingImages && widget.mapBuilder == null) {
      _loadingImages = true;
      unawaited(_loadImages());
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
      /* Native dark color scheme remains available. */
    }
  }

  Future<void> _loadImages() async {
    try {
      final icon = await TransitMarkerFactory.create(
        vehicle: false,
        tram: true,
      );
      if (!mounted) {
        await unregisterImage(icon);
        return;
      }
      _stopIcon = icon;
      _drawnRoute = null;
      _scheduleRoute();
      for (final tram in [true, false]) {
        final atlas = await TransitVehicleModel.atlas(tram: tram);
        if (!mounted) {
          for (final image in atlas.values) {
            await unregisterImage(image);
          }
          return;
        }
        _atlases[tram] = atlas;
        _vehicles.setImages(_atlases[_transit.line.isTram] ?? {});
        _syncVehicles();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _mapError = 'Prikaz vozila trenutno nije dostupan');
      }
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final routeChanged = !identical(_lastRoute, _transit.route);
    if (routeChanged) {
      _lastRoute = _transit.route;
      _scheduleRoute();
    }
    if (_lastVehicleRevision != _transit.vehicleRevision ||
        _lastFresh != _transit.fleetFresh ||
        _lastActive != _transit.active ||
        routeChanged) {
      _syncVehicles();
    }
  }

  void _syncVehicles() {
    _lastVehicleRevision = _transit.vehicleRevision;
    _lastFresh = _transit.fleetFresh;
    _lastActive = _transit.active;
    _vehicles.setImages(_atlases[_transit.line.isTram] ?? {});
    _vehicles.update(
      path: _transit.path,
      vehicles: _transit.vehicles,
      observedAt: _transit.fleetReceivedAt ?? _transit.now(),
      isFresh: _transit.fleetFresh,
      isActive: _transit.active,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _transit.setActive(state == AppLifecycleState.resumed);

  Future<void> _mapCreated(GoogleNavigationViewController map) async {
    _map = map;
    _vehicles.attach(map);
    try {
      if (_style != null) await map.setMapStyle(_style!);
      if (!mounted) return;
      await map.setMyLocationEnabled(
        context.read<BslLocationContext>().hasLocation,
      );
      if (!mounted) return;
      await map.setPadding(
        EdgeInsets.fromLTRB(
          12,
          MediaQuery.paddingOf(context).top + 166,
          12,
          210,
        ),
      );
      _drawnRoute = null;
      _scheduleRoute();
      _syncVehicles();
    } catch (_) {
      if (mounted) setState(() => _mapError = 'Mapa trenutno nije dostupna');
    }
  }

  void _scheduleRoute() {
    _pending = true;
    if (!_syncing) unawaited(_syncRoute());
  }

  Future<void> _syncRoute() async {
    _syncing = true;
    try {
      while (_pending && mounted && _map != null) {
        _pending = false;
        final map = _map!, route = _transit.route;
        if (identical(route, _drawnRoute) && _stops.isNotEmpty) continue;
        if (_stops.isNotEmpty) await map.removeMarkers(_stops);
        if (_lines.isNotEmpty) await map.removePolylines(_lines);
        _stops = [];
        _lines = [];
        _stopMarkers.clear();
        if (route == null) {
          _drawnRoute = null;
          continue;
        }
        final markers = await map.addMarkers([
          for (final stop in route.stops)
            MarkerOptions(
              position: _latLng(stop.point),
              icon: _stopIcon ?? ImageDescriptor.defaultImage,
              consumeTapEvents: true,
              anchor: const MarkerAnchor(u: .5, v: .5),
              zIndex: 1,
            ),
        ]);
        if (!mounted) return;
        _stops = markers.whereType<Marker>().toList();
        for (var i = 0; i < markers.length && i < route.stops.length; i++) {
          final marker = markers[i];
          if (marker != null) _stopMarkers[marker.markerId] = route.stops[i];
        }
        final lines = await map.addPolylines([
          PolylineOptions(
            points: route.points.map(_latLng).toList(),
            strokeColor: BslColors.cyan.withValues(alpha: .75),
            strokeWidth: 4,
          ),
        ]);
        _lines = lines.whereType<Polyline>().toList();
        _drawnRoute = route;
        var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
        for (final p in route.points) {
          if (p.latitude < south) south = p.latitude;
          if (p.latitude > north) north = p.latitude;
          if (p.longitude < west) west = p.longitude;
          if (p.longitude > east) east = p.longitude;
        }
        await map.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(latitude: south, longitude: west),
              northeast: LatLng(latitude: north, longitude: east),
            ),
            padding: 24,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _mapError = 'Mapa trenutno nije osvježena');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _focus(TransitPoint point) async {
    try {
      await _map?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _latLng(point), zoom: 15.5, tilt: 40),
        ),
      );
    } catch (_) {}
  }

  void _markerTap(String id) {
    final trip = _vehicles.tripForMarker(id);
    if (trip != null) {
      unawaited(_transit.selectVehicle(trip));
      final point = _transit.selectedVehicle?.point;
      if (point != null) unawaited(_focus(point));
      return;
    }
    final stop = _stopMarkers[id];
    if (stop != null) {
      unawaited(_transit.selectStop(stop));
      unawaited(_focus(stop.point));
    }
  }

  Future<void> _nearest() async {
    final location = context.read<BslLocationContext>();
    if (location.shouldOpenSettings) {
      await location.openRelevantSettings();
      return;
    }
    await location.refresh();
    if (!mounted) return;
    final p = location.location, route = _transit.route;
    if (p == null || route == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(location.statusMessage)));
      return;
    }
    final point = TransitPoint(p.latitude, p.longitude);
    final stops = [...route.stops]
      ..sort(
        (a, b) =>
            a.point.distanceTo(point).compareTo(b.point.distanceTo(point)),
      );
    if (stops.isEmpty) return;
    await _transit.selectStop(stops.first);
    if (!mounted) return;
    try {
      await _map?.setMyLocationEnabled(true);
    } catch (_) {}
    await _focus(stops.first.point);
  }

  Future<void> _chooseStop() async {
    final stops = _transit.route?.stops;
    if (stops == null) return;
    final selected = await showModalBottomSheet<TransitStop>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BslColors.bgDark,
      builder: (_) => _StopPicker(stops: stops),
    );
    if (selected != null && mounted) {
      unawaited(_transit.selectStop(selected));
      unawaited(_focus(selected.point));
    }
  }

  void _timetable() => unawaited(
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BslColors.bgDark,
      builder: (_) => _TimetableSheet(controller: _transit),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transit.removeListener(_changed);
    _vehicles.dispose();
    if (widget.controller == null) _transit.dispose();
    for (final atlas in _atlases.values) {
      for (final image in atlas.values) {
        unawaited(unregisterImage(image));
      }
    }
    final stopIcon = _stopIcon;
    if (stopIcon != null) unawaited(unregisterImage(stopIcon));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<BslLocationContext>();
    final selected = _transit.selectedVehicle;
    final arrival = selected == null
        ? _transit.selectedStationArrival
        : (_transit.nextFresh ? _transit.nextArrival : null);
    final next = selected != null;
    final station = next ? _transit.nextStop : _transit.stop;
    final status = _transit.liveStatus;
    return Scaffold(
      backgroundColor: BslColors.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.mapBuilder?.call(context) ??
              GoogleMapsNavigationView(
                onViewCreated: (map) => unawaited(_mapCreated(map)),
                initialCameraPosition: const CameraPosition(
                  target: LatLng(latitude: 43.86, longitude: 18.38),
                  zoom: 12,
                  tilt: 40,
                ),
                initialNavigationUIEnabledPreference:
                    NavigationUIEnabledPreference.disabled,
                initialMapColorScheme: MapColorScheme.dark,
                initialMapToolbarEnabled: false,
                initialZoomControlsEnabled: false,
                initialRotateGesturesEnabled: false,
                initialTiltGesturesEnabled: false,
                onMarkerClicked: _markerTap,
              ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                14,
                MediaQuery.paddingOf(context).top + 8,
                14,
                10,
              ),
              decoration: BslDecorations.glassCard(radius: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Nazad',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Gradski prevoz',
                          style: BslTextStyles.body,
                        ),
                      ),
                      Icon(
                        _transit.fleetFresh ? Icons.sensors : Icons.sensors_off,
                        color: _transit.fleetFresh
                            ? BslColors.success
                            : BslColors.textSecondary,
                        size: 18,
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Više',
                        color: BslColors.bgDark,
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'refresh',
                            child: Text('Osvježi'),
                          ),
                          const PopupMenuItem(
                            value: 'timetable',
                            child: Text('Red vožnje'),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'timetable') {
                            _timetable();
                          } else if (_transit.routeError != null) {
                            unawaited(_transit.selectLine(_transit.line));
                          } else {
                            unawaited(_transit.refreshArrivals());
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      for (final line in TransitLine.supported.reversed)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: ChoiceChip(
                              showCheckmark: false,
                              selected: line.id == _transit.line.id,
                              selectedColor: BslColors.glassBlue,
                              backgroundColor: BslColors.bgDark,
                              avatar: Icon(
                                line.isTram ? Icons.tram : Icons.directions_bus,
                                color: TransitVehicleModel.yellow,
                                size: 18,
                              ),
                              label: Text(
                                '${line.isTram ? 'Tramvaj' : 'Trolejbus'} ${line.code}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BslTextStyles.body.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                              onSelected: (_) =>
                                  unawaited(_transit.selectLine(line)),
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
                        isDense: true,
                        dropdownColor: BslColors.bgDark,
                        style: BslTextStyles.subtitle.copyWith(
                          color: Colors.white,
                        ),
                        iconEnabledColor: BslColors.cyan,
                        items: [
                          for (final d in _transit.directions)
                            DropdownMenuItem(
                              value: d.id,
                              child: Text(
                                d.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (id) {
                          if (id != null) {
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
                  if (_transit.loading)
                    const LinearProgressIndicator(
                      color: BslColors.cyan,
                      minHeight: 2,
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 230,
            child: BslMapLocationButton(
              isLoading: location.isLoading,
              hasLocation: location.hasLocation,
              needsAttention: location.shouldOpenSettings,
              onTap: () => unawaited(_nearest()),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BslDecorations.glassCard(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (next)
                      Row(
                        children: [
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: CustomPaint(
                              painter: _VehiclePreview(
                                tram: _transit.line.isTram,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_transit.line.isTram ? 'Tramvaj' : 'Trolejbus'} ${_transit.line.code}',
                              style: BslTextStyles.body,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Zatvori vozilo',
                            onPressed: _transit.clearVehicle,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: next ? null : () => unawaited(_chooseStop()),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  next
                                      ? 'Sljedeća stanica'
                                      : 'Dolazak na stanicu',
                                  style: BslTextStyles.subtitle,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  station?.name ??
                                      (next
                                          ? 'Krajnja stanica / podatak nije dostupan'
                                          : 'Odaberi stanicu'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: BslTextStyles.body.copyWith(
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          arrival == null
                              ? (_transit.nextLoading && next ? '…' : '—')
                              : _eta(arrival, _transit.now()),
                          style: const TextStyle(
                            color: TransitVehicleModel.yellow,
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (next && arrival == null && !_transit.nextLoading)
                      const Text(
                        'Vrijeme dolaska trenutno nije dostupno',
                        style: BslTextStyles.subtitle,
                      ),
                    if (status.isNotEmpty)
                      Text(status, style: BslTextStyles.subtitle)
                    else if (!next)
                      const Text(
                        'Dodirni vozilo za sljedeću stanicu',
                        style: BslTextStyles.subtitle,
                      ),
                    if (_mapError != null)
                      Text(_mapError!, style: BslTextStyles.subtitle),
                    if (!next)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => unawaited(_chooseStop()),
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('Promijeni stanicu'),
                        ),
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

String _eta(TransitArrival arrival, DateTime now) {
  final minutes = arrival.minutesFrom(now);
  return minutes == 0 ? 'Stiže' : '≈ $minutes min';
}

class _VehiclePreview extends CustomPainter {
  final bool tram;
  const _VehiclePreview({required this.tram});
  @override
  void paint(Canvas canvas, Size size) =>
      TransitVehicleModel.paint(canvas, size, tram: tram, bearing: 55);
  @override
  bool shouldRepaint(_VehiclePreview old) => old.tram != tram;
}

class _StopPicker extends StatefulWidget {
  final List<TransitStop> stops;
  const _StopPicker({required this.stops});
  @override
  State<_StopPicker> createState() => _StopPickerState();
}

class _StopPickerState extends State<_StopPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .6,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              style: BslTextStyles.body,
              onChanged: (value) =>
                  setState(() => query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Pretraži stanice',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (!widget.stops.any(
                  (s) => s.name.toLowerCase().contains(query),
                ))
                  const ListTile(
                    title: Text(
                      'Nema stanica za ovu pretragu.',
                      style: BslTextStyles.body,
                    ),
                  ),
                for (final stop in widget.stops.where(
                  (s) => s.name.toLowerCase().contains(query),
                ))
                  ListTile(
                    leading: const Icon(
                      Icons.trip_origin,
                      color: BslColors.cyan,
                    ),
                    title: Text(stop.name, style: BslTextStyles.body),
                    onTap: () => Navigator.pop(context, stop),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
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
