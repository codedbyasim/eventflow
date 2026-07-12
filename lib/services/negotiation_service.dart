import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'backend_service.dart';

final negotiationServiceProvider = Provider((ref) => NegotiationService());

class NegotiationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // Vendor actions: write to Firestore first, then notify the backend so the
  // Negotiation Agent can process the reply (FR-VND-03).
  //
  // Option B webhook pattern:
  //   1. Write to Firestore (realtime mirror for live UI)
  //   2. Call POST /negotiations/{id}/vendor-reply (re-invokes the agent)
  //
  // If step 2 fails (app killed, network loss), the reconciliation job
  // in the backend will pick it up within 60 seconds (NFR-REL-01/02).
  // ─────────────────────────────────────────────────────────────────────────

  /// Used by vendor when accepting the agent's current offer. (FR-VND-02)
  Future<void> acceptOffer(
    String negotiationId,
    String eventId,
    String vendorId,
    double amount, {
    String? firestoreNegotiationId, // Firestore doc ID (may differ from Postgres UUID)
  }) async {
    final batch = _db.batch();
    final negRef = _db.collection('negotiations').doc(negotiationId);

    batch.update(negRef, {
      'status': 'deal',
      'finalPrice': amount,
      'closedAt': FieldValue.serverTimestamp(),
      'isVendorTurn': false,
      'lastActivity': FieldValue.serverTimestamp(),
    });

    final msgId = _db.collection('negotiations').doc(negotiationId).collection('messages').doc().id;
    batch.set(
      negRef.collection('messages').doc(msgId),
      {
        'sender': 'vendor',
        'content': 'Accepted your offer.',
        'offerAmount': amount,
        'messageType': 'accept',
        'timestamp': FieldValue.serverTimestamp(),
      },
    );

    batch.update(
      _db.collection('events').doc(eventId).collection('negotiations').doc(vendorId),
      {'status': 'deal', 'finalPrice': amount},
    );

    await batch.commit();

    // FR-VND-03: notify backend so agent can confirm the deal
    await _notifyBackend(
      negotiationId: firestoreNegotiationId ?? negotiationId,
      messageId: msgId,
      messageType: 'accept',
      offerAmount: amount.toInt(),
    );
  }

  /// Mark negotiation expired (called by timeout logic in UI).
  Future<void> markExpired(String negotiationId) async {
    await _db.collection('negotiations').doc(negotiationId).update({
      'status': 'expired',
      'expiredAt': FieldValue.serverTimestamp(),
    });
  }

  /// Vendor submits a counter-offer. (FR-VND-02)
  Future<void> submitCounterOffer(
    String negotiationId,
    double amount,
    String note, {
    String? firestoreNegotiationId,
  }) async {
    final negRef = _db.collection('negotiations').doc(negotiationId);
    final msgId = negRef.collection('messages').doc().id;

    // 1. Perform Firestore writes first so the states are in sync when the agent runs
    final batch = _db.batch();

    batch.set(
      negRef.collection('messages').doc(msgId),
      {
        'sender': 'vendor',
        'content': note,
        'offerAmount': amount,
        'messageType': 'counter',
        'timestamp': FieldValue.serverTimestamp(),
      },
    );

    batch.update(negRef, {
      'currentOffer': amount,
      'isVendorTurn': false,
      'offerCount': FieldValue.increment(1),
      'lastActivity': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // 2. Notify backend to trigger the agent's turn
    await _notifyBackend(
      negotiationId: firestoreNegotiationId ?? negotiationId,
      messageId: msgId,
      messageType: 'counter',
      content: note,
      offerAmount: amount.toInt(),
    );
  }

  /// Vendor rejects the negotiation. (FR-VND-02)
  Future<void> rejectNegotiation(
    String negotiationId, {
    String? firestoreNegotiationId,
  }) async {
    final batch = _db.batch();
    final negRef = _db.collection('negotiations').doc(negotiationId);

    batch.update(negRef, {
      'status': 'no_deal',
      'closedAt': FieldValue.serverTimestamp(),
      'isVendorTurn': false,
    });

    final msgId = negRef.collection('messages').doc().id;
    batch.set(
      negRef.collection('messages').doc(msgId),
      {
        'sender': 'vendor',
        'content': 'Offer rejected.',
        'messageType': 'reject',
        'timestamp': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    // FR-VND-03: notify backend (agent will log and stop negotiation)
    try {
      await _notifyBackend(
        negotiationId: firestoreNegotiationId ?? negotiationId,
        messageId: msgId,
        messageType: 'reject',
      );
    } catch (e) {
      // ignore: avoid_print
      print('[NegotiationService] Reject backend sync failed: $e');
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Call POST /negotiations/{id}/vendor-reply to re-invoke the agent.
  /// FR-VND-03. Swallows errors — the reconciliation job is the safety net.
  Future<void> _notifyBackend({
    required String negotiationId,
    required String messageId,
    required String messageType,
    String? content,
    int? offerAmount,
  }) async {
    final body = <String, dynamic>{
      'message_id': messageId,
      'message_type': messageType,
      if (content != null) 'content': content,
      if (offerAmount != null) 'offer_amount': offerAmount,
    };
    await BackendService.instance.post(
      '/negotiations/$negotiationId/vendor-reply',
      body: body,
    );
  }
}
