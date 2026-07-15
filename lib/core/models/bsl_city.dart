class BslCity {
  final String name;
  final double latitude;
  final double longitude;
  final double mapZoom;

  const BslCity({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.mapZoom = 13.5,
  });
}

abstract final class BslCities {
  static const BslCity pale = BslCity(
    name: 'Pale',
    latitude: 43.8161,
    longitude: 18.5695,
  );

  static const List<BslCity> values = [
    BslCity(name: 'Sarajevo', latitude: 43.8563, longitude: 18.4131),
    BslCity(name: 'Banja Luka', latitude: 44.7722, longitude: 17.1910),
    BslCity(name: 'Mostar', latitude: 43.3438, longitude: 17.8078),
    BslCity(name: 'Tuzla', latitude: 44.5384, longitude: 18.6671),
    BslCity(name: 'Zenica', latitude: 44.2034, longitude: 17.9077),
    BslCity(name: 'Bihać', latitude: 44.8169, longitude: 15.8708),
    BslCity(name: 'Trebinje', latitude: 42.7119, longitude: 18.3436),
    pale,
    BslCity(name: 'Istočno Sarajevo', latitude: 43.8210, longitude: 18.3610),
  ];

  static BslCity byName(String? name) {
    return findExact(name ?? '') ?? pale;
  }

  static BslCity? findExact(String input) {
    final normalizedInput = normalize(input);

    for (final city in values) {
      if (normalize(city.name) == normalizedInput) return city;
    }

    return null;
  }

  static BslCity? findMentionedIn(String input) {
    final normalizedInput = ' ${normalize(input)} ';
    final citiesByLongestName = [...values]
      ..sort((a, b) => b.name.length.compareTo(a.name.length));

    for (final city in citiesByLongestName) {
      if (normalizedInput.contains(' ${normalize(city.name)} ')) return city;
    }

    return null;
  }

  static bool same(String first, String second) {
    return normalize(first) == normalize(second);
  }

  static String normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('š', 's')
        .replaceAll('ž', 'z')
        .replaceAll('đ', 'dj')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }
}
