import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_colors.dart';
import '../../services/backend_service.dart';
import 'package:go_router/go_router.dart';

// --- MODELS ---
class VendorPackage {
  final String packageId;
  final double totalCost;
  final double totalAsking;
  final double totalSavings;
  final double savingsPercent;
  final List<PackageVendor> vendors;
  final String optimizationReason;

  VendorPackage({
    required this.packageId,
    required this.totalCost,
    required this.totalAsking,
    required this.totalSavings,
    required this.savingsPercent,
    required this.vendors,
    required this.optimizationReason,
  });
}

class PackageVendor {
  final String vendorId;
  final String negotiationId; // Postgres UUID — needed for /bookings/confirm
  final String vendorName;
  final String category;
  final double askingPrice;
  final double negotiatedPrice;
  final double savings;
  final String confirmationStatus;
  final String vendorContact;

  PackageVendor({
    required this.vendorId,
    required this.negotiationId,
    required this.vendorName,
    required this.category,
    required this.askingPrice,
    required this.negotiatedPrice,
    required this.savings,
    required this.confirmationStatus,
    required this.vendorContact,
  });
}

// --- SCREEN ---
class BestCombinationScreen extends StatefulWidget {
  final double eventBudget;
  final String eventType;
  final String eventDate;
  final String city;
  final int guestCount;

  // eventFirestoreId: real Firestore event doc ID from backend
  final String eventFirestoreId;

  const BestCombinationScreen({
    super.key,
    required this.eventFirestoreId,
    this.eventBudget = 500000,
    this.eventType = 'Wedding',
    this.eventDate = '12 Dec 2026',
    this.city = 'Lahore',
    this.guestCount = 300,
  });

  @override
  State<BestCombinationScreen> createState() => _BestCombinationScreenState();
}

class _BestCombinationScreenState extends State<BestCombinationScreen> with TickerProviderStateMixin {
  late Stream<VendorPackage> _packageStream;
  VendorPackage? _loadedPackage;
  
  Set<String> selectedVendorIds = {};
  bool isConfirmSheetOpen = false;
  bool isSubmitting = false;
  String? bookingId;
  Map<String, TextEditingController> noteControllers = {};
  bool acceptedTerms = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _packageStream = _firestorePackageStream();
    
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);
  }

  @override
  void dispose() {
    for (var controller in noteControllers.values) {
      controller.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  /// Real Firestore stream — listens to events/{eventFirestoreId} and waits
  /// for the 'package' field to be written by the Aggregator Agent.
  /// FR-AGG-04, NFR-PERF-03: package appears in under 2s of agent writing it.
  Stream<VendorPackage> _firestorePackageStream() async* {
    final snapshots = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventFirestoreId)
        .snapshots();

    await for (final snap in snapshots) {
      final data = snap.data();
      if (data == null) continue;
      final pkg = data['package'] as Map<String, dynamic>?;
      if (pkg == null) continue; // aggregator hasn't finished yet

      final bestVendors = pkg['best_vendors'] as Map<String, dynamic>? ?? {};
      final vendors = bestVendors.entries.map((entry) {
        final v = entry.value as Map<String, dynamic>;
        final finalNum = (v['final_price'] as num?)?.toDouble() ?? 0;
        // asking_price is now always written by the backend aggregator.
        // Fall back to final_price if missing (no negative savings).
        final askingRaw = (v['asking_price'] as num?)?.toDouble();
        final askingNum = (askingRaw != null && askingRaw > 0) ? askingRaw : finalNum;
        final savings = (askingNum - finalNum).clamp(0.0, double.infinity);
        return PackageVendor(
          vendorId: v['vendor_id'] as String? ?? '',
          negotiationId: v['negotiation_id'] as String? ?? '',
          vendorName: v['business_name'] as String? ?? entry.key,
          category: entry.key,
          askingPrice: askingNum,
          negotiatedPrice: finalNum,
          savings: savings,
          confirmationStatus: 'pending',
          vendorContact: '',
        );
      }).toList();

      yield VendorPackage(
        packageId: widget.eventFirestoreId,
        totalCost: (pkg['total_cost'] as num?)?.toDouble() ?? 0,
        totalAsking: vendors.fold(0.0, (s, v) => s + v.askingPrice),
        totalSavings: (pkg['total_savings'] as num?)?.toDouble() ?? 0,
        savingsPercent: (pkg['savings_percentage'] as num?)?.toDouble() ?? 0,
        vendors: vendors,
        optimizationReason: pkg['summary'] as String? ?? 'Best combination selected by AI.',
      );
      break; // package is stable once written
    }
  }

  void _onPackageLoaded(VendorPackage package) {
    if (_loadedPackage == null) {
      // First load initialization
      setState(() {
        _loadedPackage = package;
        selectedVendorIds = package.vendors.map((v) => v.vendorId).toSet();
        for (var v in package.vendors) {
          if (!noteControllers.containsKey(v.vendorId)) {
            noteControllers[v.vendorId] = TextEditingController();
          }
        }
      });
    }
  }

  void _shakeTerms() {
    _shakeController.forward(from: 0).then((_) => _shakeController.reverse());
    HapticFeedback.heavyImpact();
  }

  /// Real booking submission — calls POST /bookings/confirm on the backend.
  /// [onDone] is called on the sheet's own setState so the button updates
  /// correctly even inside the StatefulBuilder.
  Future<void> _submitBooking(
    double runningTotal,
    double runningSavings,
    void Function(void Function()) setSheetState,
  ) async {
    // Guard: all selected vendors must have a real negotiation ID
    final selected = _loadedPackage!.vendors
        .where((v) => selectedVendorIds.contains(v.vendorId))
        .toList();

    if (selected.any((v) => v.negotiationId.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Some vendor data is missing. Please go back and try again.'),
          backgroundColor: Colors.redAccent,
        ));
      }
      setSheetState(() => isSubmitting = false);
      setState(() => isSubmitting = false);
      return;
    }

    try {
      final body = <String, dynamic>{
        'event_id': widget.eventFirestoreId,
        'vendors': selected.map((v) => {
          'negotiation_id': v.negotiationId,
          'vendor_id': v.vendorId,
        }).toList(),
      };

      final response = await BackendService.instance.post('/bookings/confirm', body: body);
      final confirmedId = (response['booking_ids'] as List?)?.first?.toString()
          ?? 'EF-${DateTime.now().millisecondsSinceEpoch}';

      if (!mounted) return;

      setSheetState(() => isSubmitting = false);
      setState(() {
        isSubmitting = false;
        bookingId = confirmedId;
        isConfirmSheetOpen = false;
      });

      Navigator.pop(context); // close confirmation sheet
      _showSuccessSheet(confirmedId, runningSavings);
    } on BackendException catch (e) {
      if (!mounted) return;
      setSheetState(() => isSubmitting = false);
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Booking failed: ${e.message}'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      if (!mounted) return;
      setSheetState(() => isSubmitting = false);
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Booking failed: $e'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  void _showConfirmationSheet(double runningTotal, double runningSavings, String savingsPercentStr) {
    setState(() {
      isConfirmSheetOpen = true;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAF0E6),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          children: [
                            Text("Confirm Booking", style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
                            const SizedBox(height: 24),
                            
                            // SECTION 1: Event Summary
                            Text("Event Summary", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF666666))),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE8C49A).withValues(alpha: 0.5)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.celebration, color: AppColors.goldenBrown, size: 20),
                                      const SizedBox(width: 8),
                                      Text(widget.eventType, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                                      const Spacer(),
                                      const Icon(Icons.calendar_month, color: AppColors.goldenBrown, size: 20),
                                      const SizedBox(width: 8),
                                      Text(widget.eventDate, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_city, color: AppColors.goldenBrown, size: 20),
                                      const SizedBox(width: 8),
                                      Text(widget.city, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                                      const Spacer(),
                                      const Icon(Icons.people, color: AppColors.goldenBrown, size: 20),
                                      const SizedBox(width: 8),
                                      Text("${widget.guestCount} guests", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // SECTION 2: Final Cost Summary
                            Text("Final Cost Summary", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF666666))),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.mossGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.mossGreen.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Total Cost", style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1A1A1A))),
                                      Text("PKR ${NumberFormat('#,###').format(runningTotal)}", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Total Savings", style: GoogleFonts.inter(fontSize: 14, color: AppColors.mossGreen)),
                                      Text("PKR ${NumberFormat('#,###').format(runningSavings)} ($savingsPercentStr%)", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.mossGreen)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Confirmed Vendors", style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF666666))),
                                      Text("${selectedVendorIds.length} vendors", style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF666666))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // SECTION 3: Vendor Notes (Collapsible)
                            Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text("Add notes for vendors (optional)", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF666666))),
                                children: _loadedPackage!.vendors.where((v) => selectedVendorIds.contains(v.vendorId)).map((v) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: TextField(
                                      controller: noteControllers[v.vendorId],
                                      maxLength: 150,
                                      maxLines: 2,
                                      style: GoogleFonts.inter(fontSize: 14),
                                      decoration: InputDecoration(
                                        labelText: "${v.vendorName} — ${v.category}",
                                        labelStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF888888)),
                                        hintText: "E.g. Confirm vegetarian menu for 50 guests",
                                        hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFCCCCCC)),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFFE8C49A).withValues(alpha: 0.5))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFFE8C49A).withValues(alpha: 0.5))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.goldenBrown)),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            
                            // SECTION 4: Terms
                            AnimatedBuilder(
                              animation: _shakeAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(_shakeAnimation.value * sin(_shakeAnimation.value * pi), 0),
                                  child: CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: AppColors.goldenBrown,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    title: Text(
                                      "I understand this is a simulated demo. Vendor bookings are not real.",
                                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF666666)),
                                    ),
                                    value: acceptedTerms,
                                    onChanged: (val) {
                                      setSheetState(() => acceptedTerms = val ?? false);
                                      setState(() => acceptedTerms = val ?? false);
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 32),
                            
                            // SECTION 5: Confirm Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.goldenBrown,
                                  disabledBackgroundColor: const Color(0xFFCCCCCC),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                  elevation: 0,
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () {
                                        if (!acceptedTerms) {
                                          _shakeTerms();
                                        } else {
                                          setSheetState(() => isSubmitting = true);
                                          setState(() => isSubmitting = true);
                                          _submitBooking(runningTotal, runningSavings, setSheetState);
                                        }
                                      },
                                child: isSubmitting
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text("Confirm Booking", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => isConfirmSheetOpen = false);
    });
  }

  void _showSuccessSheet(String finalBookingId, double finalSavings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF0E6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24).copyWith(bottom: MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 80, height: 80,
                      decoration: const BoxDecoration(color: AppColors.mossGreen, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 40),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text("Booking Confirmed!", style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
              const SizedBox(height: 8),
              Text(
                "You saved PKR ${NumberFormat('#,###').format(finalSavings)} on your ${widget.eventType}!",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, color: AppColors.mossGreen, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              
              // Booking ID
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: finalBookingId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!"), duration: Duration(seconds: 2)));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE8C49A).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("ID: $finalBookingId", style: GoogleFonts.firaCode(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF666666))),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy, size: 16, color: AppColors.goldenBrown),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Vendor Contacts
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Vendor Contacts", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF666666))),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8C49A).withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: _loadedPackage!.vendors.where((v) => selectedVendorIds.contains(v.vendorId)).map((v) {
                    return ListTile(
                      title: Text(v.vendorName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                      subtitle: Text("${v.category} • ${v.vendorContact}", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF888888))),
                      trailing: IconButton(
                        icon: const Icon(Icons.chat, color: Color(0xFF25D366)), // WhatsApp green
                        onPressed: () {
                          // Mock URL Launcher
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Opening WhatsApp for ${v.vendorContact}")));
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),
              
              // Share Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.goldenBrown,
                    side: const BorderSide(color: AppColors.goldenBrown),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  icon: const Icon(Icons.share, size: 20),
                  label: Text("Share Event Setup", style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    // Mock Share Plus
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opening Share Dialog...")));
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Back to Home
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // Navigate to root / home
                    context.go('/');
                  },
                  child: Text("Back to Home", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (isConfirmSheetOpen) {
          Navigator.pop(context);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF0E6),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F3EB),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF7A4E1E)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text("Best Combination", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
          centerTitle: true,
        ),
        body: StreamBuilder<VendorPackage>(
          stream: _packageStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.goldenBrown));
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Failed to load combination", style: GoogleFonts.inter(color: AppColors.strawRed)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _packageStream = _firestorePackageStream();
                        });
                      },
                      child: const Text("Retry"),
                    )
                  ],
                ),
              );
            }
            if (snapshot.hasData && _loadedPackage == null) {
              // Defer state update to avoid build cycle issues
              WidgetsBinding.instance.addPostFrameCallback((_) => _onPackageLoaded(snapshot.data!));
              return const Center(child: CircularProgressIndicator(color: AppColors.goldenBrown));
            }

            if (_loadedPackage == null) return const SizedBox();

            final pkg = _loadedPackage!;

            // ── Compute running totals from selected vendors ──────────────
            double runningTotal = 0;
            double runningAsking = 0;
            double runningSavings = 0;
            for (var v in pkg.vendors) {
              if (selectedVendorIds.contains(v.vendorId)) {
                runningTotal += v.negotiatedPrice;
                // askingPrice is now always >= negotiatedPrice (clamped in parser)
                runningAsking += v.askingPrice;
                runningSavings += v.savings; // already clamped ≥ 0 in parser
              }
            }
            // If backend already computed overall savings, prefer it when all
            // vendors are selected (more accurate — computed from Postgres).
            final allSelected = selectedVendorIds.length == pkg.vendors.length;
            if (allSelected && pkg.totalSavings > 0) {
              runningSavings = pkg.totalSavings;
            }
            // Savings percent: use backend value when all selected, else compute
            final double savingsPercentRaw = allSelected && pkg.savingsPercent > 0
                ? pkg.savingsPercent
                : (runningAsking > 0 ? (runningSavings / runningAsking * 100) : 0.0);
            final String savingsPercentStr = savingsPercentRaw.toStringAsFixed(1);
            final bool isOverBudget = runningTotal > widget.eventBudget;
            final bool canConfirm = !isOverBudget && selectedVendorIds.isNotEmpty;

            return Column(
              children: [
                // SAVINGS BANNER
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isOverBudget ? AppColors.strawRed.withValues(alpha: 0.1) : AppColors.mossGreen.withValues(alpha: 0.1),
                    border: Border(bottom: BorderSide(color: isOverBudget ? AppColors.strawRed.withValues(alpha: 0.3) : AppColors.mossGreen.withValues(alpha: 0.3))),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      key: ValueKey("$isOverBudget-$runningSavings"),
                      children: [
                        Text(
                          isOverBudget ? "Over Budget!" : "PKR ${NumberFormat('#,###').format(runningSavings)}",
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isOverBudget ? AppColors.strawRed : AppColors.mossGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOverBudget 
                            ? "PKR ${NumberFormat('#,###').format(runningTotal - widget.eventBudget)} over budget — deselect a vendor" 
                            : "You saved $savingsPercentStr% vs asking prices",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isOverBudget ? AppColors.strawRed : AppColors.mossGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // VENDOR CARDS LIST
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: pkg.vendors.length,
                    itemBuilder: (context, index) {
                      final v = pkg.vendors[index];
                      final isSelected = selectedVendorIds.contains(v.vendorId);
                      
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? AppColors.goldenBrown : const Color(0xFFE8C49A).withValues(alpha: 0.5)),
                          boxShadow: [
                            if (isSelected) BoxShadow(color: AppColors.goldenBrown.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))
                          ],
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selectedVendorIds.remove(v.vendorId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Removed ${v.vendorName}"),
                                    action: SnackBarAction(
                                      label: "Undo",
                                      onPressed: () => setState(() => selectedVendorIds.add(v.vendorId)),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  )
                                );
                              } else {
                                selectedVendorIds.add(v.vendorId);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: AppColors.goldenBrown,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        selectedVendorIds.add(v.vendorId);
                                      } else {
                                        selectedVendorIds.remove(v.vendorId);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Removed ${v.vendorName}"),
                                            action: SnackBarAction(label: "Undo", onPressed: () => setState(() => selectedVendorIds.add(v.vendorId))),
                                            behavior: SnackBarBehavior.floating,
                                          )
                                        );
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              v.vendorName,
                                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                                              maxLines: 1, overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: v.confirmationStatus == 'confirmed' ? AppColors.mossGreen.withValues(alpha: 0.1) : const Color(0xFFFFF3E0),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: v.confirmationStatus == 'confirmed' ? AppColors.mossGreen.withValues(alpha: 0.3) : const Color(0xFFFFCC80)),
                                            ),
                                            child: Text(
                                              v.confirmationStatus == 'confirmed' ? 'Confirmed' : 'Pending',
                                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: v.confirmationStatus == 'confirmed' ? AppColors.mossGreen : const Color(0xFFF57C00)),
                                            ),
                                          )
                                        ],
                                      ),
                                      Text(v.category, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF666666))),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          // Only show asking price strikethrough if it's different from negotiated
                                          if (v.askingPrice > v.negotiatedPrice) ...[
                                            Text(
                                              "PKR ${NumberFormat.compact().format(v.askingPrice)}",
                                              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF888888), decoration: TextDecoration.lineThrough),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(
                                            "PKR ${NumberFormat.compact().format(v.negotiatedPrice)}",
                                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (v.savings > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.mossGreen.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            "Saved PKR ${NumberFormat('#,###').format(v.savings.toInt())}",
                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mossGreen),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            "Final price",
                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF888888)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // OPTIMIZATION NOTE
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8EB4D9).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF4A7CB4), size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(pkg.optimizationReason, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF2B4D73)))),
                      ],
                    ),
                  ),
                ),
                
                // BOTTOM BAR
                Container(
                  padding: const EdgeInsets.all(16).copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "PKR ${NumberFormat('#,###').format(runningTotal)}",
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: isOverBudget ? AppColors.strawRed : const Color(0xFF1A1A1A)),
                            ),
                            Text("of PKR ${NumberFormat.compact().format(widget.eventBudget)} budget", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF666666))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.goldenBrown,
                          disabledBackgroundColor: const Color(0xFFCCCCCC),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          elevation: 0,
                        ),
                        onPressed: canConfirm ? () => _showConfirmationSheet(runningTotal, runningSavings, savingsPercentStr) : null,
                        child: Text("Confirm Booking", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      )
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
