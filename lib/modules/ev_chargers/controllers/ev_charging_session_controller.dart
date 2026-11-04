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
  bool _disposed = false;
  bool _saving = false;

  EvChargingSession? get displaySession {
    if (_liveSession?.isActive == true) return _liveSession;
    return _estimatedSession ?? _liveSession;
  }
  EvChargingSession? get activeSession {
    final session = displaySession;
    return session?.isActive == true ? session : null;
  }

  DateTime get currentTime => _currentTime;
  bool get isInitialized => _isInitialized;
  bool get hasOperatorSession => _liveSession != null;

  Future<void> initialize({required String userId}) async {
    _userId = userId.trim().isEmpty ? 'guest' : userId.trim();
    final session = await _store.load(userId: _userId);
    if (_disposed) return;
    _estimatedSession = session;
    _currentTime = _now();
    _isInitialized = true;
    _syncTicker();
    notifyListeners();
  }

  void setLiveSession(EvChargingSession? session) {
    if (_disposed) return;
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
    if (powerKw == null || !powerKw.isFinite || powerKw <= 0) {
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

    await _saveEstimated(session);
  }

  Future<void> completeEstimated() async {
    final session = _estimatedSession;
    if (session == null || !session.isActive) return;

    await _saveEstimated(session.complete(_now()));
  }

  Future<void> dismissEstimated() => _saveEstimated(null);

  Future<void> _saveEstimated(EvChargingSession? session) async {
    if (_disposed) return;
    if (_saving) {
      throw const EvChargingSessionException('Sačekaj da se sesija sačuva.');
    }
    _saving = true;
    try {
      if (session == null) {
        await _store.clear(userId: _userId);
      } else {
        await _store.save(userId: _userId, session: session);
      }
    } catch (error) {
      debugPrint('EV CHARGING SESSION SAVE ERROR: $error');
      throw const EvChargingSessionException('Sesija punjenja nije sačuvana.');
    } finally {
      _saving = false;
    }
    if (_disposed) return;
    _estimatedSession = session;
    _currentTime = _now();
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
    _disposed = true;
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
