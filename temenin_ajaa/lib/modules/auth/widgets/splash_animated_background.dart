// Path: widgets\splash_animated_background.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SplashAnimatedBackground extends StatelessWidget {
  const SplashAnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          color: AppTheme.background,
        ),
        Positioned(
          right: -48,
          top: 262,
          child: Container(
            width: 256,
            height: 256,
            decoration: BoxDecoration(
              color: AppTheme.primaryPink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
        ),
        Positioned(
          left: -48,
          bottom: 262,
          child: Container(
            width: 192,
            height: 192,
            decoration: BoxDecoration(
              color: AppTheme.primaryPink.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}