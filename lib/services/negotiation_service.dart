import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final negotiationServiceProvider = Provider((ref) => NegotiationService());

class NegotiationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Used by both V-04 (quick accept) and V-05 (full accept)
  Future<void> acceptOffer(
    String negotiationId,
    String eventId,
    String vendorId,
    double amount,
  ) async {
    final batch = _db.batch();

    batch.update(
      _db.collection('negotiations').doc(negotiationId),
      {
        'status': 'deal',
        'finalPrice': amount,
        'closedAt': FieldValue.serverTimestamp(),
        'isVendorTurn': false,
      },
    );

    batch.set(
      _db.collection('negotiations').doc(negotiationId).collection('messages').doc(),
      {
        'sender': 'vendor',
        'content': 'accept',
        'offerAmount': amount,
        'messageType': 'accept',
        'timestamp': FieldValue.serverTimestamp(),
      },
    );

    batch.update(
      _db.collection('events').doc(eventId).collection('negotiations').doc(vendorId),
      {
        'status': 'deal',
        'finalPrice': amount,
      },
    );

    await batch.commit();
  }

  // Used by V-04 background expiry marking
  Future<void> markExpired(String negotiationId) async {
    await _db.collection('negotiations').doc(negotiationId).update({
      'status': 'expired',
      'expiredAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitCounterOffer(String negotiationId, double amount, String note) async {
    final batch = _db.batch();

    batch.set(
      _db.collection('negotiations').doc(negotiationId).collection('messages').doc(),
      {
        'sender': 'vendor',
        'content': note,
        'offerAmount': amount,
        'messageType': 'counter',
        'timestamp': FieldValue.serverTimestamp(),
      },
    );

    batch.update(
      _db.collection('negotiations').doc(negotiationId),
      {
        'currentOffer': amount,
        'isVendorTurn': false,
        'offerCount': FieldValue.increment(1),
        'lastActivity': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  Future<void> rejectNegotiation(String negotiationId) async {
    final batch = _db.batch();

    batch.update(
      _db.collection('negotiations').doc(negotiationId),
      {
        'status': 'no_deal',
        'closedAt': FieldValue.serverTimestamp(),
        'isVendorTurn': false,
      },
    );

    batch.set(
      _db.collection('negotiations').doc(negotiationId).collection('messages').doc(),
      {
        'sender': 'vendor',
        'content': 'reject',
        'messageType': 'reject',
        'timestamp': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }
}
