// lib/routes/app_routes.dart
import 'package:flutter/material.dart';
import '../modules/auth/screens/login_screen.dart';
import '../modules/auth/screens/register_screen.dart';
import '../modules/auth/screens/splash_screen.dart';
import '../modules/auth/onboarding/screens/onboarding_screen.dart';
import '../modules/clients/screens/home_loggedin_screen.dart';
import '../modules/clients/booking/screens/hangout_booking_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String clientHome = '/client-home';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case clientHome:
        return MaterialPageRoute(builder: (_) => const HomeLoggedInScreen());
      case '/booking':
        final args = settings.arguments as Map<String, dynamic>?;
        final serviceType = args?['serviceType'] as String? ?? 'hangout';
        return MaterialPageRoute(
          builder: (_) => HangoutBookingScreen(serviceType: serviceType),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}