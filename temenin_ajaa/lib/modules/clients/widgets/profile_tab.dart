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
        print('AuthProvider user: ${authProvider.user}');
        print('Is loading: ${authProvider.isLoading}');
        
        if (authProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFF9DCC),
            ),
          );
        }
        
        if (authProvider.user == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'User not found',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _refreshUserData(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9DCC),
                  ),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        }
        
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildProfileHeader(context, authProvider.user),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildUserInfo(authProvider.user),
                    const SizedBox(height: 24),
                    _buildMembershipCard(),
                    const SizedBox(height: 20),
                    _buildStatsRow(authProvider.user),
                    const SizedBox(height: 24),
                    _buildMenuSection(
                      title: "AKUN",
                      children: [
                        _menuTile(context, Icons.person_outline_rounded, "Edit Profile",
                            onTap: () => _navigateToEditProfile(context, authProvider.user)),
                        _menuTile(context, Icons.history_rounded, "Booking History",
                            badge: "3 ACTIVE",
                            onTap: () => _navigateToBookingHistory(context)),
                        _menuTile(context, Icons.account_balance_wallet_outlined, "Payment Methods",
    onTap: () => _navigateToPaymentMethods(context)),
                        _menuTile(context, Icons.card_giftcard_outlined, "Rewards & Vouchers",
                            onTap: () => _navigateToRewards(context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildMenuSection(
                      title: "PENGATURAN & DUKUNGAN",
                      children: [
                        _menuTile(context, Icons.notifications_outlined, "Notifikasi",
                            onTap: () => _navigateToNotifications(context)),
                        _menuTile(context, Icons.help_outline_rounded, "Help Center",
                            onTap: () => _navigateToHelpCenter(context)),
                        _menuTile(context, Icons.settings_outlined, "Settings & Privacy",
                            onTap: () => _navigateToSettings(context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildMenuSection(
                      title: "LAINNYA",
                      children: [
                        _menuTile(context, Icons.share_outlined, "Bagikan Aplikasi",
                            onTap: () => _shareApp(context)),
                        _menuTile(context, Icons.info_outline, "Tentang Aplikasi",
                            onTap: () => _navigateToAbout(context)),
                        _menuTile(context, Icons.logout_rounded, "Logout",
                            isLogout: true,
                            onTap: () => _showLogoutDialog(context, authProvider)),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, dynamic user) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _showAvatarOptions(context),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPink.withOpacity(0.2),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppTheme.background,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: AppTheme.cardDeep,
                          backgroundImage: user?.avatarUrl != null
                              ? NetworkImage(user.avatarUrl)
                              : null,
                          child: user?.avatarUrl == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 45,
                                  color: AppTheme.textMuted,
                                )
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.surface, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user?.fullName ?? "User Name",
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textHighContrast,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.fuchsiaLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                          ),
                          child: Text(
                            "ELITE",
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryPink,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (user?.phone != null && user!.phone!.isNotEmpty) 
                          ? '+62 ${user.phone}' 
                          : (user?.email ?? "user@example.com"),
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                "Level 42",
                                style: GoogleFonts.inter(
                                  color: Colors.amber.shade800,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Diamond Member",
                          style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 12,
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
    );
  }

  Widget _buildUserInfo(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.fuchsiaLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_today_rounded, size: 20, color: AppTheme.primaryPink),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Bergabung sejak",
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatJoinDate(user?.createdAt),
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: user?.isVerified == true ? AppTheme.success.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  user?.isVerified == true ? Icons.verified_rounded : Icons.pending_rounded, 
                  size: 14, 
                  color: user?.isVerified == true ? AppTheme.success : Colors.orange
                ),
                const SizedBox(width: 6),
                Text(
                  user?.isVerified == true ? "Verified" : "Unverified",
                  style: GoogleFonts.inter(
                    color: user?.isVerified == true ? AppTheme.success : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D1121),
            Color(0xFF6B2142),
            Color(0xFF3B122A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "MEMBERSHIP",
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Diamond",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  Text(
                    "Member",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 75,
                height: 75,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 0.68,
                      strokeWidth: 6,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "68%",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "to next",
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPointsInfo("Points Balance", "2,450", "pts"),
                Container(
                  width: 1,
                  height: 35,
                  color: Colors.white.withOpacity(0.15),
                ),
                _buildPointsInfo("Next Reward", "500", "pts to go"),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: "Top Up",
                  icon: Icons.add_card_rounded,
                  color: AppTheme.primaryPink,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  label: "Upgrade",
                  icon: Icons.trending_up_rounded,
                  color: Colors.white,
                  isOutlined: true,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointsInfo(String label, String value, String unit) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.4), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: const Color(0xFF631841),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    );
  }

  Widget _buildStatsRow(UserModel? user) {
    final stats = user?.stats ?? {};
    
    return Row(
      children: [
        Expanded(child: _buildStatItem(
          (stats['totalBookings'] ?? 0).toString(),
          "Total Bookings", 
          Icons.calendar_month_rounded
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem(
          (stats['ongoingBookings'] ?? 0).toString(),
          "Ongoing", 
          Icons.play_circle_fill_rounded, 
          isHighlight: true
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem(
          (stats['completedBookings'] ?? 0).toString(),
          "Completed", 
          Icons.check_circle_rounded
        )),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlight ? AppTheme.primaryPink.withOpacity(0.3) : AppTheme.border,
          width: isHighlight ? 1.5 : 1.0,
        ),
        boxShadow: isHighlight ? [
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 0,
          )
        ] : null,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighlight ? AppTheme.primaryPink.withOpacity(0.12) : AppTheme.cardDeep,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon, 
              color: isHighlight ? AppTheme.primaryPink : AppTheme.textMuted, 
              size: 20
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value, 
            style: GoogleFonts.plusJakartaSans(
              color: isHighlight ? AppTheme.primaryPink : AppTheme.textHighContrast, 
              fontSize: 22, 
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label, 
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppTheme.textMuted, 
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _menuTile(
    BuildContext context, 
    IconData icon, 
    String title, {
    String? badge, 
    bool isLogout = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {
          print('Navigate to $title');
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isLogout ? AppTheme.danger.withOpacity(0.12) : AppTheme.fuchsiaLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon, 
                  color: isLogout ? AppTheme.danger : AppTheme.primaryPink, 
                  size: 20
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                  ),
                  child: Text(
                    badge, 
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryPink,
                      fontSize: 10, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
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