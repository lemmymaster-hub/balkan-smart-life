import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../models/address_search_result.dart';

class AddressGeocodingService {
  const AddressGeocodingService();

  Future<AddressSearchResult?> searchAddress({
    required String input,
    String? city,
    String country = 'Bosnia and Herzegovina',
  }) async {
    final query = input.trim();

    if (query.length < 2) return null;

    final normalizedCity = city?.trim() ?? '';
    final candidates = <String>{
      [
        query,
        if (normalizedCity.isNotEmpty) normalizedCity,
        country,
      ].join(', '),
      [query, country].join(', '),
    };
    PlatformException? lastError;

    for (final address in candidates) {
      try {
        final locations = await locationFromAddress(address);

        if (locations.isEmpty) continue;

        final location = locations.first;

        return AddressSearchResult(
          label: query,
          location: LatLng(
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        );
      } on PlatformException catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw AddressGeocodingException(
        lastError.message ?? 'Pretraga adrese trenutno nije dostupna.',
      );
    }

    return null;
  }
}

class AddressGeocodingException implements Exception {
  final String message;

  const AddressGeocodingException(this.message);

  @override
  String toString() => message;
}
