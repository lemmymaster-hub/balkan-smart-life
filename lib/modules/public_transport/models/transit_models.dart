import 'dart:math' as math;

/// IDs verified against the Ministry API, using endpoints identified in Arrivo.
class TransitLine {
  final int id;
  final String code;
  final String name;
  final bool isTram;
  const TransitLine(this.id, this.code, this.name, {this.isTram = false});

  static const supported = [
    TransitLine(225, '106', 'Otoka – Vogošća'),
    TransitLine(130, '3', 'Baščaršija – Ilidža', isTram: true),
  ];
}

class TransitPoint {
  final double latitude;
  final double longitude;
  const TransitPoint(this.latitude, this.longitude);

  factory TransitPoint.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num).toDouble();
    final lng = (json['longitude'] as num).toDouble();
    if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180) {
      throw const FormatException('Invalid transit coordinates');
    }
    return TransitPoint(lat, lng);
  }

  double distanceTo(TransitPoint other) {
    const rad = math.pi / 180;
    final a =
        math.pow(math.sin((other.latitude - latitude) * rad / 2), 2) +
        math.cos(latitude * rad) *
            math.cos(other.latitude * rad) *
            math.pow(math.sin((other.longitude - longitude) * rad / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}

class TransitStop {
  final int id;
  final String name;
  final TransitPoint point;
  const TransitStop(this.id, this.name, this.point);
  factory TransitStop.fromJson(Map<String, dynamic> json) => TransitStop(
    (json['id'] as num).toInt(),
    json['name'] as String,
    TransitPoint.fromJson(json),
  );
}

class TransitDirection {
  final int id;
  final String name;
  const TransitDirection(this.id, this.name);
  factory TransitDirection.fromJson(Map<String, dynamic> json) =>
      TransitDirection(
        (json['terminus_line_id'] as num).toInt(),
        (json['direction'] ?? json['name']) as String,
      );
}

class TransitRoute {
  final List<TransitStop> stops;
  final List<TransitPoint> points;
  const TransitRoute(this.stops, this.points);

  /// The station endpoint is alphabetical, not in travel order. Project each
  /// stop onto the ordered API geometry; never connect alphabetical stations.
  factory TransitRoute.ordered(
    List<TransitStop> stops,
    List<TransitPoint> points,
  ) {
    if (points.length < 2) {
      return TransitRoute(List.unmodifiable(stops), points);
    }
    double progress(TransitStop stop) {
      var best = double.infinity;
      var result = 0.0;
      var travelled = 0.0;
      for (var i = 1; i < points.length; i++) {
        final a = points[i - 1];
        final b = points[i];
        final scale = math.cos(stop.point.latitude * math.pi / 180);
        final dx = (b.longitude - a.longitude) * scale;
        final dy = b.latitude - a.latitude;
        final length2 = dx * dx + dy * dy;
        final t = length2 == 0
            ? 0.0
            : (((stop.point.longitude - a.longitude) * scale * dx +
                          (stop.point.latitude - a.latitude) * dy) /
                      length2)
                  .clamp(0.0, 1.0);
        final projected = TransitPoint(
          a.latitude + dy * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
        final distance = stop.point.distanceTo(projected);
        final segmentLength = a.distanceTo(b);
        if (distance < best) {
          best = distance;
          result = travelled + segmentLength * t;
        }
        travelled += segmentLength;
      }
      return result;
    }

    final positions = {for (final s in stops) s.id: progress(s)};
    final ordered = [...stops]
      ..sort((a, b) => positions[a.id]!.compareTo(positions[b.id]!));
    return TransitRoute(List.unmodifiable(ordered), List.unmodifiable(points));
  }
}

class TransitArrival {
  final int tripId;
  final int lineId;
  final int destinationStation;
  final String operatorName;
  final DateTime expectedAt;
  final TransitPoint? point;
  const TransitArrival({
    required this.tripId,
    required this.lineId,
    required this.destinationStation,
    required this.operatorName,
    required this.expectedAt,
    this.point,
  });

  factory TransitArrival.fromJson(
    Map<String, dynamic> json,
    DateTime receivedAt,
  ) {
    final time = json['expected_arrival'];
    // A timestamp without zone must not silently use the phone's timezone.
    final zoned =
        time is String && RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(time);
    final parsed = zoned ? DateTime.tryParse(time)?.toUtc() : null;
    final minutes = json['arrival_minutes'] as num?;
    if (parsed == null && minutes == null) {
      throw const FormatException('Arrival has no time');
    }
    TransitPoint? position;
    if (json['latitude'] is num && json['longitude'] is num) {
      try {
        final p = TransitPoint.fromJson(json);
        if (p.latitude != 0 || p.longitude != 0) position = p;
      } on FormatException {
        /* A missing position must not hide an ETA. */
      }
    }
    return TransitArrival(
      tripId: (json['travel_order_id'] as num).toInt(),
      lineId: (json['line_id'] as num).toInt(),
      destinationStation: (json['destination_station'] as num).toInt(),
      operatorName: json['operator_name'] as String? ?? '',
      expectedAt:
          parsed ??
          receivedAt.toUtc().add(Duration(seconds: (minutes! * 60).round())),
      point: position,
    );
  }

  int minutesFrom(DateTime now) =>
      math.max(0, (expectedAt.difference(now.toUtc()).inSeconds / 60).ceil());
}

/// The public arrival endpoint can return both destination stations and duplicate
/// travel orders even when terminus_line_id is supplied. Filter defensively.
List<TransitArrival> selectTransitArrivals(
  List<TransitArrival> rows, {
  required int lineId,
  required int destinationId,
  required DateTime now,
}) {
  final trips = <int, TransitArrival>{};
  for (final row in rows) {
    if (row.lineId != lineId ||
        row.destinationStation != destinationId ||
        row.expectedAt.isBefore(now.toUtc())) {
      continue;
    }
    final old = trips[row.tripId];
    if (old == null || row.expectedAt.isBefore(old.expectedAt)) {
      trips[row.tripId] = row;
    }
  }
  return trips.values.toList()
    ..sort((a, b) => a.expectedAt.compareTo(b.expectedAt));
}

/// Sarajevo local civil time, independent of the user's phone timezone.
/// Bosnia uses EU DST boundaries (last Sunday of March/October at 01:00 UTC).
DateTime sarajevoTime(DateTime instant) {
  final utc = instant.toUtc();
  DateTime boundary(int month) {
    final last = DateTime.utc(utc.year, month + 1, 0, 1);
    return last.subtract(Duration(days: last.weekday % 7));
  }

  final dst = !utc.isBefore(boundary(3)) && utc.isBefore(boundary(10));
  return utc.add(Duration(hours: dst ? 2 : 1));
}

class TransitDeparture {
  final String time;
  final List<int> weekdays;
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool holidays;
  final bool receivesPassengers;
  const TransitDeparture({
    required this.time,
    required this.weekdays,
    this.validFrom,
    this.validTo,
    required this.holidays,
    required this.receivesPassengers,
  });
  factory TransitDeparture.fromJson(Map<String, dynamic> json) =>
      TransitDeparture(
        time: json['start_time'] as String,
        weekdays: (json['days_of_week'] as List)
            .map((e) => (e as num).toInt())
            .toList(),
        validFrom: DateTime.tryParse(json['valid_from'] as String? ?? ''),
        validTo: DateTime.tryParse(json['valid_to'] as String? ?? ''),
        holidays: json['rides_on_holidays'] == true,
        receivesPassengers: json['receives_passengers'] == true,
      );
  bool validOn(DateTime instant, {required bool holiday}) {
    final day = sarajevoTime(instant);
    final date = DateTime.utc(day.year, day.month, day.day);
    DateTime dateOf(DateTime value) {
      final local = sarajevoTime(value);
      return DateTime.utc(local.year, local.month, local.day);
    }

    return receivesPassengers &&
        (holiday ? holidays : weekdays.contains(day.weekday)) &&
        (validFrom == null || !date.isBefore(dateOf(validFrom!))) &&
        (validTo == null || !date.isAfter(dateOf(validTo!)));
  }
}
