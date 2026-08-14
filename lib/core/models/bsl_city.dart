import 'dart:math' as math;

import 'bsl_administrative_area.dart';

class BslCity {
  final String name;
  final double latitude;
  final double longitude;
  final double mapZoom;

  const BslCity({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.mapZoom = 13.5,
  });
}

abstract final class BslCities {
  static const BslCity pale = BslCity(
    name: 'Pale',
    latitude: 43.8161,
    longitude: 18.5695,
  );

  static const BslCity bosniaAndHerzegovina = BslCity(
    name: 'Bosna i Hercegovina',
    latitude: 44.15,
    longitude: 17.68,
    mapZoom: 7.2,
  );

  static const List<BslCity> values = [
    BslCity(name: 'Sarajevo', latitude: 43.8563, longitude: 18.4131),
    BslCity(name: 'Banja Luka', latitude: 44.7722, longitude: 17.1910),
    BslCity(name: 'Mostar', latitude: 43.3438, longitude: 17.8078),
    BslCity(name: 'Tuzla', latitude: 44.5384, longitude: 18.6671),
    BslCity(name: 'Zenica', latitude: 44.2034, longitude: 17.9077),
    BslCity(name: 'Bihać', latitude: 44.8169, longitude: 15.8708),
    BslCity(name: 'Trebinje', latitude: 42.7119, longitude: 18.3436),
    pale,
    BslCity(name: 'Istočno Sarajevo', latitude: 43.8210, longitude: 18.3610),
  ];

  static final Map<String, BslCity> _resolvedCities = <String, BslCity>{};

  static void cacheResolvedCity(BslCity city) {
    _resolvedCities[normalize(city.name)] = city;
  }

  static BslCity byName(String? name) {
    final input = name ?? '';
    final exact = findExact(input);
    if (exact != null) return exact;

    final administrativeArea = BslAdministrativeAreas.findExact(input);
    if (administrativeArea != null) {
      return BslCity(
        name: administrativeArea.displayName,
        latitude: bosniaAndHerzegovina.latitude,
        longitude: bosniaAndHerzegovina.longitude,
        mapZoom: bosniaAndHerzegovina.mapZoom,
      );
    }

    return pale;
  }

  static BslCity? findExact(String input) {
    final normalizedInput = normalize(input);

    for (final city in values) {
      if (normalize(city.name) == normalizedInput) return city;
    }

    return _resolvedCities[normalizedInput];
  }

  static BslCity? findMentionedIn(String input) {
    final normalizedInput = ' ${normalize(input)} ';
    final citiesByLongestName = <BslCity>[
      ...values,
      ..._resolvedCities.values,
    ]..sort((a, b) => b.name.length.compareTo(a.name.length));

    final seen = <String>{};
    for (final city in citiesByLongestName) {
      final normalizedCity = normalize(city.name);
      if (!seen.add(normalizedCity)) continue;
      if (normalizedInput.contains(' $normalizedCity ')) return city;
    }

    return null;
  }

  static bool same(String first, String second) {
    return normalize(first) == normalize(second);
  }

  static BslCity nearestTo({
    required double latitude,
    required double longitude,
  }) {
    final candidates = <BslCity>[...values, ..._resolvedCities.values];

    return candidates.reduce((closest, candidate) {
      final closestDistance = distanceInKilometers(
        fromLatitude: latitude,
        fromLongitude: longitude,
        toLatitude: closest.latitude,
        toLongitude: closest.longitude,
      );
      final candidateDistance = distanceInKilometers(
        fromLatitude: latitude,
        fromLongitude: longitude,
        toLatitude: candidate.latitude,
        toLongitude: candidate.longitude,
      );

      return candidateDistance < closestDistance ? candidate : closest;
    });
  }

  static double distanceInKilometers({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) {
    const earthRadiusKilometers = 6371.0;
    final latitudeDelta = _toRadians(toLatitude - fromLatitude);
    final longitudeDelta = _toRadians(toLongitude - fromLongitude);
    final fromLatitudeRadians = _toRadians(fromLatitude);
    final toLatitudeRadians = _toRadians(toLatitude);

    final haversine =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(fromLatitudeRadians) *
            math.cos(toLatitudeRadians) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    final normalizedHaversine = haversine.clamp(0.0, 1.0).toDouble();

    return earthRadiusKilometers *
        2 *
        math.atan2(
          math.sqrt(normalizedHaversine),
          math.sqrt(1 - normalizedHaversine),
        );
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  static String normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('š', 's')
        .replaceAll('ž', 'z')
        .replaceAll('đ', 'dj')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }
}
