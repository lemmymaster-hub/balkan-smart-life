import 'dart:convert';

import 'package:http/http.dart' as http;

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
  static const String _overpassEndpoint =
      'https://overpass-api.de/api/interpreter';

  final http.Client _client;

  AtmService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<AtmLocation>> loadNearby({
    required double latitude,
    required double longitude,
    double radiusKilometers = defaultRadiusKilometers,
    String cityHint = '',
  }) async {
    final radiusMeters = (radiusKilometers * 1000).round();
    final query = '''
[out:json][timeout:30];
(
  nwr["amenity"="atm"](around:$radiusMeters,$latitude,$longitude);
  nwr["amenity"="bank"]["atm"="yes"](around:$radiusMeters,$latitude,$longitude);
);
out center tags;
''';

    late http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_overpassEndpoint),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              'User-Agent': 'BalkanSmartLife/1.0 ATM module',
            },
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 36));
    } catch (_) {
      throw const AtmServiceException(
        'Mreža bankomata trenutno nije dostupna. Pokušaj ponovo.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AtmServiceException(
        'Mreža bankomata trenutno nije dostupna (${response.statusCode}).',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const AtmServiceException('Primljen je neispravan odgovor za bankomate.');
    }

    return parseOverpassPayload(
      decoded,
      centerLatitude: latitude,
      centerLongitude: longitude,
      radiusKilometers: radiusKilometers,
      cityHint: cityHint,
    );
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

      final lat = _asDouble(element['lat']) ??
          _asDouble((element['center'] as Map?)?['lat']);
      final lon = _asDouble(element['lon']) ??
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
      final key = '${lat.toStringAsFixed(6)}|${lon.toStringAsFixed(6)}|$bankName';

      byCoordinateAndBank[key] = AtmLocation(
        id: id,
        bankName: bankName,
        name: name.isEmpty ? '$bankName bankomat' : name,
        address: address,
        city: city,
        latitude: lat,
        longitude: lon,
        cashDeposit: _yes(tags['cash_in']) ||
            _yes(tags['cash_deposit']) ||
            _yes(tags['deposit']),
        is24h: _isAlwaysOpen(_text(tags['opening_hours'])),
      );
    }

    final result = byCoordinateAndBank.values.toList(growable: false);
    result.sort((a, b) {
      final da = BslCities.distanceInKilometers(
        fromLatitude: centerLatitude,
        fromLongitude: centerLongitude,
        toLatitude: a.latitude,
        toLongitude: a.longitude,
      );
      final db = BslCities.distanceInKilometers(
        fromLatitude: centerLatitude,
        fromLongitude: centerLongitude,
        toLatitude: b.latitude,
        toLongitude: b.longitude,
      );
      return da.compareTo(db);
    });
    return result;
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
      'komercijalno investiciona': 'KIB Banka',
      'kib': 'KIB Banka',
    };

    for (final entry in aliases.entries) {
      if (value.contains(entry.key)) return entry.value;
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
