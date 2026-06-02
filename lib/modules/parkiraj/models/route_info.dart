import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteInfo {
  final List<LatLng> points;
  final String duration;
  final String distance;

  RouteInfo({
    required this.points,
    required this.duration,
    required this.distance,
  });
}