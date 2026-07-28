import 'package:bsl_app/modules/ai_assistant/models/bsl_ai_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prihvata samo poznatu BSL akciju', () {
    final action = BslAiAction.tryFromJson({
      'type': 'open_parking',
      'label': 'Pronađi parking',
      'parameters': {
        'city': 'Sarajevo',
        'query': 'bolnica',
        'select_nearest': true,
        'use_current_location': true,
      },
    });

    expect(action, isNotNull);
    expect(action!.type, BslAiActionType.openParking);
    expect(action.city, 'Sarajevo');
    expect(action.query, 'bolnica');
    expect(action.selectNearest, isTrue);
    expect(action.useCurrentLocation, isTrue);
    expect(action.canExecuteAutomatically, isTrue);
  });

  test('odbacuje nepoznatu rutu koju pošalje backend', () {
    final action = BslAiAction.tryFromJson({
      'type': 'open_arbitrary_route',
      'parameters': {'route': '/admin'},
    });

    expect(action, isNull);
  });

  test('novčanik se ne otvara automatski', () {
    final action = BslAiAction(type: BslAiActionType.openWallet);

    expect(action.canExecuteAutomatically, isFalse);
  });
}
