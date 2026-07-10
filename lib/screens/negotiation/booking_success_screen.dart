import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_colors.dart';
import '../../core/localization/language_provider.dart';
import 'package:go_router/go_router.dart';

class BookingSuccessScreen extends StatefulWidget {
  final String bookingId;
  final String pdfUrl;
  final DateTime eventDate;
  final int vendorCount;
  final double totalSavings;
  final String eventType;

  const BookingSuccessScreen({
    super.key,
    this.bookingId = 'EF-123456789',
    this.pdfUrl = 'https://example.com/receipt.pdf',
    required this.eventDate,
    this.vendorCount = 3,
    this.totalSavings = 55000,
    this.eventType = 'Wedding',
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
  int _daysUntilEvent = 0;
  bool _hasCopiedId = false;

  // Mock list of confirmed vendors
  final List<Map<String, String>> _confirmedVendors = [
    {'name': 'Nadeem Caterers', 'category': 'Caterer', 'contact': '03001234567'},
    {'name': 'Al-Faisal Decor', 'category': 'Decorator', 'contact': '03001234568'},
    {'name': 'Raza Photography', 'category': 'Photographer', 'contact': '03001234569'},
  ];

  @override
  void initState() {
    super.initState();
    _daysUntilEvent = widget.eventDate.difference(DateTime.now()).inDays;

    // 1. Mock Firestore completion
    debugPrint("Mock: events/{eventId} field completedAt = serverTimestamp()");

    // 2. Mock local notification scheduling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loc = context.loc;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Mock: Notification scheduled: ${loc.get('your_event_in_7_days')}"),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  void _copyBookingId(dynamic loc) {
    Clipboard.setData(ClipboardData(text: widget.bookingId));
    setState(() {
      _hasCopiedId = true;
    });
    
    // Quick SnackBar feedback as backup
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.get('copied')),
        duration: const Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _hasCopiedId = false;
        });
      }
    });
  }

  void _mockOpenWhatsApp(String phone, dynamic loc) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Opening WhatsApp: https://wa.me/92$phone")),
    );
  }

  void _mockDownloadPdf(dynamic loc) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Downloading PDF from ${widget.pdfUrl}..."), backgroundColor: AppColors.mossGreen),
    );
  }

  void _mockShare(dynamic loc) {
    final text = "I just booked my ${widget.eventType} on EventFlow! Saved PKR ${widget.totalSavings}. Booking ID: ${widget.bookingId}";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Sharing: $text"), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isUrdu = context.isUrdu;

    return WillPopScope(
      onWillPop: () async => false, // Terminal screen, override hardware back button
      child: Directionality(
        textDirection: loc.textDirection,
        child: Scaffold(
          backgroundColor: const Color(0xFFFAF0E6), // Consistent warm beige
          appBar: AppBar(
            automaticallyImplyLeading: false, // Hide back button
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Text(
              loc.get('eventflow'),
              style: loc.headingStyle(fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Animated Success Icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.mossGreen.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 64, height: 64,
                            decoration: const BoxDecoration(
                              color: AppColors.mossGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 36),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  loc.get('booking_confirmed'),
                  style: loc.headingStyle(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Savings callout
                Text(
                  "You saved PKR ${NumberFormat('#,###').format(widget.totalSavings)} on your ${widget.eventType}!",
                  textAlign: TextAlign.center,
                  style: loc.fontStyle(fontSize: 16, color: AppColors.mossGreen, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 32),

                // Booking ID Display
                GestureDetector(
                  onTap: () => _copyBookingId(loc),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: _hasCopiedId ? AppColors.mossGreen.withValues(alpha: 0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _hasCopiedId ? AppColors.mossGreen : const Color(0xFFE8C49A)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _hasCopiedId ? loc.get('copied') : "ID: ${widget.bookingId}",
                          textDirection: TextDirection.ltr,
                          style: _hasCopiedId 
                              ? loc.fontStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.mossGreen)
                              : GoogleFonts.firaCode(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          _hasCopiedId ? Icons.check : Icons.copy,
                          size: 18,
                          color: _hasCopiedId ? AppColors.mossGreen : AppColors.goldenBrown,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Countdown Display
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.goldenBrown.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.goldenBrown.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      if (_daysUntilEvent <= 0)
                        Text(
                          loc.get('event_today'),
                          style: loc.fontStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.goldenBrown),
                        )
                      else ...[
                        Text(
                          _daysUntilEvent.toString(),
                          style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.goldenBrown, height: 1.0),
                        ),
                        Text(
                          loc.get('days_to_go'),
                          style: loc.fontStyle(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF7A4E1E)),
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Vendor Contacts
                Align(
                  alignment: isUrdu ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(loc.get('vendor_contacts'), style: loc.fontStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8C49A).withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: _confirmedVendors.map((v) {
                      return ListTile(
                        title: Text(v['name']!, style: loc.fontStyle(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                        subtitle: Text("${v['category']} • ${v['contact']}", textDirection: TextDirection.ltr, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF888888))),
                        trailing: InkWell(
                          onTap: () => _mockOpenWhatsApp(v['contact']!, loc),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366).withValues(alpha: 0.1), // WhatsApp Green Tint
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // Download PDF Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mossGreen,
                      side: const BorderSide(color: AppColors.mossGreen, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 20),
                    label: Text(loc.get('download_pdf'), style: loc.fontStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    onPressed: () => _mockDownloadPdf(loc),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Share Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.goldenBrown,
                      side: const BorderSide(color: AppColors.goldenBrown, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    icon: const Icon(Icons.share, size: 20),
                    label: Text(loc.get('share_event_setup'), style: loc.fontStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    onPressed: () => _mockShare(loc),
                  ),
                ),
                const SizedBox(height: 32),

                // Back to Home Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A), // Strong dark button
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      // Navigate to splash screen
                      context.go('/');
                    },
                    child: Text(loc.get('back_to_home'), style: loc.fontStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 48), // Padding at end of scroll
              ],
            ),
          ),
        ),
      ),
    );
  }
}
