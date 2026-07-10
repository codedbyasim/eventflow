import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../profile/vendor_profile_screen.dart';
import '../inbox/vendor_inbox_screen.dart';
import '../bookings/vendor_bookings_screen.dart';
import 'vendor_dashboard_view.dart';
import '../../core/theme/app_colors.dart';

class DashboardData {
  final String businessName;
  final String category;
  final int pendingCount;
  final int activeCount;
  final int myTurnCount;
  final double todayEarnings;
  final int totalBookings;
  final double responseRate;
  final List<Map<String, dynamic>> recentNegotiations;

  DashboardData({
    required this.businessName,
    required this.category,
    required this.pendingCount,
    required this.activeCount,
    required this.myTurnCount,
    required this.todayEarnings,
    required this.totalBookings,
    required this.responseRate,
    required this.recentNegotiations,
  });
}

class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not authenticated')));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final vendorProfile = userData?['vendorProfile'] as Map<String, dynamic>?;

        final businessName = vendorProfile?['businessName'] as String? ?? '';
        final category = vendorProfile?['category'] as String? ?? '';
        final totalBookings = vendorProfile?['totalBookings'] as int? ?? 0;
        final responseRate = (vendorProfile?['responseRate'] ?? 100).toDouble();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('negotiations')
              .where('vendorId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, negSnapshot) {
            int pendingCount = 0;
            int activeCount = 0;
            int myTurnCount = 0;
            double todayEarnings = 0.0;
            List<Map<String, dynamic>> activeNegotiations = [];

            if (negSnapshot.hasData) {
              final docs = negSnapshot.data!.docs;
              final today = DateTime.now();

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                data['negotiationId'] = doc.id;
                
                final status = data['status'] as String? ?? '';
                final isVendorTurn = data['isVendorTurn'] as bool? ?? false;
                
                if (status == 'pending') pendingCount++;
                if (status == 'active') {
                  activeCount++;
                  activeNegotiations.add(data);
                }
                if (isVendorTurn) myTurnCount++;

                if (status == 'deal') {
                  final dealTimestamp = data['dealDate'] as Timestamp?;
                  if (dealTimestamp != null) {
                    final dealDate = dealTimestamp.toDate();
                    if (dealDate.year == today.year && 
                        dealDate.month == today.month && 
                        dealDate.day == today.day) {
                      todayEarnings += (data['finalPrice'] ?? 0.0).toDouble();
                    }
                  }
                }
              }
              
              // Sort active negotiations by lastActivity descending
              activeNegotiations.sort((a, b) {
                final aTime = (a['lastActivity'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bTime = (b['lastActivity'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                return bTime.compareTo(aTime);
              });
            }

            final dashboardData = DashboardData(
              businessName: businessName,
              category: category,
              pendingCount: pendingCount,
              activeCount: activeCount,
              myTurnCount: myTurnCount,
              todayEarnings: todayEarnings,
              totalBookings: totalBookings,
              responseRate: responseRate,
              recentNegotiations: activeNegotiations,
            );

            final badgeCount = pendingCount + myTurnCount;

            final List<Widget> screens = [
              VendorDashboardView(
                data: dashboardData,
                onNavigateToRequests: (int tabIndex) {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
              ),
              const VendorInboxScreen(),
              VendorBookingsScreen(
                onNavigateToRequests: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
              ),
              const VendorProfileScreen(),
            ];

            return Scaffold(
              backgroundColor: const Color(0xFFF7F3EB),
              body: screens[_currentIndex],
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _currentIndex,
                selectedItemColor: AppColors.goldenBrown,
                unselectedItemColor: Colors.grey.shade500,
                type: BottomNavigationBarType.fixed,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.home),
                    label: tr('home'),
                  ),
                  BottomNavigationBarItem(
                    icon: Badge(
                      isLabelVisible: badgeCount > 0,
                      label: Text(badgeCount.toString()),
                      backgroundColor: AppColors.strawRed,
                      child: const Icon(Icons.inbox),
                    ),
                    label: tr('requests'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.event_available),
                    label: tr('bookings'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.person),
                    label: tr('profile'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
