import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ev_charging_session.dart';

abstract interface class EvChargingSessionStore {
  Future<EvChargingSession?> load({required String userId});

  Future<void> save({
    required String userId,
    required EvChargingSession session,
  });

  Future<void> clear({required String userId});
}

class SharedPreferencesEvChargingSessionStore
    implements EvChargingSessionStore {
  SharedPreferencesEvChargingSessionStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const _storageKeyPrefix = 'bsl.ev.estimated_charging_session.v1';

  final Future<SharedPreferences> Function() _preferencesLoader;

  @override
  Future<EvChargingSession?> load({required String userId}) async {
    final preferences = await _preferencesLoader();
    final rawSession = preferences.getString(_storageKey(userId));
    if (rawSession == null || rawSession.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map) return null;

      final session = EvChargingSession.fromMap(
        Map<String, dynamic>.from(decoded),
      );
      return session.isEstimated ? session : null;
    } on FormatException {
      await preferences.remove(_storageKey(userId));
      return null;
    }
  }

  @override
  Future<void> save({
    required String userId,
    required EvChargingSession session,
  }) async {
    final preferences = await _preferencesLoader();
    await preferences.setString(
      _storageKey(userId),
      jsonEncode(session.toMap()),
    );
  }

  @override
  Future<void> clear({required String userId}) async {
    final preferences = await _preferencesLoader();
    await preferences.remove(_storageKey(userId));
  }

  String _storageKey(String userId) {
    final normalizedUserId = userId.trim().isEmpty ? 'guest' : userId.trim();
    return '$_storageKeyPrefix.$normalizedUserId';
  }
}
