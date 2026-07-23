import 'package:bsl_app/modules/ai_assistant/models/bsl_ai_answer.dart';
import 'package:bsl_app/modules/ai_assistant/widgets/bsl_ai_ask_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('šalje pitanje za izabrani grad i prikazuje odgovor', (
    tester,
  ) async {
    String? capturedQuestion;
    String? capturedCity;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BslAiAskField(
            city: 'Pale',
            onAsk: ({
              required String question,
              required String city,
            }) async {
              capturedQuestion = question;
              capturedCity = city;
              return const BslAiAnswer(
                answer: 'BSL odgovor za Pale.',
                city: 'Pale',
                grounded: true,
                sources: [BslAiSource(title: 'Testni izvor')],
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Gdje je parking?');
    await tester.tap(find.byTooltip('Pošalji pitanje'));
    await tester.pumpAndSettle();

    expect(capturedQuestion, 'Gdje je parking?');
    expect(capturedCity, 'Pale');
    expect(find.text('BSL odgovor za Pale.'), findsOneWidget);
    expect(
      find.text('Odgovor potvrđen navedenim izvorima'),
      findsOneWidget,
    );
  });
}
