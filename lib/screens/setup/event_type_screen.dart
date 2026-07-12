import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../models/event_setup_model.dart';
import 'event_details_screen.dart';

class EventTypeScreen extends StatefulWidget {
  const EventTypeScreen({super.key});

  @override
  State<EventTypeScreen> createState() => _EventTypeScreenState();
}

class _EventTypeScreenState extends State<EventTypeScreen> {
  String? _selectedType;
  List<String> _selectedVendors = [];

  // Each event type now uses a vibrant, high-contrast dark tile color scheme
  final List<Map<String, dynamic>> _eventTypes = [
    {
      'icon': Icons.favorite,
      'titleKey': 'wedding',
      'title': 'Wedding',
      'subtitle': 'شادی',
      'vendors': ['Caterer', 'Decorator', 'Photographer', 'DJ / Music', 'Tent / Marquee', 'Flowers', 'Sound System', 'Security'],
      'bgColor': const Color(0xFF1E3F2B), // Deep Moss Green
    },
    {
      'icon': Icons.business_center,
      'titleKey': 'corporate_event',
      'title': 'Corporate event',
      'subtitle': 'کارپوریٹ ایونٹ',
      'vendors': ['Venue', 'Caterer', 'AV', 'Decorator', 'Security'],
      'bgColor': const Color(0xFF1F3A60), // Deep Sky Blue / Indigo
    },
    {
      'icon': Icons.cake,
      'titleKey': 'birthday_anniversary',
      'title': 'Birthday / Anniversary',
      'subtitle': 'سالگرہ',
      'vendors': ['Caterer', 'Decorator', 'Photographer', 'DJ / Music'],
      'bgColor': const Color(0xFFC73038), // Rich Strawberry Red
    },
    {
      'icon': Icons.mosque,
      'titleKey': 'religious_gathering',
      'title': 'Religious gathering',
      'subtitle': 'مذہبی تقریب',
      'vendors': ['Tent / Marquee', 'Caterer', 'Sound System', 'Security'],
      'bgColor': const Color(0xFFA67125), // Warm Golden Brown
    },
    {
      'icon': Icons.school,
      'titleKey': 'college_fest',
      'title': 'College / School fest',
      'subtitle': 'کالج فیسٹ',
      'vendors': ['Sound System', 'Stage', 'Food', 'Security'],
      'bgColor': const Color(0xFF4A2B5E), // Deep Purple
    },
    {
      'icon': Icons.sports_soccer,
      'titleKey': 'sports_tournament',
      'title': 'Sports tournament',
      'subtitle': 'کھیلوں کا مقابلہ',
      'vendors': ['Ground', 'Refreshments', 'Medical'],
      'bgColor': const Color(0xFF1B535A), // Deep Teal
    },
  ];

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
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    if (Navigator.canPop(context))
                      IconButton(
                        icon: Icon(isUrdu ? Icons.arrow_forward : Icons.arrow_back, color: const Color(0xFF7A4E1E)),
                        onPressed: () => Navigator.pop(context),
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Center(
                        child: Text(
                          loc.get('set_up_event'),
                          style: loc.fontStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7A4E1E),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.get('what_planning'),
                        textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                        style: loc.headingStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        loc.get('event_type_subtitle'),
                        textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                        style: loc.fontStyle(
                          fontSize: 15,
                          color: const Color(0xFF666666),
                          height: isUrdu ? 2.2 : 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Cards grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.15,
                        ),
                        itemCount: _eventTypes.length,
                        itemBuilder: (context, index) {
                          final eventType = _eventTypes[index];
                          final isSelected = _selectedType == eventType['title'];
                          final Color bgColor = eventType['bgColor'];
                          
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedType = eventType['title'];
                                _selectedVendors = List<String>.from(eventType['vendors']);
                              });
                            },
                            child: AnimatedScale(
                              scale: isSelected ? 1.03 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutBack,
                              child: Stack(
                                children: [
                                  AnimatedContainer(
                                    width: double.infinity,
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: isSelected ? Border.all(
                                        color: const Color(0xFFF9E8C0), // Soft gold outline
                                        width: 2.5,
                                      ) : null,
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFF9E8C0).withOpacity(0.4),
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                              )
                                            ]
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.15),
                                                blurRadius: 6,
                                                offset: const Offset(0, 3),
                                              )
                                            ],
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Professional Icon
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withOpacity(0.15),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            eventType['icon'],
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        // English Title
                                        Text(
                                          loc.get(eventType['titleKey']),
                                          textAlign: TextAlign.center,
                                          style: loc.fontStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        // Urdu Subtitle
                                        if (!isUrdu) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            eventType['subtitle'],
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.notoNastaliqUrdu(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w300,
                                              color: Colors.white.withOpacity(0.8),
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Checkmark Indicator Badge in top-right
                                  if (isSelected)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFFC73038), // Matching strawberry red/rich color
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
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
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: _selectedType != null ? AppColors.goldenBrown : const Color(0xFFCCCCCC),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _selectedType != null
                          ? () {
                              final model = EventSetupModel(
                                eventType: _selectedType,
                                preSelectedVendors: _selectedVendors,
                              );
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  transitionDuration: const Duration(milliseconds: 300),
                                  pageBuilder: (context, animation, secondaryAnimation) => EventDetailsScreen(model: model),
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
