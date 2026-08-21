import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/bsl_administrative_area.dart';
import '../../../core/models/bsl_city.dart';
import '../models/ev_charger.dart';
import '../models/ev_charger_verification.dart';

typedef EvChargerSnapshotLoader = Future<String> Function();

class EvChargerService {
  static const _defaultOverpassEndpoints = <String>[
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];
  static const _bundledSnapshotAsset =
      'assets/data/bsl_ev_chargers_bih.json';
  static const _bihOverpassAreaId = 3602528142;
  static const _verificationCollection = 'ev_charger_verifications';
  static const _cacheLifetime = Duration(minutes: 15);
  static const _defaultRequestTimeout = Duration(seconds: 20);
  static const _searchRadiusMeters = 20000;
  static const _nationalCacheKey = '__bih_nationwide__';

  static const _bihSectors = <List<double>>[
    [44.0, 15.5, 45.4, 17.7],
    [44.0, 17.7, 45.4, 19.8],
    [42.4, 15.5, 44.0, 17.7],
    [42.4, 17.7, 44.0, 19.8],
  ];

  final FirebaseFirestore? _firestore;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final List<Uri> _overpassEndpoints;
  final Duration _requestTimeout;
  final EvChargerSnapshotLoader _bundledSnapshotLoader;
  final Map<String, _CachedChargers> _cache = {};

  EvChargerService({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
    List<String>? overpassEndpoints,
    Duration requestTimeout = _defaultRequestTimeout,
    EvChargerSnapshotLoader? bundledSnapshotLoader,
  }) : // Publicni parametar ostaje `firestore`, bez izlaganja privatnog polja.
       // ignore: prefer_initializing_formals
       _firestore = firestore,
      _httpClient = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null,
      _overpassEndpoints = List<Uri>.unmodifiable(
        (overpassEndpoints ?? _defaultOverpassEndpoints).map(Uri.parse),
      ),
      // Testovi i pozivaoci koriste javni naziv `requestTimeout`.
      // ignore: prefer_initializing_formals
      _requestTimeout = requestTimeout,
      _bundledSnapshotLoader =
          bundledSnapshotLoader ?? _loadBundledSnapshotAsset {
    if (_overpassEndpoints.isEmpty) {
      throw ArgumentError.value(
        overpassEndpoints,
        'overpassEndpoints',
        'Mora sadržavati barem jedan Overpass endpoint.',
      );
    }
  }

  /// EV mapa je nacionalna: bez obzira koji je grad trenutno odabran na
  /// početnom ekranu, uvijek učitava sve javno mapirane punjače u BiH.
  /// Parametar [city] se zadržava radi kompatibilnosti postojećeg UI-ja.
  Stream<List<EvCharger>> watchForCity(
    BslCity city, {
    bool forceRefresh = false,
  }) async* {
    var osmChargers = await _loadBundledChargers();
    if (osmChargers.isNotEmpty) {
      // Prvo prikaži provjereni OSM snapshot iz APK-a. Live osvježavanje ne
      // smije ostaviti mapu praznom kada je javni Overpass preopterećen.
      yield osmChargers;
    }

    try {
      final refreshedChargers = await fetchNationwide(
        forceRefresh: forceRefresh,
      );
      osmChargers = refreshedChargers;
      yield refreshedChargers;
    } catch (error, stackTrace) {
      if (osmChargers.isEmpty) rethrow;
      debugPrint('EV CHARGERS LIVE REFRESH ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      final firestore = _firestore ?? FirebaseFirestore.instance;
      await for (final snapshot
          in firestore.collection(_verificationCollection).snapshots()) {
        final verifications = snapshot.docs
            .map(EvChargerVerification.fromFirestore)
            .toList(growable: false);

        yield mergeNationwideVerifications(
          chargers: osmChargers,
          verifications: verifications,
        );
      }
    } catch (error, stackTrace) {
      // OSM podaci ostaju dostupni i kada Firestore nije konfigurisan ili
      // trenutna pravila još ne dozvoljavaju čitanje verifikacija.
      debugPrint('EV CHARGERS FIRESTORE ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<List<EvCharger>> fetchNationwide({
    bool forceRefresh = false,
  }) async {
    final cached = _cache[_nationalCacheKey];

    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.chargers;
    }

    try {
      final response = await _requestOverpassQuery(
        buildNationwideOverpassQuery(),
      );
      final chargers = parseNationwideOverpassResponse(
        utf8.decode(response.bodyBytes),
      );
      if (chargers.isEmpty) {
        throw const EvChargerException(
          'OSM je vratio prazan BiH rezultat; zadržavam zadnji snapshot.',
        );
      }

      _cache[_nationalCacheKey] = _CachedChargers(
        chargers: chargers,
        cachedAt: DateTime.now(),
      );
      return chargers;
    } catch (_) {
      if (cached != null) return cached.chargers;
      rethrow;
    }
  }

  Future<List<EvCharger>> _loadBundledChargers() async {
    try {
      final responseBody = await _bundledSnapshotLoader();
      return parseNationwideOverpassResponse(responseBody);
    } catch (error, stackTrace) {
      debugPrint('EV CHARGERS BUNDLED SNAPSHOT ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const <EvCharger>[];
    }
  }

  static Future<String> _loadBundledSnapshotAsset() {
    return rootBundle.loadString(_bundledSnapshotAsset);
  }

  /// Zadržano za testove i moguće city-scoped potrebe drugih ekrana.
  Future<List<EvCharger>> fetchForCity(
    BslCity city, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = BslCities.normalize(city.name);
    final cached = _cache[cacheKey];

    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.chargers;
    }

    try {
      final response = await _requestOverpassQuery(buildOverpassQuery(city));

      final chargers = parseOverpassResponse(
        utf8.decode(response.bodyBytes),
        requestedCity: city,
        sourceUpdatedAt: DateTime.now(),
      );
      _cache[cacheKey] = _CachedChargers(
        chargers: chargers,
        cachedAt: DateTime.now(),
      );

      return chargers;
    } on EvChargerException {
      if (cached != null) return cached.chargers;
      rethrow;
    } on TimeoutException {
      if (cached != null) return cached.chargers;
      throw const EvChargerException(
        'OSM servis trenutno predugo odgovara. Pokušaj ponovo.',
      );
    } on FormatException {
      if (cached != null) return cached.chargers;
      throw const EvChargerException(
        'OSM je vratio podatke koje aplikacija ne može pročitati.',
      );
    } catch (error) {
      if (cached != null) return cached.chargers;
      throw EvChargerException(
        'Punjači trenutno nisu dostupni. Provjeri internet vezu. ($error)',
      );
    }
  }

  Future<http.Response> _requestOverpassQuery(String query) async {
    Object? lastError;

    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await _httpClient
            .post(
              endpoint,
              headers: const {
                'Accept': 'application/json',
                'User-Agent':
                    'BalkanSmartLife/1.0 '
                    '(+https://github.com/lemmymaster-hub/balkan-smart-life)',
              },
              body: {'data': query},
            )
            .timeout(_requestTimeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        lastError = 'HTTP ${response.statusCode}';
      } catch (error) {
        lastError = error;
      }

      debugPrint('EV CHARGERS OVERPASS FALLBACK: $endpoint ($lastError)');
    }

    throw EvChargerException(
      'Javni OSM servisi trenutno ne odgovaraju. Pokušaj ponovo. '
      '(${lastError ?? 'nepoznata greška'})',
    );
  }

  void clearCache([BslCity? city]) {
    if (city == null) {
      _cache.clear();
      return;
    }

    _cache.remove(BslCities.normalize(city.name));
    _cache.remove(_nationalCacheKey);
  }

  /// Mobilni klijent šalje samo jedan državni upit. Ugrađeni snapshot ostaje
  /// dostupan ako javni Overpass privremeno vrati 429/5xx ili istekne rok.
  static String buildNationwideOverpassQuery() {
    return '''
[out:json][timeout:20];
area($_bihOverpassAreaId)->.bih;
(
  nwr["amenity"="charging_station"]["access"!="private"]["access"!="no"](area.bih);
);
out center tags;
''';
  }

  /// Sektorski upiti ostaju dostupni za kontrolisani backend sync i testove.
  @visibleForTesting
  static List<String> buildNationwideSectorQueries() {
    return _bihSectors.map((sector) {
      final south = sector[0];
      final west = sector[1];
      final north = sector[2];
      final east = sector[3];

      return '''
[out:json][timeout:30];
area($_bihOverpassAreaId)->.bih;
(
  nwr["amenity"="charging_station"]["access"!="private"]["access"!="no"](area.bih)($south,$west,$north,$east);
);
out center tags;
''';
    }).toList(growable: false);
  }

  static String buildOverpassQuery(BslCity city) {
    return '''
[out:json][timeout:25];
(
  nwr["amenity"="charging_station"]["access"!="private"]["access"!="no"](around:$_searchRadiusMeters,${city.latitude},${city.longitude});
);
out center tags;
''';
  }

  @visibleForTesting
  static List<EvCharger> parseNationwideOverpassResponse(
    String responseBody, {
    DateTime? sourceUpdatedAt,
  }) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Neispravan Overpass odgovor.');
    }

    final elements = decoded['elements'];
    if (elements is! List) {
      throw const FormatException('Overpass odgovor nema listu elemenata.');
    }

    final effectiveSourceUpdatedAt =
        sourceUpdatedAt ?? _sourceUpdatedAtFromResponse(decoded);
    final chargersById = <String, EvCharger>{};

    for (final rawElement in elements) {
      if (rawElement is! Map) continue;

      final element = Map<String, dynamic>.from(rawElement);
      final rawTags = element['tags'];
      final tags = rawTags is Map
          ? Map<String, dynamic>.from(rawTags)
          : const <String, dynamic>{};

      if (_isNotForCars(tags)) continue;

      try {
        var charger = EvCharger.fromOverpassElement(
          element: element,
          requestedCity: BslCities.bosniaAndHerzegovina,
          sourceUpdatedAt: effectiveSourceUpdatedAt,
        );

        if (!charger.isActive) continue;

        final cityName = _cityLabelFromTags(tags);
        if (cityName.isNotEmpty) {
          charger = charger.copyWith(city: cityName);
        }

        chargersById[charger.id] = charger;
      } on FormatException {
        // Jedan nepotpun OSM element ne smije zaustaviti cijeli modul.
      }
    }

    final chargers = chargersById.values.toList(growable: false)
      ..sort((first, second) {
        final cityOrder = BslCities.normalize(
          first.city,
        ).compareTo(BslCities.normalize(second.city));
        if (cityOrder != 0) return cityOrder;
        return first.name.compareTo(second.name);
      });

    return List<EvCharger>.unmodifiable(chargers);
  }

  static DateTime? _sourceUpdatedAtFromResponse(
    Map<String, dynamic> response,
  ) {
    final rawOsm3s = response['osm3s'];
    if (rawOsm3s is! Map) return null;
    final rawTimestamp = rawOsm3s['timestamp_osm_base']?.toString();
    return rawTimestamp == null ? null : DateTime.tryParse(rawTimestamp);
  }

  @visibleForTesting
  static List<EvCharger> parseOverpassResponse(
    String responseBody, {
    required BslCity requestedCity,
    DateTime? sourceUpdatedAt,
  }) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Neispravan Overpass odgovor.');
    }

    final elements = decoded['elements'];
    if (elements is! List) {
      throw const FormatException('Overpass odgovor nema listu elemenata.');
    }

    final chargersById = <String, EvCharger>{};

    for (final rawElement in elements) {
      if (rawElement is! Map) continue;

      final element = Map<String, dynamic>.from(rawElement);
      final rawTags = element['tags'];
      final tags = rawTags is Map
          ? Map<String, dynamic>.from(rawTags)
          : const <String, dynamic>{};

      if (_isNotForCars(tags)) continue;

      try {
        final charger = EvCharger.fromOverpassElement(
          element: element,
          requestedCity: requestedCity,
          sourceUpdatedAt: sourceUpdatedAt,
        );

        if (!charger.isActive ||
            !BslCities.same(charger.city, requestedCity.name)) {
          continue;
        }

        chargersById[charger.id] = charger;
      } on FormatException {
        // Jedan nepotpun OSM element ne smije zaustaviti cijeli modul.
      }
    }

    final chargers = chargersById.values.toList(growable: false)
      ..sort((first, second) => first.name.compareTo(second.name));

    return List<EvCharger>.unmodifiable(chargers);
  }

  @visibleForTesting
  static List<EvCharger> mergeNationwideVerifications({
    required List<EvCharger> chargers,
    required List<EvChargerVerification> verifications,
  }) {
    final verificationById = {
      for (final verification in verifications)
        verification.chargerId: verification,
    };

    final merged =
        chargers
            .map((charger) {
              final verification = verificationById[charger.id];
              return verification == null || !verification.verified
                  ? charger
                  : verification.applyTo(charger);
            })
            .where((charger) => charger.isActive)
            .toList(growable: false)
          ..sort((first, second) {
            final cityOrder = BslCities.normalize(
              first.city,
            ).compareTo(BslCities.normalize(second.city));
            if (cityOrder != 0) return cityOrder;
            return first.name.compareTo(second.name);
          });

    return List<EvCharger>.unmodifiable(merged);
  }

  @visibleForTesting
  static List<EvCharger> mergeVerifications({
    required List<EvCharger> chargers,
    required List<EvChargerVerification> verifications,
    required BslCity requestedCity,
  }) {
    final verificationById = {
      for (final verification in verifications)
        verification.chargerId: verification,
    };

    final merged =
        chargers
            .map((charger) {
              final verification = verificationById[charger.id];
              return verification == null || !verification.verified
                  ? charger
                  : verification.applyTo(charger);
            })
            .where(
              (charger) =>
                  charger.isActive &&
                  BslCities.same(charger.city, requestedCity.name),
            )
            .toList(growable: false)
          ..sort((first, second) => first.name.compareTo(second.name));

    return List<EvCharger>.unmodifiable(merged);
  }

  static String _cityLabelFromTags(Map<String, dynamic> tags) {
    final raw = [
      tags['addr:city'],
      tags['addr:place'],
      tags['addr:municipality'],
    ]
        .map((value) => value?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    if (raw.isEmpty) return '';
    final normalizedRaw = BslCities.normalize(raw);

    for (final area in BslAdministrativeAreas.values) {
      if (BslCities.normalize(area.displayName) == normalizedRaw) {
        return area.displayName;
      }
      for (final alias in area.aliases) {
        if (BslCities.normalize(alias) == normalizedRaw) {
          return area.displayName;
        }
      }
    }

    return raw;
  }

  static bool _isNotForCars(Map<String, dynamic> tags) {
    final motorcar = BslCities.normalize(tags['motorcar']?.toString() ?? '');
    final vehicle = BslCities.normalize(tags['vehicle']?.toString() ?? '');

    return motorcar == 'no' || vehicle == 'no';
  }

  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
  }
}

class EvChargerException implements Exception {
  final String message;

  const EvChargerException(this.message);

  @override
  String toString() => message;
}

class _CachedChargers {
  final List<EvCharger> chargers;
  final DateTime cachedAt;

  const _CachedChargers({required this.chargers, required this.cachedAt});

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > EvChargerService._cacheLifetime;
}
