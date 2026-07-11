import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/onboarding/sign_in_screen.dart';
import 'core/theme/app_colors.dart';
import 'core/localization/language_provider.dart';

import 'screens/onboarding/vendor_onboarding_screen.dart';
import 'screens/home/vendor_home_screen.dart';
import 'screens/dashboard/home_screen.dart';
import 'screens/negotiation/vendor_negotiation_detail_screen.dart';
import 'screens/setup/event_type_screen.dart';

// Dummy screens for GoRouter
class DummyScreen extends StatelessWidget {
  final String title;
  const DummyScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await EasyLocalization.ensureInitialized();

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ur')],
        path: 'assets/lang',
        fallbackLocale: const Locale('en'),
        child: const EventFlowApp(),
      ),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/signin',
      builder: (context, state) => const SignInScreen(isReturningUser: false),
    ),
    GoRoute(
      path: '/signin-returning',
      builder: (context, state) => const SignInScreen(isReturningUser: true),
    ),
    GoRoute(
      path: '/customer/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/vendor/home',
      builder: (context, state) => const VendorHomeScreen(),
    ),
    GoRoute(
      path: '/vendor/onboarding',
      builder: (context, state) => const VendorOnboardingScreen(),
    ),
    GoRoute(
      path: '/vendor/negotiation/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra as Map<String, dynamic>?;
        final readOnly = extra?['readOnly'] as bool? ?? false;
        return VendorNegotiationDetailScreen(negotiationId: id, readOnly: readOnly);
      },
    ),
  ],
);

class EventFlowApp extends StatelessWidget {
  const EventFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LanguageProvider(
      child: MaterialApp.router(
        title: 'EventFlow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.skyBlue),
          useMaterial3: true,
        ),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        routerConfig: _router,
      ),
    );
  }
}
