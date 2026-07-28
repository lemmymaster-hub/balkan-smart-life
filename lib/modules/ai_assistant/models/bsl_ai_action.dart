enum BslAiActionType { openParking, openEvChargers, openWeather, openWallet }

extension BslAiActionTypeWireName on BslAiActionType {
  String get wireName {
    switch (this) {
      case BslAiActionType.openParking:
        return 'open_parking';
      case BslAiActionType.openEvChargers:
        return 'open_ev_chargers';
      case BslAiActionType.openWeather:
        return 'open_weather';
      case BslAiActionType.openWallet:
        return 'open_wallet';
    }
  }

  String get defaultLabel {
    switch (this) {
      case BslAiActionType.openParking:
        return 'Otvori Parkiraj.ba';
      case BslAiActionType.openEvChargers:
        return 'Otvori EL Punjače';
      case BslAiActionType.openWeather:
        return 'Otvori vremensku prognozu';
      case BslAiActionType.openWallet:
        return 'Otvori novčanik';
    }
  }

  bool get canExecuteAutomatically {
    switch (this) {
      case BslAiActionType.openParking:
      case BslAiActionType.openEvChargers:
      case BslAiActionType.openWeather:
        return true;
      case BslAiActionType.openWallet:
        return false;
    }
  }

  static BslAiActionType? tryParse(String value) {
    for (final type in BslAiActionType.values) {
      if (type.wireName == value.trim()) return type;
    }
    return null;
  }
}

class BslAiAction {
  final BslAiActionType type;
  final String label;
  final Map<String, Object?> parameters;

  BslAiAction({
    required this.type,
    String? label,
    Map<String, Object?> parameters = const {},
  }) : label = _normalizedLabel(label, type),
       parameters = Map<String, Object?>.unmodifiable(parameters);

  String? get city => _nonEmptyString(parameters['city'], maxLength: 60);

  String? get query => _nonEmptyString(parameters['query'], maxLength: 160);

  bool get selectNearest => parameters['select_nearest'] == true;

  bool get useCurrentLocation => parameters['use_current_location'] == true;

  bool get canExecuteAutomatically => type.canExecuteAutomatically;

  Map<String, Object?> toJson() {
    return {'type': type.wireName, 'label': label, 'parameters': parameters};
  }

  static BslAiAction? tryFromJson(Object? value) {
    if (value is! Map) return null;

    final rawType = value['type']?.toString() ?? '';
    final type = BslAiActionTypeWireName.tryParse(rawType);
    if (type == null) return null;

    final rawParameters = value['parameters'];
    final parameters = _sanitizeParameters(rawParameters);

    return BslAiAction(
      type: type,
      label: value['label']?.toString(),
      parameters: parameters,
    );
  }

  static String _normalizedLabel(String? label, BslAiActionType type) {
    final normalized = label?.trim() ?? '';
    if (normalized.isEmpty || normalized.length > 80) {
      return type.defaultLabel;
    }
    return normalized;
  }

  static Map<String, Object?> _sanitizeParameters(Object? value) {
    if (value is! Map) return const {};

    final sanitized = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String ||
          (key != 'city' &&
              key != 'query' &&
              key != 'select_nearest' &&
              key != 'use_current_location')) {
        continue;
      }

      final parameterValue = entry.value;
      if (parameterValue is String || parameterValue is bool) {
        sanitized[key] = parameterValue;
      }
    }
    return sanitized;
  }

  static String? _nonEmptyString(Object? value, {required int maxLength}) {
    final normalized = value?.toString().trim() ?? '';
    if (normalized.isEmpty || normalized.length > maxLength) return null;
    return normalized;
  }
}
