import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/customer_events_provider.dart';
import '../negotiation/best_combination_screen.dart';
import '../negotiation/live_dashboard_screen.dart';
import '../../models/event_setup_model.dart';

/// Shows full detail of a past event, including the AI-generated package if available.
/// FR-USR-01: Customer can review their event history and accepted packages.
class EventDetailScreen extends StatelessWidget {
  final CustomerEvent event;
  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isUrdu = context.isUrdu;
    final pkg = event.package;

    return Directionality(
      textDirection: loc.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F7F2),
        body: CustomScrollView(
          slivers: [
            // ── Sticky header ─────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: AppColors.goldenBrown,
              leading: IconButton(
                icon: Icon(
                  isUrdu ? Icons.arrow_forward : Icons.arrow_back,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF7A4E1E),
                        AppColors.goldenBrown,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 48, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            event.type,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (event.city != null && event.city!.isNotEmpty)
                                event.city!.substring(0, 1).toUpperCase() +
                                    event.city!.substring(1),
                              if (event.eventDate != null) event.eventDate!,
                            ].join(' · '),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Event overview ─────────────────────────────────────
                    _SectionCard(
                      children: [
                        _InfoRow(
                          icon: Icons.account_balance_wallet_outlined,
                          label: loc.get('budget_label'),
                          value: 'PKR ${NumberFormat('#,###').format(event.totalBudget)}',
                          valueDirection: TextDirection.ltr,
                        ),
                        const Divider(height: 24, color: Color(0xFFF0F0F0)),
                        _InfoRow(
                          icon: Icons.timeline,
                          label: loc.get('status'),
                          value: event.status.replaceAll('_', ' ').toUpperCase(),
                          valueColor: _statusColor(event.status),
                        ),
                      ],
                    ),

                    if (['negotiating', 'matching', 'analyzing', 'draft'].contains(event.status)) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.goldenBrown,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.handshake_outlined, color: Colors.white),
                          label: Text(
                            loc.language == AppLanguage.urdu ? 'لائیو مذاکرات دیکھیں' : 'View Live Negotiations',
                            style: loc.fontStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LiveDashboardScreen(
                                  model: EventSetupModel(
                                    eventType: event.type,
                                    totalBudget: event.totalBudget,
                                    city: event.city,
                                    eventDate: event.eventDate != null ? DateTime.tryParse(event.eventDate!) : null,
                                    selectedVendors: const [],
                                  ),
                                  allocations: const {},
                                  eventFirestoreId: event.firestoreId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // ── Package section (if aggregator has finished) ───────
                    if (pkg != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        loc.get('ai_package'),
                        style: loc.fontStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Savings banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF3E1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.savings_outlined,
                                color: AppColors.mossGreen, size: 28),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PKR ${NumberFormat('#,###').format((pkg['total_savings'] as num?)?.toInt() ?? 0)}',
                                  textDirection: TextDirection.ltr,
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2E3D26),
                                  ),
                                ),
                                Text(
                                  '${((pkg['savings_percentage'] as num?)?.toStringAsFixed(1) ?? '0')}% saved vs asking prices',
                                  style: loc.fontStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF4A6A35)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Vendor list from package
                      _SectionCard(
                        children: [
                          ...(
                            (pkg['best_vendors'] as Map<String, dynamic>? ?? {}).entries.map(
                              (entry) {
                                final v = entry.value as Map<String, dynamic>;
                                final askingPrice = (v['asking_price'] as num?)?.toInt() ?? 0;
                                final finalPrice = (v['final_price'] as num?)?.toInt() ?? askingPrice;
                                final savings = askingPrice - finalPrice;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40, height: 40,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF0F3EF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.store_outlined,
                                            color: Color(0xFF2E3D26), size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              v['business_name'] as String? ?? entry.key,
                                              style: loc.fontStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            Text(
                                              entry.key,
                                              style: loc.fontStyle(
                                                  fontSize: 11,
                                                  color: const Color(0xFF888888)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'PKR ${NumberFormat('#,###').format(finalPrice)}',
                                            textDirection: TextDirection.ltr,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          if (savings > 0)
                                            Text(
                                              '-${NumberFormat('#,###').format(savings)}',
                                              textDirection: TextDirection.ltr,
                                              style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  color: AppColors.mossGreen),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ).toList()
                          ),
                        ],
                      ),

                      // View full package button
                      if (event.status == 'ready' || event.status == 'booked') ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.goldenBrown,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25)),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BestCombinationScreen(
                                  eventFirestoreId: event.firestoreId,
                                  eventBudget: event.totalBudget.toDouble(),
                                  eventType: event.type,
                                  eventDate: event.eventDate ?? '',
                                  city: event.city ?? '',
                                ),
                              ),
                            ),
                            child: Text(
                              loc.get('view_full_package'),
                              style: loc.fontStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'booked':    return AppColors.mossGreen;
      case 'ready':     return const Color(0xFF4A90D9);
      case 'cancelled': return AppColors.strawRed;
      default:          return AppColors.goldenBrown;
    }
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final TextDirection? valueDirection;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueDirection,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.goldenBrown),
        const SizedBox(width: 10),
        Text(label,
            style: loc.fontStyle(
                fontSize: 13, color: const Color(0xFF666666))),
        const Spacer(),
        Text(
          value,
          textDirection: valueDirection,
          style: loc.fontStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}
