import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:confetti/confetti.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../models/event_setup_model.dart';
import 'agent_thread_screen.dart';
import 'best_combination_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Status enum — mirrors the Firestore negotiation status field values.
// NFR-USE-02: clearly distinguishes all negotiation states for the dashboard.
// ─────────────────────────────────────────────────────────────────────────────
enum NegotiatorStatus {
  connecting,
  negotiating,
  counterOffer,
  deal,
  noDeal,
  expired,
}

NegotiatorStatus _parseStatus(String? s) {
  switch (s) {
    case 'negotiating':
      return NegotiatorStatus.negotiating;
    case 'counter_offer':
      return NegotiatorStatus.counterOffer;
    case 'deal':
      return NegotiatorStatus.deal;
    case 'no_deal':
      return NegotiatorStatus.noDeal;
    case 'expired':
      return NegotiatorStatus.expired;
    default:
      return NegotiatorStatus.connecting;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VendorNegotiationState — live view model built from Firestore documents.
// Replaces the old Random()-based VendorNegotiationState.
// ─────────────────────────────────────────────────────────────────────────────
class VendorNegotiationState {
  final String vendor; // category name (e.g. "Caterer")
  final String vendorName; // business name from Firestore
  final String negotiationId; // Firestore doc ID
  final int askingPrice;
  final int currentOffer;
  final NegotiatorStatus status;
  final int offerCount;
  final int maxOffers;

  const VendorNegotiationState({
    required this.vendor,
    required this.vendorName,
    required this.negotiationId,
    required this.askingPrice,
    required this.currentOffer,
    required this.status,
    required this.offerCount,
    required this.maxOffers,
  });

  factory VendorNegotiationState.fromFirestore(
    Map<String, dynamic> data,
    String docId,
  ) {
    return VendorNegotiationState(
      vendor: data['category'] as String? ?? 'Unknown',
      vendorName: data['vendorName'] as String? ?? 'Vendor',
      negotiationId: docId,
      askingPrice: (data['askingPrice'] as num?)?.toInt() ?? 0,
      currentOffer: (data['currentOffer'] as num?)?.toInt() ?? 0,
      status: _parseStatus(data['status'] as String?),
      offerCount: (data['offerCount'] as num?)?.toInt() ?? 0,
      maxOffers: (data['maxOffers'] as num?)?.toInt() ?? 5,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LiveDashboardScreen
// Phase 4: backed by real Firestore listeners (no Random(), no NegotiationSimulator).
//
// Accepts both the local EventSetupModel (for display) and the real
// eventFirestoreId returned by the backend after event submission.
// ─────────────────────────────────────────────────────────────────────────────
class LiveDashboardScreen extends StatefulWidget {
  final EventSetupModel model;
  final Map<String, double> allocations; // kept for fallback display
  final String eventFirestoreId; // NEW: real Firestore event doc ID

  const LiveDashboardScreen({
    super.key,
    required this.model,
    required this.allocations,
    required this.eventFirestoreId,
  });

  @override
  State<LiveDashboardScreen> createState() => _LiveDashboardScreenState();
}

class _LiveDashboardScreenState extends State<LiveDashboardScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _pulseController;

  // Firestore listener subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // Live state map: category → negotiation state
  final Map<String, VendorNegotiationState> _stateMap = {};
  bool _allFinished = false;
  bool _isLoading = true;
  String _eventStatus = 'draft';

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _startFirestoreListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSuccessDialog();
    });
  }

  void _showSuccessDialog() {
    final loc = context.loc;
    final isUrdu = context.isUrdu;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFBF7),
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE6DFD3), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEDF3E1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF5A8E40),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isUrdu
                      ? 'ایونٹ کامیابی سے لانچ ہو گیا!'
                      : 'Event Launched Successfully!',
                  textAlign: TextAlign.center,
                  style: loc.fontStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF7A4E1E),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isUrdu
                      ? 'ہمارے AI ایجنٹس نے تصدیق شدہ وینڈرز کے ساتھ بات چیت شروع کر دی ہے۔ آپ براہ راست پیشرفت دیکھ سکتے ہیں یا ہوم اسکرین پر واپس جا سکتے ہیں۔'
                      : 'Our AI Agents have started negotiating with verified vendors. You can monitor the live progress here, or return to the home screen anytime.',
                  textAlign: TextAlign.center,
                  style: loc.fontStyle(
                    fontSize: 14,
                    color: const Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF7A4E1E),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst); // Go to Home
                        },
                        child: Text(
                          isUrdu ? 'ہوم اسکرین' : 'Go to Home',
                          style: loc.fontStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF7A4E1E),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD18D55), Color(0xFFC47035)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pop(); // Close dialog to show dashboard
                          },
                          child: Text(
                            isUrdu ? 'لائیو دیکھیں' : 'Watch Live',
                            style: loc.fontStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// NFR-PERF-03: Firestore-driven updates reflect within 2 seconds of agent writing.
  /// Queries negotiations where eventFirestoreId matches, then listens to each doc.
  void _startFirestoreListeners() {
    final db = FirebaseFirestore.instance;

    // Listen to all negotiations for this event. We rebuild from the full
    // snapshot so that newly-created, updated, or terminal negotiations are
    // always reflected correctly on the customer dashboard.
    final sub = db
        .collection('negotiations')
        .where('eventFirestoreId', isEqualTo: widget.eventFirestoreId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;

            final nextStateMap = <String, VendorNegotiationState>{};
            for (final doc in snapshot.docs) {
              final data = doc.data();
              if (data == null) continue;

              final state = VendorNegotiationState.fromFirestore(data, doc.id);
              nextStateMap[state.negotiationId] = state;
            }

            setState(() {
              _stateMap
                ..clear()
                ..addAll(nextStateMap);
              _isLoading = false;
            });

            _checkIfAllFinished();
          },
          onError: (e) {
            debugPrint('[LiveDashboard] Firestore error: $e');
            setState(() => _isLoading = false);
          },
        );

    _subscriptions.add(sub);

    // Listen to the event document to break deadlock on empty matched negotiations
    final eventSub = db
        .collection('events')
        .doc(widget.eventFirestoreId)
        .snapshots()
        .listen(
          (eventSnap) {
            if (!mounted) return;
            final data = eventSnap.data();
            if (data == null) return;
            final status = data['status'] as String? ?? 'draft';
            setState(() {
              _eventStatus = status;
            });
            if (status == 'ready' || status == 'cancelled') {
              setState(() {
                _isLoading = false;
                if (_stateMap.isEmpty) {
                  _allFinished = true;
                }
              });
            }
          },
          onError: (e) {
            debugPrint('[LiveDashboard] Event fetch error: $e');
          },
        );

    _subscriptions.add(eventSub);
  }

  void _checkIfAllFinished() {
    if (_stateMap.isEmpty) return;
    final allDone = _stateMap.values.every(
      (v) =>
          v.status == NegotiatorStatus.deal ||
          v.status == NegotiatorStatus.noDeal ||
          v.status == NegotiatorStatus.expired,
    );
    if (allDone) {
      setState(() {
        _allFinished = true;
      });
      _confettiController.play();
      return;
    }
    if (allDone && !_allFinished) {
      setState(() => _allFinished = true);
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _confettiController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color _statusColor(NegotiatorStatus status) {
    switch (status) {
      case NegotiatorStatus.connecting:
        return const Color(0xFF888888);
      case NegotiatorStatus.negotiating:
        return AppColors.strawRed;
      case NegotiatorStatus.counterOffer:
        return AppColors.goldenBrown;
      case NegotiatorStatus.deal:
        return AppColors.mossGreen;
      case NegotiatorStatus.noDeal:
        return const Color(0xFF666666);
      case NegotiatorStatus.expired:
        return const Color(0xFF999999);
    }
  }

  String _statusText(NegotiatorStatus status, dynamic loc) {
    switch (status) {
      case NegotiatorStatus.connecting:
        return loc.get('connecting');
      case NegotiatorStatus.negotiating:
        return loc.get('negotiating');
      case NegotiatorStatus.counterOffer:
        return loc.get('counter_offer');
      case NegotiatorStatus.deal:
        return loc.get('deal');
      case NegotiatorStatus.noDeal:
        return loc.get('no_deal');
      case NegotiatorStatus.expired:
        return 'Expired';
    }
  }

  IconData _getIconForVendor(String vendor) {
    switch (vendor) {
      case 'Caterer':
        return Icons.restaurant_menu;
      case 'Decorator':
        return Icons.auto_awesome;
      case 'Photographer':
        return Icons.camera_alt_outlined;
      case 'DJ / Music':
        return Icons.music_note;
      case 'Tent / Marquee':
        return Icons.holiday_village_outlined;
      case 'Sound System':
        return Icons.speaker;
      case 'Flowers':
        return Icons.local_florist_outlined;
      case 'Transport':
        return Icons.directions_car_outlined;
      case 'Security':
        return Icons.security;
      default:
        return Icons.star_border;
    }
  }

  String _getLocalizedVendor(String vendor, dynamic loc) {
    final Map<String, String> vendorKeys = {
      'Caterer': 'caterer',
      'Decorator': 'decorator',
      'Photographer': 'photographer',
      'DJ / Music': 'dj_music',
      'Tent / Marquee': 'tent_marquee',
      'Sound System': 'sound_system',
      'Flowers': 'flowers',
      'Transport': 'transport',
      'Security': 'security',
    };
    final key = vendorKeys[vendor];
    return key != null ? loc.get(key) : vendor;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isUrdu = context.isUrdu;

    // Build display list: prefer real Firestore data, fall back to model's vendor list
    final displayVendors = _stateMap.isNotEmpty
        ? _stateMap.keys.toList()
        : widget.model.selectedVendors;

    int lockedInAmount = 0;
    int totalSavings = 0;
    _stateMap.forEach((key, state) {
      if (state.status == NegotiatorStatus.deal) {
        lockedInAmount += state.currentOffer;
        totalSavings += (state.askingPrice - state.currentOffer).clamp(
          0,
          999999999,
        );
      }
    });
    final int remaining = widget.model.totalBudget - lockedInAmount;

    return Directionality(
      textDirection: loc.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F7F2),
        body: Stack(
          children: [
            Column(
              children: [
                // ── TOP STRIP ──────────────────────────────────────────────
                Container(
                  color: const Color(0xFFF7F3EB),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              isUrdu ? Icons.arrow_forward : Icons.arrow_back,
                              color: const Color(0xFF7A4E1E),
                            ),
                            onPressed: () => Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: isUrdu
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, _) => Opacity(
                                        opacity: _allFinished
                                            ? 0.3
                                            : 0.3 +
                                                  (_pulseController.value *
                                                      0.7),
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.strawRed,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      loc.get('live'),
                                      style: loc
                                          .fontStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.strawRed,
                                          )
                                          .copyWith(
                                            letterSpacing: isUrdu ? 0 : 2.0,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _allFinished
                                      ? loc.get('negotiation_complete')
                                      : loc.get('ai_negotiating'),
                                  style: loc.fontStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: isUrdu
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.end,
                            children: [
                              Text(
                                loc.get('budget_label'),
                                style: loc.fontStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              Text(
                                'PKR ${NumberFormat('#,###').format(widget.model.totalBudget)}',
                                textDirection: TextDirection.ltr,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── OVERVIEW CONTAINER ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFDFD),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.get('locked_in'),
                                    style: loc.fontStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF888888),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'PKR ${NumberFormat('#,###').format(lockedInAmount)}',
                                    textDirection: TextDirection.ltr,
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF333333),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: const Color(0xFFEEEEEE),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.get('remaining'),
                                    style: loc.fontStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF888888),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'PKR ${NumberFormat('#,###').format(remaining)}',
                                    textDirection: TextDirection.ltr,
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF333333),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF3E1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                loc.get('total_savings_vs_asking'),
                                style: loc.fontStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2E3D26),
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedFlipCounter(
                                value: totalSavings,
                                prefix: 'PKR ',
                                textStyle: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2E3D26),
                                ),
                                duration: const Duration(milliseconds: 500),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                loc.get('so_far'),
                                style: loc.fontStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2E3D26),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── LOADING STATE ──────────────────────────────────────────
                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.goldenBrown,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Connecting to AI agents…',
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_stateMap.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_eventStatus == 'ready' ||
                                _eventStatus == 'cancelled') ...[
                              const Icon(
                                Icons.info_outline,
                                size: 64,
                                color: AppColors.goldenBrown,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isUrdu
                                    ? 'اس شہر میں منتخب کردہ کیٹیگریز کے لیے کوئی تصدیق شدہ وینڈر نہیں ملا۔'
                                    : 'No verified vendors matched for the selected categories in this city.',
                                textAlign: TextAlign.center,
                                style: loc.fontStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF7A4E1E),
                                  height: isUrdu ? 1.8 : 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isUrdu
                                    ? 'براہ کرم اپنا بجٹ تبدیل کریں یا دیگر کیٹیگریز منتخب کریں۔'
                                    : 'Please try adjusting your budget or selected categories.',
                                textAlign: TextAlign.center,
                                style: loc.fontStyle(
                                  fontSize: 13,
                                  color: const Color(0xFF888888),
                                  height: isUrdu ? 1.8 : 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.goldenBrown,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                  ).popUntil((route) => route.isFirst);
                                },
                                child: Text(
                                  isUrdu
                                      ? 'بجٹ تبدیل کریں (ہوم اسکرین)'
                                      : 'Adjust Budget (Go Home)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(
                                width: 50,
                                height: 50,
                                child: CircularProgressIndicator(
                                  color: AppColors.goldenBrown,
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                isUrdu
                                    ? 'بات چیت کی جا رہی ہے...'
                                    : 'Negotiations in progress...',
                                style: loc.fontStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF7A4E1E),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isUrdu
                                    ? 'ہمارا AI ایجنٹ وینڈرز کے ساتھ رابطے میں ہے۔ آپ ہوم اسکرین پر واپس جا سکتے ہیں، بات چیت پس منظر میں جاری رہے گی۔'
                                    : 'Our AI is contacting vendors. You can safely return to the home screen — negotiations will continue in the background.',
                                textAlign: TextAlign.center,
                                style: loc.fontStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF666666),
                                  height: isUrdu ? 1.6 : 1.3,
                                ),
                              ),
                              const SizedBox(height: 24),
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.home_outlined,
                                  color: Color(0xFF7A4E1E),
                                ),
                                label: Text(
                                  isUrdu
                                      ? 'ہوم اسکرین پر جائیں'
                                      : 'Go to Home Screen',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF7A4E1E),
                                  side: const BorderSide(
                                    color: Color(0xFF7A4E1E),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                  ).popUntil((route) => route.isFirst);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  // ── AGENT CARDS GRID ─────────────────────────────────────
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16).copyWith(bottom: 100),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.95,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: displayVendors.length,
                      itemBuilder: (context, index) {
                        final negotiationKey = displayVendors[index];
                        final state = _stateMap[negotiationKey];

                        if (state == null) {
                          final fallbackVendor = widget.model.selectedVendors[index % widget.model.selectedVendors.length];
                          return _buildPlaceholderCard(fallbackVendor, loc, isUrdu);
                        }

                        return _buildVendorCard(state, state.vendor, loc, isUrdu);
                      },
                    ),
                  ),
              ],
            ),

            // ── CONFETTI ───────────────────────────────────────────────────
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  AppColors.mossGreen,
                  AppColors.strawRed,
                  AppColors.goldenBrown,
                  Color(0xFF7A4E1E),
                ],
              ),
            ),

            // ── BOTTOM CTA BUTTON ──────────────────────────────────────────
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutBack,
                offset: _allFinished ? Offset.zero : const Offset(0, 1.5),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _allFinished ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 8,
                          shadowColor: AppColors.goldenBrown.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BestCombinationScreen(
                                eventFirestoreId: widget.eventFirestoreId,
                                eventBudget: widget.model.totalBudget
                                    .toDouble(),
                                eventType: widget.model.eventType ?? 'Event',
                                eventDate:
                                    widget.model.eventDate
                                        ?.toIso8601String()
                                        .split('T')
                                        .first ??
                                    '',
                                city: widget.model.city ?? '',
                                guestCount: widget.model.guestCount,
                              ),
                            ),
                          );
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            color: AppColors.goldenBrown,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              '${loc.get('see_best_combination')} →',
                              style: loc.fontStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card widgets ─────────────────────────────────────────────────────────

  Widget _buildPlaceholderCard(String vendor, dynamic loc, bool isUrdu) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F3EF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  _getIconForVendor(vendor),
                  size: 18,
                  color: const Color(0xFF2E3D26),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getLocalizedVendor(vendor, loc),
                  style: loc.fontStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF333333),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF888888).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              loc.get('connecting'),
              style: loc.fontStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF888888),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(
            value: null, // indeterminate
            backgroundColor: Color(0xFFE8C49A),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF888888)),
            minHeight: 4,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildVendorCard(
    VendorNegotiationState state,
    String vendor,
    dynamic loc,
    bool isUrdu,
  ) {
    final color = _statusColor(state.status);
    final isDeal = state.status == NegotiatorStatus.deal;
    final isNoDeal =
        state.status == NegotiatorStatus.noDeal ||
        state.status == NegotiatorStatus.expired;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AgentThreadScreen(
            vendorName: vendor,
            negotiationFirestoreId: state.negotiationId,
          ),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isNoDeal
              ? const Color(0xFFF5F5F5)
              : Color.alphaBlend(color.withValues(alpha: 0.06), Colors.white),
          border: Border.all(
            color: isDeal ? const Color(0xFFEDF3E1) : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F3EF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: isNoDeal ? 0.7 : 1.0,
                    child: Icon(
                      _getIconForVendor(vendor),
                      size: 18,
                      color: const Color(0xFF2E3D26),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getLocalizedVendor(vendor, loc),
                    textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                    style: loc.fontStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── STATUS CHIP ────────────────────────────────────────────────
            if (isDeal)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mossGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, color: Colors.white, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      loc.get('deal'),
                      style: loc.fontStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else if (isNoDeal)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.strawRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.close, color: Colors.white, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      loc.get('no_deal'),
                      style: loc.fontStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusText(state.status, loc),
                  style: loc.fontStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),

            const Spacer(),

            // ── PRICES ─────────────────────────────────────────────────────
            Text(
              '${loc.get('asking_price')}: ${NumberFormat.compact().format(state.askingPrice)}',
              textDirection: TextDirection.ltr,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF999999),
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${loc.get('current_offer')}: ${NumberFormat.compact().format(state.currentOffer)}',
              textDirection: TextDirection.ltr,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDeal
                    ? const Color(0xFF2E3D26)
                    : const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 12),

            // ── SAVINGS / PROGRESS ─────────────────────────────────────────
            if (isDeal)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF3E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${loc.get('saved_pkr')} ${NumberFormat.compact().format((state.askingPrice - state.currentOffer).clamp(0, 99999999))}',
                  textDirection: TextDirection.ltr,
                  style: loc.fontStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E3D26),
                  ),
                ),
              )
            else if (!isNoDeal) ...[
              LinearProgressIndicator(
                value: state.maxOffers > 0
                    ? state.offerCount / state.maxOffers
                    : 0,
                backgroundColor: const Color(0xFFE8C49A),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 18),
            ] else
              const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}
