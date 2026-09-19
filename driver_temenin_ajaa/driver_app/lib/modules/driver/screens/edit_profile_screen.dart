import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../providers/auth_provider.dart';
import 'driver_addons_screen.dart';

class EditDriverProfileScreen extends StatefulWidget {
  const EditDriverProfileScreen({super.key});

  @override
  State<EditDriverProfileScreen> createState() => _EditDriverProfileScreenState();
}

class _EditDriverProfileScreenState extends State<EditDriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _vehicleNameController;
  late TextEditingController _plateNumberController;
  late TextEditingController _priceController;
  late TextEditingController _experienceController;
  late TextEditingController _bioController;
  
  String _selectedGender = 'Laki-laki';
  bool _initialized = false;

  List<String> _selectedCities = [];
  List<String> _selectedSkills = [];
  List<String> _selectedLanguages = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _addons = [];
  int _activeVehicleIndex = 0;

  final List<String> _allCities = [
    'Jakarta',
    'Bandung',
    'Surabaya',
    'Medan',
    'Makassar',
    'Yogyakarta',
    'Semarang',
    'Bali',
    'Tangerang',
    'Bekasi',
    'Bogor',
    'Depok',
  ];

  final List<String> _allSkillsRecommendation = [
    'Paham Rute & Jalan Pintas',
    'Mengemudi Defensif & Aman',
    'Navigasi GPS Cepat & Ahli',
    'Ramah & Komunikatif',
    'Teman Wisata Kuliner & Kafe',
    'Paham Spot Wisata & Tempat Hits',
    'Fotografi & Bantu Foto Aesthetic',
    'Disiplin & Selalu Tepat Waktu',
    'Menjaga Privasi & Rahasia Klien',
    'Bantuan Angkat Barang Belanja',
    'Tanggap Darurat Kendaraan',
    'Rute Antar Kota & Tol Bebas Hambatan',
    'Antar Jemput Bandara & Stasiun',
    'Pendengar Cerita yang Baik & Berempati',
    'Peka Terhadap Kebutuhan Klien',
    'Berpakaian Rapi, Bersih & Wangi',
    'Etika & Tata Krama Sopan',
    'Teman Nonton / Konser / Event',
    'Pendamping Acara Formal & Bisnis',
    'Siap Menunggu dengan Sabar',
    'Pet Friendly (Ramah Hewan)',
    'Bebas Asap Rokok di Kendaraan',
    'Kabin Bersih & AC Dingin',
    'Paham Area Belanja & Mall',
    'Asisten Pribadi On-The-Go',
  ];

  final List<String> _allLanguages = [
    'Bahasa Indonesia',
    'Bahasa Inggris',
    'Bahasa Jawa',
    'Bahasa Sunda',
    'Bahasa Mandarin',
    'Bahasa Jepang',
    'Bahasa Korea',
    'Bahasa Arab',
    'Bahasa Minang',
    'Bahasa Bali',
  ];

  String _detectVehicleCategory(String name, [String? rawType]) {
    final lowerName = name.toLowerCase();
    final lowerType = (rawType ?? '').toLowerCase();

    if (lowerType.contains('mobil') || lowerName.contains('mobil') || lowerName.contains('car') || lowerName.contains('avanza') || lowerName.contains('xenia') || lowerName.contains('brio') || lowerName.contains('agya') || lowerName.contains('ayla') || lowerName.contains('innova') || lowerName.contains('rush') || lowerName.contains('terios') || lowerName.contains('yaris') || lowerName.contains('jazz') || lowerName.contains('calya') || lowerName.contains('sigra')) {
      return 'Mobil';
    }

    if (lowerType.contains('sport') || lowerName.contains('cbr') || lowerName.contains('ninja') || lowerName.contains('r15') || lowerName.contains('r25') || lowerName.contains('gsx') || lowerName.contains('sport') || lowerName.contains('cb150') || lowerName.contains('vixion') || lowerName.contains('mt-') || lowerName.contains('mt15') || lowerName.contains('mt25') || lowerName.contains('klx') || lowerName.contains('crf') || lowerName.contains('wr155')) {
      return 'Motor Sport';
    }

    if (lowerType.contains('classic') || lowerType.contains('retro') || lowerName.contains('vespa') || lowerName.contains('scoopy') || lowerName.contains('fazzio') || lowerName.contains('filano') || lowerName.contains('grand filano') || lowerName.contains('genio') || lowerName.contains('w175') || lowerName.contains('classic') || lowerName.contains('retro')) {
      return 'Motor Classic';
    }

    if (lowerType.contains('bebek') || lowerName.contains('supra') || lowerName.contains('jupiter') || lowerName.contains('revo') || lowerName.contains('vega') || lowerName.contains('smash') || lowerName.contains('shogun') || lowerName.contains('blade') || lowerName.contains('satria') || lowerName.contains('mx king') || lowerName.contains('bebek')) {
      return 'Motor Bebek';
    }

    return 'Motor Matic';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final auth = Provider.of<AuthProvider>(context);
      final user = auth.user;
      final driver = auth.driverProfileData;

      _fullNameController = TextEditingController(text: user?.fullName ?? '');
      _phoneController = TextEditingController(text: user?.phone ?? '');
      _priceController = TextEditingController(text: (driver?['price_per_hour'] ?? 50000).toString());
      _experienceController = TextEditingController(text: (driver?['experience_years'] ?? 0).toString());
      _selectedGender = user?.gender ?? 'Laki-laki';
      
      final String vehicleStnk = driver?['vehicle_stnk'] ?? '';
      String bioText = '';

      if (vehicleStnk.startsWith('{')) {
        try {
          final Map<String, dynamic> metadata = jsonDecode(vehicleStnk);
          if (metadata['operational_cities'] != null) {
            _selectedCities = List<String>.from(metadata['operational_cities']);
          }
          if (metadata['skills'] != null) {
            _selectedSkills = List<String>.from(metadata['skills']);
          }
          if (metadata['languages'] != null) {
            _selectedLanguages = List<String>.from(metadata['languages']);
          }
          if (metadata['vehicles'] != null) {
            _vehicles = List<Map<String, dynamic>>.from(
              (metadata['vehicles'] as List).map((v) => Map<String, dynamic>.from(v))
            );
          }
          if (metadata['addons'] != null) {
            _addons = List<Map<String, dynamic>>.from(
              (metadata['addons'] as List).map((a) => Map<String, dynamic>.from(a))
            );
          }
          _activeVehicleIndex = metadata['active_vehicle_index'] ?? 0;
          bioText = metadata['bio'] ?? '';
        } catch (e) {
          debugPrint('Error parsing vehicle_stnk: $e');
        }
      } else {
        bioText = vehicleStnk;
      }

      if (_selectedLanguages.isEmpty) {
        _selectedLanguages = ['Bahasa Indonesia'];
      }

      if (_vehicles.isEmpty) {
        final vName = driver?['vehicle_name']?.toString().trim();
        final vPlate = driver?['plate_number']?.toString().trim();
        final vType = driver?['vehicle_type']?.toString().trim();

        if (vName != null && vName.isNotEmpty && vName != 'Belum diatur') {
          _vehicles.add({
            'type': (vType != null && vType.isNotEmpty) ? vType : 'Motor',
            'name': vName,
            'plate_number': (vPlate != null && vPlate.isNotEmpty) ? vPlate : '',
            'age': '< 5 Tahun',
          });
        }
      }

      final activeV = (_vehicles.isNotEmpty && _activeVehicleIndex < _vehicles.length)
          ? _vehicles[_activeVehicleIndex]
          : {'name': driver?['vehicle_name'] ?? '', 'plate_number': driver?['plate_number'] ?? ''};

      _vehicleNameController = TextEditingController(text: activeV['name'] ?? '');
      _plateNumberController = TextEditingController(text: activeV['plate_number'] ?? '');
      _bioController = TextEditingController(text: bioText);
      
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _vehicleNameController.dispose();
    _plateNumberController.dispose();
    _priceController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_vehicles.isNotEmpty && _activeVehicleIndex < _vehicles.length) {
      _vehicleNameController.text = _vehicles[_activeVehicleIndex]['name'] ?? '';
      _plateNumberController.text = _vehicles[_activeVehicleIndex]['plate_number'] ?? '';
    }

    final metadata = {
      'bio': _bioController.text,
      'operational_cities': _selectedCities,
      'skills': _selectedSkills,
      'languages': _selectedLanguages,
      'vehicles': _vehicles,
      'addons': _addons,
      'active_vehicle_index': _activeVehicleIndex,
    };
    final String vehicleStnkJsonString = jsonEncode(metadata);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.updateProfile(
      fullName: _fullNameController.text,
      phone: _phoneController.text,
      gender: _selectedGender,
      vehicleName: _vehicleNameController.text,
      plateNumber: _plateNumberController.text,
      pricePerHour: double.tryParse(_priceController.text) ?? 50000.0,
      experienceYears: int.tryParse(_experienceController.text) ?? 0,
      bio: _bioController.text,
      vehicleStnk: vehicleStnkJsonString,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Profil berhasil diperbarui!',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  auth.errorMessage ?? 'Gagal memperbarui profil',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            "Edit Profil",
            style: GoogleFonts.poppins(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: AppTheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textHighContrast),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.darkBgGradient,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("INFORMASI PRIBADI"),
                  
                  _buildFieldLabel("NAMA LENGKAP"),
                  _buildTextField(
                    controller: _fullNameController,
                    hint: "Andi Wijaya",
                    icon: Icons.person_rounded,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Nama harus diisi';
                      if (v.trim().length < 3) return 'Nama minimal 3 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel("NOMOR TELEPON"),
                  _buildTextField(
                    controller: _phoneController,
                    hint: "0812xxxxxxxx",
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Nomor telepon harus diisi';
                      if (!RegExp(r'^[0-9]+$').hasMatch(v.trim())) return 'Hanya boleh angka';
                      if (v.trim().length < 9 || v.trim().length > 15) return 'Nomor tidak valid (9-15 digit)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel("GENDER"),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        value: _selectedGender,
                        dropdownColor: AppTheme.surface,
                        style: GoogleFonts.poppins(color: AppTheme.textHighContrast, fontSize: 14),
                        decoration: const InputDecoration(border: InputBorder.none),
                        items: ['Laki-laki', 'Perempuan']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: AppTheme.textHighContrast))))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedGender = val!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildSectionHeader("WILAYAH OPERASIONAL"),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allCities.map((city) {
                      final isSelected = _selectedCities.contains(city);
                      return FilterChip(
                        label: Text(city),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryPink.withOpacity(0.15),
                        checkmarkColor: AppTheme.primaryPink,
                        labelStyle: GoogleFonts.poppins(
                          color: isSelected ? AppTheme.primaryPink : AppTheme.textHighContrast,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? AppTheme.primaryPink : AppTheme.border,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCities.add(city);
                            } else {
                              _selectedCities.remove(city);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),

                  _buildSectionHeader("INFORMASI KENDARAAN"),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._vehicles.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final v = entry.value;
                        final isCurrentActive = idx == _activeVehicleIndex;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrentActive ? AppTheme.primaryPink.withOpacity(0.08) : AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrentActive ? AppTheme.primaryPink : AppTheme.border,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Radio<int>(
                                value: idx,
                                groupValue: _activeVehicleIndex,
                                activeColor: AppTheme.primaryPink,
                                onChanged: (val) {
                                  setState(() {
                                    _activeVehicleIndex = val!;
                                  });
                                },
                              ),
                              Icon(
                                v['type'] == 'Mobil' ? Icons.directions_car_rounded : Icons.motorcycle_rounded,
                                color: isCurrentActive ? AppTheme.primaryPink : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(
                                       v['name'] ?? '',
                                       style: GoogleFonts.poppins(
                                         color: AppTheme.textHighContrast,
                                         fontWeight: isCurrentActive ? FontWeight.bold : FontWeight.normal,
                                         fontSize: 13,
                                       ),
                                     ),
                                     const SizedBox(height: 3),
                                     Row(
                                       children: [
                                         Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                           decoration: BoxDecoration(
                                             color: AppTheme.fuchsiaLight,
                                             borderRadius: BorderRadius.circular(4),
                                             border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                                           ),
                                           child: Text(
                                             _detectVehicleCategory(v['name'] ?? '', v['type']),
                                             style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 9.5, fontWeight: FontWeight.bold),
                                           ),
                                         ),
                                         const SizedBox(width: 6),
                                         Expanded(
                                           child: Text(
                                             "${v['plate_number'] ?? ''} • Usia: ${v['age'] ?? '< 5 tahun'}",
                                             style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                             overflow: TextOverflow.ellipsis,
                                           ),
                                         ),
                                       ],
                                     ),
                                   ],
                                ),
                              ),
                              if (_vehicles.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _vehicles.removeAt(idx);
                                      if (_activeVehicleIndex >= _vehicles.length) {
                                        _activeVehicleIndex = 0;
                                      }
                                    });
                                  },
                                )
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                      
                      // Button to Add Vehicle
                      OutlinedButton.icon(
                        onPressed: () => _showAddVehicleDialog(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text("TAMBAH KENDARAAN BARU"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryPink,
                          side: const BorderSide(color: AppTheme.primaryPink),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  _buildSectionHeader("KEBIJAKAN TARIF & STANDARISASI"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDeep,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryPink.withOpacity(0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPink.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.verified_rounded, color: AppTheme.primaryPink, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Tarif Ditetapkan Oleh Admin",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.textHighContrast,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    "Standarisasi Resmi Platform",
                                    style: GoogleFonts.inter(
                                      color: AppTheme.primaryPink,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withOpacity(0.4)),
                              ),
                              child: const Text(
                                "HARGA PAS",
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Untuk menjaga keadilan dan transparansi bagi Mitra dan Klien, seluruh tarif pesanan (Per KM & Per Jam) diatur terpusat oleh Admin. Driver tidak dapat mengubah tarif manual dan pesanan reguler langsung menggunakan tarif resmi tanpa tawar-menawar.",
                          style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildSectionHeader("PENGALAMAN & PROFIL"),

                  _buildFieldLabel("PENGALAMAN (TAHUN)"),
                  _buildTextField(
                    controller: _experienceController,
                    hint: "3",
                    icon: Icons.work_history_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.trim().isEmpty ? 'Pengalaman harus diisi' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel("BIOGRAFI / DESKRIPSI DIRI"),
                  _buildTextField(
                    controller: _bioController,
                    hint: "Tulis biografi menarik tentang diri Anda agar klien tertarik menyewa jasa pendampingan Anda...",
                    icon: Icons.description_rounded,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader("AREA OPERASIONAL & JANGKAUAN"),
                  _buildFieldLabel("PILIH KOTA OPERASIONAL"),
                  Text(
                    "Pilih kota-kota tempat Anda siap melayani penjemputan & pendampingan klien.",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allCities.map((city) {
                      final isSelected = _selectedCities.contains(city);
                      return FilterChip(
                        label: Text(city),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryPink.withOpacity(0.2),
                        checkmarkColor: AppTheme.primaryPink,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: isSelected ? AppTheme.primaryPink : AppTheme.textHighContrast,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isSelected ? AppTheme.primaryPink : AppTheme.border),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCities.add(city);
                            } else {
                              _selectedCities.remove(city);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  _buildSectionHeader("KEAHLIAN & SPESIALISASI DRIVER"),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFieldLabel("PILIH DARI REKOMENDASI RESMI"),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPink.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${_selectedSkills.length} Dipilih",
                          style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "Pilih keahlian & nilai tambah Anda (minimal 3 - 10+ keahlian) yang akan ditampilkan di profil Anda kepada klien.",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allSkillsRecommendation.map((skill) {
                      final isSelected = _selectedSkills.contains(skill);
                      return FilterChip(
                        label: Text(skill),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryPink.withOpacity(0.2),
                        checkmarkColor: AppTheme.primaryPink,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: isSelected ? AppTheme.primaryPink : AppTheme.textHighContrast,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isSelected ? AppTheme.primaryPink : AppTheme.border),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedSkills.add(skill);
                            } else {
                              _selectedSkills.remove(skill);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  _buildSectionHeader("KEMAMPUAN BAHASA PERCAKAPAN"),
                  _buildFieldLabel("PILIH BAHASA YANG DIKUASAI"),
                  Text(
                    "Pilih bahasa yang Anda kuasai untuk memudahkan komunikasi saat mendampingi klien.",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allLanguages.map((lang) {
                      final isSelected = _selectedLanguages.contains(lang);
                      return FilterChip(
                        label: Text(lang),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryPink.withOpacity(0.2),
                        checkmarkColor: AppTheme.primaryPink,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: isSelected ? AppTheme.primaryPink : AppTheme.textHighContrast,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isSelected ? AppTheme.primaryPink : AppTheme.border),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedLanguages.add(lang);
                            } else {
                              _selectedLanguages.remove(lang);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  _buildSectionHeader("ADD-ONS & FASILITAS TAMBAHAN"),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFieldLabel("FASILITAS EKSTRA UNTUK KLIEN"),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPink.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${_addons.where((a) => a['is_active'] == true).length} Aktif",
                          style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "Atur add-ons yang Anda sediakan (Kamera Pro, AC, Outfit Match, Snack, Tour Guide, dll) agar klien dapat memilihnya di form pemesanan.",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DriverAddonsScreen()),
                      );
                      // Reload addons from driver profile
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final String vehicleStnk = auth.driverProfileData?['vehicle_stnk'] ?? '';
                      if (vehicleStnk.startsWith('{')) {
                        try {
                          final meta = jsonDecode(vehicleStnk);
                          if (meta['addons'] != null) {
                            setState(() {
                              _addons = List<Map<String, dynamic>>.from(meta['addons']);
                            });
                          }
                        } catch (_) {}
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.fuchsiaLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.extension_rounded, color: AppTheme.primaryPink, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Kelola & Tambah Add-on Mitra",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.textHighContrast,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Atur tarif tambahan & fasilitas kustom Anda",
                                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryPink, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.primaryPink,
                            AppTheme.roseGold,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: auth.isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Menyimpan Perubahan...",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                "SIMPAN PERUBAHAN",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textHighContrast,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: AppTheme.border),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
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
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.poppins(color: AppTheme.textHighContrast, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppTheme.primaryPink, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  void _showAddVehicleDialog(BuildContext context) {
    String type = 'Motor Matic';
    String age = '< 5 Tahun';
    String? vehiclePhotoUrl;
    bool isUploadingPhoto = false;
    final nameCtrl = TextEditingController();
    final plateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                "Tambah Unit Kendaraan",
                style: GoogleFonts.poppins(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kategori Kendaraan",
                      style: GoogleFonts.poppins(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        'Motor Matic',
                        'Motor Sport',
                        'Motor Classic',
                        'Motor Bebek',
                        'Mobil',
                      ].map((cat) {
                        final isSelected = type == cat;
                        String iconStr = '🛵';
                        if (cat == 'Motor Sport') iconStr = '🏍️';
                        if (cat == 'Motor Classic') iconStr = '🛵';
                        if (cat == 'Motor Bebek') iconStr = '🏍️';
                        if (cat == 'Mobil') iconStr = '🚗';

                        return ChoiceChip(
                          label: Text("$cat $iconStr"),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryPink.withOpacity(0.15),
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.primaryPink : AppTheme.textHighContrast,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 11,
                          ),
                          side: BorderSide(color: isSelected ? AppTheme.primaryPink : AppTheme.border),
                          onSelected: (selected) {
                            if (selected) setDialogState(() => type = cat);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Nama / Model",
                      style: GoogleFonts.poppins(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "cth: Honda Vario 160",
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.cardDeep,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Plat Nomor",
                      style: GoogleFonts.poppins(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: plateCtrl,
                      style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "cth: B 1234 TAA",
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.cardDeep,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Usia Kendaraan",
                      style: GoogleFonts.poppins(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: age,
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.cardDeep,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                      ),
                      items: ['< 5 Tahun', '5-10 Tahun', '> 10 Tahun']
                          .map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(color: AppTheme.textHighContrast))))
                          .toList(),
                      onChanged: (val) => setDialogState(() => age = val!),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Foto Kendaraan (Opsional)",
                      style: GoogleFonts.poppins(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                        if (photo != null) {
                          setDialogState(() => isUploadingPhoto = true);
                          String finalPhotoPath = photo.path;
                          try {
                            final cropped = await ImageCropper().cropImage(
                              sourcePath: photo.path,
                              uiSettings: [
                                AndroidUiSettings(
                                  toolbarTitle: 'Potong Foto Kendaraan',
                                  toolbarColor: AppTheme.surface,
                                  toolbarWidgetColor: AppTheme.textHighContrast,
                                  activeControlsWidgetColor: AppTheme.primaryPink,
                                ),
                                IOSUiSettings(title: 'Potong Foto Kendaraan'),
                              ],
                            );
                            if (cropped != null) finalPhotoPath = cropped.path;
                          } catch (_) {}

                          final uploaded = await context.read<AuthProvider>().uploadImageFile(File(finalPhotoPath), folder: 'vehicles');
                          setDialogState(() {
                            vehiclePhotoUrl = uploaded;
                            isUploadingPhoto = false;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDeep,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: vehiclePhotoUrl != null ? AppTheme.primaryPink : AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            if (isUploadingPhoto)
                              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPink))
                            else if (vehiclePhotoUrl != null)
                              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryPink, size: 20)
                            else
                              const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryPink, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                vehiclePhotoUrl != null ? "Foto Terpilih ✔" : "Unggah Foto Unit 📸",
                                style: GoogleFonts.inter(
                                  color: vehiclePhotoUrl != null ? AppTheme.primaryPink : AppTheme.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Batal", style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final plate = plateCtrl.text.toUpperCase().trim();
                    if (name.isNotEmpty && plate.isNotEmpty) {
                      setState(() {
                        _vehicles.add({
                          'type': type,
                          'name': name,
                          'plate_number': plate,
                          'image': vehiclePhotoUrl,
                          'age': age,
                        });
                        _activeVehicleIndex = _vehicles.length - 1;
                        _vehicleNameController.text = name;
                        _plateNumberController.text = plate;
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPink),
                  child: const Text("Tambah & Pilih Unit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
