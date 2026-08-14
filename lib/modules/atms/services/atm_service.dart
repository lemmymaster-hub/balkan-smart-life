import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/bsl_city.dart';
import '../models/atm_location.dart';

class AtmServiceException implements Exception {
  final String message;
  const AtmServiceException(this.message);

  @override
  String toString() => message;
}

class AtmService {
  static const double defaultRadiusKilometers = 10;

  // Publishable Supabase keys are intended for client applications. Database
  // access is restricted to the read-only bsl_nearby_atms_map RPC.
  static const String _supabaseUrl = 'https://jkzjktrnqtkpdiiugfar.supabase.co';
  static const String _supabasePublishableKey =
      'sb_publishable_3s2pD65jngWSus-6wV-jpw_vXynI3oJ';

  static const List<String> _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  static const Duration _supabaseTimeout = Duration(seconds: 9);
  static const Duration _overpassTimeout = Duration(seconds: 13);
  static const Duration _cacheMaxAge = Duration(days: 30);

  final http.Client _client;

  AtmService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<AtmLocation>> loadNearby({
    required double latitude,
    required double longitude,
    double radiusKilometers = defaultRadiusKilometers,
    String cityHint = '',
  }) async {
    Object? supabaseError;

    try {
      final atms = await _loadFromSupabase(
        latitude: latitude,
        longitude: longitude,
        radiusKilometers: radiusKilometers,
      );

      if (atms.isNotEmpty) {
        await _writeCache(
          atms,
          latitude: latitude,
          longitude: longitude,
          radiusKilometers: radiusKilometers,
        );
        return atms;
      }
    } catch (error) {
      supabaseError = error;
    }

    // A recent BSL cache is preferred over a live public Overpass request.
    // This keeps the ATM map useful during short Supabase/network outages.
    final cached = await _readCache(
      latitude: latitude,
      longitude: longitude,
      radiusKilometers: radiusKilometers,
    );
    if (cached.isNotEmpty) return cached;

    Object? overpassError;
    try {
      final osm = await _loadFromOverpass(
        latitude: latitude,
        longitude: longitude,
        radiusKilometers: radiusKilometers,
        cityHint: cityHint,
      );
      if (osm.isNotEmpty) {
        await _writeCache(
          osm,
          latitude: latitude,
          longitude: longitude,
          radiusKilometers: radiusKilometers,
        );
        return osm;
      }
    } catch (error) {
      overpassError = error;
    }

    throw AtmServiceException(
      'Mreža bankomata trenutno nije dostupna. Pokušaj ponovo. '
      '(${supabaseError ?? overpassError ?? 'nema podataka'})',
    );
  }

  Future<List<AtmLocation>> _loadFromSupabase({
    required double latitude,
    required double longitude,
    required double radiusKilometers,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_supabaseUrl/rest/v1/rpc/bsl_nearby_atms_map'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'apikey': _supabasePublishableKey,
          },
          body: jsonEncode({
            'p_lat': latitude,
            'p_lon': longitude,
            'p_radius_m': (radiusKilometers * 1000).round(),
          }),
        )
        .timeout(_supabaseTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Supabase HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Supabase ATM odgovor nije lista.');
    }

    final result = <AtmLocation>[];
    for (final raw in decoded) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final lat = _asDouble(row['latitude']);
      final lon = _asDouble(row['longitude']);
      if (lat == null || lon == null) continue;

      final distance = BslCities.distanceInKilometers(
        fromLatitude: latitude,
        fromLongitude: longitude,
        toLatitude: lat,
        toLongitude: lon,
      );
      if (distance > radiusKilometers + 0.2) continue;

      final bank = _text(row['bank_brand']);
      final source = _text(row['source']);
      result.add(
        AtmLocation(
          id: _text(row['location_id']).isEmpty
              ? 'bsl_${lat}_$lon'
              : _text(row['location_id']),
          bankName: bank.isEmpty ? 'Ostali bankomati' : bank,
          name: _text(row['name']),
          address: _text(row['address']),
          city: _text(row['city']),
          latitude: lat,
          longitude: lon,
          cashDeposit: row['cash_deposit'] == true,
          is24h: row['is_24h'] == true,
          source: source.isEmpty ? 'BSL Supabase' : source,
        ),
      );
    }

    result.sort((a, b) {
      final da = BslCities.distanceInKilometers(
        fromLatitude: latitude,
        fromLongitude: longitude,
        toLatitude: a.latitude,
        toLongitude: a.longitude,
      );
      final db = BslCities.distanceInKilometers(
        fromLatitude: latitude,
        fromLongitude: longitude,
        toLatitude: b.latitude,
        toLongitude: b.longitude,
      );
      return da.compareTo(db);
    });

    return result;
  }

  Future<List<AtmLocation>> _loadFromOverpass({
    required double latitude,
    required double longitude,
    required double radiusKilometers,
    required String cityHint,
  }) async {
    final radiusMeters = (radiusKilometers * 1000).round();
    final query =
        '''
[out:json][timeout:25];
(
  nwr["amenity"="atm"](around:$radiusMeters,$latitude,$longitude);
  nwr["amenity"="bank"]["atm"="yes"](around:$radiusMeters,$latitude,$longitude);
);
out center tags;
''';

    Object? lastError;
    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await _client
            .post(
              Uri.parse(endpoint),
              headers: const {
                'Accept': 'application/json',
                'Content-Type':
                    'application/x-www-form-urlencoded; charset=UTF-8',
                'User-Agent': 'BalkanSmartLife/1.0 ATM fallback',
              },
              body: {'data': query},
            )
            .timeout(_overpassTimeout);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = 'HTTP ${response.statusCode} @ $endpoint';
          continue;
        }

        return parseOverpassPayload(
          jsonDecode(response.body),
          centerLatitude: latitude,
          centerLongitude: longitude,
          radiusKilometers: radiusKilometers,
          cityHint: cityHint,
        );
      } catch (error) {
        lastError = error;
      }
    }

    throw StateError('Overpass nije dostupan: ${lastError ?? 'nema odgovora'}');
  }

  List<AtmLocation> parseOverpassPayload(
    Object? payload, {
    required double centerLatitude,
    required double centerLongitude,
    required double radiusKilometers,
    String cityHint = '',
  }) {
    if (payload is! Map<String, dynamic>) return const [];
    final elements = payload['elements'];
    if (elements is! List) return const [];

    final byCoordinateAndBank = <String, AtmLocation>{};

    for (final raw in elements) {
      if (raw is! Map) continue;
      final element = Map<String, dynamic>.from(raw);
      final rawTags = element['tags'];
      final tags = rawTags is Map
          ? Map<String, dynamic>.from(rawTags)
          : const <String, dynamic>{};

      final lat =
          _asDouble(element['lat']) ??
          _asDouble((element['center'] as Map?)?['lat']);
      final lon =
          _asDouble(element['lon']) ??
          _asDouble((element['center'] as Map?)?['lon']);
      if (lat == null || lon == null) continue;

      final distance = BslCities.distanceInKilometers(
        fromLatitude: centerLatitude,
        fromLongitude: centerLongitude,
        toLatitude: lat,
        toLongitude: lon,
      );
      if (distance > radiusKilometers + 0.15) continue;

      final operator = _text(tags['operator']);
      final brand = _text(tags['brand']);
      final name = _text(tags['name']);
      final network = _text(tags['network']);
      final bankName = normalizeBankName(
        [brand, operator, network, name].where((v) => v.isNotEmpty).join(' '),
      );

      final street = _text(tags['addr:street']);
      final number = _text(tags['addr:housenumber']);
      final place = _text(tags['addr:place']);
      final address = [
        if (street.isNotEmpty) street,
        if (number.isNotEmpty) number,
        if (street.isEmpty && place.isNotEmpty) place,
      ].join(' ').trim();
      final city = _text(tags['addr:city']).isNotEmpty
          ? _text(tags['addr:city'])
          : cityHint;

      final osmType = _text(element['type']);
      final osmId = element['id']?.toString() ?? '${lat}_$lon';
      final id = 'osm_${osmType}_$osmId';
      final key =
          '${lat.toStringAsFixed(6)}|${lon.toStringAsFixed(6)}|$bankName';

      byCoordinateAndBank[key] = AtmLocation(
        id: id,
        bankName: bankName,
        name: name.isEmpty ? '$bankName bankomat' : name,
        address: address,
        city: city,
        latitude: lat,
        longitude: lon,
        cashDeposit:
            _yes(tags['cash_in']) ||
            _yes(tags['cash_deposit']) ||
            _yes(tags['deposit']),
        is24h: _isAlwaysOpen(_text(tags['opening_hours'])),
        source: 'OpenStreetMap fallback',
      );
    }

    return byCoordinateAndBank.values.toList(growable: false);
  }

  Future<void> _writeCache(
    List<AtmLocation> atms, {
    required double latitude,
    required double longitude,
    required double radiusKilometers,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(latitude, longitude, radiusKilometers),
        jsonEncode({
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'items': atms.map(_toJson).toList(growable: false),
        }),
      );
    } catch (_) {
      // Cache must never block the map.
    }
  }

  Future<List<AtmLocation>> _readCache({
    required double latitude,
    required double longitude,
    required double radiusKilometers,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(
        _cacheKey(latitude, longitude, radiusKilometers),
      );
      if (raw == null || raw.isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final savedAt = _asInt(decoded['savedAt']);
      if (savedAt == null) return const [];

      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(savedAt),
      );
      if (age > _cacheMaxAge) return const [];

      final items = decoded['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((raw) => _fromJson(Map<String, dynamic>.from(raw)))
          .whereType<AtmLocation>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Map<String, Object?> _toJson(AtmLocation atm) => {
    'id': atm.id,
    'bankName': atm.bankName,
    'name': atm.name,
    'address': atm.address,
    'city': atm.city,
    'latitude': atm.latitude,
    'longitude': atm.longitude,
    'cashDeposit': atm.cashDeposit,
    'is24h': atm.is24h,
    'source': atm.source,
  };

  static AtmLocation? _fromJson(Map<String, dynamic> json) {
    final latitude = _asDouble(json['latitude']);
    final longitude = _asDouble(json['longitude']);
    if (latitude == null || longitude == null) return null;

    return AtmLocation(
      id: _text(json['id']),
      bankName: _text(json['bankName']),
      name: _text(json['name']),
      address: _text(json['address']),
      city: _text(json['city']),
      latitude: latitude,
      longitude: longitude,
      cashDeposit: json['cashDeposit'] == true,
      is24h: json['is24h'] == true,
      source: _text(json['source']).isEmpty
          ? 'BSL ATM cache'
          : _text(json['source']),
    );
  }

  static String _cacheKey(
    double latitude,
    double longitude,
    double radiusKilometers,
  ) {
    return 'bsl_atm_cache_v2_'
        '${latitude.toStringAsFixed(1)}_'
        '${longitude.toStringAsFixed(1)}_'
        '${radiusKilometers.toStringAsFixed(0)}';
  }

  static String normalizeBankName(String raw) {
    final value = BslCities.normalize(raw);
    if (value.isEmpty) return 'Ostali bankomati';

    const aliases = <String, String>{
      'raiffeisen': 'Raiffeisen Bank',
      'unicredit': 'UniCredit Bank',
      'addiko': 'Addiko Bank',
      'sparkasse': 'Sparkasse Bank',
      'nlb': 'NLB Banka',
      'nova banka': 'Nova banka',
      'asa banka': 'ASA Banka',
      'bosna bank international': 'BBI Banka',
      'bbi': 'BBI Banka',
      'intesa sanpaolo': 'Intesa Sanpaolo Banka',
      'procredit': 'ProCredit Bank',
      'ziraat': 'ZiraatBank BH',
      'union banka': 'Union Banka',
      'privredna banka sarajevo': 'Privredna banka Sarajevo',
      'pbs': 'Privredna banka Sarajevo',
      'atos': 'ATOS BANK',
      'mf banka': 'MF banka',
      'nasa banka': 'Naša banka',
      'postanska stedionica': 'Banka Poštanska štedionica',
      'poštanska štedionica': 'Banka Poštanska štedionica',
      'komercijalna banka': 'Banka Poštanska štedionica',
      'komercijalno investiciona': 'KIB Banka',
      'kib': 'KIB Banka',
    };

    for (final entry in aliases.entries) {
      if (value.contains(BslCities.normalize(entry.key))) return entry.value;
    }

    final clean = raw
        .replaceAll(RegExp(r'\b(ATM|atm|bankomat|Bankomat)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return clean.isEmpty ? 'Ostali bankomati' : clean;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';

  static bool _yes(Object? value) {
    final v = BslCities.normalize(_text(value));
    return v == 'yes' || v == 'true' || v == '1';
  }

  static bool _isAlwaysOpen(String value) {
    final normalized = value.replaceAll(' ', '').toLowerCase();
    return normalized == '24/7' || normalized == '24-7';
  }

  void dispose() => _client.close();
}
