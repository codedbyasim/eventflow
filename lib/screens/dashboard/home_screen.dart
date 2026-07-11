import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/customer_events_provider.dart';
import '../setup/event_type_screen.dart';
import '../history/event_history_screen.dart';
import '../profile/customer_profile_screen.dart';
import '../history/event_detail_screen.dart';
import '../../widgets/app_logo.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;
  const HomeScreen({super.key, this.isGuest = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    final List<Widget> screens = [
      CustomerDashboardView(isGuest: widget.isGuest),
      const EventHistoryScreen(),
      const CustomerProfileScreen(),
    ];

    return Directionality(
      textDirection: loc.textDirection,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFF7F3EB),
          selectedItemColor: AppColors.goldenBrown,
          unselectedItemColor: const Color(0xFF888888),
          selectedLabelStyle: loc.fontStyle(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: loc.fontStyle(fontSize: 12),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: loc.language == AppLanguage.urdu ? 'ہوم' : 'Home',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history),
              activeIcon: const Icon(Icons.history),
              label: loc.language == AppLanguage.urdu ? 'سرگرمیاں' : 'Events',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: loc.language == AppLanguage.urdu ? 'پروفائل' : 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerDashboardView extends ConsumerWidget {
  final bool isGuest;
  const CustomerDashboardView({super.key, this.isGuest = false});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final user = FirebaseAuth.instance.currentUser;
    final eventsAsync = ref.watch(customerEventsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: CustomScrollView(
        slivers: [
          // ── Hero section ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3A2008), Color(0xFF7A4E1E)],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Row(
                        children: [
                          const AppLogo(size: 42),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                                Text(
                                  user?.displayName?.split(' ').first ??
                                      loc.get('guest'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Profile avatar button
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const CustomerProfileScreen(),
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              child: user?.photoURL != null
                                  ? ClipOval(
                                      child: Image.network(user!.photoURL!,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover))
                                  : const Icon(Icons.person_outline,
                                      color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 36),

                      // Headline
                      Text(
                        loc.get('home_headline'),
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.get('home_subtitle'),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 14),
                      ),

                      const SizedBox(height: 32),

                      // CTA button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28)),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const EventTypeScreen()),
                          ),
                          icon: const Icon(Icons.auto_awesome,
                              color: Color(0xFF7A4E1E)),
                          label: Text(
                            loc.get('plan_new_event'),
                            style: loc.fontStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF7A4E1E),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── My Events Section ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.language == AppLanguage.urdu ? 'میرے ایونٹس' : 'My Events',
                    style: loc.fontStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  eventsAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.goldenBrown)),
                    error: (err, _) => Center(child: Text("Error: $err")),
                    data: (events) {
                      if (events.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE8C49A).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.event_busy, size: 48, color: AppColors.goldenBrown),
                              const SizedBox(height: 12),
                              Text(
                                loc.language == AppLanguage.urdu ? 'کوئی فعال ایونٹ نہیں ملا' : 'No active events found',
                                style: loc.fontStyle(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF666666)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loc.language == AppLanguage.urdu 
                                    ? 'شروع کرنے کے لیے "نیا ایونٹ پلان کریں" پر کلک کریں۔' 
                                    : 'Click "Plan New Event" to get started.',
                                textAlign: TextAlign.center,
                                style: loc.fontStyle(fontSize: 12, color: const Color(0xFF888888)),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return Column(
                        children: events.map((e) => _DashboardEventRow(event: e)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── How It Works list ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.get('how_it_works'),
                    style: loc.fontStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FeatureRow(
                    step: '01',
                    title: loc.get('feature_1_title'),
                    subtitle: loc.get('feature_1_sub'),
                    icon: Icons.edit_note,
                  ),
                  _FeatureRow(
                    step: '02',
                    title: loc.get('feature_2_title'),
                    subtitle: loc.get('feature_2_sub'),
                    icon: Icons.smart_toy_outlined,
                  ),
                  _FeatureRow(
                    step: '03',
                    title: loc.get('feature_3_title'),
                    subtitle: loc.get('feature_3_sub'),
                    icon: Icons.savings_outlined,
                  ),
                  _FeatureRow(
                    step: '04',
                    title: loc.get('feature_4_title'),
                    subtitle: loc.get('feature_4_sub'),
                    icon: Icons.check_circle_outline,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardEventRow extends StatelessWidget {
  final CustomerEvent event;
  const _DashboardEventRow({required this.event});

  Color _statusColor(String status) {
    switch (status) {
      case 'booked':      return AppColors.mossGreen;
      case 'ready':       return const Color(0xFF4A90D9);
      case 'negotiating': return AppColors.goldenBrown;
      case 'cancelled':   return AppColors.strawRed;
      default:            return const Color(0xFF888888);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'booked':      return Icons.check_circle_outline;
      case 'ready':       return Icons.thumb_up_alt_outlined;
      case 'negotiating': return Icons.handshake_outlined;
      case 'cancelled':   return Icons.cancel_outlined;
      default:            return Icons.hourglass_top_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final statusColor = _statusColor(event.status);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0xFFE8C49A).withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon(event.status), color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.type,
                      style: loc.fontStyle(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (event.city != null) event.city!.toUpperCase(),
                        if (event.eventDate != null) event.eventDate!,
                      ].join(' · '),
                      style: loc.fontStyle(fontSize: 11, color: const Color(0xFF888888)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLast;

  const _FeatureRow({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.goldenBrown.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    step,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.goldenBrown,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: const Color(0xFFE8C49A),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: loc.fontStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: loc.fontStyle(
                              fontSize: 12,
                              color: const Color(0xFF888888)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(icon, color: AppColors.goldenBrown, size: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
