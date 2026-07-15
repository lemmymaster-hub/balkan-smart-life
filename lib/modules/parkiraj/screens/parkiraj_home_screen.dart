import 'package:flutter/material.dart';
import 'parking_map_screen.dart';

class ParkirajHomeScreen extends StatelessWidget {
  final String city;

  const ParkirajHomeScreen({
    super.key,
    required this.city,
  });

  @override
  Widget build(BuildContext context) {
    return ParkingMapScreen(
      city: city,
    );
  }
}