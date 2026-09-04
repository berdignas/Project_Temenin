import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  File? _selectedImage;
  bool _isLoading = false;
  bool _isImageLoading = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _fullNameController.text = authProvider.user!.fullName ?? '';
      _phoneController.text = authProvider.user!.phone ?? '';
    }
  }

  Future<void> _pickImage() async {
    setState(() => _isImageLoading = true);
    
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImageLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    
    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama lengkap tidak boleh kosong')),
      );
      return;
    }
    
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor telepon tidak boleh kosong')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final bool success;
      if (_selectedImage != null) {
        success = await authProvider.updateCompleteProfile(
          fullName: fullName,
          phone: phone,
          avatarImage: _selectedImage!,
        );
      } else {
        success = await authProvider.updateProfile(fullName, phone);
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil berhasil diperbarui!'),
              backgroundColor: AppTheme.success,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 'Gagal memperbarui profil'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Edit Profil',
          style: GoogleFonts.inter(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: Text(
              'Simpan',
              style: GoogleFonts.inter(
                color: AppTheme.primaryPink,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar Section
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPink.withOpacity(0.15),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: AppTheme.fuchsiaLight,
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : (user?.avatarUrl != null
                                ? NetworkImage(user!.avatarUrl!)
                                : null) as ImageProvider?,
                        child: (_selectedImage == null && user?.avatarUrl == null)
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: AppTheme.primaryPink,
                              )
                            : null,
                      ),
                    ),
                    if (_isImageLoading)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.4),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPink,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.background, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ketuk untuk mengganti foto profil',
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 32),
              
              // Full Name Field
              TextFormField(
                controller: _fullNameController,
                style: GoogleFonts.inter(color: AppTheme.textHighContrast),
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  labelStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryPink),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Silakan masukkan nama lengkap Anda';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Phone Field
              TextFormField(
                controller: _phoneController,
                style: GoogleFonts.inter(color: AppTheme.textHighContrast),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Nomor Telepon',
                  labelStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.primaryPink),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Silakan masukkan nomor telepon Anda';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Email Field (Read-only)
              TextFormField(
                initialValue: user?.email ?? '',
                style: GoogleFonts.inter(color: AppTheme.textMuted),
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Alamat Email',
                  labelStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.cardDeep,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryPink),
                ),
              ),
              const SizedBox(height: 24),
              
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.fuchsiaLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryPink.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.primaryPink),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Alamat email terdaftar tidak dapat diubah. Hubungi pusat bantuan jika Anda membutuhkan bantuan.',
                        style: GoogleFonts.inter(
                          color: AppTheme.textHighContrast,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}