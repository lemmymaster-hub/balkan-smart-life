import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/transit_models.dart';
import '../services/transit_service.dart';

class TransitController extends ChangeNotifier {
  final TransitGateway gateway;
  final DateTime Function() now;
  TransitController({TransitGateway? gateway, DateTime Function()? now})
    : gateway = gateway ?? MinistryTransitService(),
      now = now ?? DateTime.now;

  TransitLine line = TransitLine.supported.first;
  List<TransitDirection> directions = const [];
  TransitDirection? direction;
  TransitRoute? route;
  TransitStop? stop;
  List<TransitArrival> _arrivals = const [];
  List<TransitDeparture> departures = const [];
  DateTime? receivedAt;
  DateTime? timetableReceivedAt;
  String? routeError;
  String? arrivalError;
  String? timetableError;
  bool loading = false;
  bool refreshing = false;
  bool active = true;
  bool _disposed = false;
  int _generation = 0;
  int _stopGeneration = 0;
  Timer? _timer;

  bool get fresh =>
      receivedAt != null &&
      arrivalError == null &&
      now().difference(receivedAt!) < const Duration(seconds: 60);
  List<TransitArrival> get arrivals {
    final currentRoute = route;
    if (!fresh || currentRoute == null || currentRoute.stops.isEmpty)
      return const [];
    return selectTransitArrivals(
      _arrivals,
      lineId: line.id,
      destinationId: currentRoute.stops.last.id,
      now: now(),
    );
  }

  String get liveStatus {
    if (arrivalError != null) return arrivalError!;
    if (refreshing && receivedAt == null) return 'Provjeravam dolaske…';
    if (receivedAt == null) return 'Odaberi stanicu za dolaske';
    if (!fresh) return 'Podaci o dolascima su zastarjeli';
    return arrivals.isEmpty
        ? 'Izvor trenutno nema dolazaka za ovaj smjer'
        : 'Procjene dolaska iz izvora';
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int token) => !_disposed && token == _generation;

  Future<void> start() async {
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (active) {
        _emit();
        unawaited(refreshArrivals());
      }
    });
    await selectLine(line);
  }

  void setActive(bool value) {
    active = value;
    if (value) {
      _emit();
      unawaited(refreshArrivals());
    }
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
      directions = list;
      if (list.isEmpty) throw const FormatException('No directions');
      await selectDirection(list.first);
    } catch (_) {
      if (!_current(token)) return;
      routeError =
          'Nije moguće učitati liniju. Provjeri vezu i pokušaj ponovo.';
      loading = false;
      _emit();
    }
  }

  void _clearRoute() {
    route = null;
    stop = null;
    _arrivals = const [];
    departures = const [];
    receivedAt = null;
    timetableReceivedAt = null;
    routeError = null;
    arrivalError = null;
    timetableError = null;
    refreshing = false;
  }

  Future<void> selectDirection(TransitDirection value) async {
    final token = ++_generation;
    _stopGeneration++;
    direction = value;
    _clearRoute();
    loading = true;
    _emit();
    // Timetable failure does not prevent displaying a valid route or live ETA.
    unawaited(_loadTimetable(token, line, value));
    try {
      final loaded = await gateway.route(value);
      if (!_current(token)) return;
      route = loaded;
      stop = loaded.stops.first;
      loading = false;
      _emit();
      await refreshArrivals();
    } catch (_) {
      if (!_current(token)) return;
      routeError = 'Stanice i trasa trenutno nisu dostupne. Pokušaj ponovo.';
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
    _emit();
    await refreshArrivals();
  }

  Future<void> refreshArrivals() async {
    if (_disposed ||
        !active ||
        refreshing ||
        loading ||
        stop == null ||
        direction == null)
      return;
    final token = _generation;
    final stopToken = _stopGeneration;
    final selectedStop = stop!;
    refreshing = true;
    _emit();
    bool current() => _current(token) && stopToken == _stopGeneration;
    try {
      final loaded = await gateway.arrivals(line, direction!, selectedStop);
      if (!current()) return;
      _arrivals = loaded;
      receivedAt = now();
      arrivalError = null;
    } catch (_) {
      if (!current()) return;
      _arrivals = const [];
      arrivalError = 'Dolasci trenutno nisu dostupni. Provjeri vezu.';
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
    _timer?.cancel();
    gateway.dispose();
    super.dispose();
  }
}
