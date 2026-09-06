import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../clients/screens/home_loggedin_screen.dart';
import 'register_screen.dart';
import 'setup_account_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isObscure = true;
  String? _loginError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _loginError = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final identifier = _identifierController.text.trim();
      final isEmail = identifier.contains('@');

      if (!isEmail) {
        // Phone Login Flow - Sanitize phone number
        var phone = identifier.replaceAll(RegExp(r'\D'), '');
        if (phone.startsWith('0')) {
          phone = phone.substring(1);
        }
        if (phone.startsWith('62')) {
          phone = phone.substring(2);
        }

        final sendResult = await authProvider.sendOtp(phone);
        
        if (sendResult['success'] == true) {
          setState(() {
            _isLoading = false;
          });
          
          final otpCode = sendResult['otp'] ?? '';
          
          if (mounted) {
            String? enteredOtp;
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                final otpDialogController = TextEditingController();
                String? dialogError;
                
                return StatefulBuilder(
                  builder: (context, setDialogState) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFF121B22), // WhatsApp Dark Background
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: const Color(0xFF00A884).withOpacity(0.3), width: 1.5),
                      ),
                      title: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF00A884)),
                          const SizedBox(width: 8),
                          Text(
                            'WhatsApp OTP',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Kode verifikasi dikirim ke +62 $phone.\n(OTP Simulasi: $otpCode)',
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade300,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF00A884).withOpacity(0.2)),
                            ),
                            child: TextField(
                              controller: otpDialogController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              style: const TextStyle(
                                color: Colors.white, 
                                letterSpacing: 8, 
                                fontSize: 16, 
                                fontWeight: FontWeight.bold
                              ),
                              decoration: const InputDecoration(
                                hintText: '******',
                                counterText: '',
                                hintStyle: TextStyle(color: Colors.white24),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          if (dialogError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              dialogError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Batal',
                            style: TextStyle(color: const Color(0xFF00A884)),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final code = otpDialogController.text.trim();
                            if (code.length != 6) {
                              setDialogState(() {
                                dialogError = 'Harap masukkan 6 digit OTP';
                              });
                              return;
                            }
                            
                            enteredOtp = code;
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A884),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Verifikasi'),
                        ),
                      ],
                    );
                  },
                );
              },
            );
            
            if (enteredOtp != null) {
              setState(() {
                _isLoading = true;
              });
              
              // Verify OTP
              final verifyResult = await authProvider.verifyOtp(phone, enteredOtp!);
              if (verifyResult['success'] == true) {
                // Proceed with login
                final success = await authProvider.loginWithPhone(phone, enteredOtp!);
                setState(() {
                  _isLoading = false;
                });
                
                if (success) {
                  if (mounted) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('userRole', 'user');
                    
                    final user = authProvider.user;
                    if (user != null && (user.email == null || user.email!.trim().isEmpty || user.email!.endsWith('@temenin.aja') || user.isVerified == false)) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const SetupAccountScreen()),
                      );
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeLoggedInScreen()),
                      );
                    }
                  }
                } else {
                  setState(() {
                    _loginError = 'Gagal masuk. Silakan periksa kembali data Anda.';
                  });
                }
              } else {
                setState(() {
                  _isLoading = false;
                  _loginError = verifyResult['message'] ?? 'Kode OTP salah atau kedaluwarsa.';
                });
              }
            } else {
              setState(() {
                _isLoading = false;
              });
            }
          }
        } else {
          setState(() {
            _isLoading = false;
            _loginError = sendResult['message'] ?? 'Gagal mengirim OTP. Pastikan nomor handphone terdaftar.';
          });
        }
      } else {
        // Email Login Flow
        final password = _passwordController.text;
        if (password.isEmpty) {
          setState(() {
            _isLoading = false;
            _loginError = 'Kata sandi harus diisi untuk masuk menggunakan email.';
          });
          return;
        }
        
        final success = await authProvider.login(identifier, password);
        setState(() {
          _isLoading = false;
        });
        
        if (success) {
          if (mounted) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userRole', 'user');
            
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeLoggedInScreen()),
            );
          }
        } else {
          setState(() {
            _loginError = authProvider.errorMessage ?? 'Gagal masuk. Silakan periksa kembali email dan kata sandi Anda.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loginError = 'Terjadi kesalahan: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryPink.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withOpacity(0.1),
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo / Title
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryPink.withOpacity(0.2),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/images/app_logo.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Temenin Ajaa',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryPink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Masukkan Email/No. HP dan Kata Sandi Anda',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email/Phone Field
                          Text(
                            'Email atau Nomor HP',
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade300,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: TextFormField(
                              controller: _identifierController,
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Contoh: 081234567890 / email@domain.com',
                                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded, 
                                  color: AppTheme.primaryPink,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Email atau Nomor HP harus diisi';
                                }
                                return null;
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Password Field
                          Text(
                            'Kata Sandi',
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade300,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: _isObscure,
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Masukkan kata sandi Anda',
                                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded, 
                                  color: AppTheme.primaryPink,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isObscure ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey.shade500,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isObscure = !_isObscure;
                                    });
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Kata sandi harus diisi';
                                }
                                return null;
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Error Message
                          if (_loginError != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _loginError!,
                                      style: GoogleFonts.inter(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          const SizedBox(height: 24),
                          
                          // Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryPink,
                                foregroundColor: const Color(0xFF6F004B),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF6F004B),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'Masuk',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Register Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Belum punya akun? ',
                                style: GoogleFonts.inter(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Daftar Sekarang',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.primaryPink,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}