import 'package:google_maps_flutter/google_maps_flutter.dart';

class AddressSearchResult {
  final String label;
  final LatLng location;

  const AddressSearchResult({
    required this.label,
    required this.location,
  });
}
