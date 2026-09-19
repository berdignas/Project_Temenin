// lib/modules/home/widgets/profile_tab.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temenin_ajaa/data/models/user_model.dart';
import 'package:temenin_ajaa/modules/clients/pages/help_center_page.dart';
import 'package:temenin_ajaa/modules/clients/pages/notifications_page.dart';
import 'package:temenin_ajaa/modules/clients/pages/settings_page.dart';
import '../../../providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../pages/edit_profile_page.dart';
import '../pages/booking_history_page.dart';
import '../pages/payment_methods_page.dart';
import '../pages/rewards_page.dart';
import '../../../core/theme/app_theme.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserData();
    });
  }

  Future<void> _refreshUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.refreshUser();
  }

  void _refreshProfile() {
    setState(() {
      _refreshKey++;
    });
    _refreshUserData();
  }

  Future<void> _navigateToEditProfile(BuildContext context, dynamic user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfilePage(),
      ),
    );
    
    if (result == true) {
      _refreshProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      key: ValueKey(_refreshKey),
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryPink),
          );
        }
        
        if (authProvider.user == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off_outlined, size: 64, color: AppTheme.textMuted.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text('User not found', style: GoogleFonts.poppins(color: AppTheme.textMuted)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _refreshUserData(),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPink),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        }
        
        return Container(
          color: AppTheme.background,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildCreativeHeader(context, authProvider.user),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      _buildCreativeStats(authProvider.user),
                      const SizedBox(height: 32),
                      Text(
                        "Menu Utama",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textHighContrast,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCreativeMenuSection([
                        _creativeMenuTile(context, Icons.person_rounded, "Edit Profile", Colors.blue.shade400,
                            onTap: () => _navigateToEditProfile(context, authProvider.user)),
                        _creativeMenuTile(context, Icons.history_rounded, "Riwayat Booking", AppTheme.primaryPink,
                            badge: "3 Aktif",
                            onTap: () => _navigateToBookingHistory(context)),
                        _creativeMenuTile(context, Icons.account_balance_wallet_rounded, "Metode Pembayaran", Colors.orange.shade400,
                            onTap: () => _navigateToPaymentMethods(context)),
                        _creativeMenuTile(context, Icons.card_giftcard_rounded, "Rewards & Voucher", Colors.green.shade400,
                            onTap: () => _navigateToRewards(context)),
                      ]),
                      const SizedBox(height: 24),
                      Text(
                        "Dukungan & Lainnya",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textHighContrast,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCreativeMenuSection([
                        _creativeMenuTile(context, Icons.notifications_rounded, "Notifikasi", Colors.purple.shade400,
                            onTap: () => _navigateToNotifications(context)),
                        _creativeMenuTile(context, Icons.support_agent_rounded, "Pusat Bantuan", Colors.teal.shade400,
                            onTap: () => _navigateToHelpCenter(context)),
                        _creativeMenuTile(context, Icons.settings_rounded, "Pengaturan", Colors.grey.shade600,
                            onTap: () => _navigateToSettings(context)),
                        _creativeMenuTile(context, Icons.logout_rounded, "Keluar", AppTheme.danger,
                            isLogout: true,
                            onTap: () => _showLogoutDialog(context, authProvider)),
                      ]),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreativeHeader(BuildContext context, dynamic user) {
    return SizedBox(
      height: 330,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Background Gradient / Pattern
          Container(
            height: 250,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE83A65), Color(0xFFFF8B94)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: -20,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Profile Details Floating Card
          Positioned(
            top: 130,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    user?.fullName ?? "User Name",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textHighContrast,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (user?.phone != null && user!.phone!.isNotEmpty) 
                        ? '+62 ${user.phone}' 
                        : (user?.email ?? "user@example.com"),
                    style: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPink.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded, size: 16, color: AppTheme.primaryPink),
                            const SizedBox(width: 4),
                            Text(
                              "Elite Member",
                              style: GoogleFonts.inter(
                                color: AppTheme.primaryPink,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: user?.isVerified == true ? AppTheme.success.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              user?.isVerified == true ? Icons.verified_rounded : Icons.pending_rounded,
                              size: 16,
                              color: user?.isVerified == true ? AppTheme.success : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user?.isVerified == true ? "Verified" : "Unverified",
                              style: GoogleFonts.inter(
                                color: user?.isVerified == true ? AppTheme.success : Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Center Avatar (Overlapping Card)
          Positioned(
            top: 80,
            child: GestureDetector(
              onTap: () => _navigateToEditProfile(context, user),
              child: Hero(
                tag: 'profile-avatar',
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPink.withOpacity(0.3),
                            blurRadius: 16,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: AppTheme.fuchsiaLight,
                        backgroundImage: user?.avatarUrl != null ? NetworkImage(user.avatarUrl) : null,
                        child: user?.avatarUrl == null
                            ? const Icon(Icons.person_rounded, size: 45, color: AppTheme.primaryPink)
                            : null,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.card, width: 2),
                      ),
                      child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Header Actions
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20, top: 10),
                child: IconButton(
                  onPressed: () => _navigateToSettings(context),
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreativeStats(dynamic user) {
    final stats = user?.stats ?? {};
    final totalBookings = (stats['totalBookings'] ?? 0).toString();
    final ongoing = (stats['ongoingBookings'] ?? 0).toString();
    
    return Row(
      children: [
        Expanded(
          child: _creativeStatBox(
            title: "Total Perjalanan",
            value: totalBookings,
            icon: Icons.route_rounded,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _creativeStatBox(
            title: "Sedang Berjalan",
            value: ongoing,
            icon: Icons.motorcycle_rounded,
            color: Colors.pink,
          ),
        ),
      ],
    );
  }

  Widget _creativeStatBox({required String title, required String value, required IconData icon, required MaterialColor color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color.shade400, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textHighContrast,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreativeMenuSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _creativeMenuTile(
    BuildContext context, 
    IconData icon, 
    String title, 
    Color iconColor, {
    String? badge, 
    bool isLogout = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLogout ? AppTheme.danger.withOpacity(0.1) : iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon, 
                  color: isLogout ? AppTheme.danger : iconColor, 
                  size: 22
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title, 
                  style: GoogleFonts.plusJakartaSans(
                    color: isLogout ? AppTheme.danger : AppTheme.textHighContrast, 
                    fontSize: 15, 
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge, 
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (badge == null && !isLogout)
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatJoinDate(DateTime? date) {
    if (date == null) return "2024";
    return "${date.year}";
  }

  void _showAvatarOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.fuchsiaLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_camera_rounded, color: AppTheme.primaryPink, size: 20),
                ),
                title: Text("Take a photo", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.camera, context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.fuchsiaLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryPink, size: 20),
                ),
                title: Text("Choose from gallery", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.gallery, context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_rounded, color: AppTheme.danger, size: 20),
                ),
                title: Text("Remove photo", style: GoogleFonts.inter(color: AppTheme.danger, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteAvatar(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        if (kIsWeb) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Upload foto via web belum mendukung file sistem lokal.')),
            );
          }
          return;
        }
        final File imageFile = File(image.path);
        await _uploadAvatar(imageFile, context);
      }
    } catch (e) {
      print('Error picking image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e')),
        );
      }
    }
  }

  Future<void> _uploadAvatar(File imageFile, BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryPink),
      ),
    );
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.uploadAvatar(imageFile);
      
      if (context.mounted) {
        Navigator.pop(context);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto profil berhasil diupdate')),
          );
          _refreshProfile();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authProvider.errorMessage ?? 'Gagal upload foto')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteAvatar(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus Foto', style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus foto profil?', style: GoogleFonts.inter(color: AppTheme.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final success = await authProvider.deleteAvatar();
              
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Foto profil berhasil dihapus')),
                  );
                  _refreshProfile();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(authProvider.errorMessage ?? 'Gagal hapus foto')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Hapus', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigateToBookingHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BookingHistoryPage(),
      ),
    );
  }

  void _navigateToPaymentMethods(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaymentMethodsPage(),
      ),
    );
  }

  void _navigateToRewards(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RewardsPage(),
      ),
    );
  }

  void _navigateToHelpCenter(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpCenterPage(),
      ),
    );
  }

  void _navigateToNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsPage(),
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }

  void _shareApp(BuildContext context) {
    print('Share app');
  }

  void _navigateToAbout(BuildContext context) {
    print('Navigate to About');
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Konfirmasi Logout",
            style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Apakah kamu yakin ingin keluar?",
            style: GoogleFonts.inter(color: AppTheme.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Batal",
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w500),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await authProvider.logout();
                
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                "Logout",
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}