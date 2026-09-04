// Path: widgets\login_footer.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class LoginFooter extends StatelessWidget {
  const LoginFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'POWERED BY GLOWUP',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted.withOpacity(0.4),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Kebijakan Privasi',
                style: TextStyle(
                  color: AppTheme.textMuted.withOpacity(0.4),
                ),
              ),
            ),
            Text(
              '•',
              style: TextStyle(color: AppTheme.textMuted.withOpacity(0.4)),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Syarat & Ketentuan',
                style: TextStyle(
                  color: AppTheme.textMuted.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}