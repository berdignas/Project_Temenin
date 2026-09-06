// Path: lib\main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/modules/auth/onboarding/screens/onboarding_screen.dart';
import 'package:temenin_ajaa/modules/auth/screens/login_screen.dart';
import 'package:temenin_ajaa/modules/auth/screens/setup_account_screen.dart';
import 'package:temenin_ajaa/modules/auth/screens/verify_email_waiting_screen.dart';
import 'package:temenin_ajaa/modules/clients/screens/home_loggedin_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/driver_provider.dart';
import 'providers/client_booking_provider.dart';
import 'providers/community_provider.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: 'https://wdjjaevfuxqrephhdacp.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndkamphZXZmdXhxcmVwaGhkYWNwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODI5MjQ0MSwiZXhwIjoyMTAzODY4NDQxfQ.GCnanHjOJ095gHvQwHXHLy_zpgAg1c7VRc90ZpO4ROc',
    );
    print('✅ Supabase initialized successfully');
  } catch (e) {
    print('❌ Error initializing Supabase: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider()..checkAuthStatus(),
        ),
        ChangeNotifierProvider<DriverProvider>(
          create: (_) => DriverProvider(),
        ),
        ChangeNotifierProvider<ClientBookingProvider>(
          create: (_) => ClientBookingProvider(),
        ),
        ChangeNotifierProvider<CommunityProvider>(
          create: (_) => CommunityProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Temenin Ajaa',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasCheckedAuth = false;
  bool _hasRefreshedOnce = false;
  bool _isOnboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(Duration.zero);
    if (mounted && !_hasCheckedAuth) {
      _hasCheckedAuth = true;
      
      try {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _isOnboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
        });
      } catch (e) {
        debugPrint('Error checking onboarding: $e');
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.checkAuthStatus();
      
      // Refresh user data only once after successful auth
      if (mounted && authProvider.isAuthenticated && authProvider.user != null && !_hasRefreshedOnce) {
        _hasRefreshedOnce = true;
        await authProvider.refreshUser();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    /// LOADING STATE
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Memuat...',
                style: TextStyle(
                  color: AppTheme.primaryPink,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    /// CHECK IF ERROR OCCURRED
    if (authProvider.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Terjadi Kesalahan',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  authProvider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    _hasCheckedAuth = false;
                    _hasRefreshedOnce = false;
                    authProvider.checkAuthStatus();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    foregroundColor: AppTheme.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Coba Lagi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    /// LOGIN SUCCESS - USER AUTHENTICATED
    if (authProvider.isAuthenticated && authProvider.user != null) {
      final user = authProvider.user!;
      if (user.email == null || user.email!.isEmpty || user.email!.endsWith('@temenin.aja')) {
        return const SetupAccountScreen();
      }
      if (user.isVerified == false) {
        return const VerifyEmailWaitingScreen();
      }
      return const HomeLoggedInScreen();
    }

    /// NOT LOGGED IN - IF ONBOARDING COMPLETED, SHOW LOGIN
    if (_isOnboardingCompleted) {
      return const LoginScreen();
    }

    /// NOT LOGGED IN - SHOW ONBOARDING
    return const OnboardingScreen();
  }
}