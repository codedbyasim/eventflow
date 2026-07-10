import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../models/event_setup_model.dart';
import 'budget_screen.dart';

class VendorCategoriesScreen extends StatefulWidget {
  final EventSetupModel model;

  const VendorCategoriesScreen({super.key, required this.model});

  @override
  State<VendorCategoriesScreen> createState() => _VendorCategoriesScreenState();
}

class _VendorCategoriesScreenState extends State<VendorCategoriesScreen> {
  late Set<String> _selectedVendors;
  
  final List<Map<String, dynamic>> _allVendors = [
    {'title': 'Caterer', 'titleKey': 'caterer', 'icon': Icons.restaurant, 'price': 'PKR 800–1,500/head', 'sub': ['Desi', 'Continental', 'BBQ']},
    {'title': 'Decorator', 'titleKey': 'decorator', 'icon': Icons.auto_awesome, 'price': 'PKR 80,000–400,000', 'sub': ['Floral', 'Fairy lights', 'Stage']},
    {'title': 'Photographer', 'titleKey': 'photographer', 'icon': Icons.camera_alt, 'price': 'PKR 50,000–200,000', 'sub': ['Photo', 'Video', 'Drone']},
    {'title': 'DJ / Music', 'titleKey': 'dj_music', 'icon': Icons.music_note, 'price': 'PKR 25,000–100,000', 'sub': ['DJ', 'Live band', 'Qawwali']},
    {'title': 'Tent / Marquee', 'titleKey': 'tent_marquee', 'icon': Icons.storefront, 'price': 'PKR 60,000–250,000', 'sub': ['Shamiana', 'Marquee', 'Hall']},
    {'title': 'Sound System', 'titleKey': 'sound_system', 'icon': Icons.speaker, 'price': 'PKR 20,000–80,000', 'sub': ['PA system', 'Monitors', 'Lighting']},
    {'title': 'Flowers', 'titleKey': 'flowers', 'icon': Icons.local_florist, 'price': 'PKR 15,000–80,000', 'sub': ['Bouquets', 'Garlands', 'Centerpieces']},
    {'title': 'Transport', 'titleKey': 'transport', 'icon': Icons.directions_car, 'price': 'PKR 10,000–50,000', 'sub': ['Dholki car', 'Barat convoy']},
    {'title': 'Security', 'titleKey': 'security', 'icon': Icons.security, 'price': 'PKR 15,000–60,000', 'sub': ['Guards', 'Crowd management']},
  ];

  @override
  void initState() {
    super.initState();
    _selectedVendors = Set<String>.from(widget.model.preSelectedVendors);
  }

  void _onContinue() {
    final loc = context.loc;
    if (_selectedVendors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.get('select_vendor_warning'), style: loc.fontStyle(color: Colors.white)),
          backgroundColor: AppColors.strawRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    final updatedModel = widget.model.copyWith(selectedVendors: _selectedVendors.toList());
    
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => BudgetScreen(model: updatedModel),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isUrdu = context.isUrdu;

    return Directionality(
      textDirection: loc.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F7F2), // Premium Linen Beige
        body: SafeArea(
          child: Column(
            children: [
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
                          loc.get('step_3_of_4'),
                          style: loc.fontStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E3D26), // Deep Moss Green
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  children: [
                    Center(
                      child: Text(
                        loc.get('who_need'),
                        textAlign: TextAlign.center,
                        style: loc.headingStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E3D26), // Deep Moss Green
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E3D26), // Deep Moss Green
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${_selectedVendors.length} ${loc.get('vendors_selected')} • ${loc.get('estimated')}",
                        style: loc.fontStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFDFBF7), // Light Cream
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  itemCount: _allVendors.length,
                  itemBuilder: (context, index) {
                    final v = _allVendors[index];
                    final isSelected = _selectedVendors.contains(v['title']);
                    final isRequired = widget.model.preSelectedVendors.contains(v['title']);
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedVendors.remove(v['title']);
                          } else {
                            _selectedVendors.add(v['title']);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF), // Pure crisp White
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected ? Border.all(color: const Color(0xFF2E3D26), width: 1.5) : Border.all(color: Colors.transparent, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE5DED5).withOpacity(0.6), // Subtle beige blur tint
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF0F3EF), // 10% tint of Moss Green
                                shape: BoxShape.circle,
                              ),
                              child: Icon(v['icon'] as IconData, size: 24, color: const Color(0xFF2E3D26)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          loc.get(v['titleKey']),
                                          textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                                          style: loc.fontStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF333333), // Dark charcoal
                                          ),
                                        ),
                                      ),
                                      if (isRequired && isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2E3D26), // Moss Green
                                            borderRadius: BorderRadius.circular(12), // Pill shape
                                          ),
                                          child: Text(
                                            loc.get('suggested'),
                                            style: loc.fontStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    v['price'].replaceAll('[city]', widget.model.city ?? 'your city'),
                                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF777777)), // Soft medium grey
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: (v['sub'] as List<String>).map((sub) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F5F5), // Light grey background
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          sub,
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF2E3D26)), // Dark Moss Green
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFF2E3D26), // Deep Moss Green
                              checkColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedVendors.add(v['title']);
                                  } else {
                                    _selectedVendors.remove(v['title']);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Bottom Action
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: _selectedVendors.isNotEmpty ? AppColors.goldenBrown : const Color(0xFFCCCCCC),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 0,
                      ),
                      onPressed: _selectedVendors.isNotEmpty ? _onContinue : null,
                      child: Text(
                        "${loc.get('continue_btn')} →",
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
            ],
          ),
        ),
      ),
    );
  }
}
