import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceSearchResult {
  final String placeId;
  final String title;
  final String description;
  final LatLng location;

  const PlaceSearchResult({
    required this.placeId,
    required this.title,
    required this.description,
    required this.location,
  });

  factory PlaceSearchResult.fromJson(
    Map<String, dynamic> json,
    LatLng location,
  ) {
    return PlaceSearchResult(
      placeId: json['place_id'] ?? '',
      title: json['structured_formatting']?['main_text'] ??
          json['description'] ??
          '',
      description:
          json['structured_formatting']?['secondary_text'] ?? '',
      location: location,
    );
  }
}