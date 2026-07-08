import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/place_search_result.dart';

class GooglePlacesService {
  static const String _apiKey = 'AIzaSyAJhwGcnhYD5wQs41TY-RSfrfELp4p68nY';

  Future<List<PlaceSearchResult>> searchPlaces({
    required String input,
    String language = 'bs',
    String country = 'ba',
  }) async {
    final query = input.trim();

    if (query.length < 2) return [];

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
        'components': 'country:$country',
        'language': language,
        'key': _apiKey,
      },
    );

    final response = await http.get(uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || data['status'] != 'OK') {
      return [];
    }

    final predictions = (data['predictions'] as List?) ?? [];

    final results = <PlaceSearchResult>[];

    for (final item in predictions) {
      final prediction = item as Map<String, dynamic>;
      final placeId = prediction['place_id']?.toString() ?? '';

      if (placeId.isEmpty) continue;

      final details = await getPlaceDetails(
        placeId: placeId,
        language: language,
      );

      if (details != null) {
        results.add(
          PlaceSearchResult.fromJson(
            prediction,
            details,
          ),
        );
      }
    }

    return results;
  }

  Future<LatLng?> getPlaceDetails({
    required String placeId,
    String language = 'bs',
  }) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'geometry,name,formatted_address',
        'language': language,
        'key': _apiKey,
      },
    );

    final response = await http.get(uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || data['status'] != 'OK') {
      return null;
    }

    final location = data['result']?['geometry']?['location'];

    if (location == null) return null;

    return LatLng(
      (location['lat'] as num).toDouble(),
      (location['lng'] as num).toDouble(),
    );
  }
}