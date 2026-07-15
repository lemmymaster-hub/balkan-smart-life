import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class BslLocationResult {
  final double latitude;
  final double longitude;
  final String city;
  final String municipality;
  final String country;

  const BslLocationResult({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.municipality,
    required this.country,
  });
}

class BslLocationService {
  Future<BslLocationResult> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const BslLocationException(
        'Lokacijske usluge su isključene na uređaju.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const BslLocationException(
        'Dozvola za lokaciju nije odobrena.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const BslLocationException(
        'Dozvola za lokaciju je trajno odbijena. Omogući je u postavkama uređaja.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    final placemark = placemarks.isNotEmpty ? placemarks.first : null;

    return BslLocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      city: _firstNotEmpty([
        placemark?.locality,
        placemark?.subAdministrativeArea,
        placemark?.administrativeArea,
      ]),
      municipality: _firstNotEmpty([
        placemark?.subLocality,
        placemark?.locality,
        placemark?.subAdministrativeArea,
      ]),
      country: placemark?.country?.trim() ?? '',
    );
  }

  String _firstNotEmpty(List<String?> values) {
    for (final value in values) {
      final normalizedValue = value?.trim() ?? '';

      if (normalizedValue.isNotEmpty) {
        return normalizedValue;
      }
    }

    return 'Nepoznata lokacija';
  }
}

class BslLocationException implements Exception {
  final String message;

  const BslLocationException(this.message);

  @override
  String toString() => message;
}