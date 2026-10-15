import 'dart:async';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../models/transit_models.dart';
import '../models/transit_route_path.dart';
import '../widgets/transit_vehicle_model.dart';

/// Stable native markers; a batch of positions is updated at up to 20 FPS.
/// Route/stop controls never tear down and recreate moving vehicles.
class TransitVehicleLayer {
  GoogleNavigationViewController? _map;
  TransitRoutePath? _path;
  Map<int, ImageDescriptor> _images = {};
  List<TransitArrival> _desired = [];
  final _markers = <int, Marker>{};
  final _motions = <int, TransitVehicleMotion>{};
  final _markerTrips = <String, int>{};
  bool _closed = false, _syncing = false, _pending = false, _rendering = false;
  bool fresh = true, active = true;
  bool _resetMarkers = false, _needsFrame = false;
  int _generation = 0;
  Timer? _timer;
  DateTime Function() now;
  TransitVehicleLayer({DateTime Function()? now}) : now = now ?? DateTime.now;

  int? tripForMarker(String marker) => _markerTrips[marker];
  void attach(GoogleNavigationViewController map) {
    _map = map;
    _schedule();
  }

  void setImages(Map<int, ImageDescriptor> images) {
    _images = images;
    _needsFrame = true;
  }

  void update({
    required TransitRoutePath? path,
    required List<TransitArrival> vehicles,
    required DateTime observedAt,
    required bool isFresh,
    required bool isActive,
  }) {
    final changedRoute = !identical(_path, path);
    _path = path;
    _desired = List.of(vehicles);
    _needsFrame = true;
    fresh = isFresh;
    active = isActive;
    if (changedRoute) {
      _generation++;
      _resetMarkers = true;
      _motions.clear();
    }
    final geometry = _path;
    if (geometry != null) {
      for (final row in vehicles) {
        final point = row.point;
        if (point != null) {
          final motion = _motions.putIfAbsent(
            row.tripId,
            () => TransitVehicleMotion(geometry),
          );
          if (isFresh) motion.observe(point, observedAt);
        }
      }
    }
    _timer ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (active &&
          (_needsFrame ||
              (fresh && _motions.values.any((m) => m.moving(now()))))) {
        unawaited(_render(force: _needsFrame));
      }
    });
    _schedule();
  }

  ImageDescriptor? _image(double bearing) =>
      _images[TransitVehicleModel.viewIndex(bearing)];
  LatLng _position(TransitPoint p) =>
      LatLng(latitude: p.latitude, longitude: p.longitude);

  void _schedule() {
    _pending = true;
    if (!_syncing) unawaited(_reconcile());
  }

  Future<void> _reconcile() async {
    _syncing = true;
    try {
      while (_pending && !_closed && _map != null) {
        _pending = false;
        final map = _map!;
        final wanted = _desired.map((v) => v.tripId).toSet();
        final reset = _resetMarkers;
        _resetMarkers = false;
        final removed = _markers.keys
            .where(
              (id) => reset || !wanted.contains(id) || _motions[id] == null,
            )
            .toList();
        if (removed.isNotEmpty) {
          await map.removeMarkers(removed.map((id) => _markers[id]!).toList());
          for (final id in removed) {
            _markerTrips.remove(_markers.remove(id)?.markerId);
            if (!wanted.contains(id)) _motions.remove(id);
          }
        }
        if (_closed || _images.isEmpty) continue;
        final generation = _generation;
        for (final row in List<TransitArrival>.of(_desired)) {
          if (_markers.containsKey(row.tripId)) continue;
          final motion = _motions[row.tripId];
          if (motion == null) continue;
          final pose = motion.pose(now());
          final image = _image(pose.bearing);
          if (image == null) continue;
          final result = await map.addMarkers([
            MarkerOptions(
              position: _position(pose.point),
              icon: image,
              anchor: const MarkerAnchor(u: .5, v: .57),
              consumeTapEvents: true,
              flat: false,
              zIndex: 20,
              alpha: fresh ? 1 : .4,
            ),
          ]);
          final marker = result.isEmpty ? null : result.first;
          if (marker == null) continue;
          if (_closed || generation != _generation) {
            await map.removeMarkers([marker]);
            continue;
          }
          _markers[row.tripId] = marker;
          _markerTrips[marker.markerId] = row.tripId;
        }
        await _render(force: true);
      }
    } on ViewNotFoundException {
      // Native view was disposed while an operation was pending.
    } catch (_) {
      // Prediction cards remain usable if a native map update fails.
    } finally {
      _syncing = false;
    }
  }

  Future<void> _render({bool force = false}) async {
    if (_closed ||
        _rendering ||
        (_syncing && !force) ||
        _map == null ||
        (!active && !force)) {
      return;
    }
    final generation = _generation;
    final updates = <Marker>[];
    final ids = <int>[];
    final time = now();
    for (final entry in _markers.entries) {
      final motion = _motions[entry.key];
      if (motion == null) continue;
      final pose = motion.pose(time);
      final image = _image(pose.bearing);
      if (image == null) continue;
      ids.add(entry.key);
      updates.add(
        entry.value.copyWith(
          options: entry.value.options.copyWith(
            position: _position(pose.point),
            icon: image,
            alpha: fresh ? 1 : .4,
          ),
        ),
      );
    }
    if (updates.isEmpty) return;
    _rendering = true;
    try {
      final results = await _map!.updateMarkers(updates);
      if (_closed || generation != _generation) return;
      _needsFrame = false;
      for (var i = 0; i < results.length && i < ids.length; i++) {
        final marker = results[i];
        if (marker != null && _markers.containsKey(ids[i])) {
          _markers[ids[i]] = marker;
        }
      }
    } on MarkerNotFoundException {
      // A route replacement will reconcile the marker set again.
    } on ViewNotFoundException {
      // Screen closed.
    } catch (_) {
      // Retry on a later observation; never leave an unhandled animation Future.
    } finally {
      _rendering = false;
    }
  }

  void dispose() {
    _closed = true;
    _generation++;
    _timer?.cancel();
    _markers.clear();
    _motions.clear();
    _markerTrips.clear();
    _map = null;
  }
}
