import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

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
  List<Map<String, dynamic>> _vehicles = [];
  int _activeVehicleIndex = 0;

  final List<String> _allCities = [
    'Jakarta',
    'Bandung',
    'Surabaya',
    'Medan',
    'Makassar',
    'Yogyakarta',
    'Semarang',
    'Bali'
  ];

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
          if (metadata['vehicles'] != null) {
            _vehicles = List<Map<String, dynamic>>.from(
              (metadata['vehicles'] as List).map((v) => Map<String, dynamic>.from(v))
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

      if (_vehicles.isEmpty) {
        _vehicles.add({
          'type': driver?['vehicle_type'] ?? 'Motor',
          'name': driver?['vehicle_name'] ?? 'Honda PCX',
          'plate_number': driver?['plate_number'] ?? 'B 1234 XYZ',
          'age': '< 5 Tahun',
        });
      }

      final activeV = _activeVehicleIndex < _vehicles.length ? _vehicles[_activeVehicleIndex] : _vehicles[0];
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
      'vehicles': _vehicles,
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
        const SnackBar(
          content: Text('Profil berhasil diperbarui'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Gagal memperbarui profil'),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
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
                    validator: (v) => v!.trim().isEmpty ? 'Nama harus diisi' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel("NOMOR TELEPON"),
                  _buildTextField(
                    controller: _phoneController,
                    hint: "+62 812-xxxx-xxxx",
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.trim().isEmpty ? 'Nomor telepon harus diisi' : null,
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
                                    Text(
                                      "${v['plate_number'] ?? ''} • Usia: ${v['age'] ?? '< 5 tahun'}",
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                    )
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

                  _buildSectionHeader("PENGATURAN LAYANAN"),

                  _buildFieldLabel("TARIF PER JAM (RP)"),
                  _buildTextField(
                    controller: _priceController,
                    hint: "50000",
                    icon: Icons.monetization_on_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v!.trim().isEmpty) return 'Tarif harus diisi';
                      final price = double.tryParse(v);
                      if (price == null || price < 25000) return 'Tarif minimal Rp 25.000';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

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
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
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
    String type = 'Motor';
    String age = '< 5 Tahun';
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
                "Tambah Kendaraan Baru",
                style: GoogleFonts.poppins(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tipe Kendaraan",
                      style: GoogleFonts.poppins(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Radio<String>(
                          value: 'Motor',
                          groupValue: type,
                          activeColor: AppTheme.primaryPink,
                          onChanged: (val) => setDialogState(() => type = val!),
                        ),
                        const Text("Motor", style: TextStyle(color: AppTheme.textHighContrast, fontSize: 13)),
                        const SizedBox(width: 20),
                        Radio<String>(
                          value: 'Mobil',
                          groupValue: type,
                          activeColor: AppTheme.primaryPink,
                          onChanged: (val) => setDialogState(() => type = val!),
                        ),
                        const Text("Mobil", style: TextStyle(color: AppTheme.textHighContrast, fontSize: 13)),
                      ],
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
                        hintText: "Yamaha NMAX 2024",
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
                        hintText: "B 1234 XYZ",
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
                    if (nameCtrl.text.trim().isNotEmpty && plateCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _vehicles.add({
                          'type': type,
                          'name': nameCtrl.text.trim(),
                          'plate_number': plateCtrl.text.toUpperCase().trim(),
                          'age': age,
                        });
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPink),
                  child: const Text("Tambah", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
