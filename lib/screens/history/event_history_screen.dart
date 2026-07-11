import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../providers/customer_events_provider.dart';
import 'event_detail_screen.dart';

/// FR-USR-01: Customer event history screen.
/// Lists all events, grouped by status, streamed live from Firestore.
class EventHistoryScreen extends ConsumerWidget {
  const EventHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final eventsAsync = ref.watch(customerEventsProvider);

    return Directionality(
      textDirection: loc.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F7F2),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F3EB),
          elevation: 0,
          title: Text(
            loc.get('my_events'),
            style: loc.fontStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A)),
          ),
          leading: IconButton(
            icon: Icon(
              context.isUrdu ? Icons.arrow_forward : Icons.arrow_back,
              color: const Color(0xFF7A4E1E),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: eventsAsync.when(
          loading: () => const Center(
              child:
                  CircularProgressIndicator(color: AppColors.goldenBrown)),
          error: (e, _) => Center(
              child: Text('Could not load events: $e',
                  style: loc.fontStyle(
                      fontSize: 14, color: AppColors.strawRed))),
          data: (events) {
            if (events.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_note_outlined,
                        size: 64, color: Color(0xFFCCCCCC)),
                    const SizedBox(height: 16),
                    Text(
                      loc.get('no_events_yet'),
                      style: loc.fontStyle(
                          fontSize: 16, color: const Color(0xFF888888)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.get('start_planning'),
                      style: loc.fontStyle(
                          fontSize: 13, color: const Color(0xFFAAAAAA)),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: events.length,
              itemBuilder: (context, i) => _EventCard(event: events[i]),
            );
          },
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final CustomerEvent event;
  const _EventCard({required this.event});

  Color _statusColor(String status) {
    switch (status) {
      case 'booked':      return AppColors.mossGreen;
      case 'negotiating':
      case 'aggregating': return AppColors.goldenBrown;
      case 'ready':       return const Color(0xFF4A90D9);
      case 'cancelled':   return AppColors.strawRed;
      default:            return const Color(0xFF888888);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'booked':      return Icons.check_circle_outline;
      case 'ready':       return Icons.thumb_up_alt_outlined;
      case 'negotiating': return Icons.handshake_outlined;
      case 'cancelled':   return Icons.cancel_outlined;
      default:            return Icons.hourglass_top_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final statusColor = _statusColor(event.status);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status badge
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon(event.status),
                    color: statusColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.type,
                      style: loc.fontStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (event.city != null && event.city!.isNotEmpty)
                          event.city!.substring(0, 1).toUpperCase() +
                              event.city!.substring(1),
                        if (event.eventDate != null) event.eventDate!,
                      ].join(' · '),
                      style: loc.fontStyle(
                          fontSize: 12, color: const Color(0xFF888888)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'PKR ${NumberFormat('#,###').format(event.totalBudget)}',
                          textDirection: TextDirection.ltr,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF555555)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            event.status.replaceAll('_', ' ').toUpperCase(),
                            style: loc.fontStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                context.isUrdu ? Icons.chevron_left : Icons.chevron_right,
                color: const Color(0xFFCCCCCC),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
