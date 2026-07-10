import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/vendor_negotiations_provider.dart';
import '../../services/negotiation_service.dart';

class VendorInboxScreen extends ConsumerStatefulWidget {
  const VendorInboxScreen({super.key});

  @override
  ConsumerState<VendorInboxScreen> createState() => _VendorInboxScreenState();
}

class _VendorInboxScreenState extends ConsumerState<VendorInboxScreen> with TickerProviderStateMixin {
  Timer? _expiryTimer;
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Assuming initialTab might be passed via GoRouter later, we'll default to 0
    _tabController = TabController(length: 3, vsync: this);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _expiryTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => ref.invalidate(vendorNegotiationsProvider(user.uid)),
      );
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _showAcceptSheet(String negotiationId, String eventId, double amount) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('confirm_accept', args: [amount.toStringAsFixed(0)]),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('back'), style: GoogleFonts.inter(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.mossGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          ref.read(negotiationServiceProvider).acceptOffer(
                            negotiationId,
                            eventId,
                            user.uid,
                            amount,
                          );
                        }
                      },
                      child: Text(tr('yes'), style: GoogleFonts.inter(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String textKey, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            tr(textKey),
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildNewCard(NegotiationSummary n) {
    final remaining = n.expiresAt.difference(DateTime.now());
    
    Widget timeWidget;
    if (remaining.inMinutes > 60) {
      timeWidget = Text(
        tr('time_left', args: ['${remaining.inHours}h']),
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mossGreen),
      );
    } else if (remaining.inMinutes > 15) {
      timeWidget = Text(
        tr('time_left', args: ['${remaining.inMinutes}m']),
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.goldenBrown),
      );
    } else {
      timeWidget = ScaleTransition(
        scale: _pulseAnimation,
        child: Text(
          tr('expiring_soon'),
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.strawRed),
        ),
      );
    }

    final dateStr = DateFormat('MMM d, yyyy').format(n.eventDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr(n.eventType),
                  style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                timeWidget,
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(dateStr, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(width: 16),
                Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(tr(n.city), style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(width: 16),
                Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text('${n.guestCount}', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              tr('agent_offer', args: [n.currentOffer.toStringAsFixed(0)]),
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.strawRed),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mossGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () => _showAcceptSheet(n.negotiationId, n.eventId, n.currentOffer),
                    child: Text(tr('accept'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: AppColors.goldenBrown),
                    ),
                    onPressed: () => context.push('/vendor/negotiation/${n.negotiationId}'),
                    child: Text(tr('open'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.goldenBrown)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCard(NegotiationSummary n) {
    final dateStr = DateFormat('MMM d, yyyy').format(n.eventDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: n.isMyTurn ? AppColors.goldenBrown : Colors.grey.shade200,
          width: n.isMyTurn ? 2 : 1,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr(n.eventType),
                  style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  tr('round', args: [n.offerCount.toString()]),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(dateStr, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(width: 16),
                Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(tr(n.city), style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(width: 16),
                Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text('${n.guestCount}', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('current_offer', args: [n.currentOffer.toStringAsFixed(0)]),
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.goldenBrown),
                      ),
                      const SizedBox(height: 4),
                      if (n.isMyTurn)
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Text(
                            tr('your_turn'),
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.strawRed),
                          ),
                        )
                      else
                        Text(
                          tr('agent_responding'),
                          style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: n.isMyTurn ? AppColors.goldenBrown : Colors.grey.shade800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => context.push('/vendor/negotiation/${n.negotiationId}'),
                  child: Text(tr('open'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedCard(NegotiationSummary n) {
    final dateStr = DateFormat('MMM d, yyyy').format(n.eventDate);

    Color chipColor;
    String chipKey;
    if (n.status == 'deal') {
      chipColor = AppColors.mossGreen;
      chipKey = 'deal_closed';
    } else if (n.status == 'expired') {
      chipColor = AppColors.goldenBrown;
      chipKey = 'expired';
    } else {
      chipColor = Colors.grey.shade500;
      chipKey = 'no_deal';
    }

    return InkWell(
      onTap: () => context.push('/vendor/negotiation/${n.negotiationId}', extra: {'readOnly': true}),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        color: Colors.white.withOpacity(0.8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr(n.eventType),
                    style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: chipColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      tr(chipKey),
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: chipColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(dateStr, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(width: 16),
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(tr(n.city), style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
              if (n.status == 'deal' && n.finalPrice != null) ...[
                const SizedBox(height: 12),
                Text(
                  'PKR ${n.finalPrice!.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mossGreen),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not authenticated')));

    final asyncData = ref.watch(vendorNegotiationsProvider(user.uid));

    return asyncData.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (data) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F3EB),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              tr('requests'),
              style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.goldenBrown,
              unselectedLabelColor: Colors.grey.shade500,
              indicatorColor: AppColors.goldenBrown,
              tabs: [
                Tab(text: '${tr('new')} (${data.pendingList.length})'),
                Tab(text: '${tr('active')} (${data.activeList.length})'),
                Tab(text: '${tr('closed')} (${data.closedList.length})'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // New Tab
              data.pendingList.isEmpty
                  ? _buildEmptyState('no_new_requests', Icons.inbox_outlined)
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: data.pendingList.length,
                      itemBuilder: (context, index) => _buildNewCard(data.pendingList[index]),
                    ),
              
              // Active Tab
              data.activeList.isEmpty
                  ? _buildEmptyState('no_active_negotiations', Icons.handshake_outlined)
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: data.activeList.length,
                      itemBuilder: (context, index) => _buildActiveCard(data.activeList[index]),
                    ),

              // Closed Tab
              data.closedList.isEmpty
                  ? _buildEmptyState('no_closed_yet', Icons.history)
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: data.closedList.length,
                      itemBuilder: (context, index) => _buildClosedCard(data.closedList[index]),
                    ),
            ],
          ),
        );
      },
    );
  }
}