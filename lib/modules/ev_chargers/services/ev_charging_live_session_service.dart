import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ev_charging_session.dart';

class EvChargingLiveSessionService {
  EvChargingLiveSessionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const collectionName = 'ev_active_charging_sessions';

  final FirebaseFirestore _firestore;

  Stream<EvChargingSession?> watchForUser(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return Stream.value(null);

    return _firestore
        .collection(collectionName)
        .doc(normalizedUserId)
        .snapshots()
        .map((document) {
          final data = document.data();
          if (!document.exists || data == null) return null;

          return parseDocument(documentId: document.id, data: data);
        });
  }

  static EvChargingSession parseDocument({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final normalized = Map<String, dynamic>.from(data);
    normalized['id'] ??= normalized['sessionId'] ?? documentId;

    for (final field in const [
      'startedAt',
      'updatedAt',
      'endedAt',
      'stoppedAt',
    ]) {
      final value = normalized[field];
      if (value is Timestamp) normalized[field] = value.toDate();
    }

    return EvChargingSession.fromMap(
      normalized,
      forcedSource: EvChargingSessionSource.operatorLive,
    );
  }
}
