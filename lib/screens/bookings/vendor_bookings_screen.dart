import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/vendor_bookings_provider.dart';

class VendorBookingsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToRequests;
  const VendorBookingsScreen({super.key, this.onNavigateToRequests});

  @override
  ConsumerState<VendorBookingsScreen> createState() => _VendorBookingsScreenState();
}

class _VendorBookingsScreenState extends ConsumerState<VendorBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildEarningsBanner(List<VendorBooking> bookings) {
    double thisMonthEarned = 0;
    double totalEarned = 0;
    
    final now = DateTime.now();

    for (var b in bookings) {
      totalEarned += b.finalPrice;
      if (b.bookedAt.year == now.year && b.bookedAt.month == now.month) {
        thisMonthEarned += b.finalPrice;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PKR ${thisMonthEarned.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.mossGreen)),
                const SizedBox(height: 4),
                Text(tr('this_month'), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PKR ${totalEarned.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.goldenBrown)),
                const SizedBox(height: 4),
                Text(tr('total_earned'), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingDetailsSheet(VendorBooking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) {
            final dateStr = DateFormat('dd MMM yyyy').format(booking.eventDate);
            
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(tr(booking.eventType), style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: booking.bookingStatus == 'upcoming' ? AppColors.mossGreen.withOpacity(0.1) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: booking.bookingStatus == 'upcoming' ? AppColors.mossGreen.withOpacity(0.3) : Colors.transparent),
                        ),
                        child: Text(
                          tr(booking.bookingStatus),
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: booking.bookingStatus == 'upcoming' ? AppColors.mossGreen : Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow(Icons.calendar_today, tr('date'), dateStr),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.location_on, tr('city'), tr(booking.city)),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.people, tr('guests'), booking.guestCount.toString()),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.person, tr('customer_order', args: ['']), booking.customerFirstName),
                  const SizedBox(height: 24),
                  Text(
                    'PKR ${booking.finalPrice.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.mossGreen),
                  ),
                  const SizedBox(height: 24),
                  if (booking.customerNote != null && booking.customerNote!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF7F3EB), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes, size: 20, color: AppColors.goldenBrown),
                          const SizedBox(width: 12),
                          Expanded(child: Text(booking.customerNote!, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade800, height: 1.5))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('booking_id'), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                          const SizedBox(height: 4),
                          Text(booking.negotiationId, style: GoogleFonts.robotoMono(fontSize: 13, color: Colors.grey.shade700)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: AppColors.goldenBrown),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: booking.negotiationId));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('copied')), duration: const Duration(seconds: 2)));
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('close'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600)),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  Widget _buildBookingCard(VendorBooking booking) {
    final dateStr = DateFormat('dd MMM yyyy').format(booking.eventDate);
    final daysUntil = booking.eventDate.difference(DateTime.now()).inDays;
    
    final bool isUrgent = daysUntil >= 0 && daysUntil <= 7;
    
    return InkWell(
      onTap: () => _showBookingDetailsSheet(booking),
      child: Card(
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
                    tr(booking.eventType),
                    style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      if (isUrgent) ...[
                        const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.goldenBrown),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        dateStr,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
                          color: isUrgent ? AppColors.goldenBrown : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(tr(booking.city), style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(width: 16),
                  Icon(Icons.people, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(booking.guestCount.toString(), style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('customer_order', args: [booking.customerFirstName]), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text(
                        'PKR ${booking.finalPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.mossGreen),
                      ),
                    ],
                  ),
                ],
              ),
              if (booking.customerNote != null && booking.customerNote!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF7F3EB), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.notes, size: 14, color: AppColors.goldenBrown),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.customerNote!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(booking.negotiationId, style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.grey.shade400)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String textKey, bool isUpcoming) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            tr(textKey),
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade500),
          ),
          if (isUpcoming) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldenBrown,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
              ),
              onPressed: () {
                if (widget.onNavigateToRequests != null) {
                  widget.onNavigateToRequests!();
                } else {
                  context.push('/vendor/inbox');
                }
              },
              child: Text(tr('view_requests'), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not authenticated')));

    final asyncBookings = ref.watch(vendorBookingsProvider(user.uid));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          tr('bookings'),
          style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: asyncBookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (bookings) {
          final upcoming = bookings.where((b) => b.bookingStatus == 'upcoming').toList();
          final past = bookings.where((b) => b.bookingStatus == 'completed').toList();

          return RefreshIndicator(
            color: AppColors.goldenBrown,
            onRefresh: () async {
              ref.invalidate(vendorBookingsProvider(user.uid));
            },
            child: Column(
              children: [
                _buildEarningsBanner(bookings),
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.goldenBrown,
                    unselectedLabelColor: Colors.grey.shade500,
                    indicatorColor: AppColors.goldenBrown,
                    tabs: [
                      Tab(text: '${tr('upcoming')} (${upcoming.length})'),
                      Tab(text: '${tr('past')} (${past.length})'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      upcoming.isEmpty
                          ? _buildEmptyState('no_upcoming_bookings', true)
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 8, bottom: 24),
                              itemCount: upcoming.length,
                              itemBuilder: (_, i) => _buildBookingCard(upcoming[i]),
                            ),
                      past.isEmpty
                          ? _buildEmptyState('no_past_bookings', false)
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 8, bottom: 24),
                              itemCount: past.length,
                              itemBuilder: (_, i) => _buildBookingCard(past[i]),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}