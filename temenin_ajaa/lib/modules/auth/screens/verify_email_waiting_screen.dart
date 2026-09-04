import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../clients/screens/home_loggedin_screen.dart';

class VerifyEmailWaitingScreen extends StatefulWidget {
  const VerifyEmailWaitingScreen({Key? key}) : super(key: key);

  @override
  _VerifyEmailWaitingScreenState createState() => _VerifyEmailWaitingScreenState();
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
        setState(() => _errorMessage = 'Email belum diverifikasi. Silakan cek inbox Anda.');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Email'),
        automaticallyImplyLeading: false, // Prevent going back
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mark_email_unread, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Cek Inbox Email Anda',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Kami telah mengirimkan link verifikasi ke email Anda. Klik link tersebut, lalu tekan tombol di bawah ini.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ElevatedButton(
              onPressed: _isLoading ? null : _checkVerification,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Saya Sudah Verifikasi', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
