import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:temenin_ajaa/core/theme/app_theme.dart';
import '../../screens/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Temenin Ajaa',
      subtitle: 'Hadir untuk menemani\nsetiap momentmu',
      image: Icons.people_alt,
    ),
    OnboardingData(
      title: 'Temenin Ajaa',
      subtitle: 'Exclusive lifestyle companionship\nat your fingertips.',
      image: Icons.star,
    ),
    OnboardingData(
      title: 'Temenin Ajaa',
      subtitle: 'Premium Lifestyle Experience',
      image: Icons.workspace_premium,
    ),
  ];

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _onContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return OnboardingPage(
                data: _pages[index],
                isLastPage: index == _pages.length - 1,
                onContinue: _onContinue,
              );
            },
          ),

          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => _buildDot(index),
                  ),
                ),

                const SizedBox(height: 20),

                // Tombol hanya muncul di halaman terakhir
                if (_currentPage == _pages.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: _onContinue,
                          style: ElevatedButton.styleFrom(
                            minimumSize:
                                const Size(double.infinity, 56),
                            backgroundColor:
                                AppTheme.primaryPink,
                            foregroundColor:
                                AppTheme.background,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Mulai Sekarang',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: _currentPage == index
            ? AppTheme.primaryPink
            : AppTheme.textMuted.withOpacity(0.3),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final IconData image;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.image,
  });
}

class OnboardingPage extends StatelessWidget {
  final OnboardingData data;
  final bool isLastPage;
  final VoidCallback onContinue;

  const OnboardingPage({
    super.key,
    required this.data,
    required this.isLastPage,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppTheme.primaryPink,
                  AppTheme.roseGold,
                ],
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              data.image,
              size: 50,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 40),

          Text(
            data.title,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryPink,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            data.subtitle,
            style: const TextStyle(
              fontSize: 18,
              color: AppTheme.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}