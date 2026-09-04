import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/modules/clients/matching/screens/match_result_screen.dart';

class MatchingRadarScreen extends StatefulWidget {
  final String activity;
  final String vibe;
  final String topic;

  const MatchingRadarScreen({
    super.key,
    required this.activity,
    required this.vibe,
    required this.topic,
  });

  @override
  State<MatchingRadarScreen> createState() => _MatchingRadarScreenState();
}

class _MatchingRadarScreenState extends State<MatchingRadarScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanController;
  String _loadingText = 'Menyalakan Radar Matching...';
  late Timer _textTimer;
  late Timer _transitionTimer;

  final List<String> _loadingPhrases = [
    'Mendeteksi partner aktif di sekitar...',
    'Menyaring tipe kepribadian cocok...',
    'Mengkalibrasi hobi & preferensi obrolan...',
    'Menghitung persentase chemistry...',
    'Menemukan chemistry 98% cocok! 🎉',
  ];
  int _phraseIdx = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Rotate loading text
    _textTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (_phraseIdx < _loadingPhrases.length) {
        if (mounted) {
          setState(() {
            _loadingText = _loadingPhrases[_phraseIdx];
            _phraseIdx++;
          });
        }
      }
    });

    // Auto transition after 4.5 seconds
    _transitionTimer = Timer(const Duration(milliseconds: 4800), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MatchResultScreen(
            activity: widget.activity,
            vibe: widget.vibe,
            topic: widget.topic,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _textTimer.cancel();
    _transitionTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // Radar Circular Animation
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Ripple 3
                  _buildRipple(1.5, 0.2),
                  // Outer Ripple 2
                  _buildRipple(1.0, 0.4),
                  // Outer Ripple 1
                  _buildRipple(0.5, 0.6),

                  // Rotating Radar Line
                  RotationTransition(
                    turns: _scanController,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.15)),
                        gradient: SweepGradient(
                          colors: [
                            AppTheme.primaryPink.withOpacity(0.25),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.2, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Inner static circle
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPink.withOpacity(0.15),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: AppTheme.primaryPink,
                        size: 42,
                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                       .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 700.ms),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 50),

            // Scanning Status Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _loadingText,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppTheme.textHighContrast,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ).animate(key: ValueKey(_loadingText)).fade(duration: 200.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 8),
            Text(
              'Harap tunggu sebentar...',
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildRipple(double delayMultiplier, double opacity) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        double progress = (_pulseController.value + (delayMultiplier * 0.33)) % 1.0;
        double size = 140 + (160 * progress);
        double currentOpacity = opacity * (1.0 - progress);

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryPink.withOpacity(currentOpacity),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }
}
