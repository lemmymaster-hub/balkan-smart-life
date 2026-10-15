import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/transit_models.dart';
import '../models/transit_route_path.dart';
import '../services/transit_service.dart';

class TransitController extends ChangeNotifier {
  final TransitGateway gateway;
  final DateTime Function() now;
  TransitController({TransitGateway? gateway, DateTime Function()? now})
    : gateway = gateway ?? MinistryTransitService(),
      now = now ?? DateTime.now;

  // Start with tram 3, the first service for which live predictions were verified.
  TransitLine line = TransitLine.supported.last;
  List<TransitDirection> directions = const [];
  TransitDirection? direction;
  TransitRoute? route;
  TransitRoutePath? path;
  TransitStop? stop;
  List<TransitArrival> _arrivals = const [];
  List<TransitArrival> _fleet = const [];
  List<TransitDeparture> departures = const [];
  DateTime? receivedAt;
  DateTime? fleetReceivedAt;
  DateTime? timetableReceivedAt;
  String? routeError;
  String? arrivalError;
  String? timetableError;
  bool loading = false;
  bool refreshing = false;
  bool active = true;
  int vehicleRevision = 0;
  int? selectedTripId;
  TransitStop? nextStop;
  TransitArrival? nextArrival;
  DateTime? nextReceivedAt;
  bool nextLoading = false;
  bool _disposed = false;
  int _generation = 0, _stopGeneration = 0, _nextGeneration = 0;
  Timer? _timer, _clock;

  bool _recent(DateTime? time) =>
      time != null && now().difference(time) < const Duration(seconds: 20);
  bool get fresh => arrivalError == null && _recent(receivedAt);
  bool get fleetFresh => arrivalError == null && _recent(fleetReceivedAt);
  bool get nextFresh => fleetFresh && _recent(nextReceivedAt);

  List<TransitArrival> _filter(List<TransitArrival> rows) {
    final current = route;
    if (current == null || current.stops.isEmpty) return const [];
    return selectTransitArrivals(
      rows,
      lineId: line.id,
      destinationId: current.stops.last.id,
      now: now(),
    );
  }

  List<TransitArrival> get arrivals => fresh ? _filter(_arrivals) : const [];
  List<TransitArrival> get vehicles {
    // A single GPS position may be attached to several future travel orders.
    // Do not stack multiple apparent vehicles at the exact same observation.
    final positions = <String, TransitArrival>{};
    for (final row in _filter(_fleet)) {
      final p = row.point;
      if (p == null) continue;
      final key =
          '${p.latitude.toStringAsFixed(5)}:${p.longitude.toStringAsFixed(5)}';
      positions.putIfAbsent(key, () => row);
    }
    return positions.values.toList();
  }

  TransitArrival? get selectedVehicle {
    for (final vehicle in vehicles) {
      if (vehicle.tripId == selectedTripId) return vehicle;
    }
    return null;
  }

  TransitArrival? get selectedStationArrival {
    if (selectedTripId == null) return arrivals.isEmpty ? null : arrivals.first;
    for (final arrival in arrivals) {
      if (arrival.tripId == selectedTripId) return arrival;
    }
    return null;
  }

  String get liveStatus {
    if (routeError != null) return routeError!;
    if (arrivalError != null || (fleetReceivedAt != null && !fleetFresh)) {
      return 'Podaci se trenutno ne osvježavaju';
    }
    if (loading || (refreshing && receivedAt == null)) return 'Učitavam…';
    return vehicles.isEmpty ? 'Trenutno nema podataka o vozilima' : '';
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int token) => !_disposed && token == _generation;

  Future<void> start() async {
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      if (active) unawaited(refreshArrivals());
    });
    _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (active) _emit();
    });
    await selectLine(line);
  }

  void setActive(bool value) {
    active = value;
    _emit();
    if (value) unawaited(refreshArrivals());
  }

  Future<void> selectLine(TransitLine value) async {
    final token = ++_generation;
    _stopGeneration++;
    line = value;
    directions = const [];
    direction = null;
    _clearRoute();
    loading = true;
    _emit();
    try {
      final list = await gateway.directions(value);
      if (!_current(token)) return;
      if (list.isEmpty) throw const FormatException('No directions');
      directions = list;
      await selectDirection(list.first);
    } catch (_) {
      if (!_current(token)) return;
      routeError = 'Linija trenutno nije dostupna. Pokušaj ponovo.';
      loading = false;
      _emit();
    }
  }

  void _clearRoute() {
    route = null;
    path = null;
    stop = null;
    _arrivals = const [];
    _fleet = const [];
    departures = const [];
    receivedAt = null;
    fleetReceivedAt = null;
    timetableReceivedAt = null;
    routeError = null;
    arrivalError = null;
    timetableError = null;
    refreshing = false;
    clearVehicle(emit: false);
    vehicleRevision++;
  }

  Future<void> selectDirection(TransitDirection value) async {
    final token = ++_generation;
    _stopGeneration++;
    direction = value;
    _clearRoute();
    loading = true;
    _emit();
    unawaited(_loadTimetable(token, line, value));
    try {
      final loaded = await gateway.route(value);
      if (!_current(token)) return;
      route = loaded;
      path = TransitRoutePath(loaded);
      stop = loaded.stops.first;
      loading = false;
      _emit();
      await refreshArrivals();
    } catch (_) {
      if (!_current(token)) return;
      routeError = 'Trasa trenutno nije dostupna. Pokušaj ponovo.';
      loading = false;
      _emit();
    }
  }

  Future<void> _loadTimetable(
    int token,
    TransitLine selectedLine,
    TransitDirection selectedDirection,
  ) async {
    try {
      final loaded = await gateway.timetable(selectedLine, selectedDirection);
      if (!_current(token)) return;
      departures = loaded;
      timetableReceivedAt = now();
    } catch (_) {
      if (!_current(token)) return;
      timetableError = 'Red vožnje trenutno nije dostupan.';
    }
    _emit();
  }

  Future<void> selectStop(TransitStop value) async {
    if (route?.stops.any((s) => s.id == value.id) != true) return;
    _stopGeneration++;
    stop = value;
    _arrivals = const [];
    receivedAt = null;
    arrivalError = null;
    refreshing = false;
    clearVehicle(emit: false);
    _emit();
    await refreshArrivals();
  }

  void clearVehicle({bool emit = true}) {
    _nextGeneration++;
    selectedTripId = null;
    nextStop = null;
    nextArrival = null;
    nextReceivedAt = null;
    nextLoading = false;
    if (emit) _emit();
  }

  Future<void> selectVehicle(int tripId) async {
    if (!vehicles.any((v) => v.tripId == tripId)) return;
    selectedTripId = tripId;
    nextArrival = null;
    nextReceivedAt = null;
    _emit();
    await _refreshNextStop();
  }

  Future<void> _refreshNextStop() async {
    final vehicle = selectedVehicle;
    final currentDirection = direction;
    final position = vehicle?.point;
    final target = position == null ? null : path?.nextStop(position);
    final token = ++_nextGeneration;
    if (nextStop?.id != target?.id) {
      nextArrival = null;
      nextReceivedAt = null;
    }
    nextStop = target;
    if (vehicle == null ||
        target == null ||
        currentDirection == null ||
        !fleetFresh) {
      nextLoading = false;
      _emit();
      return;
    }
    nextLoading = true;
    _emit();
    final generation = _generation;
    bool current() =>
        _current(generation) &&
        token == _nextGeneration &&
        selectedTripId == vehicle.tripId;
    try {
      final rows = await gateway.arrivals(line, currentDirection, target);
      if (!current()) return;
      final matches = _filter(rows).where((a) => a.tripId == vehicle.tripId);
      nextArrival = matches.isEmpty ? null : matches.first;
      nextReceivedAt = now();
    } catch (_) {
      if (!current()) return;
      nextArrival = null;
    } finally {
      if (current()) {
        nextLoading = false;
        _emit();
      }
    }
  }

  Future<void> refreshArrivals() async {
    if (_disposed ||
        !active ||
        refreshing ||
        loading ||
        stop == null ||
        direction == null ||
        route == null) {
      return;
    }
    final token = _generation, stopToken = _stopGeneration;
    final selectedStop = stop!,
        selectedDirection = direction!,
        selectedLine = line;
    final terminal = route!.stops.last;
    refreshing = true;
    _emit();
    bool current() => _current(token) && stopToken == _stopGeneration;
    try {
      // Destination-terminal predictions discover vehicles along the complete
      // selected direction, independently of the user's chosen boarding stop.
      final fleetRequest = gateway.arrivals(
        selectedLine,
        selectedDirection,
        terminal,
      );
      final stationRequest = selectedStop.id == terminal.id
          ? fleetRequest
          : gateway.arrivals(selectedLine, selectedDirection, selectedStop);
      final results = await Future.wait([fleetRequest, stationRequest]);
      if (!current()) return;
      _fleet = results[0];
      _arrivals = results[1];
      receivedAt = now();
      fleetReceivedAt = receivedAt;
      arrivalError = null;
      vehicleRevision++;
      if (selectedTripId != null && selectedVehicle == null)
        clearVehicle(emit: false);
      _emit();
      if (selectedTripId != null) await _refreshNextStop();
    } catch (_) {
      if (!current()) return;
      arrivalError = 'Dolasci trenutno nisu dostupni.';
      nextArrival = null;
      nextReceivedAt = null;
      vehicleRevision++;
    } finally {
      if (current()) {
        refreshing = false;
        _emit();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _nextGeneration++;
    _timer?.cancel();
    _clock?.cancel();
    gateway.dispose();
    super.dispose();
  }
}
