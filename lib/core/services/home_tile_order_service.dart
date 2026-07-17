import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeTileOrderService {
  HomeTileOrderService({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String _storageKeyPrefix = 'bsl.home.tile_order.v1';

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<List<String>> loadOrder({
    required String userId,
    required List<String> availableIds,
  }) async {
    final preferences = await _preferencesLoader();
    final key = _storageKey(userId);
    final storedIds = preferences.getStringList(key) ?? const <String>[];
    final reconciledIds = reconcileOrder(
      storedIds: storedIds,
      availableIds: availableIds,
    );

    if (!listEquals(storedIds, reconciledIds)) {
      await preferences.setStringList(key, reconciledIds);
    }

    return reconciledIds;
  }

  Future<void> saveOrder({
    required String userId,
    required List<String> orderedIds,
    required List<String> availableIds,
  }) async {
    final preferences = await _preferencesLoader();
    final reconciledIds = reconcileOrder(
      storedIds: orderedIds,
      availableIds: availableIds,
    );

    await preferences.setStringList(_storageKey(userId), reconciledIds);
  }

  Future<void> resetOrder({required String userId}) async {
    final preferences = await _preferencesLoader();
    await preferences.remove(_storageKey(userId));
  }

  @visibleForTesting
  static List<String> reconcileOrder({
    required List<String> storedIds,
    required List<String> availableIds,
  }) {
    final availableIdSet = availableIds.toSet();
    final seenIds = <String>{};
    final result = <String>[];

    for (final id in storedIds) {
      if (availableIdSet.contains(id) && seenIds.add(id)) {
        result.add(id);
      }
    }

    for (final id in availableIds) {
      if (seenIds.add(id)) {
        result.add(id);
      }
    }

    return result;
  }

  String _storageKey(String userId) {
    final normalizedUserId = userId.trim().isEmpty ? 'guest' : userId.trim();
    return '$_storageKeyPrefix.$normalizedUserId';
  }
}
