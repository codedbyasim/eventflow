import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VendorBooking {
  final String negotiationId;
  final String eventId;
  final String eventType;
  final DateTime eventDate;
  final String city;
  final int guestCount;
  final double finalPrice;
  final String customerFirstName;
  final String? customerNote;
  final DateTime bookedAt;
  final String bookingStatus;

  VendorBooking({
    required this.negotiationId,
    required this.eventId,
    required this.eventType,
    required this.eventDate,
    required this.city,
    required this.guestCount,
    required this.finalPrice,
    required this.customerFirstName,
    this.customerNote,
    required this.bookedAt,
    required this.bookingStatus,
  });

  factory VendorBooking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final eventDate = (data['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    // Normalize today to start of day for accurate >= today checking
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedEventDate = DateTime(eventDate.year, eventDate.month, eventDate.day);
    
    final bookingStatus = normalizedEventDate.isBefore(normalizedToday) ? 'completed' : 'upcoming';

    return VendorBooking(
      negotiationId: doc.id,
      eventId: data['eventId'] as String? ?? '',
      eventType: data['eventType'] as String? ?? 'other',
      eventDate: eventDate,
      city: data['city'] as String? ?? '',
      guestCount: data['guestCount'] as int? ?? 0,
      finalPrice: (data['finalPrice'] ?? 0.0).toDouble(),
      customerFirstName: data['customerFirstName'] as String? ?? 'Customer',
      customerNote: data['customerNote'] as String?,
      bookedAt: (data['closedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bookingStatus: bookingStatus,
    );
  }
}

final vendorBookingsProvider = StreamProvider.family<List<VendorBooking>, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('negotiations')
      .where('vendorFirebaseUid', isEqualTo: uid)
      .where('status', isEqualTo: 'deal')
      .snapshots()
      .map((snapshot) {
        final bookings = snapshot.docs.map((doc) => VendorBooking.fromFirestore(doc)).toList();
        // Sort locally by bookedAt (closedAt) descending
        bookings.sort((a, b) => b.bookedAt.compareTo(a.bookedAt));
        return bookings;
      });
});
