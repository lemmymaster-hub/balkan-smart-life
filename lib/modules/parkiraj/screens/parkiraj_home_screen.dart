import 'package:flutter/material.dart';
import 'parking_map_screen.dart';

class ParkirajHomeScreen extends StatelessWidget {
  final String city;
  final String? initialSearchQuery;
  final bool selectNearestOnOpen;
  final bool useCurrentLocationOnOpen;

  const ParkirajHomeScreen({
    super.key,
    required this.city,
    this.initialSearchQuery,
    this.selectNearestOnOpen = false,
    this.useCurrentLocationOnOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ParkingMapScreen(
      city: city,
      initialSearchQuery: initialSearchQuery,
      selectNearestOnOpen: selectNearestOnOpen,
      useCurrentLocationOnOpen: useCurrentLocationOnOpen,
    );
  }
}
