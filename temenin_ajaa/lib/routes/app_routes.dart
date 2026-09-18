// lib/routes/app_routes.dart
import 'package:flutter/material.dart';
import '../modules/auth/screens/login_screen.dart';
import '../modules/auth/screens/register_screen.dart';
import '../modules/auth/screens/splash_screen.dart';
import '../modules/auth/onboarding/screens/onboarding_screen.dart';
import '../modules/clients/screens/home_loggedin_screen.dart';
import '../modules/clients/booking/screens/antar_jemput_booking_screen.dart';
import '../modules/clients/booking/screens/hangout_booking_screen.dart';
import '../modules/clients/booking/screens/freedom_request_booking_screen.dart';
import '../modules/clients/booking/screens/sleep_call_booking_screen.dart';
import '../modules/clients/booking/screens/virtual_call_booking_screen.dart';
import '../modules/clients/booking/screens/gaming_buddy_booking_screen.dart';
import '../modules/clients/booking/screens/booking_type_selector_screen.dart';
import '../modules/clients/pages/edit_profile_page.dart';
import '../modules/clients/pages/settings_page.dart';
import '../modules/clients/pages/notifications_page.dart';
import '../modules/clients/pages/help_center_page.dart';
import '../modules/clients/pages/payment_methods_page.dart';
import '../modules/clients/pages/rewards_page.dart';
import '../modules/clients/pages/booking_history_page.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String clientHome = '/client-home';
  static const String editProfile = '/edit-profile';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String helpCenter = '/help-center';
  static const String paymentMethods = '/payment-methods';
  static const String rewards = '/rewards';
  static const String bookingHistory = '/booking-history';
  static const String bookingTypeSelector = '/booking-type-selector';

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
      case editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfilePage());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsPage());
      case helpCenter:
        return MaterialPageRoute(builder: (_) => const HelpCenterPage());
      case paymentMethods:
        return MaterialPageRoute(builder: (_) => const PaymentMethodsPage());
      case rewards:
        return MaterialPageRoute(builder: (_) => const RewardsPage());
      case bookingHistory:
        return MaterialPageRoute(builder: (_) => const BookingHistoryPage());
      case bookingTypeSelector:
        return MaterialPageRoute(builder: (_) => const BookingTypeSelectorScreen());
      case '/booking':
        final args = settings.arguments as Map<String, dynamic>?;
        final serviceType = (args?['serviceType'] as String? ?? 'hangout').toLowerCase();
        final selectedPartner = args?['selectedPartner'] as Map<String, dynamic>?;

        if (serviceType == 'sleep' || serviceType == 'sleep_call') {
          return MaterialPageRoute(
            builder: (_) => SleepCallBookingScreen(
              selectedPartner: selectedPartner,
            ),
          );
        } else if (serviceType == 'telepon' || serviceType == 'virtual' || serviceType == 'counseling' || serviceType == 'curhat') {
          return MaterialPageRoute(
            builder: (_) => VirtualCallBookingScreen(
              serviceType: serviceType,
              selectedPartner: selectedPartner,
            ),
          );
        } else if (serviceType == 'gaming' || serviceType == 'game' || serviceType == 'mabar') {
          return MaterialPageRoute(
            builder: (_) => GamingBuddyBookingScreen(
              selectedPartner: selectedPartner,
            ),
          );
        } else if (serviceType == 'regular' || serviceType == 'antar_jemput' || serviceType == 'ride' || serviceType == 'sporty' || serviceType == 'sporty_ride') {
          return MaterialPageRoute(
            builder: (_) => AntarJemputBookingScreen(
              selectedPartner: selectedPartner,
              serviceType: serviceType,
            ),
          );
        } else if (serviceType == 'freedom' || serviceType == 'freedom_request' || serviceType == 'assistant' || serviceType == 'detektif' || serviceType == 'detective') {
          return MaterialPageRoute(
            builder: (_) => FreedomRequestBookingScreen(
              selectedPartner: selectedPartner,
              serviceType: serviceType,
            ),
          );
        } else {
          return MaterialPageRoute(
            builder: (_) => HangoutBookingScreen(
              selectedPartner: selectedPartner,
              serviceType: serviceType,
            ),
          );
        }
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