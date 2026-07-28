import 'dart:convert';

import 'package:bsl_app/modules/ai_assistant/services/bsl_ai_service.dart';
import 'package:bsl_app/modules/ai_assistant/models/bsl_ai_action.dart';
import 'package:bsl_app/modules/ai_assistant/models/bsl_ai_request_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('šalje pitanje, grad i Firebase token te mapira izvore', () async {
    late http.Request capturedRequest;

    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'answer': 'Najbliži parking je Skenderija.',
          'city': 'Sarajevo',
          'grounded': true,
          'sources': [
            {
              'title': 'BSL parking podaci',
              'url': 'https://example.com/parking',
            },
          ],
          'request_id': 'req-1',
          'action': {
            'type': 'open_parking',
            'parameters': {
              'city': 'Sarajevo',
              'query': 'Skenderija',
              'select_nearest': true,
            },
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = BslAiService(
      httpClient: client,
      endpoint: Uri.parse('https://api.example.com/v1/ask'),
      idTokenProvider: () async => 'firebase-token',
    );

    final answer = await service.ask(
      question: 'Gdje je parking?',
      city: 'Sarajevo',
      context: const BslAiRequestContext(
        city: 'Sarajevo',
        latitude: 43.8563,
        longitude: 18.4131,
      ),
    );

    final requestBody =
        jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(capturedRequest.headers['authorization'], 'Bearer firebase-token');
    expect(requestBody['question'], 'Gdje je parking?');
    expect(requestBody['city'], 'Sarajevo');
    expect(requestBody['locale'], 'bs');
    final requestContext = requestBody['context'] as Map<String, dynamic>;
    expect(requestContext['city'], 'Sarajevo');
    expect(requestContext['location'], {
      'latitude': 43.8563,
      'longitude': 18.4131,
    });
    expect(answer.answer, 'Najbliži parking je Skenderija.');
    expect(answer.grounded, isTrue);
    expect(answer.sources.single.title, 'BSL parking podaci');
    expect(answer.requestId, 'req-1');
    expect(answer.action?.type, BslAiActionType.openParking);

    service.dispose();
  });

  test('429 mapira u razumljivu poruku za korisnika', () async {
    final service = BslAiService(
      httpClient: MockClient((request) async => http.Response('', 429)),
      endpoint: Uri.parse('https://api.example.com/v1/ask'),
      idTokenProvider: () async => null,
    );

    await expectLater(
      service.ask(question: 'Pitanje', city: 'Pale'),
      throwsA(
        isA<BslAiException>()
            .having((error) => error.statusCode, 'statusCode', 429)
            .having(
              (error) => error.userMessage,
              'userMessage',
              contains('zauzet'),
            ),
      ),
    );

    service.dispose();
  });
}
