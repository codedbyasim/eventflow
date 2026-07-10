import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:confetti/confetti.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../models/event_setup_model.dart';
import 'agent_thread_screen.dart';
import 'best_combination_screen.dart';

enum NegotiatorStatus { connecting, negotiating, counterOffer, deal, noDeal }

class VendorNegotiationState {
  final String vendor;
  final int askingPrice;
  final int currentOffer;
  final NegotiatorStatus status;
  final int offerCount;
  final int maxOffers;

  VendorNegotiationState({
    required this.vendor,
    required this.askingPrice,
    required this.currentOffer,
    required this.status,
    required this.offerCount,
    required this.maxOffers,
  });
}

class NegotiationSimulator {
  final List<String> vendors;
  final Map<String, double> initialAllocations;
  
  final _controller = StreamController<Map<String, VendorNegotiationState>>.broadcast();
  final Map<String, VendorNegotiationState> _stateMap = {};
  final Random _rnd = Random();
  
  NegotiationSimulator(this.vendors, this.initialAllocations) {
    _startSimulation();
  }

  Stream<Map<String, VendorNegotiationState>> get stream => _controller.stream;

  void _startSimulation() {
    for (var vendor in vendors) {
      double alloc = initialAllocations[vendor] ?? 100000;
      int asking = alloc.toInt();
      if (asking <= 0) asking = 50000;
      
      _stateMap[vendor] = VendorNegotiationState(
        vendor: vendor,
        askingPrice: asking,
        currentOffer: asking,
        status: NegotiatorStatus.connecting,
        offerCount: 0,
        maxOffers: 5,
      );
      
      _runVendorThread(vendor, asking);
    }
    _controller.add(Map.from(_stateMap));
  }

  Future<void> _runVendorThread(String vendor, int askingPrice) async {
    // Phase 1 (0–2s): status = Connecting
    await Future.delayed(Duration(milliseconds: _rnd.nextInt(2000)));
    
    await Future.delayed(Duration(milliseconds: 1500 + _rnd.nextInt(500)));
    
    // Phase 2 (2–4s): status = Negotiating
    _updateState(vendor, NegotiatorStatus.negotiating, askingPrice, 1);
    await Future.delayed(Duration(milliseconds: 1500 + _rnd.nextInt(1000)));
    
    // Phase 3 (4–6s): status = CounterOffer
    int offer1 = (askingPrice * (0.88 + _rnd.nextDouble() * 0.07)).round();
    _updateState(vendor, NegotiatorStatus.counterOffer, offer1, 2);
    await Future.delayed(Duration(milliseconds: 1500 + _rnd.nextInt(1000)));
    
    // Phase 4 (6–8s): status = Negotiating
    _updateState(vendor, NegotiatorStatus.negotiating, offer1, 3);
    await Future.delayed(Duration(milliseconds: 1500 + _rnd.nextInt(1000)));
    
    // Phase 5 (8–10s): status = CounterOffer again
    int offer2 = (askingPrice * (0.78 + _rnd.nextDouble() * 0.10)).round();
    _updateState(vendor, NegotiatorStatus.counterOffer, offer2, 4);
    await Future.delayed(Duration(milliseconds: 1500 + _rnd.nextInt(1000)));
    
    // Phase 6 (10–13s): status = Deal OR NoDeal
    bool isDeal = _rnd.nextDouble() < 0.90;
    _updateState(
      vendor, 
      isDeal ? NegotiatorStatus.deal : NegotiatorStatus.noDeal, 
      isDeal ? offer2 : askingPrice, 
      5
    );
  }

  void _updateState(String vendor, NegotiatorStatus status, int offer, int count) {
    final old = _stateMap[vendor]!;
    _stateMap[vendor] = VendorNegotiationState(
      vendor: vendor,
      askingPrice: old.askingPrice,
      currentOffer: offer,
      status: status,
      offerCount: count,
      maxOffers: old.maxOffers,
    );
    if (!_controller.isClosed) {
      _controller.add(Map.from(_stateMap));
    }
  }

  void dispose() {
    _controller.close();
  }
}

class LiveDashboardScreen extends StatefulWidget {
  final EventSetupModel model;
  final Map<String, double> allocations;

  const LiveDashboardScreen({super.key, required this.model, required this.allocations});

  @override
  State<LiveDashboardScreen> createState() => _LiveDashboardScreenState();
}

class _LiveDashboardScreenState extends State<LiveDashboardScreen> with SingleTickerProviderStateMixin {
  late NegotiationSimulator _simulator;
  late ConfettiController _confettiController;
  late AnimationController _pulseController;
  
  Map<String, VendorNegotiationState> _currentState = {};
  bool _allFinished = false;

  @override
  void initState() {
    super.initState();
    _simulator = NegotiationSimulator(widget.model.selectedVendors, widget.allocations);
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    
    _simulator.stream.listen((state) {
      if (!mounted) return;
      setState(() {
        _currentState = state;
      });
      _checkIfAllFinished(state);
    });
  }
  
  void _checkIfAllFinished(Map<String, VendorNegotiationState> state) {
    if (state.isEmpty) return;
    bool allDone = true;
    for (var v in state.values) {
      if (v.status != NegotiatorStatus.deal && v.status != NegotiatorStatus.noDeal) {
        allDone = false;
        break;
      }
    }
    if (allDone && !_allFinished) {
      _allFinished = true;
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _simulator.dispose();
    _confettiController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color _statusColor(NegotiatorStatus status) {
    switch (status) {
      case NegotiatorStatus.connecting: return const Color(0xFF888888);
      case NegotiatorStatus.negotiating: return AppColors.strawRed;
      case NegotiatorStatus.counterOffer: return AppColors.goldenBrown;
      case NegotiatorStatus.deal: return AppColors.mossGreen;
      case NegotiatorStatus.noDeal: return const Color(0xFF666666);
    }
  }

  String _statusText(NegotiatorStatus status, dynamic loc) {
    switch (status) {
      case NegotiatorStatus.connecting: return loc.get('connecting');
      case NegotiatorStatus.negotiating: return loc.get('negotiating');
      case NegotiatorStatus.counterOffer: return loc.get('counter_offer');
      case NegotiatorStatus.deal: return loc.get('deal');
      case NegotiatorStatus.noDeal: return loc.get('no_deal');
    }
  }

  IconData _getIconForVendor(String vendor) {
    switch (vendor) {
      case 'Caterer': return Icons.restaurant_menu;
      case 'Decorator': return Icons.auto_awesome;
      case 'Photographer': return Icons.camera_alt_outlined;
      case 'DJ / Music': return Icons.music_note;
      case 'Tent / Marquee': return Icons.holiday_village_outlined;
      case 'Sound System': return Icons.speaker;
      case 'Flowers': return Icons.local_florist_outlined;
      case 'Transport': return Icons.directions_car_outlined;
      case 'Security': return Icons.security;
      default: return Icons.star_border;
    }
  }

  String _getLocalizedVendor(String vendor, dynamic loc) {
    final Map<String, String> vendorKeys = {
      'Caterer': 'caterer', 'Decorator': 'decorator', 'Photographer': 'photographer',
      'DJ / Music': 'dj_music', 'Tent / Marquee': 'tent_marquee', 'Sound System': 'sound_system',
      'Flowers': 'flowers', 'Transport': 'transport', 'Security': 'security',
    };
    final key = vendorKeys[vendor];
    return key != null ? loc.get(key) : vendor;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isUrdu = context.isUrdu;
    
    int lockedInAmount = 0;
    int totalSavings = 0;
    
    _currentState.forEach((key, state) {
      if (state.status == NegotiatorStatus.deal) {
        lockedInAmount += state.currentOffer;
        totalSavings += (state.askingPrice - state.currentOffer);
      }
    });

    int remaining = widget.model.totalBudget - lockedInAmount;
    
    return Directionality(
      textDirection: loc.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F7F2), // Premium Linen Beige background
        body: Stack(
          children: [
            Column(
              children: [
                // TOP STRIP
                Container(
                  color: const Color(0xFFF7F3EB), // Slightly lighter top bar
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(isUrdu ? Icons.arrow_forward : Icons.arrow_back, color: const Color(0xFF7A4E1E)),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        return Opacity(
                                          opacity: _allFinished ? 0.3 : 0.3 + (_pulseController.value * 0.7),
                                          child: Container(
                                            width: 8, height: 8,
                                            decoration: const BoxDecoration(color: AppColors.strawRed, shape: BoxShape.circle),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      loc.get('live'),
                                      style: loc.fontStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.strawRed,
                                      ).copyWith(letterSpacing: isUrdu ? 0 : 2.0),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _allFinished ? loc.get('negotiation_complete') : loc.get('ai_negotiating'),
                                  style: loc.fontStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: isUrdu ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                            children: [
                              Text(loc.get('budget_label'), style: loc.fontStyle(fontSize: 12, color: const Color(0xFF666666))),
                              Text(
                                "PKR ${NumberFormat('#,###').format(widget.model.totalBudget)}",
                                textDirection: TextDirection.ltr,
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // NEW OVERVIEW CONTAINER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFDFD), // Soft off-white / glassmorphic
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
                                  Text(loc.get('locked_in'), style: loc.fontStyle(fontSize: 12, color: const Color(0xFF888888))),
                                  const SizedBox(height: 4),
                                  Text(
                                    "PKR ${NumberFormat('#,###').format(lockedInAmount)}",
                                    textDirection: TextDirection.ltr,
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.get('remaining'), style: loc.fontStyle(fontSize: 12, color: const Color(0xFF888888))),
                                  const SizedBox(height: 4),
                                  Text(
                                    "PKR ${NumberFormat('#,###').format(remaining)}",
                                    textDirection: TextDirection.ltr,
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF3E1), // Soft Moss Green tint
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(loc.get('total_savings_vs_asking'), style: loc.fontStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2E3D26))),
                              const SizedBox(width: 4),
                              AnimatedFlipCounter(
                                value: totalSavings,
                                prefix: "PKR ",
                                textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2E3D26)),
                                duration: const Duration(milliseconds: 500),
                              ),
                              const SizedBox(width: 4),
                              Text(loc.get('so_far'), style: loc.fontStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2E3D26))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // AGENT CARDS GRID
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16.0).copyWith(bottom: 100), // padding for CTA
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: widget.model.selectedVendors.length,
                    itemBuilder: (context, index) {
                      final vendor = widget.model.selectedVendors[index];
                      final state = _currentState[vendor];
                      
                      if (state == null) return const SizedBox();
                      
                      final color = _statusColor(state.status);
                      
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AgentThreadScreen(vendorName: vendor)),
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: state.status == NegotiatorStatus.noDeal 
                                ? const Color(0xFFF5F5F5) 
                                : Color.alphaBlend(color.withValues(alpha: 0.06), Colors.white),
                            border: Border.all(color: state.status == NegotiatorStatus.deal ? const Color(0xFFEDF3E1) : Colors.transparent, width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ROW 1
                              Row(
                                children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF0F3EF), // 10% Moss Green
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Opacity(
                                      opacity: state.status == NegotiatorStatus.noDeal ? 0.7 : 1.0,
                                      child: Icon(_getIconForVendor(vendor), size: 18, color: const Color(0xFF2E3D26)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getLocalizedVendor(vendor, loc),
                                      textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                                      style: loc.fontStyle(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF333333)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // STATUS CHIP
                              if (state.status == NegotiatorStatus.deal)
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
                                        style: loc.fontStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                )
                              else if (state.status == NegotiatorStatus.noDeal)
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
                                        style: loc.fontStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
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
                                    style: loc.fontStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                                  ),
                                ),
                              
                              const Spacer(),
                              
                              // ROW 2 - Asking Price
                              Text(
                                "${loc.get('asking_price')}: ${NumberFormat.compact().format(state.askingPrice)}",
                                textDirection: TextDirection.ltr,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF999999),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(height: 2),
                              
                              // ROW 3 - Current Offer
                              Text(
                                "${loc.get('current_offer')}: ${NumberFormat.compact().format(state.currentOffer)}",
                                textDirection: TextDirection.ltr,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: state.status == NegotiatorStatus.deal ? const Color(0xFF2E3D26) : const Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // ROW 6 Savings chip
                              if (state.status == NegotiatorStatus.deal)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDF3E1), // Light olive/linen background
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "${loc.get('saved_pkr')} ${NumberFormat.compact().format(state.askingPrice - state.currentOffer)}",
                                    textDirection: TextDirection.ltr,
                                    style: loc.fontStyle(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2E3D26)),
                                  ),
                                )
                              else if (state.status != NegotiatorStatus.noDeal) ...[
                                LinearProgressIndicator(
                                  value: state.maxOffers > 0 ? state.offerCount / state.maxOffers : 0,
                                  backgroundColor: const Color(0xFFE8C49A),
                                  valueColor: AlwaysStoppedAnimation<Color>(color),
                                  minHeight: 4,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                const SizedBox(height: 18),
                              ] else ...[
                                const SizedBox(height: 22),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            
            // Confetti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [AppColors.mossGreen, AppColors.strawRed, AppColors.goldenBrown, Color(0xFF7A4E1E)],
              ),
            ),
            
            // BOTTOM FIXED BUTTON
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
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          elevation: 8,
                          shadowColor: AppColors.goldenBrown.withValues(alpha: 0.5),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const BestCombinationScreen()),
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
                              "${loc.get('see_best_combination')} →",
                              style: loc.fontStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
}
