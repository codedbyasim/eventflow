import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme/app_colors.dart';
import '../../services/backend_service.dart';

class VendorOnboardingScreen extends StatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  State<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends State<VendorOnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Business Name
  final _businessNameController = TextEditingController();
  
  // Step 2: Service Category
  String? _selectedCategory;
  
  // Step 3: Location & Pricing
  String? _selectedCity;
  final _basePriceController = TextEditingController();
  final _minPriceController = TextEditingController();
  String? _priceError;
  
  // Step 4: Availability
  Set<DateTime> _blockedDates = {};

  final List<Map<String, dynamic>> _categories = [
    {'key': 'caterer', 'icon': Icons.restaurant},
    {'key': 'decorator', 'icon': Icons.color_lens},
    {'key': 'photographer', 'icon': Icons.camera_alt},
    {'key': 'dj_sound', 'icon': Icons.music_note},
    {'key': 'tent', 'icon': Icons.home_work},
    {'key': 'security', 'icon': Icons.security},
    {'key': 'flowers', 'icon': Icons.local_florist},
    {'key': 'other', 'icon': Icons.add_circle_outline},
  ];

  final List<String> _cities = [
    'islamabad',
    'lahore',
    'karachi',
    'rawalpindi',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _businessNameController.dispose();
    _basePriceController.dispose();
    _minPriceController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/signin');
      }
    }
  }

  Future<void> _submitOnboarding() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final basePrice = double.tryParse(_basePriceController.text) ?? 0.0;
      final minPrice = double.tryParse(_minPriceController.text) ?? 0.0;

      final isoBlockedDates = _blockedDates.map((d) => d.toIso8601String()).toList();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'onboardingComplete': true,
        'vendorProfile': {
          'businessName': _businessNameController.text.trim(),
          'category': _selectedCategory,
          'city': _selectedCity,
          'basePrice': basePrice,
          'minPrice': minPrice,
          'blockedDates': isoBlockedDates,
          'rating': 0.0,
          'totalBookings': 0,
          'responseRate': 100,
          'onboardingComplete': true,
          'createdAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      // Force-refresh the ID token so the backend sees the latest Firestore claims.
      // This ensures the role lookup on the backend gets the freshly written role.
      await user.getIdToken(true);

      // Sync onboarding details to PostgreSQL database so they can match/claim negotiations
      String pgCategory = 'Caterer';
      switch (_selectedCategory) {
        case 'caterer': pgCategory = 'Caterer'; break;
        case 'decorator': pgCategory = 'Decorator'; break;
        case 'photographer': pgCategory = 'Photographer'; break;
        case 'dj_sound': pgCategory = 'DJ / Music'; break;
        case 'tent': pgCategory = 'Tent / Marquee'; break;
        case 'flowers': pgCategory = 'Flowers'; break;
      }

      await BackendService.instance.post(
        '/users/onboard-vendor',
        body: {
          'business_name': _businessNameController.text.trim(),
          'category': pgCategory,
          'city': _selectedCity!.toLowerCase(),
          'base_price': basePrice,
          'min_price': minPrice,
        },
      );

      if (mounted) {
        context.go('/vendor/home');
      }
    } on BackendException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('save_error')}: ${e.message}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('save_error')}: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _canProceedStep1() {
    final text = _businessNameController.text.trim();
    return text.length >= 2 && text.length <= 60;
  }

  bool _canProceedStep2() {
    return _selectedCategory != null;
  }

  bool _canProceedStep3() {
    if (_selectedCity == null) return false;
    final basePrice = double.tryParse(_basePriceController.text);
    final minPrice = double.tryParse(_minPriceController.text);
    
    if (basePrice == null || basePrice <= 0) return false;
    if (minPrice == null || minPrice <= 0) return false;
    
    if (minPrice >= basePrice) {
      return false;
    }
    return true;
  }
  
  void _validateStep3Prices() {
    final basePrice = double.tryParse(_basePriceController.text);
    final minPrice = double.tryParse(_minPriceController.text);
    
    if (basePrice != null && minPrice != null && minPrice >= basePrice) {
      setState(() {
        _priceError = tr('price_floor_error');
      });
    } else {
      setState(() {
        _priceError = null;
      });
    }
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              decoration: BoxDecoration(
                color: index <= _currentStep ? AppColors.goldenBrown : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomButton({required bool enabled, required String text, required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled ? AppColors.strawRed : Colors.grey.shade300,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            elevation: 0,
          ),
          onPressed: enabled ? onPressed : null,
          child: _isLoading 
            ? const SizedBox(
                width: 24, height: 24, 
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
              )
            : Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.white : Colors.grey.shade500,
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('business_name'),
            style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _businessNameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (value) => setState(() {}),
            style: GoogleFonts.inter(fontSize: 18),
            decoration: InputDecoration(
              hintText: tr('business_name_hint'),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('what_do_you_offer'),
            style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat['key'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat['key']),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.goldenBrown : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(cat['icon'], size: 40, color: isSelected ? AppColors.goldenBrown : Colors.grey.shade600),
                              const SizedBox(height: 12),
                              Text(
                                tr(cat['key']),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? AppColors.goldenBrown : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(Icons.check_circle, color: AppColors.goldenBrown),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    // Dynamic text based on selected category
    String pricingBasisEn = '';
    String pricingBasisUr = '';
    
    switch (_selectedCategory) {
      case 'caterer':
        pricingBasisEn = 'Catering prices are calculated per person (per head). For example: PKR 2,000 per head.';
        pricingBasisUr = 'کیٹرنگ کی قیمتیں فی کس (پر پرسن) شمار ہوتی ہیں۔ مثال کے طور پر: 2000 روپے فی کس۔';
        break;
      case 'tent':
        pricingBasisEn = 'Enter your base hall/marquee setup fee. Additional seating is calculated at PKR 300 per head.';
        pricingBasisUr = 'ہال/مارکی کا بنیادی کرایہ درج کریں۔ مہمانوں کے بیٹھنے کا کرایہ 300 روپے فی کس الگ سے شمار ہوگا۔';
        break;
      case 'decorator':
        pricingBasisEn = 'Enter your base package rate. It will scale automatically by 1.25x for Outdoor events, and +5% for every 100 excess guests.';
        pricingBasisUr = 'اپنے بنیادی پیکج کی قیمت درج کریں۔ آؤٹ ڈور ایونٹس کے لیے 1.25 گنا اور 100 سے زائد مہمانوں پر +5 فیصد خودکار طور پر بڑھے گی۔';
        break;
      case 'flowers':
        pricingBasisEn = 'Enter your base floral package. It scales proportionally for guest counts above 100 guests.';
        pricingBasisUr = 'اپنے پھولوں کے بنیادی پیکج کی قیمت درج کریں۔ 100 سے زائد مہمانوں کی صورت میں قیمت متناسب طور پر بڑھے گی۔';
        break;
      default:
        pricingBasisEn = 'This is a flat rate package for a standard single-day event booking.';
        pricingBasisUr = 'یہ ایک دن کے ایونٹ کی فلیٹ شرح (مقررہ قیمت) ہے۔';
    }

    final isUrdu = context.locale.languageCode == 'ur';
    final pricingBasis = isUrdu ? pricingBasisUr : pricingBasisEn;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('your_city'),
            style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _cities.map((city) {
              final isSelected = _selectedCity == city;
              return InkWell(
                onTap: () => setState(() {
                  _selectedCity = city;
                  _validateStep3Prices();
                }),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.goldenBrown : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? AppColors.goldenBrown : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    tr(city),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Dynamic pricing basis explanation card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.goldenBrown.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.goldenBrown.withValues(alpha: 0.25), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.goldenBrown, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUrdu ? 'قیمت کی بنیاد (Pricing Basis):' : 'Pricing Basis:',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7A4E1E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pricingBasis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.black87,
                          height: isUrdu ? 1.8 : 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Text(tr('base_price'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _basePriceController,
            keyboardType: TextInputType.number,
            onChanged: (v) {
              _validateStep3Prices();
              setState((){});
            },
            style: GoogleFonts.inter(fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(tr('base_price_helper'), style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
          ),
          
          const SizedBox(height: 24),
          
          Text(tr('minimum_price'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _minPriceController,
            keyboardType: TextInputType.number,
            onChanged: (v) {
              _validateStep3Prices();
              setState((){});
            },
            style: GoogleFonts.inter(fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              tr('minimum_price_helper'),
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.strawRed),
            ),
          ),
          if (_priceError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                _priceError!,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('when_available'),
            style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 30)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: DateTime.now(),
              selectedDayPredicate: (day) {
                return _blockedDates.any((d) => isSameDay(d, day));
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              calendarBuilders: CalendarBuilders(
                selectedBuilder: (context, day, focusedDay) {
                  return Container(
                    margin: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.close, color: Colors.grey, size: 20),
                    ),
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  return Container(
                    margin: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(
                      color: AppColors.goldenBrown.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(day.day.toString(), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  final exists = _blockedDates.any((d) => isSameDay(d, selectedDay));
                  if (exists) {
                    _blockedDates.removeWhere((d) => isSameDay(d, selectedDay));
                  } else {
                    _blockedDates.add(selectedDay);
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(tr('available'), style: GoogleFonts.inter(fontSize: 14)),
                ],
              ),
              const SizedBox(width: 32),
              Row(
                children: [
                  const Icon(Icons.close, color: Colors.grey, size: 18),
                  const SizedBox(width: 4),
                  Text(tr('busy'), style: GoogleFonts.inter(fontSize: 14)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = context.locale.languageCode == 'ur';
    final textDirection = isUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F3EB),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(isUrdu ? Icons.arrow_forward : Icons.arrow_back, color: Colors.black87),
            onPressed: _previousStep,
          ),
        ),
        body: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                ],
              ),
            ),
            if (_currentStep == 0)
              _buildBottomButton(enabled: _canProceedStep1(), text: tr('next'), onPressed: _nextStep)
            else if (_currentStep == 1)
              _buildBottomButton(enabled: _canProceedStep2(), text: tr('next'), onPressed: _nextStep)
            else if (_currentStep == 2)
              _buildBottomButton(enabled: _canProceedStep3(), text: tr('next'), onPressed: _nextStep)
            else if (_currentStep == 3)
              _buildBottomButton(enabled: true, text: tr('finish'), onPressed: _submitOnboarding),
          ],
        ),
      ),
    );
  }
}
