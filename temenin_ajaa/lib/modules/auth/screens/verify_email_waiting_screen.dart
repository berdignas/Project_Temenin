import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../clients/screens/home_loggedin_screen.dart';

class VerifyEmailWaitingScreen extends StatefulWidget {
  const VerifyEmailWaitingScreen({super.key});

  @override
  State<VerifyEmailWaitingScreen> createState() => _VerifyEmailWaitingScreenState();
}

class _VerifyEmailWaitingScreenState extends State<VerifyEmailWaitingScreen> {
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _checkVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // Panggil reload user / getMe untuk mengupdate status is_verified
      await authProvider.refreshUser();

      final user = authProvider.user;
      if (user != null && user.isVerified == true) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeLoggedInScreen()),
        );
      } else {
        setState(() => _errorMessage = 'Email belum diverifikasi. Silakan klik link verifikasi di inbox email Anda.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Gagal mengecek status verifikasi');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userEmail = authProvider.user?.email ?? 'email Anda';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppTheme.fuchsiaLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    size: 46,
                    color: AppTheme.primaryPink,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Cek Inbox Email Anda',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textHighContrast,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Kami telah mengirimkan tautan verifikasi ke:\n$userEmail\n\nKlik tautan verifikasi di email tersebut, lalu tekan tombol di bawah ini untuk masuk ke Dashboard.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              if (_errorMessage.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: GoogleFonts.inter(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'Saya Sudah Verifikasi Email',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
