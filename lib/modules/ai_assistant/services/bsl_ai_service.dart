import 'dart:async';
import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/bsl_ai_answer.dart';
import '../models/bsl_ai_request_context.dart';

typedef BslAiIdTokenProvider = Future<String?> Function();
typedef BslAiAppCheckTokenProvider = Future<String?> Function();

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
  final BslAiAppCheckTokenProvider _appCheckTokenProvider;
  final Duration timeout;

  BslAiService({
    http.Client? httpClient,
    Uri? endpoint,
    BslAiIdTokenProvider? idTokenProvider,
    BslAiAppCheckTokenProvider? appCheckTokenProvider,
    this.timeout = const Duration(seconds: 20),
  }) : _httpClient = httpClient ?? http.Client(),
       _endpoint = endpoint ?? _parseConfiguredEndpoint(),
       _idTokenProvider = idTokenProvider ?? _firebaseIdToken,
       _appCheckTokenProvider = appCheckTokenProvider ?? _firebaseAppCheckToken;

  bool get isConfigured => _endpoint != null;

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

  static Future<String?> _firebaseAppCheckToken() async {
    try {
      return await FirebaseAppCheck.instance.getToken();
    } catch (_) {
      throw const BslAiException(
        'Sigurnosna provjera BSL aplikacije nije dostupna. '
        'Provjerite App Check konfiguraciju.',
      );
    }
  }

  Future<BslAiAnswer> ask({
    required String question,
    required String city,
    BslAiRequestContext? context,
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
      final appCheckToken = await _appCheckTokenProvider();
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (idToken != null && idToken.isNotEmpty)
          'Authorization': 'Bearer $idToken',
        if (appCheckToken != null && appCheckToken.isNotEmpty)
          'X-Firebase-AppCheck': appCheckToken,
      };

      final response = await _httpClient
          .post(
            endpoint,
            headers: headers,
            body: jsonEncode({
              'question': normalizedQuestion,
              'city': normalizedCity,
              'locale': context?.locale ?? 'bs',
              'context': (context ?? BslAiRequestContext(city: normalizedCity))
                  .toJson(),
            }),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _exceptionForStatus(response.statusCode);
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'BSL AI odgovor nije ispravan JSON objekt.',
        );
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
        return BslAiException(
          'Prijava za BSL AI nije važeća. Prijavite se ponovo.',
          statusCode: statusCode,
        );
      case 403:
        return BslAiException(
          'Sigurnosna provjera BSL aplikacije nije uspjela. '
          'Ažurirajte aplikaciju ili provjerite App Check konfiguraciju.',
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
