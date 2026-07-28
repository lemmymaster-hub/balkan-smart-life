import 'package:bsl_app/core/services/bsl_nearest_place_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vraća najbliži rezultat unutar dozvoljenog radijusa', () {
    const places = [
      _Place('dalji', 43.8600, 18.4200),
      _Place('bliži', 43.8565, 18.4135),
    ];

    final nearest = BslNearestPlaceSelector.find(
      items: places,
      latitude: 43.8563,
      longitude: 18.4131,
      latitudeOf: (place) => place.latitude,
      longitudeOf: (place) => place.longitude,
      maxDistanceKilometers: 5,
    );

    expect(nearest?.id, 'bliži');
  });

  test('ne predstavlja udaljeni rezultat kao obližnji', () {
    const places = [_Place('Mostar', 43.3438, 17.8078)];

    final nearest = BslNearestPlaceSelector.find(
      items: places,
      latitude: 43.8563,
      longitude: 18.4131,
      latitudeOf: (place) => place.latitude,
      longitudeOf: (place) => place.longitude,
      maxDistanceKilometers: 8,
    );

    expect(nearest, isNull);
  });
}

class _Place {
  final String id;
  final double latitude;
  final double longitude;

  const _Place(this.id, this.latitude, this.longitude);
}
