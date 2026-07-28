import '../../../core/models/bsl_city.dart';
import '../models/bsl_ai_action.dart';
import '../models/bsl_ai_answer.dart';
import '../models/bsl_ai_request_context.dart';

class BslAiLocalIntentResolver {
  const BslAiLocalIntentResolver();

  BslAiAnswer? resolve({
    required String question,
    required BslAiRequestContext context,
  }) {
    final normalizedQuestion = BslCities.normalize(question);
    if (normalizedQuestion.isEmpty) return null;

    final mentionedCity = _findMentionedCity(question);
    final city = mentionedCity?.name ?? BslCities.byName(context.city).name;

    if (_containsAny(normalizedQuestion, _parkingTerms)) {
      final target = _extractTarget(
        normalizedQuestion,
        city: city,
        intentTerms: _parkingTerms,
      );

      return BslAiAnswer(
        answer: target == null
            ? 'Otvaram Parkiraj.ba i tražim najbliži dostupan parking u '
                  '$city.'
            : 'Otvaram Parkiraj.ba i tražim najbliži parking lokaciji '
                  '„$target“ u gradu $city.',
        city: city,
        grounded: false,
        sources: const [],
        action: BslAiAction(
          type: BslAiActionType.openParking,
          parameters: {'city': city, 'query': ?target, 'select_nearest': true},
        ),
      );
    }

    if (_containsAny(normalizedQuestion, _evChargerTerms)) {
      final target = _extractTarget(
        normalizedQuestion,
        city: city,
        intentTerms: _evChargerTerms,
      );

      return BslAiAnswer(
        answer: target == null
            ? 'Otvaram EL Punjače i tražim najbliži punjač u gradu $city.'
            : 'Otvaram EL Punjače i tražim najbliži punjač lokaciji '
                  '„$target“ u gradu $city.',
        city: city,
        grounded: false,
        sources: const [],
        action: BslAiAction(
          type: BslAiActionType.openEvChargers,
          parameters: {'city': city, 'query': ?target, 'select_nearest': true},
        ),
      );
    }

    if (_containsAny(normalizedQuestion, _weatherTerms)) {
      return BslAiAnswer(
        answer: 'Otvaram vremensku prognozu za $city.',
        city: city,
        grounded: false,
        sources: const [],
        action: BslAiAction(
          type: BslAiActionType.openWeather,
          parameters: {'city': city},
        ),
      );
    }

    if (_containsAny(normalizedQuestion, _walletTerms)) {
      return BslAiAnswer(
        answer:
            'Mogu otvoriti BSL novčanik. Plaćanje i druge finansijske '
            'radnje uvijek će zahtijevati tvoju jasnu potvrdu.',
        city: city,
        grounded: false,
        sources: const [],
        action: BslAiAction(
          type: BslAiActionType.openWallet,
          parameters: {'city': city},
        ),
      );
    }

    return null;
  }

  String? _extractTarget(
    String normalizedQuestion, {
    required String city,
    required List<String> intentTerms,
  }) {
    var candidate = normalizedQuestion;

    for (final marker in _nearMarkers) {
      final markerIndex = candidate.indexOf('$marker ');
      if (markerIndex >= 0) {
        candidate = candidate.substring(markerIndex + marker.length).trim();
        break;
      }
    }

    candidate = candidate.replaceAll(BslCities.normalize(city), ' ');
    for (final form in _cityMentionForms[city] ?? const <String>[]) {
      candidate = candidate.replaceAll(form, ' ');
    }

    final removableTerms = <String>{
      ...intentTerms,
      ..._commandWords,
      ..._nearMarkers,
    };
    final words = candidate
        .split(' ')
        .where((word) => word.isNotEmpty && !removableTerms.contains(word))
        .toList(growable: false);

    if (words.isEmpty) return null;

    candidate = words.join(' ').trim();
    candidate = _canonicalizeCommonPlace(candidate);

    return candidate.length < 2 ? null : candidate;
  }

  String _canonicalizeCommonPlace(String value) {
    var result = value
        .replaceAll('klinickog centra', 'klinicki centar')
        .replaceAll('trznog centra', 'trzni centar');

    const replacements = <String, String>{
      'bolnice': 'bolnica',
      'poste': 'posta',
      'aerodroma': 'aerodrom',
      'stanice': 'stanica',
      'centra': 'centar',
      'hotela': 'hotel',
      'stadiona': 'stadion',
    };

    final replacement = replacements[result];
    if (replacement != null) return replacement;

    for (final entry in replacements.entries) {
      if (result.endsWith(' ${entry.key}')) {
        result =
            '${result.substring(0, result.length - entry.key.length)}'
            '${entry.value}';
      }
    }

    return result.trim();
  }

  bool _containsAny(String value, List<String> terms) {
    final paddedValue = ' $value ';
    return terms.any((term) => paddedValue.contains(' $term '));
  }

  BslCity? _findMentionedCity(String question) {
    final exactMention = BslCities.findMentionedIn(question);
    if (exactMention != null) return exactMention;

    final normalizedQuestion = ' ${BslCities.normalize(question)} ';

    final citiesByLongestName = [
      ...BslCities.values,
    ]..sort((first, second) => second.name.length.compareTo(first.name.length));

    for (final city in citiesByLongestName) {
      final forms = _cityMentionForms[city.name] ?? const <String>[];
      if (forms.any((form) => normalizedQuestion.contains(' $form '))) {
        return city;
      }
    }

    return null;
  }

  static const _parkingTerms = <String>[
    'parking',
    'parkinga',
    'parkingu',
    'parkiraj',
    'parkirati',
    'parkiraliste',
    'parkiralista',
    'garaza',
    'garaze',
    'garazu',
  ];

  static const _evChargerTerms = <String>[
    'punjac',
    'punjaci',
    'punjaca',
    'punjacem',
    'punjenje',
    'punionica',
    'punionice',
    'ev',
  ];

  static const _weatherTerms = <String>[
    'vrijeme',
    'vremenska',
    'vremensku',
    'prognoza',
    'prognozu',
    'temperatura',
    'temperaturu',
    'kisa',
    'kisu',
    'snijeg',
  ];

  static const _walletTerms = <String>[
    'novcanik',
    'novcanika',
    'novcaniku',
    'kartica',
    'kartice',
    'karticu',
  ];

  static const _nearMarkers = <String>[
    'u blizini',
    'najblizi',
    'najblize',
    'blizu',
    'kod',
    'pored',
    'oko',
  ];

  static const _commandWords = <String>[
    'nadji',
    'pronadji',
    'prikazi',
    'pokazi',
    'otvori',
    'trebam',
    'treba',
    'mi',
    'molim',
    'te',
    'za',
    'u',
    'na',
  ];

  static const _cityMentionForms = <String, List<String>>{
    'Sarajevo': ['sarajevu', 'sarajeva'],
    'Banja Luka': ['banjoj luci', 'banja luci', 'banju luku', 'banje luke'],
    'Mostar': ['mostaru', 'mostara'],
    'Tuzla': ['tuzli', 'tuzlu', 'tuzle'],
    'Zenica': ['zenici', 'zenicu', 'zenice'],
    'Bihać': ['bihacu', 'bihaca'],
    'Trebinje': ['trebinju', 'trebinja'],
    'Pale': ['palama'],
    'Istočno Sarajevo': ['istocnom sarajevu', 'istocnog sarajeva'],
  };
}
