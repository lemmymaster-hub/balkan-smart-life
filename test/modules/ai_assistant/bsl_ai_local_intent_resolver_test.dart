import 'package:bsl_app/modules/ai_assistant/models/bsl_ai_action.dart';
import 'package:bsl_app/modules/ai_assistant/models/bsl_ai_request_context.dart';
import 'package:bsl_app/modules/ai_assistant/services/bsl_ai_local_intent_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = BslAiLocalIntentResolver();
  const sarajevoContext = BslAiRequestContext(
    city: 'Sarajevo',
    latitude: 43.8563,
    longitude: 18.4131,
  );

  test('parking kod bolnice pretvara u akciju za Parkiraj.ba', () {
    final answer = resolver.resolve(
      question: 'Pronađi mi parking u blizini bolnice',
      context: sarajevoContext,
    );

    expect(answer, isNotNull);
    expect(answer!.action?.type, BslAiActionType.openParking);
    expect(answer.action?.city, 'Sarajevo');
    expect(answer.action?.query, 'bolnica');
    expect(answer.action?.selectNearest, isTrue);
  });

  test('grad iz pitanja ima prednost nad gradom početnog ekrana', () {
    final answer = resolver.resolve(
      question: 'Pronađi parking kod aerodroma u Mostaru',
      context: sarajevoContext,
    );

    expect(answer?.city, 'Mostar');
    expect(answer?.action?.city, 'Mostar');
    expect(answer?.action?.query, 'aerodrom');
  });

  test('prepoznaje punjač i vremensku prognozu', () {
    final chargerAnswer = resolver.resolve(
      question: 'Nađi najbliži punjač',
      context: sarajevoContext,
    );
    final weatherAnswer = resolver.resolve(
      question: 'Kakvo je vrijeme u Trebinju?',
      context: sarajevoContext,
    );

    expect(chargerAnswer?.action?.type, BslAiActionType.openEvChargers);
    expect(chargerAnswer?.action?.selectNearest, isTrue);
    expect(weatherAnswer?.action?.type, BslAiActionType.openWeather);
    expect(weatherAnswer?.action?.city, 'Trebinje');
  });

  test('prepoznaje padeže u vremenskoj komandi i nazivu grada', () {
    final answer = resolver.resolve(
      question: 'Otvori vremensku prognozu za Tuzlu',
      context: sarajevoContext,
    );

    expect(answer?.action?.type, BslAiActionType.openWeather);
    expect(answer?.action?.city, 'Tuzla');
  });

  test('moja lokacija koristi GPS bez slanja fraze geokoderu', () {
    final answer = resolver.resolve(
      question: 'Nađi mi EL punjač blizu moje lokacije',
      context: sarajevoContext,
    );

    expect(answer?.action?.type, BslAiActionType.openEvChargers);
    expect(answer?.action?.query, isNull);
    expect(answer?.action?.selectNearest, isTrue);
    expect(answer?.action?.useCurrentLocation, isTrue);
  });

  test('ne glumi preciznost kada GPS lokacija nije dostupna', () {
    final answer = resolver.resolve(
      question: 'Nađi parking blizu moje lokacije',
      context: const BslAiRequestContext(city: 'Sarajevo'),
    );

    expect(answer?.action, isNull);
    expect(answer?.answer, contains('GPS položaj nije dostupan'));
  });

  test('ne pokušava lokalno odgovoriti na opšte pitanje', () {
    final answer = resolver.resolve(
      question: 'Ko je napisao Na Drini ćuprija?',
      context: sarajevoContext,
    );

    expect(answer, isNull);
  });
}
