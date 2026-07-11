import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Model representing a past event.
class CustomerEvent {
  final String eventId;
  final String firestoreId;
  final String type;
  final String? city;
  final String? eventDate;
  final int totalBudget;
  final String status;
  final Map<String, dynamic>? package;
  final DateTime createdAt;

  const CustomerEvent({
    required this.eventId,
    required this.firestoreId,
    required this.type,
    this.city,
    this.eventDate,
    required this.totalBudget,
    required this.status,
    this.package,
    required this.createdAt,
  });

  factory CustomerEvent.fromFirestore(Map<String, dynamic> data, String docId) {
    return CustomerEvent(
      eventId: docId,
      firestoreId: docId,
      type: data['type'] as String? ?? 'Event',
      city: data['city'] as String?,
      eventDate: data['eventDate'] as String?,
      totalBudget: (data['totalBudget'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'draft',
      package: data['package'] as Map<String, dynamic>?,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Riverpod provider: streams all events for the current customer.
/// FR-USR-01: customer can view their event history.
/// Performs sorting locally to avoid the need for composite indexes.
final customerEventsProvider = StreamProvider.autoDispose<List<CustomerEvent>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('events')
      .where('customerId', isEqualTo: uid)
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((doc) => CustomerEvent.fromFirestore(
                  doc.data(),
                  doc.id,
                ))
            .toList();
        // Sort locally by createdAt descending (newest first)
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
});
