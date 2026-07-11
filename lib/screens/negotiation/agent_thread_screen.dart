import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_colors.dart';
import '../../core/localization/language_provider.dart';

/// Shows the full agent ↔ vendor message thread for a single negotiation.
/// NFR-USE-02: agent messages and vendor messages are visually distinct.
/// FR-NEG-04: every action and vendor response is displayed here.
class AgentThreadScreen extends StatelessWidget {
  final String vendorName;
  final String negotiationFirestoreId;

  const AgentThreadScreen({
    super.key,
    required this.vendorName,
    required this.negotiationFirestoreId,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isUrdu = context.isUrdu;

    return Directionality(
      textDirection: loc.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F7F2),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F3EB),
          elevation: 0,
          leading: IconButton(
            icon: Icon(isUrdu ? Icons.arrow_forward : Icons.arrow_back,
                color: const Color(0xFF7A4E1E)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment:
                isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(vendorName,
                  style: loc.fontStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A))),
              Text('Negotiation Thread',
                  style: loc.fontStyle(
                      fontSize: 11, color: const Color(0xFF888888))),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('negotiations')
              .doc(negotiationFirestoreId)
              .collection('messages')
              .orderBy('timestamp', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child:
                    CircularProgressIndicator(color: AppColors.goldenBrown),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text('No messages yet…',
                    style: loc.fontStyle(
                        fontSize: 14, color: const Color(0xFF888888))),
              );
            }

            final docs = snapshot.data!.docs;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                return _MessageBubble(data: data, loc: loc, isUrdu: isUrdu);
              },
            );
          },
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final dynamic loc;
  final bool isUrdu;

  const _MessageBubble(
      {required this.data, required this.loc, required this.isUrdu});

  @override
  Widget build(BuildContext context) {
    final sender = data['sender'] as String? ?? 'system';
    final content = data['content'] as String? ?? '';
    final messageType = data['messageType'] as String? ?? 'offer';
    final offerAmount = data['offerAmount'] as num?;
    final isAgent = sender == 'agent';
    final isSystem = sender == 'system';

    Color bubbleColor;
    Color textColor;
    Alignment alignment;
    IconData? icon;

    if (isSystem) {
      bubbleColor = const Color(0xFFF0F0F0);
      textColor = const Color(0xFF888888);
      alignment = Alignment.center;
    } else if (isAgent) {
      // NFR-USE-02: agent messages — left aligned, golden-tinted
      bubbleColor = const Color(0xFFFFF8F0);
      textColor = const Color(0xFF7A4E1E);
      alignment = isUrdu ? Alignment.centerRight : Alignment.centerLeft;
      icon = Icons.smart_toy_outlined;
    } else {
      // Vendor messages — right aligned, green-tinted
      bubbleColor = const Color(0xFFEDF3E1);
      textColor = const Color(0xFF2E3D26);
      alignment = isUrdu ? Alignment.centerLeft : Alignment.centerRight;
      icon = Icons.person_outline;
    }

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAgent
                ? const Color(0xFFE8C49A)
                : isSystem
                    ? Colors.transparent
                    : const Color(0xFFBDD19A),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isSystem ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            if (!isSystem)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 12, color: textColor),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    isAgent ? 'AI Agent' : 'Vendor',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  if (offerAmount != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PKR ${NumberFormat('#,###').format(offerAmount.toInt())}',
                        textDirection: TextDirection.ltr,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            if (!isSystem) const SizedBox(height: 4),
            Text(
              content,
              style: loc.fontStyle(fontSize: 13, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
