import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

Map<String, dynamic> buildVendorProfilePayload({
  required String businessName,
  String? city,
  required double basePrice,
  required double minPrice,
  required List<String> blockedDates,
}) {
  return {
    'updatedAt': FieldValue.serverTimestamp(),
    'vendorProfile': {
      'businessName': businessName,
      'city': city,
      'basePrice': basePrice,
      'minPrice': minPrice,
      'blockedDates': blockedDates,
    },
  };
}

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = false;
  bool _hasChanges = false;
  
  final _businessNameController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _minPriceController = TextEditingController();
  
  String? _selectedCity;
  Set<DateTime> _blockedDates = {};
  
  String? _priceError;
  bool _pricesFocused = false;
  
  final FocusNode _basePriceFocus = FocusNode();
  final FocusNode _minPriceFocus = FocusNode();

  final List<String> _cities = [
    'islamabad',
    'lahore',
    'karachi',
    'rawalpindi',
  ];

  @override
  void initState() {
    super.initState();
    _basePriceFocus.addListener(_onPriceFocusChange);
    _minPriceFocus.addListener(_onPriceFocusChange);
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _basePriceController.dispose();
    _minPriceController.dispose();
    _basePriceFocus.dispose();
    _minPriceFocus.dispose();
    super.dispose();
  }

  void _onPriceFocusChange() {
    setState(() {
      _pricesFocused = _basePriceFocus.hasFocus || _minPriceFocus.hasFocus;
    });
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  void _populateForm(Map<String, dynamic> data) {
    _businessNameController.text = data['businessName'] ?? '';
    _basePriceController.text = (data['basePrice'] ?? 0.0).toString();
    _minPriceController.text = (data['minPrice'] ?? 0.0).toString();
    _selectedCity = data['city'];
    
    final List<dynamic>? dates = data['blockedDates'];
    if (dates != null) {
      _blockedDates = dates.map((d) => DateTime.parse(d as String)).toSet();
    } else {
      _blockedDates = {};
    }
    
    _hasChanges = false;
    _isEditing = true;
  }

  void _validatePrices() {
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

  Future<void> _saveProfile() async {
    final basePrice = double.tryParse(_basePriceController.text);
    final minPrice = double.tryParse(_minPriceController.text);
    
    if (basePrice == null || basePrice <= 0) return;
    if (minPrice == null || minPrice <= 0) return;
    
    if (minPrice >= basePrice) {
      setState(() => _priceError = tr('price_floor_error'));
      return;
    }
    if (_businessNameController.text.trim().isEmpty) return;
    if (_selectedCity == null) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final isoBlockedDates = _blockedDates.map((d) => d.toIso8601String()).toList();

      final payload = buildVendorProfilePayload(
        businessName: _businessNameController.text.trim(),
        city: _selectedCity,
        basePrice: basePrice,
        minPrice: minPrice,
        blockedDates: isoBlockedDates,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _isEditing = false;
          _hasChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('saved_successfully'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('save_error'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('unsaved_changes_title')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Discard
            child: Text(tr('discard'), style: const TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, false);
              _saveProfile();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.strawRed),
            child: Text(tr('save'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (result == true) {
      setState(() {
        _hasChanges = false;
        _isEditing = false;
      });
    }
    return result ?? false;
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.goldenBrown),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildReadOnly(Map<String, dynamic> data) {
    final businessName = data['businessName'] ?? '';
    final category = data['category'] ?? '';
    final city = data['city'] ?? '';
    final basePrice = data['basePrice'] ?? 0.0;
    final minPrice = data['minPrice'] ?? 0.0;
    final totalBookings = data['totalBookings'] ?? 0;
    // Assuming avgDealValue might be pre-calculated or fetched. If missing, default to 0
    final avgDealValue = data['avgDealValue'] ?? 0.0; 
    final responseRate = data['responseRate'] ?? 100;
    
    final List<dynamic>? dates = data['blockedDates'];
    final displayBlockedDates = dates != null ? dates.map((d) => DateTime.parse(d as String)).toSet() : <DateTime>{};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildStatCard(tr('total_bookings'), totalBookings.toString()),
              _buildStatCard(tr('avg_deal_value'), 'PKR $avgDealValue'),
              _buildStatCard(tr('response_rate'), '$responseRate%'),
            ],
          ),
          const SizedBox(height: 32),
          
          _buildDisplayTile(tr('business_name'), businessName),
          _buildDisplayTile(tr('category'), tr(category)),
          _buildDisplayTile(tr('your_city'), tr(city)),
          _buildDisplayTile(tr('base_price'), 'PKR $basePrice'),
          _buildDisplayTile(tr('minimum_price'), 'PKR $minPrice'),
          
          const SizedBox(height: 24),
          Text(tr('when_available'), style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 30)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: DateTime.now(),
              availableGestures: AvailableGestures.none, // Non-interactive
              selectedDayPredicate: (day) => displayBlockedDates.any((d) => isSameDay(d, day)),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              calendarBuilders: CalendarBuilders(
                selectedBuilder: (context, day, focusedDay) {
                  return Container(
                    margin: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle),
                    child: const Center(child: Icon(Icons.close, color: Colors.grey, size: 20)),
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  return Container(
                    margin: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(color: AppColors.goldenBrown.withOpacity(0.3), shape: BoxShape.circle),
                    child: Center(child: Text(day.day.toString(), style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                  );
                },
              ),
              onDaySelected: null,
            ),
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldenBrown,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
              onPressed: () {
                setState(() {
                  _populateForm(data);
                });
              },
              child: Text(tr('edit'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.goldenBrown),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                foregroundColor: AppColors.goldenBrown,
              ),
              icon: const Icon(Icons.language),
              label: Text(
                context.locale.languageCode == 'ur' ? 'English (انگریزی)' : 'اردو (Urdu)',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                if (context.locale.languageCode == 'ur') {
                  context.setLocale(const Locale('en'));
                } else {
                  context.setLocale(const Locale('ur'));
                }
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.strawRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                foregroundColor: AppColors.strawRed,
              ),
              icon: const Icon(Icons.logout),
              label: Text(tr('sign_out'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  context.go('/');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditMode(Map<String, dynamic> data) {
    final category = data['category'] as String?;
    String pricingBasisEn = '';
    String pricingBasisUr = '';
    
    switch (category) {
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
          Text(tr('business_name'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _businessNameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _markChanged(),
            style: GoogleFonts.inter(fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          
          const SizedBox(height: 24),
          Text(tr('your_city'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _cities.map((city) {
              final isSelected = _selectedCity == city;
              return InkWell(
                onTap: () {
                  setState(() => _selectedCity = city);
                  _markChanged();
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.goldenBrown : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isSelected ? AppColors.goldenBrown : Colors.grey.shade300),
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
            margin: const EdgeInsets.only(bottom: 24),
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
          
          if (_pricesFocused)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('price_change_info'),
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),

          Text(tr('base_price'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _basePriceController,
            focusNode: _basePriceFocus,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              _markChanged();
              _validatePrices();
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
            focusNode: _minPriceFocus,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              _markChanged();
              _validatePrices();
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
            child: Text(tr('minimum_price_helper'), style: GoogleFonts.inter(fontSize: 13, color: AppColors.strawRed)),
          ),
          if (_priceError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(_priceError!, style: GoogleFonts.inter(fontSize: 13, color: Colors.red)),
            ),

          const SizedBox(height: 24),
          Text(tr('when_available'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 30)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: DateTime.now(),
              selectedDayPredicate: (day) => _blockedDates.any((d) => isSameDay(d, day)),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              calendarBuilders: CalendarBuilders(
                selectedBuilder: (context, day, focusedDay) {
                  return Container(
                    margin: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle),
                    child: const Center(child: Icon(Icons.close, color: Colors.grey, size: 20)),
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  return Container(
                    margin: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(color: AppColors.goldenBrown.withOpacity(0.3), shape: BoxShape.circle),
                    child: Center(child: Text(day.day.toString(), style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                  );
                },
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _markChanged();
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
          
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    onPressed: () async {
                      if (_hasChanges) {
                        final discard = await _onWillPop();
                        if (!discard) return;
                      } else {
                        setState(() {
                          _isEditing = false;
                        });
                      }
                    },
                    child: Text(tr('cancel'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.strawRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    onPressed: _priceError != null || _isLoading ? null : _saveProfile,
                    child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(tr('save'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not authenticated')));

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F3EB),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(tr('profile'), style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          centerTitle: true,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            final vendorProfile = userData?['vendorProfile'] as Map<String, dynamic>?;

            if (vendorProfile == null) {
              return const Center(child: Text('No vendor profile found.'));
            }

            return _isEditing ? _buildEditMode(vendorProfile) : _buildReadOnly(vendorProfile);
          },
        ),
      ),
    );
  }
}