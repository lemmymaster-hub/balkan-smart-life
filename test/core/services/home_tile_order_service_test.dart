import 'package:bsl_app/core/services/home_tile_order_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const defaultIds = <String>[
    'parking',
    'ev_chargers',
    'public_transport',
    'taxi',
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('čuva i učitava raspored odvojeno za svakog korisnika', () async {
    final service = HomeTileOrderService();

    await service.saveOrder(
      userId: 'user-a',
      orderedIds: const <String>[
        'taxi',
        'parking',
        'ev_chargers',
        'public_transport',
      ],
      availableIds: defaultIds,
    );

    expect(
      await service.loadOrder(userId: 'user-a', availableIds: defaultIds),
      const <String>['taxi', 'parking', 'ev_chargers', 'public_transport'],
    );
    expect(
      await service.loadOrder(userId: 'user-b', availableIds: defaultIds),
      defaultIds,
    );
  });

  test('dodaje novi modul bez gubitka korisničkog rasporeda', () {
    final result = HomeTileOrderService.reconcileOrder(
      storedIds: const <String>['taxi', 'parking'],
      availableIds: const <String>['parking', 'ev_chargers', 'taxi'],
    );

    expect(result, const <String>['taxi', 'parking', 'ev_chargers']);
  });

  test('uklanja nepoznate i duplirane module', () {
    final result = HomeTileOrderService.reconcileOrder(
      storedIds: const <String>['taxi', 'obsolete', 'taxi', 'parking'],
      availableIds: defaultIds,
    );

    expect(result, const <String>[
      'taxi',
      'parking',
      'ev_chargers',
      'public_transport',
    ]);
  });

  test('reset vraća podrazumijevani raspored', () async {
    final service = HomeTileOrderService();

    await service.saveOrder(
      userId: 'user-a',
      orderedIds: const <String>[
        'taxi',
        'parking',
        'ev_chargers',
        'public_transport',
      ],
      availableIds: defaultIds,
    );
    await service.resetOrder(userId: 'user-a');

    expect(
      await service.loadOrder(userId: 'user-a', availableIds: defaultIds),
      defaultIds,
    );
  });
}
