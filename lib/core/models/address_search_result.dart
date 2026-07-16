import 'package:google_navigation_flutter/google_navigation_flutter.dart';

class AddressSearchResult {
  final String label;
  final LatLng location;

  const AddressSearchResult({required this.label, required this.location});
}
