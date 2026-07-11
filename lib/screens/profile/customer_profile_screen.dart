import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/localization/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../providers/customer_events_provider.dart';
import '../history/event_history_screen.dart';
import '../setup/event_type_screen.dart';

/// FR-USR-01: Customer profile — shows name, stats, and quick links.
/// Enables user name editing and Firestore profile sync.
class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  ConsumerState<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen> {
  String? _customDisplayName;

  void _showEditNameDialog(BuildContext context, User? user, AppLocalizations loc) {
    if (user == null) return;
    final controller = TextEditingController(text: _customDisplayName ?? user.displayName);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(loc.language == AppLanguage.urdu ? 'پروفائل تبدیل کریں' : 'Edit Profile Name'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: loc.language == AppLanguage.urdu ? 'اپنا نام درج کریں' : 'Enter your name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.language == AppLanguage.urdu ? 'منسوخ' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldenBrown,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  await user.updateDisplayName(newName);
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                    'displayName': newName,
                  });
                  await user.reload();
                  setState(() {
                    _customDisplayName = newName;
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.language == AppLanguage.urdu ? 'پروفائل اپ ڈیٹ ہو گئی!' : 'Profile updated!')),
                    );
                  }
                }
              },
              child: Text(loc.language == AppLanguage.urdu ? 'محفوظ کریں' : 'Save', style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final user = FirebaseAuth.instance.currentUser;
    final eventsAsync = ref.watch(customerEventsProvider);
    final String currentName = _customDisplayName ?? user?.displayName ?? loc.get('guest');

    return Directionality(
      textDirection: loc.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F7F2),
        body: CustomScrollView(
          slivers: [
            // ── Hero header ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7A4E1E), AppColors.goldenBrown],
                  ),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 40,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.2),
                          child: user?.photoURL != null
                              ? ClipOval(
                                  child: Image.network(user!.photoURL!,
                                      width: 80, height: 80,
                                      fit: BoxFit.cover))
                              : Text(
                                  currentName.isEmpty ? 'U' : currentName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              currentName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                              onPressed: () => _showEditNameDialog(context, user, loc),
                            ),
                          ],
                        ),
                        if (user?.email != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            user!.email!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Stats row
                        eventsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (events) {
                            final total = events.length;
                            final booked = events
                                .where((e) => e.status == 'booked')
                                .length;
                            final inProgress = events
                                .where((e) => ![
                                      'booked',
                                      'cancelled',
                                      'draft'
                                    ].contains(e.status))
                                .length;

                            return Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                              children: [
                                _StatChip(
                                    label: loc.get('total_events'),
                                    value: '$total'),
                                _StatChip(
                                    label: loc.get('booked'),
                                    value: '$booked'),
                                _StatChip(
                                    label: loc.get('in_progress'),
                                    value: '$inProgress'),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Actions ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    // Quick actions grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      children: [
                        _ActionTile(
                          icon: Icons.add_circle_outline,
                          label: loc.get('plan_new_event'),
                          color: AppColors.goldenBrown,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const EventTypeScreen()),
                          ),
                        ),
                        _ActionTile(
                          icon: Icons.history,
                          label: loc.get('my_events'),
                          color: const Color(0xFF4A90D9),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const EventHistoryScreen()),
                          ),
                        ),
                        _ActionTile(
                          icon: Icons.savings_outlined,
                          label: loc.get('total_savings_label'),
                          color: AppColors.mossGreen,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const EventHistoryScreen()),
                          ),
                        ),
                        _ActionTile(
                          icon: Icons.logout,
                          label: loc.get('sign_out'),
                          color: AppColors.strawRed,
                          onTap: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              context.go('/');
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Recent events
                    Text(
                      loc.get('recent_events'),
                      style: loc.fontStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    eventsAsync.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.goldenBrown)),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (events) {
                        if (events.isEmpty) {
                          return _EmptyEventsCard();
                        }
                        final recent = events.take(3).toList();
                        return Column(
                          children: [
                            ...recent.map((e) => _MiniEventRow(event: e)),
                            if (events.length > 3)
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const EventHistoryScreen()),
                                ),
                                child: Text(
                                  '${loc.get('see_all')} →',
                                  style: loc.fontStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.goldenBrown,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: loc.fontStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniEventRow extends StatelessWidget {
  final CustomerEvent event;
  const _MiniEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    Color statusColor;
    switch (event.status) {
      case 'booked':
        statusColor = AppColors.mossGreen;
        break;
      case 'ready':
        statusColor = const Color(0xFF4A90D9);
        break;
      case 'cancelled':
        statusColor = AppColors.strawRed;
        break;
      default:
        statusColor = AppColors.goldenBrown;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(event.type,
                style: loc.fontStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A))),
          ),
          Text(
            'PKR ${(event.totalBudget / 1000).toStringAsFixed(0)}K',
            textDirection: TextDirection.ltr,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF888888)),
          ),
        ],
      ),
    );
  }
}

class _EmptyEventsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available_outlined,
              size: 40, color: Color(0xFFDDDDDD)),
          const SizedBox(height: 10),
          Text(loc.get('no_events_yet'),
              style: loc.fontStyle(
                  fontSize: 14, color: const Color(0xFF999999))),
        ],
      ),
    );
  }
}
