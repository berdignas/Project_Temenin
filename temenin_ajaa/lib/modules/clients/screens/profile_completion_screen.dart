import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/providers/auth_provider.dart';
import 'package:temenin_ajaa/data/models/user_model.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final UserModel user;

  const ProfileCompletionScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  int _currentStep = 1; // 1: Data Diri, 2: Verifikasi Email
  bool _otpSent = false;
  String _generatedOtp = '';
  bool _isSaving = false;
  String? _errorMsg;

  late TextEditingController _nameController;
  late TextEditingController _nikController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  late TextEditingController _otpController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName ?? '');
    _nikController = TextEditingController();
    _addressController = TextEditingController();
    
    String emailText = '';
    if (widget.user.email.isNotEmpty && !widget.user.email.endsWith('@temenin.aja')) {
      emailText = widget.user.email;
    }
    _emailController = TextEditingController(text: emailText);
    _otpController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nikController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_currentStep == 2) {
      setState(() {
        _currentStep = 1;
        _errorMsg = null;
      });
      return false; // Stay on screen
    }
    
    // Warn user they are leaving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Silakan lengkapi profil nanti untuk mengakses fitur pemesanan secara penuh.'),
        backgroundColor: AppColors.warning,
      ),
    );
    return true; // Allow pop
  }

  void _nextStep() {
    final name = _nameController.text.trim();
    final nik = _nikController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMsg = 'Nama Lengkap wajib diisi.');
      return;
    }
    if (nik.length != 16) {
      setState(() => _errorMsg = 'NIK wajib berisi 16 digit angka.');
      return;
    }
    if (address.isEmpty) {
      setState(() => _errorMsg = 'Alamat wajib diisi.');
      return;
    }

    setState(() {
      _currentStep = 2;
      _errorMsg = null;
    });
  }

  void _sendOtp() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMsg = 'Masukkan alamat email yang valid.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });
    
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final random = Random();
      _generatedOtp = (100000 + random.nextInt(900000)).toString();
      setState(() {
        _isSaving = false;
        _otpSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '[SIMULASI OTP] Kode OTP Anda: $_generatedOtp',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.electricPink,
          duration: const Duration(seconds: 15),
          action: SnackBarAction(
            label: 'SALIN',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) {
                _otpController.text = _generatedOtp;
              }
            },
          ),
        ),
      );
    });
  }

  Future<void> _verifyAndSave() async {
    final enteredOtp = _otpController.text.trim();
    if (enteredOtp != _generatedOtp) {
      setState(() => _errorMsg = 'Kode OTP yang Anda masukkan salah.');
      return;
    }
    
    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.verifyEmailAndCompleteProfile(
      email: _emailController.text.trim(),
      fullName: _nameController.text.trim(),
      phone: widget.user.phone ?? '',
      nik: _nikController.text.trim(),
      address: _addressController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true); // Return true indicating success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil dan Email Anda berhasil diverifikasi!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _isSaving = false;
        _errorMsg = authProvider.errorMessage ?? 'Gagal menyimpan data.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.obsidian,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textHighContrast),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.pop(context, false);
              }
            },
          ),
          title: Text(
            _currentStep == 1 ? 'Lengkapi Data Diri' : 'Verifikasi Email',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textHighContrast,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.electricPink,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: _currentStep == 2 ? AppColors.electricPink : AppColors.elevatedDark,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: _currentStep == 1 ? _buildStep1() : _buildStep2(),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
          child: _currentStep == 1
              ? ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.electricPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Lanjut',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sesuai regulasi keamanan, lengkapi data profil Anda untuk mulai memesan partner.',
          style: GoogleFonts.inter(
            color: AppColors.textMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        
        Text(
          'Nama Lengkap (Sesuai KTP)',
          style: GoogleFonts.inter(color: AppColors.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: AppColors.textHighContrast, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Contoh: Sarah Jessica',
            hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
            filled: true,
            fillColor: AppColors.obsidian,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.elevatedDark)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.elevatedDark)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Nomor KTP / NIK (16 Digit)',
          style: GoogleFonts.inter(color: AppColors.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nikController,
          keyboardType: TextInputType.number,
          maxLength: 16,
          style: const TextStyle(color: AppColors.textHighContrast, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Masukkan 16 digit NIK Anda',
            hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
            counterText: '',
            filled: true,
            fillColor: AppColors.obsidian,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.elevatedDark)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.elevatedDark)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Alamat Lengkap',
          style: GoogleFonts.inter(color: AppColors.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _addressController,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textHighContrast, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Contoh: Jalan Senopati No. 12, Jakarta Selatan',
            hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
            filled: true,
            fillColor: AppColors.obsidian,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.elevatedDark)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.elevatedDark)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        
        if (_errorMsg != null) ...[
          const SizedBox(height: 24),
          Text(
            _errorMsg!,
            style: GoogleFonts.inter(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Masukkan alamat email aktif Anda untuk mengirimkan kode verifikasi OTP.',
          style: GoogleFonts.inter(
            color: AppColors.textMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        
        Text(
          'Alamat Email',
          style: GoogleFonts.inter(color: AppColors.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_otpSent,
                style: const TextStyle(color: AppColors.textHighContrast, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Contoh: user@gmail.com',
                  hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
                  filled: true,
                  fillColor: AppColors.obsidian,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.elevatedDark)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.elevatedDark)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            if (_otpSent) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _otpSent = false;
                    _otpController.clear();
                  });
                },
                child: Text(
                  'Ubah',
                  style: GoogleFonts.inter(color: AppColors.electricPink, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),

        if (!_otpSent) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Kirim Kode OTP', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ] else ...[
          Text(
            'Kode Verifikasi OTP (6 Digit)',
            style: GoogleFonts.inter(color: AppColors.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: AppColors.textHighContrast, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: '------',
              hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.4), letterSpacing: 8),
              counterText: '',
              filled: true,
              fillColor: AppColors.obsidian,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.elevatedDark)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.elevatedDark)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _verifyAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Verifikasi & Simpan', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],

        if (_errorMsg != null) ...[
          const SizedBox(height: 24),
          Text(
            _errorMsg!,
            style: GoogleFonts.inter(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class AppColors {
  // Core Palette (Clean Modern Fuchsia + Putih + Abu-abu Terang)
  static const Color deepVoid = Color(0xFFF8F9FA);     // Putih Tulang / Off-White
  static const Color obsidian = Color(0xFFFFFFFF);     // Putih Bersih
  static const Color elevatedDark = Color(0xFFE2E8F0); // Abu-abu Terang / Border
  static const Color electricPink = Color(0xFFE11D74); // Vibrant Fuchsia
  static const Color roseGold = Color(0xFFDB2777);     // Fuchsia Secondary

  // Status Colors
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // Text Colors
  static const Color textHighContrast = Color(0xFF0F172A);
  static const Color textMediumContrast = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);
  
  static const Color background = deepVoid;
}
