import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import 'vendor_home_screen.dart'; // To get DashboardData
import '../../widgets/app_logo.dart';

class VendorDashboardView extends StatefulWidget {
  final DashboardData data;
  final Function(int) onNavigateToRequests;

  const VendorDashboardView({
    super.key,
    required this.data,
    required this.onNavigateToRequests,
  });

  @override
  State<VendorDashboardView> createState() => _VendorDashboardViewState();
}

class _VendorDashboardViewState extends State<VendorDashboardView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildGreeting() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('greeting', args: [widget.data.businessName]),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              if (widget.data.category.isNotEmpty)
                Text(
                  tr(widget.data.category),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.goldenBrown,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const AppLogo(size: 48),
      ],
    );
  }

  Widget _buildPendingAlert() {
    if (widget.data.pendingCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.strawRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.strawRed.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.strawRed,
              shape: BoxShape.circle,
            ),
            child: Text(
              widget.data.pendingCount.toString(),
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('new_requests'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.strawRed,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.strawRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () => widget.onNavigateToRequests(0),
                    child: Text(
                      tr('view_now'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyTurnAlert() {
    if (widget.data.myTurnCount == 0 || widget.data.activeCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.goldenBrown.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldenBrown.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: AppColors.goldenBrown),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('your_turn_count', args: [widget.data.myTurnCount.toString()]),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldenBrown,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldenBrown,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () => widget.onNavigateToRequests(1),
              child: Text(
                tr('respond_now'),
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildStatTile(
              tr('today'),
              'PKR ${widget.data.todayEarnings.toStringAsFixed(0)}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatTile(
              tr('total_bookings'),
              widget.data.totalBookings.toString(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Tooltip(
              message: tr('response_rate_tip'),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(12),
              textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              triggerMode: TooltipTriggerMode.tap,
              child: _buildStatTile(
                tr('response_rate'),
                '${widget.data.responseRate.toStringAsFixed(0)}%',
                showInfo: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, {bool showInfo = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.goldenBrown,
                ),
              ),
              if (showInfo) ...[
                const SizedBox(width: 4),
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
              ]
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveNegotiations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('active_negotiations'),
          style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (widget.data.recentNegotiations.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                tr('no_active_negotiations'),
                style: GoogleFonts.inter(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.data.recentNegotiations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final neg = widget.data.recentNegotiations[index];
              final isMyTurn = neg['isVendorTurn'] as bool? ?? false;
              final eventTypeKey = neg['eventType'] as String? ?? 'other';
              final currentOffer = (neg['currentOffer'] ?? 0.0).toString();
              
              DateTime eventDate = DateTime.now();
              if (neg['eventDate'] is Timestamp) {
                eventDate = (neg['eventDate'] as Timestamp).toDate();
              } else if (neg['eventDate'] is String) {
                eventDate = DateTime.tryParse(neg['eventDate']) ?? DateTime.now();
              }
              final dateStr = DateFormat('MMM d, yyyy').format(eventDate);

              return InkWell(
                onTap: () {
                  final negId = neg['negotiationId'];
                  // push placeholder since actual route might not exist perfectly yet
                  context.push('/vendor/negotiation/$negId');
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isMyTurn ? AppColors.goldenBrown : Colors.grey.shade200,
                      width: isMyTurn ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(eventTypeKey),
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(dateStr, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                            const SizedBox(height: 8),
                            Text(
                              tr('current_offer', args: [currentOffer]),
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.goldenBrown),
                            ),
                          ],
                        ),
                      ),
                      if (isMyTurn)
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.goldenBrown,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tr('your_turn'),
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        )
                      else
                        Text(
                          tr('agent_responding'),
                          style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreeting(),
            _buildPendingAlert(),
            _buildMyTurnAlert(),
            _buildQuickStats(),
            _buildActiveNegotiations(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
