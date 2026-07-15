import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
    final scopedAddress = [
      query,
      if (normalizedCity.isNotEmpty) normalizedCity,
      country,
    ].join(', ');

    try {
      final locations = await locationFromAddress(scopedAddress);

      if (locations.isEmpty) return null;

      final location = locations.first;

      return AddressSearchResult(
        label: query,
        location: LatLng(location.latitude, location.longitude),
      );
    } on PlatformException catch (error) {
      throw AddressGeocodingException(
        error.message ?? 'Pretraga adrese trenutno nije dostupna.',
      );
    }
  }
}

class AddressGeocodingException implements Exception {
  final String message;

  const AddressGeocodingException(this.message);

  @override
  String toString() => message;
}
