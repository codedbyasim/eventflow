import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../models/event_setup_model.dart';
import '../../providers/budget_provider.dart';
import '../../services/event_service.dart';
import '../../services/backend_service.dart';
import '../negotiation/live_dashboard_screen.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    String cleanedText = newValue.text.replaceAll(',', '');
    if (int.tryParse(cleanedText) == null) {
      return oldValue;
    }
    final int value = int.parse(cleanedText);
    final String formattedText = NumberFormat('#,###').format(value);
    
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class BudgetScreen extends StatefulWidget {
  final EventSetupModel model;

  const BudgetScreen({super.key, required this.model});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late BudgetProvider _budgetProvider;
  final TextEditingController _budgetController = TextEditingController();
  bool _isSubmitting = false;
  double _flexibilityValue = 0.15;
  
  final List<Color> _chartColors = [
    AppColors.goldenBrown,
    AppColors.mossGreen,
    AppColors.skyBlue,
    AppColors.strawRed,
    AppColors.linenBeige,
    const Color(0xFFF4C87A),
    const Color(0xFFA8C87A),
    const Color(0xFFE0937A),
    const Color(0xFFC4A8E0),
  ];

  @override
  void initState() {
    super.initState();
    _budgetProvider = BudgetProvider();
    _budgetProvider.initialize(widget.model.selectedVendors);
    _budgetProvider.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _budgetProvider.dispose();
    super.dispose();
  }

  void _onQuickBudget(int amount) {
    _budgetController.text = NumberFormat('#,###').format(amount);
    _budgetProvider.setTotalBudget(amount);
  }

  void _onBudgetChanged(String value) {
    String cleanedText = value.replaceAll(',', '');
    int? amount = int.tryParse(cleanedText);
    _budgetProvider.setTotalBudget(amount ?? 0);
  }

  String _getEmojiForVendor(String vendor) {
    final Map<String, String> emojis = {
      'Caterer': '🍽️', 'Decorator': '🌸', 'Photographer': '📸',
      'DJ / Music': '🎵', 'Tent / Marquee': '⛺', 'Sound System': '🔊',
      'Flowers': '💐', 'Transport': '🚗', 'Security': '🛡️'
    };
    return emojis[vendor] ?? '✨';
  }

  /// Get localized vendor name
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
    final bool hasBudget = _budgetProvider.totalBudget > 0;
    final vendors = widget.model.selectedVendors;
    
    return Directionality(
      textDirection: loc.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF0E6),
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(isUrdu ? Icons.arrow_forward : Icons.arrow_back, color: const Color(0xFF7A4E1E)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          loc.get('step_4_of_4'),
                          style: loc.fontStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7A4E1E),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // SECTION 1: Total Budget Input
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Text(
                              loc.get('total_budget'),
                              textAlign: TextAlign.center,
                              style: loc.headingStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF7A4E1E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              loc.get('budget_subtitle'),
                              textAlign: TextAlign.center,
                              style: loc.fontStyle(fontSize: 14, color: const Color(0xFFB08040), height: isUrdu ? 2.2 : 1.4),
                            ),
                            const SizedBox(height: 40),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  "PKR",
                                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.goldenBrown),
                                ),
                                const SizedBox(width: 8),
                                IntrinsicWidth(
                                  child: TextFormField(
                                    controller: _budgetController,
                                    onChanged: _onBudgetChanged,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      ThousandsSeparatorInputFormatter(),
                                      LengthLimitingTextInputFormatter(9),
                                    ],
                                    style: GoogleFonts.inter(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF7A4E1E),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "0",
                                      hintStyle: GoogleFonts.inter(color: const Color(0xFFE8C49A)),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 8,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildQuickBudgetChip("PKR 3L", 300000),
                                _buildQuickBudgetChip("PKR 5L", 500000),
                                _buildQuickBudgetChip("PKR 10L", 1000000),
                                _buildQuickBudgetChip("PKR 20L", 2000000),
                                _buildQuickBudgetChip("PKR 50L", 5000000),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // SECTION 2: Auto-Split Chart
                    if (hasBudget && vendors.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    loc.get('suggested_split'),
                                    style: loc.fontStyle(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF7A4E1E)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    loc.get('tap_to_edit'),
                                    style: loc.fontStyle(fontSize: 12, color: const Color(0xFFB08040)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                height: 200,
                                child: Stack(
                                  children: [
                                    PieChart(
                                      PieChartData(
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 60,
                                        sections: List.generate(vendors.length, (i) {
                                          final vendor = vendors[i];
                                          final val = _budgetProvider.allocations[vendor] ?? 0;
                                          return PieChartSectionData(
                                            color: _chartColors[i % _chartColors.length],
                                            value: val,
                                            title: '',
                                            radius: 28,
                                          );
                                        }),
                                      ),
                                    ),
                                    Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(loc.get('total'), style: loc.fontStyle(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF7A4E1E))),
                                          Text(
                                            "PKR ${NumberFormat('#,###').format(_budgetProvider.totalBudget)}",
                                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF7A4E1E)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                alignment: WrapAlignment.center,
                                children: List.generate(vendors.length, (i) {
                                  final vendor = vendors[i];
                                  final val = _budgetProvider.allocations[vendor] ?? 0;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10, height: 10,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: _chartColors[i % _chartColors.length]),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(_getLocalizedVendor(vendor, loc), style: loc.fontStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                      const SizedBox(width: 4),
                                      Text("PKR ${NumberFormat.compact().format(val)}", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB08040))),
                                    ],
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                    // SECTION 3: Per-Category Sliders
                    if (hasBudget && vendors.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                          child: Column(
                            crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(loc.get('adjust_allocation'), style: loc.fontStyle(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF7A4E1E))),
                              const SizedBox(height: 16),
                              ...List.generate(vendors.length, (i) {
                                final vendor = vendors[i];
                                final val = _budgetProvider.allocations[vendor] ?? 0;
                                final color = _chartColors[i % _chartColors.length];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 20.0),
                                  child: Column(
                                    crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                                          const SizedBox(width: 8),
                                          Text(_getEmojiForVendor(vendor)),
                                          const SizedBox(width: 4),
                                          Text(_getLocalizedVendor(vendor, loc), style: loc.fontStyle(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF1A1A1A))),
                                          const Spacer(),
                                          Text("PKR ${NumberFormat('#,###').format(val)}", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.goldenBrown)),
                                        ],
                                      ),
                                      SliderTheme(
                                        data: SliderThemeData(
                                          trackHeight: 4,
                                          activeTrackColor: color,
                                          inactiveTrackColor: color.withOpacity(0.2),
                                          thumbColor: color,
                                        ),
                                        child: Slider(
                                          value: val,
                                          min: 0,
                                          max: _budgetProvider.totalBudget.toDouble(),
                                          onChanged: (newVal) => _budgetProvider.updateAllocation(vendor, newVal),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Text(loc.get('min_budget'), style: loc.fontStyle(fontSize: 11, color: const Color(0xFFB08040))),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      
                    // SECTION 3.5: Negotiation Flexibility Range
                    if (hasBudget)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isUrdu ? "بات چیت کی لچک (Negotiation Flexibility)" : "Negotiation Flexibility Range",
                                  style: loc.fontStyle(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF7A4E1E)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isUrdu
                                      ? "یہ بتاتا ہے کہ AI ایجنٹ مناسب ڈیل حاصل کرنے کے لیے بجٹ سے کتنا اوپر جا سکتا ہے۔"
                                      : "Allows the AI Agent to negotiate up to this percentage above allocations if needed to secure a deal.",
                                  style: loc.fontStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "0%",
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                    Text(
                                      "${(_flexibilityValue * 100).toStringAsFixed(0)}%",
                                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.goldenBrown),
                                    ),
                                    Text(
                                      "30%",
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 4,
                                    activeTrackColor: AppColors.goldenBrown,
                                    inactiveTrackColor: AppColors.goldenBrown.withOpacity(0.2),
                                    thumbColor: AppColors.goldenBrown,
                                  ),
                                  child: Slider(
                                    value: _flexibilityValue,
                                    min: 0.0,
                                    max: 0.30,
                                    divisions: 6,
                                    onChanged: (val) {
                                      setState(() {
                                        _flexibilityValue = val;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // SECTION 4: Pre-flight Summary
                    if (hasBudget)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                _buildSummaryRow(
                                  loc.get('guests_label'),
                                  "${widget.model.guestCount} (Est. food: PKR ${NumberFormat('#,###').format(_budgetProvider.totalBudget * 0.4 / widget.model.guestCount)}/head)",
                                  loc,
                                ),
                                const SizedBox(height: 12),
                                _buildSummaryRow(loc.get('city_label'), widget.model.city ?? loc.get('not_specified'), loc),
                                const SizedBox(height: 12),
                                _buildSummaryRow(
                                  loc.get('date_label'), 
                                  widget.model.eventDate != null 
                                    ? "${DateFormat('MMM d, yyyy').format(widget.model.eventDate!)} (${widget.model.eventDate!.difference(DateTime.now()).inDays} ${loc.get('days_from_today')})" 
                                    : loc.get('tbd'),
                                  loc,
                                ),
                                const SizedBox(height: 12),
                                _buildSummaryRow(loc.get('agents_to_launch'), "${vendors.length} ${loc.get('vendors_selected')}", loc),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16.0),
                                  child: Divider(color: Color(0xFFE8C49A), height: 1),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(loc.get('total_budget_label'), style: loc.fontStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                                    Text("PKR ${NumberFormat('#,###').format(_budgetProvider.totalBudget)}", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.goldenBrown)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: Hero(
              tag: 'launch_button',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD18D55), Color(0xFFC47035)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: hasBudget ? [BoxShadow(color: AppColors.goldenBrown.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))] : null,
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      disabledBackgroundColor: const Color(0xFFCCCCCC),
                    ),
                    onPressed: (hasBudget && !_isSubmitting)
                        ? () => _submitAndLaunch()
                        : null,
                    child: Text(
                      loc.get('launch_negotiations'),
                      style: loc.fontStyle(
                        fontSize: 18,
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
    );
  }

  Future<void> _submitAndLaunch() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final updatedModel = widget.model.copyWith(
      totalBudget: _budgetProvider.totalBudget,
      negotiationFlexibility: _flexibilityValue,
    );

    try {
      // Force-refresh the Firebase ID token before calling the backend.
      // This ensures the backend role-check sees the latest Firestore role
      // (avoids 403 on accounts created moments ago).
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in. Please sign in again.');
      await user.getIdToken(true);

      // FR-EVT-07: submit to backend — triggers Analyzer Agent within 3s
      final result = await EventService.instance.submitEvent(
        updatedModel,
        perCategoryMax: _budgetProvider.allocations.map(
          (k, v) => MapEntry(k, v),
        ),
      );

      if (!mounted) return;

      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) =>
              LiveDashboardScreen(
            model: updatedModel,
            allocations: _budgetProvider.allocations,
            eventFirestoreId: result.eventFirestoreId,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } on BackendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not start negotiations: ${e.message}'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 6),
      ));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildQuickBudgetChip(String label, int amount) {
    return InkWell(
      onTap: () => _onQuickBudget(amount),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE8C49A)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF7A4E1E)),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, dynamic loc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: loc.fontStyle(fontSize: 13.0, color: const Color(0xFF666666))),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: loc.fontStyle(fontSize: 13.0, fontWeight: FontWeight.w500, color: const Color(0xFF1A1A1A)),
          ),
        ),
      ],
    );
  }
}
