import 'package:bsl_app/modules/ai_assistant/controllers/bsl_ai_coordinator.dart';
import 'package:bsl_app/modules/ai_assistant/models/bsl_ai_action.dart';
import 'package:bsl_app/modules/ai_assistant/models/bsl_ai_request_context.dart';
import 'package:bsl_app/modules/ai_assistant/services/bsl_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lokalna BSL komanda radi i bez AI backenda', () async {
    final coordinator = BslAiCoordinator(
      remoteService: BslAiService(
        endpoint: null,
        idTokenProvider: () async => null,
      ),
    );

    final answer = await coordinator.ask(
      question: 'Otvori vremensku prognozu za Tuzlu',
      context: const BslAiRequestContext(city: 'Pale'),
    );

    expect(answer.action?.type, BslAiActionType.openWeather);
    expect(answer.city, 'Tuzla');

    coordinator.dispose();
  });

  test('bez backenda jasno opisuje trenutno podržane mogućnosti', () async {
    final coordinator = BslAiCoordinator(
      remoteService: BslAiService(
        endpoint: null,
        idTokenProvider: () async => null,
      ),
    );

    final answer = await coordinator.ask(
      question: 'Preporuči mi restoran',
      context: const BslAiRequestContext(city: 'Pale'),
    );

    expect(answer.action, isNull);
    expect(answer.answer, contains('sigurni BSL AI server'));

    coordinator.dispose();
  });
}
