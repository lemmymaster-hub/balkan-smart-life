class BslLocationResult {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final bool isFromCache;
  final String city;
  final String municipality;
  final String country;

  const BslLocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.isFromCache,
    this.city = '',
    this.municipality = '',
    this.country = '',
  });

  bool get hasResolvedPlace =>
      city.isNotEmpty || municipality.isNotEmpty || country.isNotEmpty;

  String get displayLabel {
    if (city.isNotEmpty) return city;
    if (municipality.isNotEmpty) return municipality;
    if (country.isNotEmpty) return country;
    return isFromCache ? 'Posljednja poznata lokacija' : 'Trenutna lokacija';
  }

  BslLocationResult copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? timestamp,
    bool? isFromCache,
    String? city,
    String? municipality,
    String? country,
  }) {
    return BslLocationResult(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      isFromCache: isFromCache ?? this.isFromCache,
      city: city ?? this.city,
      municipality: municipality ?? this.municipality,
      country: country ?? this.country,
    );
  }
}
