import 'dart:math';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../clients/screens/home_loggedin_screen.dart';
import 'setup_account_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _phoneController = TextEditingController(text: "81298765432");
  final _otpController = TextEditingController();
  final _fullNameController = TextEditingController(text: "Faizun A.");
  final _nickNameController = TextEditingController(text: "Faizun");
  final _dobController = TextEditingController(text: "1998-05-14");
  
  int _currentStep = 1; // Step 1: HP & OTP, Step 2: Lengkapi Profil
  bool _isLoading = false;
  bool _otpSent = false;
  String _generatedOtp = '';
  String? _errorMessage;
  
  // Profile / Gender Selection
  String _selectedGender = 'Pria';
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar: $e')),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _fullNameController.dispose();
    _nickNameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // --- Date Picker Helper ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1998, 5, 14),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // 18+ years requirement
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryPink,
              onPrimary: Colors.black,
              surface: AppTheme.surface,
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryPink,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // --- Step 1: OTP ---
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    var phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }
    if (phone.startsWith('62')) {
      phone = phone.substring(2);
    }
    
    final result = await authProvider.sendOtp(phone);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final otp = result['otp'] ?? '';
      setState(() {
        _otpSent = true;
        _generatedOtp = otp;
      });

      if (mounted && otp.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF075E54), // WhatsApp Dark Green
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.message,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WhatsApp • Temenin Ajaa',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF25D366), // WhatsApp Bright Green
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kode verifikasi unik Anda adalah: $otp. Jangan bagikan kode ini kepada siapapun.',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 15),
            action: SnackBarAction(
              label: 'SALIN',
              textColor: const Color(0xFF25D366),
              onPressed: () {
                setState(() {
                  _otpController.text = otp;
                });
              },
            ),
          ),
        );
      }
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Gagal mengirim OTP';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Harap masukkan 6 digit kode OTP.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    var phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }
    if (phone.startsWith('62')) {
      phone = phone.substring(2);
    }
    final result = await authProvider.verifyOtp(phone, otp);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final bool isRegistered = result['isRegistered'] ?? false;
      if (isRegistered) {
        // Phone number is already registered, automatically log them in
        setState(() {
          _isLoading = true;
        });
        final loginResult = await authProvider.loginWithPhone(phone, otp);

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });
        if (loginResult) {
          if (mounted) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userRole', 'user');

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login Berhasil!'),
                backgroundColor: Colors.green,
              ),
            );
            final user = authProvider.user;
            if (user != null && (user.email == null || user.email!.trim().isEmpty || user.email!.endsWith('@temenin.aja') || user.isVerified == false)) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const SetupAccountScreen()),
                (route) => false,
              );
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeLoggedInScreen()),
                (route) => false,
              );
            }
          }
        } else {
          setState(() {
            _errorMessage = 'Gagal masuk setelah verifikasi OTP.';
          });
        }
      } else {
        // Go to complete profile form
        setState(() {
          _currentStep = 2;
        });
      }
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Kode OTP yang Anda masukkan salah.';
      });
    }
  }

  // --- Final Register Submission ---
  Future<void> _submitRegistration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      var phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
      if (phone.startsWith('0')) {
        phone = phone.substring(1);
      }
      if (phone.startsWith('62')) {
        phone = phone.substring(2);
      }

      final success = await authProvider.registerWithPhone(
        phone: phone,
        otp: _otpController.text.trim(),
        fullName: _fullNameController.text.trim(),
        avatarFile: _profileImage,
      );

      if (success) {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userRole', 'user');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registrasi Berhasil!'),
              backgroundColor: Colors.green,
            ),
          );
          final user = authProvider.user;
          if (user != null && (user.email == null || user.email!.trim().isEmpty || user.email!.endsWith('@temenin.aja') || user.isVerified == false)) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const SetupAccountScreen()),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeLoggedInScreen()),
              (route) => false,
            );
          }
        }
      } else {
        setState(() {
          _errorMessage = authProvider.errorMessage ?? 'Gagal mendaftar. Silakan coba kembali.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
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
                color: AppTheme.primaryPink.withOpacity(0.06),
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
                color: Colors.purple.withOpacity(0.06),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Top Custom Header / App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                        onPressed: () {
                          if (_currentStep > 1) {
                            setState(() {
                              _currentStep--;
                              _errorMessage = null;
                            });
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Daftar Baru',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balancing size
                    ],
                  ),
                ),
                
                // Step Progress Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildProgressIndicator(),
                ),
                const SizedBox(height: 24),
                
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_currentStep == 1) _buildStep1PhoneOtp(),
                          if (_currentStep == 2) _buildStep2Profile(),
                          
                          // Error Display
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 20),
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
                                      _errorMessage!,
                                      style: GoogleFonts.inter(color: Colors.red, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Fixed Bottom Button
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildBottomButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 1: Progress Indicator ---
  Widget _buildProgressIndicator() {
    double progressPercent = 0.5;
    if (_currentStep == 2) progressPercent = 1.0;

    return Row(
      children: [
        Text(
          'Langkah $_currentStep dari 2',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.roseGold,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF23262F),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressPercent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryPink, AppTheme.roseGold],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Step 1 Layout: HP & OTP ---
  Widget _buildStep1PhoneOtp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nomor HP Anda',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Masukkan nomor handphone aktif untuk menerima kode verifikasi OTP via SMS.',
          style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 28),
        
        Text(
          'Nomor WhatsApp / HP',
          style: GoogleFonts.inter(color: Colors.grey.shade300, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF16181D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Center(
                child: Text(
                  '🇮🇩 +62',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF16181D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _otpSent ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.08)),
                ),
                child: TextFormField(
                  controller: _phoneController,
                  enabled: !_otpSent,
                  style: GoogleFonts.inter(color: _otpSent ? Colors.white54 : Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '812-3456-7890',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Nomor HP harus diisi';
                    return null;
                  },
                ),
              ),
            ),
          ],
        ),
        
        if (_otpSent) ...[
          const SizedBox(height: 20),
          Text(
            'Kode 6-Digit dikirim ke +62 ${_phoneController.text.trim()}',
            style: GoogleFonts.inter(color: AppTheme.roseGold, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF16181D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextFormField(
              controller: _otpController,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primaryPink, 
                letterSpacing: 12, 
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                counterText: '',
                hintText: '******',
                hintStyle: TextStyle(color: Colors.white10),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12),
                children: const [
                  TextSpan(text: 'Kirim ulang kode dalam '),
                  TextSpan(
                    text: '02:45',
                    style: TextStyle(color: AppTheme.primaryPink, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- Step 2 Layout: Lengkapi Profil ---
  Widget _buildStep2Profile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lengkapi Profil',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Informasi ini akan ditampilkan pada profil Anda.',
          style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        
        // Foto Profil (Placeholder)
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF16181D),
                    border: Border.all(color: AppTheme.primaryPink, width: 2),
                    image: _profileImage != null
                        ? DecorationImage(
                            image: FileImage(_profileImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _profileImage == null
                      ? const Icon(Icons.person, size: 50, color: Colors.white24)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryPink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Nama Lengkap
        Text(
          'Nama Lengkap',
          style: GoogleFonts.inter(color: Colors.grey.shade300, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF16181D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextFormField(
            controller: _fullNameController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Masukkan nama',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            validator: (value) => value == null || value.isEmpty ? 'Nama lengkap harus diisi' : null,
          ),
        ),
        const SizedBox(height: 20),

        // Jenis Kelamin
        Text(
          'Jenis Kelamin',
          style: GoogleFonts.inter(color: Colors.grey.shade300, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedGender = 'Pria'),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _selectedGender == 'Pria' ? const Color(0xFF331626) : const Color(0xFF16181D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedGender == 'Pria' ? AppTheme.primaryPink : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Pria',
                      style: GoogleFonts.inter(
                        color: _selectedGender == 'Pria' ? AppTheme.primaryPink : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedGender = 'Wanita'),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _selectedGender == 'Wanita' ? const Color(0xFF331626) : const Color(0xFF16181D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedGender == 'Wanita' ? AppTheme.primaryPink : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Wanita',
                      style: GoogleFonts.inter(
                        color: _selectedGender == 'Wanita' ? AppTheme.primaryPink : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Bottom Button Layout ---
  Widget _buildBottomButton() {
    final isEnabled = !_isLoading;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isEnabled
              ? const LinearGradient(colors: [AppTheme.primaryPink, AppTheme.roseGold])
              : null,
          color: isEnabled ? null : Colors.grey.shade800,
        ),
        child: ElevatedButton(
          onPressed: isEnabled ? _onButtonPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getButtonText(),
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _currentStep == 2 ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _getButtonText() {
    if (_currentStep == 1) {
      return _otpSent ? 'Verifikasi Kode OTP' : 'Kirim Kode OTP';
    } else {
      return 'Daftar Sekarang';
    }
  }

  void _onButtonPressed() {
    if (_currentStep == 1) {
      if (_otpSent) {
        _verifyOtp();
      } else {
        _sendOtp();
      }
    } else {
      if (_fullNameController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Harap isi nama lengkap Anda.');
        return;
      }
      _submitRegistration();
    }
  }
}