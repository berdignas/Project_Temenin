// Path: modules/auth/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import '../widgets/splash_animated_background.dart';
import '../onboarding/screens/onboarding_screen.dart';
import 'login_screen.dart';  // Import LoginScreen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SplashAnimatedBackground(),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 24),
                    _buildTextContent(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildMenuOptions(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
        borderRadius: BorderRadius.circular(36),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Image.asset(
          'assets/images/app_logo.jpg',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Column(
      children: [
        Text(
          'Temenin Ajaa',  // Ganti dengan Temenin Ajaa
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryPink,
            letterSpacing: -0.9,
            shadows: [
              Shadow(
                color: AppTheme.primaryPink.withOpacity(0.3),
                blurRadius: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SizedBox(
          width: 280,
          child: Text(
            'Hadir untuk menemani\nsetiap momenmu',  // Ubah teks sesuai keinginan
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,  // Sesuaikan ukuran font
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryPink,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuOptions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Tombol Lanjutkan (untuk user baru) - mengarah ke OnboardingScreen
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ElevatedButton(
            onPressed: () {
              // Navigasi ke OnboardingScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const OnboardingScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              shadowColor: AppTheme.primaryPink.withValues(alpha: 0.3),
            ),
            child: const Text(
              'Lanjutkan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tombol Sudah Punya Akun (untuk user existing) - mengarah ke LoginScreen
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: OutlinedButton(
            onPressed: () {
              // Navigasi ke LoginScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryPink,
              minimumSize: const Size(double.infinity, 56),
              side: BorderSide(
                color: AppTheme.primaryPink.withValues(alpha: 0.5),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Sudah Punya Akun',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}