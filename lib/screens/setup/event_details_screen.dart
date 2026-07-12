import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../models/event_setup_model.dart';
import 'vendor_categories_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventSetupModel model;

  const EventDetailsScreen({super.key, required this.model});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  DateTime? _selectedDate;
  String? _selectedCity;
  int _guestCount = 50;
  String _venuePref = 'Indoor';

  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.goldenBrown,
              onPrimary: Colors.white,
              onSurface: Color(0xFF7A4E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  void _pickCity() {
    final loc = context.loc;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: loc.textDirection,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                _buildCityOption('islamabad', loc.get('islamabad_sub'), loc),
                _buildCityOption('lahore', loc.get('lahore_sub'), loc),
                _buildCityOption('karachi', loc.get('karachi_sub'), loc),
                _buildCityOption('rawalpindi', loc.get('rawalpindi_sub'), loc),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCityOption(String cityKey, String subtitle, dynamic loc) {
    final title = loc.get(cityKey);
    
    IconData cityIcon;
    switch (cityKey) {
      case 'islamabad':
        cityIcon = Icons.account_balance_outlined;
        break;
      case 'lahore':
        cityIcon = Icons.park_outlined;
        break;
      case 'karachi':
        cityIcon = Icons.waves;
        break;
      case 'rawalpindi':
        cityIcon = Icons.castle_outlined;
        break;
      default:
        cityIcon = Icons.location_city_outlined;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.goldenBrown.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(cityIcon, color: AppColors.goldenBrown, size: 20),
      ),
      title: Text(title, style: loc.fontStyle(fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A), fontSize: 15.0)),
      subtitle: Text(subtitle, style: loc.fontStyle(fontSize: 13.0, color: const Color(0xFF666666))),
      onTap: () {
        setState(() {
          _selectedCity = cityKey;
        });
        Navigator.pop(context);
      },
    );
  }

  bool _isFormValid() {
    return _selectedDate != null && _selectedCity != null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isUrdu = context.isUrdu;

    return Directionality(
      textDirection: loc.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F3EB),
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
                          loc.get('step_2_of_4'),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.get('when_where'),
                        textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                        style: loc.headingStyle(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.get('details_subtitle'),
                        textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                        style: loc.fontStyle(fontSize: 15, color: const Color(0xFF666666), height: isUrdu ? 2.2 : 1.4),
                      ),
                      const SizedBox(height: 32),
                      
                      // DATE
                      Text(loc.get('event_date'), style: loc.fontStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE8C49A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, color: AppColors.goldenBrown, size: 20),
                              const SizedBox(width: 16),
                              Text(
                                _selectedDate != null ? DateFormat('MMM d, yyyy').format(_selectedDate!) : loc.get('select_date'),
                                style: loc.fontStyle(
                                  fontSize: 15,
                                  color: _selectedDate != null ? const Color(0xFF7A4E1E) : const Color(0xFFB08040),
                                  fontWeight: _selectedDate != null ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right, color: AppColors.goldenBrown),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedDate != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFEDF3E1), borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            "📅 ${_selectedDate!.difference(DateTime.now()).inDays} ${loc.get('days_from_today')}",
                            style: loc.fontStyle(fontSize: 12, color: AppColors.mossGreen, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // CITY
                      Text(loc.get('city'), style: loc.fontStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickCity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE8C49A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_city_outlined, color: AppColors.goldenBrown, size: 20),
                              const SizedBox(width: 16),
                              Text(
                                _selectedCity != null ? loc.get(_selectedCity!) : loc.get('select_city'),
                                style: loc.fontStyle(
                                  fontSize: 15,
                                  color: _selectedCity != null ? const Color(0xFF7A4E1E) : const Color(0xFFB08040),
                                  fontWeight: _selectedCity != null ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right, color: AppColors.goldenBrown),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // GUESTS
                      Text(loc.get('expected_guests'), style: loc.fontStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                NumberFormat('#,###').format(_guestCount),
                                style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.goldenBrown, height: 1.0),
                              ),
                              Text(loc.get('guests'), style: loc.fontStyle(fontSize: 14, color: const Color(0xFFB08040))),
                            ],
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              if (_guestCount > 50) setState(() => _guestCount -= 10);
                            },
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE8C49A))),
                              child: const Icon(Icons.remove, color: AppColors.goldenBrown),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () {
                              if (_guestCount < 2000) setState(() => _guestCount += 10);
                            },
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE8C49A))),
                              child: const Icon(Icons.add, color: AppColors.goldenBrown),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          activeTrackColor: AppColors.goldenBrown,
                          inactiveTrackColor: const Color(0xFFE8C49A),
                          thumbColor: AppColors.goldenBrown,
                          overlayColor: AppColors.goldenBrown.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: _guestCount.toDouble(),
                          min: 50,
                          max: 2000,
                          divisions: 195,
                          onChanged: (v) => setState(() => _guestCount = v.round()),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("50", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB08040))),
                          Text("2,000+", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB08040))),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // VENUE
                      Text(loc.get('venue_preference'), style: loc.fontStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildVenueToggle(loc.get('indoor'), 'Indoor', loc)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildVenueToggle(loc.get('outdoor'), 'Outdoor', loc)),
                        ],
                      ),
                      const SizedBox(height: 48), // Padding at end of scroll
                    ],
                  ),
                ),
              ),
              
              // Bottom Action
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFormValid() ? AppColors.goldenBrown : const Color(0xFFCCCCCC),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    onPressed: _isFormValid()
                        ? () {
                            final updatedModel = widget.model.copyWith(
                              eventDate: _selectedDate,
                              city: _selectedCity,
                              guestCount: _guestCount,
                              venuePreference: _venuePref.contains('Indoor') ? 'Indoor' : 'Outdoor',
                            );
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                transitionDuration: const Duration(milliseconds: 300),
                                pageBuilder: (context, animation, secondaryAnimation) => VendorCategoriesScreen(model: updatedModel),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  return FadeTransition(opacity: animation, child: child);
                                },
                              ),
                            );
                          }
                        : null,
                    child: Text(
                      loc.get('continue_btn'),
                      style: loc.fontStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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

  Widget _buildVenueToggle(String label, String value, dynamic loc) {
    final isSelected = _venuePref == value;
    final icon = value == 'Indoor' ? Icons.home_outlined : Icons.park_outlined;

    return GestureDetector(
      onTap: () => setState(() => _venuePref = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.goldenBrown : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.goldenBrown : const Color(0xFFE8C49A)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.goldenBrown,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: loc.fontStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF7A4E1E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
