import '../models/bsl_city.dart';

abstract final class BslNearestPlaceSelector {
  static T? find<T>({
    required Iterable<T> items,
    required double latitude,
    required double longitude,
    required double Function(T item) latitudeOf,
    required double Function(T item) longitudeOf,
    required double maxDistanceKilometers,
  }) {
    T? nearest;
    var nearestDistance = double.infinity;

    for (final item in items) {
      final distance = BslCities.distanceInKilometers(
        fromLatitude: latitude,
        fromLongitude: longitude,
        toLatitude: latitudeOf(item),
        toLongitude: longitudeOf(item),
      );
      if (distance < nearestDistance) {
        nearest = item;
        nearestDistance = distance;
      }
    }

    return nearestDistance <= maxDistanceKilometers ? nearest : null;
  }
}
