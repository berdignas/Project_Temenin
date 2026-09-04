import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../driver/screens/home_screen.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  // Page Controller to navigate through registration steps
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 11; // Increased to 11 for separated question pages

  // Step 1: Phone
  final _phoneController = TextEditingController();
  
  // Step 2: OTP
  final _otpController = TextEditingController();
  int _resendTimerSeconds = 60;
  bool _canResendOtp = false;
  bool _isOtpVerified = false;
  String _selectedOtpChannel = 'WhatsApp';
  
  // Step 3: Operational Cities
  final List<String> _cities = [
    'Jakarta',
    'Bandung',
    'Surabaya',
    'Medan',
    'Makassar',
    'Yogyakarta',
    'Semarang',
    'Bali'
  ];
  final List<String> _selectedCities = [];
  
  // Step 4: Vehicle Choice
  String _selectedVehicleType = 'Motor';
  final _vehicleNameController = TextEditingController();
  final _plateNumberController = TextEditingController();
  
  // Step 5-8: Criteria Questions
  final _ageController = TextEditingController(); // For numeric age input
  bool? _criteriaDocsValid; // KTP, SIM berlaku (Yes/No)
  bool? _criteriaVehicleAgeValid; // Usia kendaraan (Yes/No)
  bool? _criteriaBankValid; // Punya rekening bank (Yes/No)

  // Step 9: Data Diri Form
  final _formKeyDataDiri = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _referralController = TextEditingController();
  String _selectedGender = 'Laki-laki';
  bool _obscurePassword = true;

  // Step 7: Document Upload Sequence
  String? _ktpPhotoPath;
  String? _selfiePhotoPath;
  String? _stnkPhotoPath;
  String? _simPhotoPath;

  // Camera simulation variables
  bool _isCameraOpen = false;
  String _currentDocumentTypeToCapture = '';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _vehicleNameController.dispose();
    _plateNumberController.dispose();
    _ageController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emergencyPhoneController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  // Helper to start OTP timer
  void _startOtpTimer() {
    setState(() {
      _resendTimerSeconds = 60;
      _canResendOtp = false;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_resendTimerSeconds > 0) {
          _resendTimerSeconds--;
        } else {
          _canResendOtp = true;
        }
      });
      return _resendTimerSeconds > 0;
    });
  }

  // Handle OTP request simulation
  void _requestOtp() {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nomor HP Anda terlebih dahulu')),
      );
      return;
    }
    
    // Simulate generating an OTP code
    final generatedOtp = "123456";
    
    // Show WhatsApp-style SnackBar with SALIN action exactly like the client app
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF121B22),
        content: Row(
          children: [
            const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF25D366), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WhatsApp Simulator',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF25D366),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kode verifikasi unik Anda adalah: $generatedOtp. Jangan bagikan kode ini kepada siapapun.',
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
              _otpController.text = generatedOtp;
            });
            // Automatically verify the OTP immediately after it is pasted!
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _verifyOtp();
            });
          },
        ),
      ),
    );

    _startOtpTimer();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Handle OTP verification simulation
  void _verifyOtp() {
    if (_otpController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan 6 digit kode OTP')),
      );
      return;
    }
    setState(() {
      _isOtpVerified = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verifikasi OTP Berhasil!'),
        backgroundColor: Colors.green,
      ),
    );
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Real Document Capture / Upload
  Future<void> _pickImage(String docType, ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      setState(() {
        if (docType == 'KTP') _ktpPhotoPath = image.path;
        else if (docType == 'Selfie') _selfiePhotoPath = image.path;
        else if (docType == 'STNK') _stnkPhotoPath = image.path;
        else if (docType == 'SIM') _simPhotoPath = image.path;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto $docType berhasil ditambahkan!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _openCamera(String docType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                title: Text('Ambil dari Kamera', style: GoogleFonts.poppins(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(docType, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
                title: Text('Pilih dari Galeri', style: GoogleFonts.poppins(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(docType, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  // Submit all data to register
  void _submitRegistration() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Build the vehicle_stnk JSON payload to encapsulate Gojek-style extra fields
    final Map<String, dynamic> metadata = {
      'operational_cities': _selectedCities,
      'emergency_phone': _emergencyPhoneController.text.trim(),
      'referral_code': _referralController.text.trim(),
      'vehicles': [
        {
          'type': _selectedVehicleType,
          'name': _vehicleNameController.text.trim(),
          'plate_number': _plateNumberController.text.toUpperCase().trim(),
          'age': _criteriaVehicleAgeValid == true ? '< 10 Tahun' : '> 10 Tahun',
        }
      ],
      'active_vehicle_index': 0,
      'criteria_answers': {
        'driver_age': int.tryParse(_ageController.text.trim()) ?? 0,
        'age_valid': true, // Since we validate >18 and <45 in the step before proceeding
        'docs_valid': _criteriaDocsValid ?? false,
        'has_bank_account': _criteriaBankValid ?? false,
      },
      'documents': {
        'ktp': _ktpPhotoPath ?? '',
        'selfie': _selfiePhotoPath ?? '',
        'stnk': _stnkPhotoPath ?? '',
        'sim': _simPhotoPath ?? '',
      }
    };

    final String vehicleStnkJsonString = jsonEncode(metadata);

    final success = await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      gender: _selectedGender,
      vehicleType: _selectedVehicleType == 'Keduanya' ? 'Motor' : _selectedVehicleType, // database constraint compat
      vehicleName: _vehicleNameController.text.trim(),
      plateNumber: _plateNumberController.text.toUpperCase().trim(),
      vehicleStnk: vehicleStnkJsonString,
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Registrasi gagal. Coba lagi.'),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;

        if (_currentStep > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            // Background Gradient decoration
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.darkBgGradient,
              ),
            ),
            
            SafeArea(
              child: _buildWizardFlow(authProvider),
            ),
          ],
        ),
      ),
    );
  }

  // Interactive Viewfinder Mock for Documents camera capture
  // Steps UI Controller
  Widget _buildWizardFlow(AuthProvider auth) {
    return Column(
      children: [
        // App Bar & Steps Progress
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textHighContrast),
                onPressed: () {
                  if (_currentStep > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pendaftaran Driver',
                      style: GoogleFonts.poppins(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    // Progress Line
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / _totalSteps,
                        backgroundColor: AppTheme.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${_currentStep + 1}/$_totalSteps',
                style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        
        // Wizard Pages
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // Force navigation via buttons
            onPageChanged: (step) {
              setState(() {
                _currentStep = step;
              });
            },
            children: [
              _buildStepPhoneInput(),
              _buildStepOtpVerify(),
              _buildStepOperationalCities(),
              _buildStepVehicleDetails(),
              _buildStepAgeInput(),
              _buildStepDocumentValidity(),
              _buildStepVehicleAge(),
              _buildStepBankAccount(),
              _buildStepPersonalData(),
              _buildStepIncomePrepAndTutorial(),
              _buildStepDocumentUpload(auth),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 1: Phone input & OTP choice
  Widget _buildStepPhoneInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Masukkan Nomor HP",
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            "Gunakan nomor HP aktif untuk menerima kode OTP verifikasi",
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 32),
          
          // Phone Input
          Text(
            "NOMOR HP UTAMA",
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPink),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "812xxxxxxxx",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Text("+62 ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // OTP Delivery Channel Option
          Text(
            "PILIH SALURAN PENGIRIMAN OTP",
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPink),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedOtpChannel = 'WhatsApp'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _selectedOtpChannel == 'WhatsApp' 
                          ? AppTheme.primaryPink.withOpacity(0.1) 
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedOtpChannel == 'WhatsApp' 
                            ? AppTheme.primaryPink 
                            : Colors.white.withOpacity(0.05)
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.chat_bubble_rounded, color: Colors.greenAccent, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          "WhatsApp",
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedOtpChannel = 'SMS'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _selectedOtpChannel == 'SMS' 
                          ? AppTheme.primaryPink.withOpacity(0.1) 
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedOtpChannel == 'SMS' 
                            ? AppTheme.primaryPink 
                            : Colors.white.withOpacity(0.05)
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.sms_rounded, color: Colors.blueAccent, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          "SMS",
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          
          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _requestOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                "KIRIM KODE OTP",
                style: GoogleFonts.poppins(color: const Color(0xFF4A1031), fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          )
        ],
      ),
    );
  }

  // STEP 2: OTP Verification
  Widget _buildStepOtpVerify() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Masukkan Kode OTP",
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            "Kami telah mengirimkan 6 digit kode OTP ke nomor +62 ${_phoneController.text} via $_selectedOtpChannel",
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 32),
          
          // OTP Textfield
          Text(
            "KODE VERIFIKASI (OTP)",
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPink),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: "123456",
                hintStyle: TextStyle(color: Colors.white10),
                border: InputBorder.none,
                counterText: "",
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: (val) {
                if (val.length == 6) {
                  _verifyOtp();
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          
          // Resend section
          Center(
            child: _canResendOtp 
              ? TextButton(
                  onPressed: _startOtpTimer,
                  child: Text(
                    "Kirim ulang kode OTP",
                    style: GoogleFonts.poppins(color: AppTheme.primaryPink, fontWeight: FontWeight.bold),
                  ),
                )
              : Text(
                  "Kirim ulang OTP dalam $_resendTimerSeconds detik",
                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
                ),
          ),
          const SizedBox(height: 40),
          
          // Submit verify button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.roseGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                "VERIFIKASI OTP",
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          )
        ],
      ),
    );
  }

  // STEP 3: Operational Cities (Multi-select)
  Widget _buildStepOperationalCities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pilih Kota Operasional",
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                "Di kota mana Anda akan aktif melayani pendampingan? Anda bisa memilih lebih dari satu kota.",
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
              ),
            ],
          ),
        ),
        
        // Multi-select list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _cities.length,
            itemBuilder: (context, index) {
              final city = _cities[index];
              final isSelected = _selectedCities.contains(city);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryPink.withOpacity(0.08) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryPink : Colors.white.withOpacity(0.05),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  title: Text(
                    city,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  activeColor: AppTheme.primaryPink,
                  checkColor: const Color(0xFF4A1031),
                  tileColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedCities.add(city);
                      } else {
                        _selectedCities.remove(city);
                      }
                    });
                  },
                ),
              );
            },
          ),
        ),
        
        // Navigation button
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _selectedCities.isEmpty 
                  ? null 
                  : () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                disabledBackgroundColor: Colors.white10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                "LANJUTKAN (${_selectedCities.length} KOTA TERPILIH)",
                style: GoogleFonts.poppins(
                  color: _selectedCities.isEmpty ? Colors.white30 : const Color(0xFF4A1031),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  // STEP 4: Vehicle Details
  Widget _buildStepVehicleDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Detail Kendaraan",
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            "Pilih tipe kendaraan primer Anda",
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 24),
          
          // Vehicle Type Selector
          Text(
            "PILIHAN KENDARAAN",
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPink),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildVehicleTypeCard('Motor', Icons.motorcycle_rounded),
              const SizedBox(width: 8),
              _buildVehicleTypeCard('Mobil', Icons.directions_car_rounded),
              const SizedBox(width: 8),
              _buildVehicleTypeCard('Keduanya', Icons.electric_moped_rounded),
            ],
          ),
          const SizedBox(height: 16),
          
          // Vehicle Name
          Text(
            "MERK / MODEL KENDARAAN",
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPink),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _vehicleNameController,
            hint: "Honda Beat 2023 / Toyota Avanza 2021",
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 16),
          
          // Plate Number
          Text(
            "PLAT NOMOR KENDARAAN",
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPink),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _plateNumberController,
            hint: "B 1234 XYZ",
            icon: Icons.credit_card_rounded,
          ),
          const SizedBox(height: 32),
          
          // Next Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_vehicleNameController.text.trim().isEmpty || _plateNumberController.text.trim().isEmpty)
                  ? null
                  : () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                disabledBackgroundColor: Colors.white10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                "SIMPAN DETAIL KENDARAAN",
                style: GoogleFonts.poppins(
                  color: (_vehicleNameController.text.trim().isEmpty || _plateNumberController.text.trim().isEmpty) 
                      ? Colors.white30 
                      : const Color(0xFF4A1031),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 5: Age Question
  Widget _buildStepAgeInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Usia Anda saat ini",
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            "Masukkan berapa usia Anda (Kriteria Gojek minimal 18 tahun dan maksimal 45 tahun)",
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 32),
          Text(
            "MASUKKAN USIA (TAHUN)",
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPink),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _ageController,
            hint: "Contoh: 24",
            icon: Icons.calendar_today_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                final age = int.tryParse(_ageController.text.trim());
                if (age == null || age < 18 || age > 45) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Usia harus antara 18 hingga 45 tahun')),
                  );
                  return;
                }
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                "LANJUTKAN",
                style: GoogleFonts.poppins(
                  color: const Color(0xFF4A1031),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYesNoQuestionPage({
    required String title,
    required String subtitle,
    required bool? value,
    required Function(bool) onSelected,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: value == true ? AppTheme.primaryPink : AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: value == true ? AppTheme.primaryPink : Colors.white.withOpacity(0.05)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "IYA",
                      style: GoogleFonts.poppins(
                        color: value == true ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: value == false ? AppTheme.primaryPink : AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: value == false ? AppTheme.primaryPink : Colors.white.withOpacity(0.05)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "TIDAK",
                      style: GoogleFonts.poppins(
                        color: value == false ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: value == null
                  ? null
                  : () {
                      if (value == false) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Maaf, Anda belum memenuhi kriteria')),
                        );
                        return;
                      }
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                disabledBackgroundColor: Colors.white10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                "LANJUTKAN",
                style: GoogleFonts.poppins(
                  color: value == null ? Colors.white30 : const Color(0xFF4A1031),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 6: Document Validity
  Widget _buildStepDocumentValidity() {
    return _buildYesNoQuestionPage(
      title: "Dokumen Pribadi",
      subtitle: "Apakah Anda memiliki KTP & SIM aktif yang berlaku?",
      value: _criteriaDocsValid,
      onSelected: (val) => setState(() => _criteriaDocsValid = val),
    );
  }

  // STEP 7: Vehicle Age
  Widget _buildStepVehicleAge() {
    return _buildYesNoQuestionPage(
      title: "Usia Kendaraan",
      subtitle: "Apakah usia kendaraan yang Anda gunakan di bawah 10 tahun (Minimal tahun 2014)?",
      value: _criteriaVehicleAgeValid,
      onSelected: (val) => setState(() => _criteriaVehicleAgeValid = val),
    );
  }

  // STEP 8: Bank Account
  Widget _buildStepBankAccount() {
    return _buildYesNoQuestionPage(
      title: "Rekening Bank",
      subtitle: "Apakah Anda memiliki rekening bank aktif untuk pencairan dana?",
      value: _criteriaBankValid,
      onSelected: (val) => setState(() => _criteriaBankValid = val),
    );
  }

  Widget _buildVehicleTypeCard(String type, IconData icon) {
    final isSelected = _selectedVehicleType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedVehicleType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryPink.withOpacity(0.1) : AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primaryPink : Colors.white.withOpacity(0.05),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppTheme.primaryPink : Colors.white54, size: 22),
              const SizedBox(height: 6),
              Text(
                type,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCriteriaSwitch(String title, bool val, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
            ),
          ),
          Switch(
            value: val,
            onChanged: onChanged,
            activeColor: AppTheme.primaryPink,
          ),
        ],
      ),
    );
  }

  // STEP 5: Personal Data Form
  Widget _buildStepPersonalData() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeyDataDiri,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Formulir Data Diri",
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "Lengkapi data pribadi Anda untuk pembuatan akun kemitraan",
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 24),
            
            _buildFieldLabel("NAMA LENGKAP"),
            _buildTextField(
              controller: _fullNameController,
              hint: "Andi Wijaya",
              icon: Icons.person_rounded,
              validator: (v) => v!.trim().isEmpty ? 'Nama lengkap wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            
            _buildFieldLabel("ALAMAT EMAIL"),
            _buildTextField(
              controller: _emailController,
              hint: "andi@example.com",
              icon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (!v!.contains('@')) ? 'Email tidak valid' : null,
            ),
            const SizedBox(height: 16),
            
            _buildFieldLabel("PASSWORD AKUN"),
            _buildTextField(
              controller: _passwordController,
              hint: "Minimal 6 karakter",
              icon: Icons.lock_rounded,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white30,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) => v!.length < 6 ? 'Password minimal 6 karakter' : null,
            ),
            const SizedBox(height: 16),
            
            _buildFieldLabel("NOMOR HP DARURAT (EMERGENCY)"),
            _buildTextField(
              controller: _emergencyPhoneController,
              hint: "+62 8xx-xxxx-xxxx",
              icon: Icons.contact_phone_rounded,
              keyboardType: TextInputType.phone,
              validator: (v) => v!.trim().isEmpty ? 'Nomor darurat wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            _buildFieldLabel("GENDER"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  dropdownColor: AppTheme.surface,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(border: InputBorder.none),
                  items: ['Laki-laki', 'Perempuan']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedGender = val!),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildFieldLabel("KODE REFERRAL (OPSIONAL)"),
            _buildTextField(
              controller: _referralController,
              hint: "TEMENIN-XXXX",
              icon: Icons.card_giftcard_rounded,
            ),
            const SizedBox(height: 32),
            
            // Next Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKeyDataDiri.currentState!.validate()) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  "LANJUTKAN PROFIL",
                  style: GoogleFonts.poppins(color: const Color(0xFF4A1031), fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // STEP 6: Income Prep Page & Photo Tutorial
  Widget _buildStepIncomePrepAndTutorial() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Persiapan Akun",
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),
          
          // Core Preparation Message Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E1045), Color(0xFF160D27)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryPink.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.stars_rounded, color: AppTheme.primaryPink, size: 36),
                const SizedBox(height: 12),
                Text(
                  "Akun Temenin Ajaa Anda akan disiapkan untuk menerima pendapatan",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.4
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Mari lengkapi verifikasi dokumen fisik Anda agar akun dapat segera aktif menerima pesanan dari pengguna.",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                )
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Profile Photo with KTP Tutorial
          Text(
            "PANDUAN FOTO PROFIL DENGAN E-KTP",
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPink, letterSpacing: 1.0),
          ),
          const SizedBox(height: 12),
          _buildTutorialItem(Icons.face_rounded, "Wajah & KTP Terlihat Jelas", "Posisikan e-KTP di samping/di bawah dagu tanpa menutupi wajah Anda."),
          _buildTutorialItem(Icons.lightbulb_rounded, "Cahaya Cukup (Terang)", "Pastikan berfoto di tempat terang dan tulisan pada e-KTP terbaca jelas."),
          _buildTutorialItem(Icons.blur_off_rounded, "Foto Fokus & Tidak Kabur", "Kamera harus fokus dan stabil. Hindari pantulan cahaya pada kartu e-KTP."),
          const SizedBox(height: 40),
          
          // "Boleh" Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                "BOLEH, LANJUTKAN",
                style: GoogleFonts.poppins(color: const Color(0xFF4A1031), fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTutorialItem(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryPink, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(description, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // STEP 7: Document Upload Sequence (e-KTP, Selfie+KTP, STNK, SIM)
  Widget _buildStepDocumentUpload(AuthProvider auth) {
    final bool allUploaded = _ktpPhotoPath != null &&
        _selfiePhotoPath != null &&
        _stnkPhotoPath != null &&
        _simPhotoPath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Unggah Dokumen",
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                "Unggah dokumen persyaratan Anda secara berurutan di bawah ini.",
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _buildUploadDocItem(
                title: "1. Foto E-KTP",
                desc: "Foto KTP elektronik Anda secara mendatar",
                isUploaded: _ktpPhotoPath != null,
                onTap: () => _openCamera("KTP"),
              ),
              _buildUploadDocItem(
                title: "2. Foto Selfie",
                desc: "Foto wajah Anda dengan jelas",
                isUploaded: _selfiePhotoPath != null,
                onTap: () => _openCamera("Selfie"),
              ),
              _buildUploadDocItem(
                title: "3. Dokumen STNK (Kendaraan)",
                desc: "Pastikan STNK kendaraan Anda aktif dan terlihat jelas",
                isUploaded: _stnkPhotoPath != null,
                onTap: () => _openCamera("STNK"),
              ),
              _buildUploadDocItem(
                title: "4. Dokumen SIM (Driver)",
                desc: "Unggah Foto SIM A atau SIM C Anda yang masih aktif",
                isUploaded: _simPhotoPath != null,
                onTap: () => _openCamera("SIM"),
              ),
            ],
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (allUploaded && !auth.isLoading) ? _submitRegistration : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.roseGold,
                disabledBackgroundColor: Colors.white10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      "SELESAIKAN PENDAFTARAN",
                      style: GoogleFonts.poppins(
                        color: allUploaded ? Colors.white : Colors.white30,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadDocItem({
    required String title,
    required String desc,
    required bool isUploaded,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUploaded ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.05),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUploaded ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.02),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUploaded ? Icons.check_circle_rounded : Icons.camera_enhance_rounded,
              color: isUploaded ? Colors.greenAccent : AppTheme.primaryPink,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isUploaded ? Colors.white12 : AppTheme.primaryPink.withOpacity(0.1),
              foregroundColor: AppTheme.primaryPink,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isUploaded ? "Ubah" : "Unggah",
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryPink,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
          prefixIcon: Icon(icon, color: AppTheme.primaryPink, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }
}
