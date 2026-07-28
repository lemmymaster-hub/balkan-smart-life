import 'bsl_ai_action.dart';

class BslAiRequestContext {
  final String city;
  final double? latitude;
  final double? longitude;
  final String locale;

  const BslAiRequestContext({
    required this.city,
    this.latitude,
    this.longitude,
    this.locale = 'bs',
  });

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, Object?> toJson() {
    return {
      'city': city,
      'locale': locale,
      'location': hasLocation
          ? {'latitude': latitude, 'longitude': longitude}
          : null,
      'supported_actions': BslAiActionType.values
          .map((type) => type.wireName)
          .toList(growable: false),
    };
  }
}
