import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallet_demo_models.dart';

abstract interface class WalletDemoStore {
  Future<WalletDemoSnapshot?> load({required String userId});

  Future<void> save({
    required String userId,
    required WalletDemoSnapshot snapshot,
  });

  Future<void> clear({required String userId});
}

class SharedPreferencesWalletDemoStore implements WalletDemoStore {
  SharedPreferencesWalletDemoStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const _storageKeyPrefix = 'bsl.wallet.demo.v1';

  final Future<SharedPreferences> Function() _preferencesLoader;

  @override
  Future<WalletDemoSnapshot?> load({required String userId}) async {
    final preferences = await _preferencesLoader();
    final rawSnapshot = preferences.getString(_storageKey(userId));
    if (rawSnapshot == null || rawSnapshot.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(rawSnapshot);
      if (decoded is! Map) return null;
      return WalletDemoSnapshot.fromMap(Map<String, dynamic>.from(decoded));
    } on Object {
      // Oštećen ili ručno izmijenjen demo zapis ne smije srušiti novčanik.
      await preferences.remove(_storageKey(userId));
      return null;
    }
  }

  @override
  Future<void> save({
    required String userId,
    required WalletDemoSnapshot snapshot,
  }) async {
    final preferences = await _preferencesLoader();
    await preferences.setString(
      _storageKey(userId),
      jsonEncode(snapshot.toMap()),
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
