import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ev_charger.dart';
import '../models/ev_charging_session.dart';
import '../services/ev_charging_session_store.dart';

class EvChargingSessionController extends ChangeNotifier {
  factory EvChargingSessionController({
    EvChargingSessionStore? store,
    DateTime Function()? now,
    bool enableTicker = true,
  }) {
    return EvChargingSessionController._(
      store ?? SharedPreferencesEvChargingSessionStore(),
      now ?? DateTime.now,
      enableTicker,
    );
  }

  EvChargingSessionController._(this._store, this._now, this._enableTicker);

  final EvChargingSessionStore _store;
  final DateTime Function() _now;
  final bool _enableTicker;

  EvChargingSession? _estimatedSession;
  EvChargingSession? _liveSession;
  Timer? _ticker;
  String _userId = 'guest';
  DateTime _currentTime = DateTime.now();
  bool _isInitialized = false;

  EvChargingSession? get displaySession => _liveSession ?? _estimatedSession;
  EvChargingSession? get activeSession {
    final session = displaySession;
    return session?.isActive == true ? session : null;
  }

  DateTime get currentTime => _currentTime;
  bool get isInitialized => _isInitialized;
  bool get hasOperatorSession => _liveSession != null;

  Future<void> initialize({required String userId}) async {
    _userId = userId.trim().isEmpty ? 'guest' : userId.trim();
    _estimatedSession = await _store.load(userId: _userId);
    _currentTime = _now();
    _isInitialized = true;
    _syncTicker();
    notifyListeners();
  }

  void setLiveSession(EvChargingSession? session) {
    if (session != null && session.isEstimated) {
      throw const EvChargingSessionException(
        'Live kanal je vratio procijenjenu sesiju.',
      );
    }

    _liveSession = session;
    _currentTime = _now();
    _syncTicker();
    notifyListeners();
  }

  Future<void> startEstimated({
    required EvCharger charger,
    required EvConnector connector,
  }) async {
    final powerKw = connector.powerKw;
    if (powerKw == null || powerKw <= 0) {
      throw const EvChargingSessionException(
        'Za ovaj priključak nije poznata nazivna snaga.',
      );
    }

    final currentActive = activeSession;
    if (currentActive != null) {
      throw EvChargingSessionException(
        currentActive.source == EvChargingSessionSource.operatorLive
            ? 'Operator već prijavljuje aktivnu sesiju.'
            : 'Već pratiš jedno punjenje. Prvo ga završi.',
      );
    }

    final now = _now();
    final session = EvChargingSession(
      id: 'estimated_${now.microsecondsSinceEpoch}',
      chargerId: charger.id,
      chargerName: charger.name,
      city: charger.city,
      connectorLabel: connector.type,
      source: EvChargingSessionSource.estimated,
      status: EvChargingSessionStatus.charging,
      startedAt: now,
      updatedAt: now,
      ratedPowerKw: powerKw,
      powerKw: powerKw,
      message: 'Procjena prema nazivnoj snazi priključka.',
    );

    _estimatedSession = session;
    _currentTime = now;
    await _store.save(userId: _userId, session: session);
    _syncTicker();
    notifyListeners();
  }

  Future<void> completeEstimated() async {
    final session = _estimatedSession;
    if (session == null || !session.isActive) return;

    final now = _now();
    final completed = session.complete(now);
    _estimatedSession = completed;
    _currentTime = now;
    await _store.save(userId: _userId, session: completed);
    _syncTicker();
    notifyListeners();
  }

  Future<void> dismissEstimated() async {
    _estimatedSession = null;
    await _store.clear(userId: _userId);
    _syncTicker();
    notifyListeners();
  }

  bool hasSessionFor(String chargerId) {
    return displaySession?.chargerId == chargerId;
  }

  void _syncTicker() {
    final shouldTick = _enableTicker && displaySession?.isActive == true;

    if (!shouldTick) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }

    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _currentTime = _now();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

class EvChargingSessionException implements Exception {
  final String message;

  const EvChargingSessionException(this.message);

  @override
  String toString() => message;
}
