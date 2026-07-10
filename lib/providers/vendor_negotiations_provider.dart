import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/negotiation_service.dart';

class NegotiationSummary {
  final String negotiationId;
  final String eventType;
  final String city;
  final int guestCount;
  final DateTime eventDate;
  final DateTime expiresAt;
  final double currentOffer;
  final double? finalPrice;
  final String status;
  final bool isMyTurn;
  final int offerCount;
  final DateTime lastActivity;
  final String eventId;

  NegotiationSummary({
    required this.negotiationId,
    required this.eventType,
    required this.city,
    required this.guestCount,
    required this.eventDate,
    required this.expiresAt,
    required this.currentOffer,
    this.finalPrice,
    required this.status,
    required this.isMyTurn,
    required this.offerCount,
    required this.lastActivity,
    required this.eventId,
  });

  factory NegotiationSummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NegotiationSummary(
      negotiationId: doc.id,
      eventType: data['eventType'] as String? ?? 'other',
      city: data['city'] as String? ?? '',
      guestCount: data['guestCount'] as int? ?? 0,
      eventDate: (data['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 2)),
      currentOffer: (data['currentOffer'] ?? 0.0).toDouble(),
      finalPrice: data['finalPrice']?.toDouble(),
      status: data['status'] as String? ?? 'pending',
      isMyTurn: data['isVendorTurn'] as bool? ?? false,
      offerCount: data['offerCount'] as int? ?? 1,
      lastActivity: (data['lastActivity'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventId: data['eventId'] as String? ?? '',
    );
  }
}

class VendorNegotiationsData {
  final List<NegotiationSummary> pendingList;
  final List<NegotiationSummary> activeList;
  final List<NegotiationSummary> closedList;

  VendorNegotiationsData({
    required this.pendingList,
    required this.activeList,
    required this.closedList,
  });
}

bool isExpired(NegotiationSummary n) {
  return n.status == 'pending' && DateTime.now().isAfter(n.expiresAt);
}

// Ensure background writes only trigger once per item
final Set<String> _alreadyMarked = {};

final vendorNegotiationsProvider = StreamProvider.family<VendorNegotiationsData, String>((ref, uid) {
  final query = FirebaseFirestore.instance
      .collection('negotiations')
      .where('vendorId', isEqualTo: uid);

  return query.snapshots().map((snapshot) {
    final pendingList = <NegotiationSummary>[];
    final activeList = <NegotiationSummary>[];
    final closedList = <NegotiationSummary>[];

    final service = ref.read(negotiationServiceProvider);

    for (var doc in snapshot.docs) {
      final item = NegotiationSummary.fromFirestore(doc);

      if (isExpired(item)) {
        if (!_alreadyMarked.contains(item.negotiationId)) {
          _alreadyMarked.add(item.negotiationId);
          service.markExpired(item.negotiationId).catchError((_) {});
        }
        closedList.add(item);
      } else {
        if (item.status == 'pending') {
          pendingList.add(item);
        } else if (item.status == 'active') {
          activeList.add(item);
        } else if (['deal', 'no_deal', 'expired'].contains(item.status)) {
          closedList.add(item);
        }
      }
    }

    // Sort locally by lastActivity descending
    int sortDesc(NegotiationSummary a, NegotiationSummary b) => b.lastActivity.compareTo(a.lastActivity);
    pendingList.sort(sortDesc);
    activeList.sort(sortDesc);
    closedList.sort(sortDesc);

    return VendorNegotiationsData(
      pendingList: pendingList,
      activeList: activeList,
      closedList: closedList,
    );
  });
});
