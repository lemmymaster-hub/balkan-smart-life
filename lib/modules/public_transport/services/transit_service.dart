import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transit_models.dart';

abstract class TransitGateway {
  Future<List<TransitDirection>> directions(TransitLine line);
  Future<TransitRoute> route(TransitDirection direction);
  Future<List<TransitArrival>> arrivals(
    TransitLine line,
    TransitDirection direction,
    TransitStop stop,
  );
  Future<List<TransitDeparture>> timetable(
    TransitLine line,
    TransitDirection direction,
  );
  void dispose();
}

class TransitApiException implements Exception {
  final int status;
  const TransitApiException(this.status);
  @override
  String toString() => 'Transit API HTTP $status';
}

/// Public Ministry endpoints identified in the supplied Arrivo 1.9.3 APK.
/// No Arrivo keys, private proxy, account sessions or third-party map assets.
class MinistryTransitService implements TransitGateway {
  final http.Client _client;
  final DateTime Function() _now;
  MinistryTransitService({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _now = now ?? DateTime.now;

  Future<List<Map<String, dynamic>>> _request(
    String path, {
    Map<String, Object>? body,
  }) async {
    final uri = Uri.https('javniprevozks.ba', path);
    final response =
        await (body == null
                ? _client.get(uri, headers: {'Accept': 'application/json'})
                : _client.post(
                    uri,
                    headers: {
                      'Accept': 'application/json',
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode(body),
                  ))
            .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw TransitApiException(response.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('Expected a transit list');
    }
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<List<TransitDirection>> directions(TransitLine line) async {
    final rows = await _request(
      '/api/public/lines/line/${line.id}/directions/list',
    );
    return rows
        .where((r) => r['line_id'] == line.id)
        .map(TransitDirection.fromJson)
        .toList();
  }

  @override
  Future<TransitRoute> route(TransitDirection direction) async {
    final result = await Future.wait([
      _request(
        '/api/public/lines/terminus-line/${direction.id}/stations-with-distance/list/0/0',
      ),
      _request(
        '/public-api/public/lines/terminus-line/${direction.id}/station-line/points/list',
      ),
    ]);
    final stops = result[0].map(TransitStop.fromJson).toList();
    final points = result[1].map(TransitPoint.fromJson).toList();
    if (stops.isEmpty || points.length < 2) {
      throw const FormatException('Incomplete transit route');
    }
    return TransitRoute.ordered(stops, points);
  }

  @override
  Future<List<TransitArrival>> arrivals(
    TransitLine line,
    TransitDirection direction,
    TransitStop stop,
  ) async {
    final rows = await _request(
      '/api/public/lines/upcoming-arrivals',
      body: {
        'line_id': line.id,
        'terminus_line_id': direction.id,
        'station_id': stop.id,
        'limit': 20,
      },
    );
    final received = _now();
    // A malformed row cannot convert the entire feed into an empty success.
    return rows.map((r) => TransitArrival.fromJson(r, received)).toList();
  }

  @override
  Future<List<TransitDeparture>> timetable(
    TransitLine line,
    TransitDirection direction,
  ) async {
    // This endpoint takes line_id, NOT terminus_line_id.
    final groups = await _request(
      '/api/public/lines/timetables/${line.id}/list',
    );
    return groups
        .where((g) => g['id'] == direction.id)
        .expand((g) => g['timetable'] as List)
        .map(
          (r) => TransitDeparture.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  @override
  void dispose() => _client.close();
}
