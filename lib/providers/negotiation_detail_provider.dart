import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NegotiationDetail {
  final String negotiationId;
  final String vendorId;
  final String eventId;
  final String eventType;
  final DateTime eventDate;
  final String city;
  final int guestCount;
  final String requirement;
  final double budgetAllocated;
  final double vendorBasePrice;
  final double currentOffer;
  final String status;
  final bool isVendorTurn;
  final int offerCount;
  final double? finalPrice;

  NegotiationDetail({
    required this.negotiationId,
    required this.vendorId,
    required this.eventId,
    required this.eventType,
    required this.eventDate,
    required this.city,
    required this.guestCount,
    required this.requirement,
    required this.budgetAllocated,
    required this.vendorBasePrice,
    required this.currentOffer,
    required this.status,
    required this.isVendorTurn,
    required this.offerCount,
    this.finalPrice,
  });

  factory NegotiationDetail.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NegotiationDetail(
      negotiationId: doc.id,
      vendorId: data['vendorId'] as String? ?? '',
      eventId: data['eventId'] as String? ?? '',
      eventType: data['eventType'] as String? ?? 'other',
      eventDate: (data['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      city: data['city'] as String? ?? '',
      guestCount: data['guestCount'] as int? ?? 0,
      requirement: data['requirement'] as String? ?? '',
      budgetAllocated: (data['budgetAllocated'] ?? 0.0).toDouble(),
      vendorBasePrice: (data['vendorBasePrice'] ?? 0.0).toDouble(),
      currentOffer: (data['currentOffer'] ?? 0.0).toDouble(),
      status: data['status'] as String? ?? 'pending',
      isVendorTurn: data['isVendorTurn'] as bool? ?? false,
      offerCount: data['offerCount'] as int? ?? 1,
      finalPrice: data['finalPrice']?.toDouble(),
    );
  }
}

class NegotiationMessage {
  final String messageId;
  final String sender; // 'agent' | 'vendor'
  final String content;
  final double? offerAmount;
  final String messageType; // greeting/offer/counter/accept/reject
  final DateTime timestamp;

  NegotiationMessage({
    required this.messageId,
    required this.sender,
    required this.content,
    this.offerAmount,
    required this.messageType,
    required this.timestamp,
  });

  factory NegotiationMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NegotiationMessage(
      messageId: doc.id,
      sender: data['sender'] as String? ?? 'agent',
      content: data['content'] as String? ?? '',
      offerAmount: data['offerAmount']?.toDouble(),
      messageType: data['messageType'] as String? ?? 'offer',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

final negotiationDetailProvider = StreamProvider.family<NegotiationDetail, String>((ref, negotiationId) {
  return FirebaseFirestore.instance
      .collection('negotiations')
      .doc(negotiationId)
      .snapshots()
      .map((doc) => NegotiationDetail.fromFirestore(doc));
});

final negotiationMessagesProvider = StreamProvider.family<List<NegotiationMessage>, String>((ref, negotiationId) {
  return FirebaseFirestore.instance
      .collection('negotiations')
      .doc(negotiationId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => NegotiationMessage.fromFirestore(doc)).toList());
});
