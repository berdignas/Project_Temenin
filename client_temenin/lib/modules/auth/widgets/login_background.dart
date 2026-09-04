// Path: widgets\login_background.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class LoginBackground extends StatelessWidget {
  const LoginBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          color: AppTheme.background,
        ),
        Container(
          width: double.infinity,
          height: 884,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryPink.withOpacity(0.1),
                AppTheme.primaryPink.withOpacity(0),
              ],
            ),
          ),
        ),
        Positioned(
          right: -39,
          top: -88,
          child: Container(
            width: 156,
            height: 354,
            decoration: BoxDecoration(
              color: AppTheme.primaryPink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
        ),
        Positioned(
          left: -39,
          bottom: -18,
          child: Container(
            width: 156,
            height: 354,
            decoration: BoxDecoration(
              color: AppTheme.primaryPink.withOpacity(0.05),
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
        ),
      ],
    );
  }
}