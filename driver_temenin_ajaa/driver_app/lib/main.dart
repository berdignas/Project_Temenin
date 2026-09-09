import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/notification_sound_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/community_provider.dart';
import 'modules/auth/screens/login_screen.dart';
import 'modules/driver/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase (matching client configurations)
  try {
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
    );
    debugPrint('✅ Supabase initialized successfully on Driver App');
  } catch (e) {
    debugPrint('❌ Error initializing Supabase on Driver App: $e');
  }

  // Initialize Notification Audio Service
  try {
    await NotificationSoundService().init();
  } catch (e) {
    debugPrint('ℹ️ NotificationSoundService init info: $e');
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
        ChangeNotifierProvider<BookingProvider>(
          create: (_) => BookingProvider(),
        ),
        ChangeNotifierProvider<CommunityProvider>(
          create: (_) => CommunityProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Temenin Ajaa Driver',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme.copyWith(
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
          ),
        ),
        home: const AuthWrapper(),
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

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(Duration.zero);
    if (mounted && !_hasCheckedAuth) {
      _hasCheckedAuth = true;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.checkAuthStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF9DCC)),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Memuat Portal Driver...',
                style: TextStyle(color: Color(0xFFFF9DCC), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (auth.isAuthenticated && auth.user != null) {
      return const DriverHomeScreen();
    }

    return const DriverLoginScreen();
  }
}
