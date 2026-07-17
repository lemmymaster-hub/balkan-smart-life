import 'package:bsl_app/core/navigation/bsl_navigation_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BSL odredište čuva neutralne podatke za sve module', () {
    const destination = BslNavigationDestination(
      id: 'osm_node_123',
      title: 'EL punjač Sarajevo',
      latitude: 43.8563,
      longitude: 18.4131,
    );

    expect(destination.id, 'osm_node_123');
    expect(destination.title, 'EL punjač Sarajevo');
    expect(destination.latitude, 43.8563);
    expect(destination.longitude, 18.4131);
  });
}
