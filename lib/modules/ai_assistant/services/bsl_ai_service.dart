import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/bsl_ai_answer.dart';

typedef BslAiIdTokenProvider = Future<String?> Function();

class BslAiException implements Exception {
  final String userMessage;
  final int? statusCode;

  const BslAiException(this.userMessage, {this.statusCode});

  @override
  String toString() => userMessage;
}

class BslAiService {
  static const String _endpointFromEnvironment = String.fromEnvironment(
    'BSL_AI_ENDPOINT',
  );

  final http.Client _httpClient;
  final Uri? _endpoint;
  final BslAiIdTokenProvider _idTokenProvider;
  final Duration _timeout;

  BslAiService({
    http.Client? httpClient,
    Uri? endpoint,
    BslAiIdTokenProvider? idTokenProvider,
    Duration timeout = const Duration(seconds: 20),
  }) : _httpClient = httpClient ?? http.Client(),
       _endpoint = endpoint ?? _parseConfiguredEndpoint(),
       _idTokenProvider = idTokenProvider ?? _firebaseIdToken,
       _timeout = timeout;

  static Uri? _parseConfiguredEndpoint() {
    final value = _endpointFromEnvironment.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    return uri;
  }

  static Future<String?> _firebaseIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  Future<BslAiAnswer> ask({
    required String question,
    required String city,
  }) async {
    final normalizedQuestion = question.trim();
    final normalizedCity = city.trim();

    if (normalizedQuestion.isEmpty) {
      throw const BslAiException('Unesite pitanje za BSL AI.');
    }

    final endpoint = _endpoint;
    if (endpoint == null) {
      throw const BslAiException(
        'BSL AI još nije povezan sa sigurnim serverom. '
        'NVIDIA ključ ne smije biti ugrađen direktno u aplikaciju.',
      );
    }

    try {
      final idToken = await _idTokenProvider();
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (idToken != null && idToken.isNotEmpty)
          'Authorization': 'Bearer $idToken',
      };

      final response = await _httpClient
          .post(
            endpoint,
            headers: headers,
            body: jsonEncode({
              'question': normalizedQuestion,
              'city': normalizedCity,
              'locale': 'bs',
            }),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _exceptionForStatus(response.statusCode);
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('BSL AI odgovor nije ispravan JSON objekt.');
      }

      return BslAiAnswer.fromJson(decoded, fallbackCity: normalizedCity);
    } on BslAiException {
      rethrow;
    } on TimeoutException {
      throw const BslAiException(
        'BSL AI trenutno odgovara presporo. Pokušajte ponovo.',
      );
    } on FormatException {
      throw const BslAiException(
        'BSL AI je vratio neispravan odgovor. Pokušajte ponovo.',
      );
    } on http.ClientException {
      throw const BslAiException(
        'Nije moguće uspostaviti vezu sa BSL AI servisom.',
      );
    } catch (_) {
      throw const BslAiException(
        'BSL AI trenutno nije dostupan. Pokušajte ponovo.',
      );
    }
  }

  BslAiException _exceptionForStatus(int statusCode) {
    switch (statusCode) {
      case 401:
      case 403:
        return BslAiException(
          'Prijava za BSL AI nije važeća. Prijavite se ponovo.',
          statusCode: statusCode,
        );
      case 429:
        return BslAiException(
          'BSL AI je trenutno zauzet. Pokušajte za nekoliko trenutaka.',
          statusCode: statusCode,
        );
      default:
        return BslAiException(
          'BSL AI servis trenutno nije dostupan.',
          statusCode: statusCode,
        );
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
