import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../data/models/booking_model.dart';
import 'active_booking_screen.dart';
import 'chat_list_screen.dart';
import 'earnings_screen.dart';
import 'profile_screen.dart';
import 'driver_negotiation_screen.dart';
import 'open_offers_screen.dart';
import 'driver_community_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _currentIndex = 0;
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    // Fetch initial profile and subscribe to realtime orders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final booking = Provider.of<BookingProvider>(context, listen: false);

      auth.refreshProfile().then((_) {
        final driverId = auth.driverProfileData?['id']?.toString() ?? 
                         auth.user?.id ?? 
                         Supabase.instance.client.auth.currentUser?.id ?? 
                         'active-driver';
        booking.subscribeToBookings(driverId, userId: auth.user?.id);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final booking = context.watch<BookingProvider>();

    // List of screens to display in bottom navigation
    final List<Widget> screens = [
      _buildDashboard(auth, booking),
      const DriverCommunityScreen(),
      const DriverChatListScreen(),
      const DriverEarningsScreen(),
      const DriverProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          screens[_currentIndex],
          if (booking.activeBannerNotification != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopNotificationBanner(booking),
            ),
        ],
      ),
      bottomNavigationBar: _buildModernBottomNavBar(),
    );
  }

  Widget _buildTopNotificationBanner(BookingProvider booking) {
    final notif = booking.activeBannerNotification;
    if (notif == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(20),
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F1D2B), Color(0xFF2C1625)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryPink, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPink.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryPink, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.title,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notif.message,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final targetBooking = notif.booking ?? booking.incomingBooking;
                    booking.dismissBannerNotification();
                    if (targetBooking != null) {
                      _showIncomingRequestDialog(targetBooking);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const OpenOffersScreen()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    "Terima",
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                  padding: const EdgeInsets.only(left: 4),
                  constraints: const BoxConstraints(),
                  onPressed: () => booking.dismissBannerNotification(),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: -1.0, end: 0.0, duration: 300.ms, curve: Curves.easeOutBack);
  }

  // ============================================================
  // SLEEK MODERN BOTTOM NAVIGATION BAR (Matching Reference Style)
  // ============================================================
  Widget _buildModernBottomNavBar() {
    final navItems = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.explore_rounded, 'label': 'Komunitas'},
      {'icon': Icons.chat_bubble_rounded, 'label': 'Chat'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'Pendapatan'},
      {'icon': Icons.person_rounded, 'label': 'Profil'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black, // Changed to black
        border: Border(
          top: BorderSide(
            color: AppTheme.border,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(navItems.length, (index) {
            final isSelected = _currentIndex == index;
            final item = navItems[index];

            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = index;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Container( // Changed from AnimatedContainer to Container to remove delay
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryPink.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      color: isSelected ? AppTheme.primaryPink : AppTheme.textMuted,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['label'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppTheme.primaryPink : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ============================================================
  // DASHBOARD MAIN VIEW (Screen 1 Design Reference)
  // ============================================================
  Widget _buildDashboard(AuthProvider auth, BookingProvider booking) {
    final name = auth.user?.fullName ?? 'Driver';
    final vehicle = auth.driverProfileData?['vehicle_name'] ?? 'Unit Kendaraan';
    final plate = auth.driverProfileData?['plate_number'] ?? 'B 1234 DS';
    final rating = (auth.driverProfileData?['rating'] != null)
        ? (auth.driverProfileData!['rating'] as num).toDouble()
        : 5.0;
    final totalRides = auth.driverProfileData?['total_rides'] ?? 0;

    String formatCurrency(double amount) {
      return "Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======================================================
          // 1. TOP HERO SECTION (Vibrant Pink Fuchsia Gradient)
          // ======================================================
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppTheme.heroGradient,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(36),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x40FF2E93),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- TOP HEADER BAR: Profile, Vehicle Info, Rating, Notif ---
                    Row(
                      children: [
                        // Avatar with clean white container
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 8,
                              )
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: AppTheme.cardDeep,
                            backgroundImage: NetworkImage(
                              (auth.user?.avatarUrl != null &&
                                      auth.user!.avatarUrl!.isNotEmpty &&
                                      !auth.user!.avatarUrl!.contains('dummy'))
                                  ? _resolveImageUrl(auth.user!.avatarUrl!)
                                  : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=D64573&color=fff&bold=true',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Greeting & Vehicle plate
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Halo, $name! 👋",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$vehicle • $plate",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Rating Badge (Clean White Pill)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textHighContrast,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Notification Bell (Clean White Button)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const OpenOffersScreen()),
                            );
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                )
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(
                                  Icons.notifications_none_rounded,
                                  color: AppTheme.textHighContrast,
                                  size: 20,
                                ),
                                if (booking.unreadNotificationsCount > 0)
                                  Positioned(
                                    top: -3,
                                    right: -3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryPink,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: Text(
                                        "${booking.unreadNotificationsCount}",
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // --- 2x2 HIGH CONTRAST ACTION CARDS ---
                    Row(
                      children: [
                        // Card 1: Status Online / Offline
                        Expanded(
                          child: _buildHeroCard(
                            title: "Status Kerja",
                            subtitle: auth.isAvailable ? "ONLINE" : "OFFLINE",
                            badgeText: auth.isAvailable ? "SIAP KERJA" : "OFFLINE",
                            badgeColor: auth.isAvailable ? AppTheme.success : Colors.redAccent,
                            icon: Icons.power_settings_new_rounded,
                            iconColor: auth.isAvailable ? AppTheme.success : AppTheme.textMuted,
                            hasSwitch: true,
                            switchValue: auth.isAvailable,
                            onSwitchChanged: (val) async {
                              final success = await auth.toggleAvailability();
                              if (success && mounted) {
                                final driverId = auth.driverProfileData?['id']?.toString() ?? 
                                                 auth.user?.id ?? 
                                                 Supabase.instance.client.auth.currentUser?.id ?? 
                                                 'active-driver';
                                booking.subscribeToBookings(driverId, userId: auth.user?.id);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Card 2: Tawaran & Permintaan
                        Expanded(
                          child: _buildHeroCard(
                            title: "Tawaran Terbuka",
                            subtitle: "Custom Bids",
                            badgeText: "PROMO",
                            badgeColor: const Color(0xFFFF9E79),
                            icon: Icons.local_offer_rounded,
                            iconColor: const Color(0xFFFF9E79),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const OpenOffersScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // Card 3: Saldo & Dompet
                        Expanded(
                          child: _buildHeroCard(
                            title: "Saldo Dompet",
                            subtitle: formatCurrency(auth.user?.balance ?? 0.0),
                            badgeText: "TARIK DANA",
                            badgeColor: const Color(0xFF8B5CF6),
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            onTap: () {
                              setState(() {
                                _currentIndex = 3; // Switch to Earnings/Wallet Tab
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Card 4: Riwayat & Komunitas
                        Expanded(
                          child: _buildHeroCard(
                            title: "Total Perjalanan",
                            subtitle: "$totalRides Selesai",
                            badgeText: "COMMUNITY",
                            badgeColor: AppTheme.primaryPink,
                            icon: Icons.two_wheeler_rounded,
                            iconColor: AppTheme.primaryPink,
                            onTap: () {
                              setState(() {
                                _currentIndex = 1; // Switch to Community Tab
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ======================================================
          // 2. BOTTOM SECTION (Deep Charcoal/Black Void)
          // ======================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- PILL SEARCH / ROUTE FILTER BAR (Matching Reference Style) ---
                _buildSearchAndFilterPill(),

                const SizedBox(height: 24),

                // --- ACTIVE ORDER (IF ANY) OR STANDBY RADAR ---
                if (booking.activeBooking != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "ORDER PENDAMPINGAN AKTIF",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primaryPink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "BERLANGSUNG",
                              style: GoogleFonts.inter(
                                color: const Color(0xFF10B981),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildActiveBookingCard(booking.activeBooking!),
                  const SizedBox(height: 28),
                ] else ...[
                  _buildStandbyRadarCard(auth.isAvailable),
                  const SizedBox(height: 26),
                ],

                // --- RECENT / AVAILABLE ROUTES LIST (Screen 1 List Items) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Rute & Permintaan Terkini",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textHighContrast,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OpenOffersScreen()),
                        );
                      },
                      child: Text(
                        "Lihat Semua ➔",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primaryPink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Mock Recent Activities / Available Routes matching reference style
                _buildRouteItemCard(
                  vehicleIcon: Icons.directions_car_rounded,
                  title: "Grand Indonesia • Lobby Shinta",
                  subtitle: "Senopati, Kebayoran Baru • 23 Ags, 19:00",
                  price: "Rp 120.000",
                  statusTag: "SELESAI",
                  isCompleted: true,
                ),
                _buildRouteItemCard(
                  vehicleIcon: Icons.two_wheeler_rounded,
                  title: "Mall Kelapa Gading 3",
                  subtitle: "Pantai Indah Kapuk (PIK) • 20 Ags, 14:30",
                  price: "Rp 145.000",
                  statusTag: "SELESAI",
                  isCompleted: true,
                ),
                _buildRouteItemCard(
                  vehicleIcon: Icons.directions_car_rounded,
                  title: "Stasiun Gambir • Pintu Timur",
                  subtitle: "BSD City, Tangerang Selatan • 18 Ags, 09:15",
                  price: "Rp 210.000",
                  statusTag: "SELESAI",
                  isCompleted: true,
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO 2x2 CARD COMPONENT (Matching Reference Screen 1)
  // ============================================================
  Widget _buildHeroCard({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
    bool hasSwitch = false,
    bool switchValue = false,
    ValueChanged<bool>? onSwitchChanged,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 128,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface, // Clean White Card inside vibrant hero
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Icon + Badge / Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDeep,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (hasSwitch)
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: switchValue,
                      onChanged: onSwitchChanged,
                      activeColor: AppTheme.success,
                      activeTrackColor: AppTheme.success.withOpacity(0.3),
                      inactiveThumbColor: AppTheme.textMuted,
                      inactiveTrackColor: AppTheme.border,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.plusJakartaSans(
                        color: badgeColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),

            // Bottom: Title & Subtitle/Value
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textHighContrast,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PILL SEARCH & TIME SELECTOR BAR (Reference Style)
  // ============================================================
  Widget _buildSearchAndFilterPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Cari rute / penjemputan...",
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.cardDeep,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_rounded, color: AppTheme.primaryPink, size: 14),
                const SizedBox(width: 5),
                Text(
                  "Sekarang",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textHighContrast,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STANDBY RADAR CARD (When no active order)
  // ============================================================
  Widget _buildStandbyRadarCard(bool isOnline) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOnline ? AppTheme.primaryPink.withOpacity(0.3) : AppTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? AppTheme.primaryPink.withOpacity(0.12) : AppTheme.cardDeep,
            ),
            child: Icon(
              isOnline ? Icons.radar_rounded : Icons.pause_circle_outline_rounded,
              color: isOnline ? AppTheme.primaryPink : AppTheme.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? "Radar Penumpang Aktif" : "Status Sedang Offline",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textHighContrast,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isOnline
                      ? "Siap menerima orderan pendampingan terdekat..."
                      : "Aktifkan switch di atas untuk mulai bertugas.",
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ROUTE ITEM CARD (Screen 1 & 2 List Style)
  // ============================================================
  Widget _buildRouteItemCard({
    required IconData vehicleIcon,
    required String title,
    required String subtitle,
    required String price,
    required String statusTag,
    bool isCompleted = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Vehicle Icon Container
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.cardDeep,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(vehicleIcon, color: AppTheme.textHighContrast, size: 20),
          ),
          const SizedBox(width: 12),

          // Route Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textHighContrast,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Price & Chevron Button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.primaryPink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.cardDeep,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMuted,
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIVE BOOKING CARD (Dashboard View)
  // ============================================================
  Widget _buildActiveBookingCard(BookingModel bookingData) {
    final clientName = bookingData.client?.fullName ?? 'Client';
    final service = bookingData.additionalDetails?['serviceType'] ?? 'antar_jemput';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DriverActiveBookingScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primaryPink.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPink.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.cardDeep,
                  backgroundImage: (bookingData.client?.avatarUrl != null && bookingData.client!.avatarUrl!.isNotEmpty)
                      ? NetworkImage(_resolveImageUrl(bookingData.client!.avatarUrl!))
                      : null,
                  child: (bookingData.client?.avatarUrl == null || bookingData.client!.avatarUrl!.isEmpty)
                      ? const Icon(Icons.person, color: AppTheme.textMuted, size: 18)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textHighContrast,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        service == 'antar_jemput'
                            ? 'Layanan Antar Jemput'
                            : (service == 'hangout' ? 'Layanan Hangout' : 'Freedom Request Pendamping'),
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bookingData.status.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primaryPink,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              ],
            ),
            const Divider(color: AppTheme.border, height: 24),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppTheme.primaryPink, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bookingData.pickupLocation,
                    style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.flag_rounded, color: AppTheme.textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bookingData.dropoffLocation,
                    style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Rp ${(bookingData.totalPrice).toStringAsFixed(0)}",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primaryPink,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "LIHAT DETAIL",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primaryPink,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryPink, size: 16),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INCOMING REQUEST ALERT DIALOG (Preserved Logic + Clean Fuchsia)
  // ============================================================
  Future<void> _showIncomingRequestDialog(BookingModel request) {
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final String clientName = request.client?.fullName ?? 'Siti Rahma';
    final String clientPhone = request.client?.phone ?? '+62 812-9876-5432';
    const String bookingDate = 'Minggu, 07 Sep 2026';
    const String bookingTime = '14:00 WIB';

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.primaryPink.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppTheme.primaryPink.withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPink.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryPink, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                "PESANAN BARU MASUK",
                                style: GoogleFonts.inter(
                                  color: AppTheme.primaryPink,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.cardDeep,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: const Text("MENUNGGU RESPON", style: TextStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Customer Profile Card
                    GestureDetector(
                      onTap: () {
                        _showCustomerDetailSummaryModal(context, request);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDeep,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppTheme.border,
                                      backgroundImage: (request.client?.avatarUrl != null && request.client!.avatarUrl!.isNotEmpty)
                                          ? NetworkImage(_resolveImageUrl(request.client!.avatarUrl!))
                                          : const NetworkImage('https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150'),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.blueAccent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 10),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              clientName,
                                              style: GoogleFonts.plusJakartaSans(
                                                color: AppTheme.textHighContrast,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                                                const SizedBox(width: 3),
                                                Text(
                                                  "4.9",
                                                  style: GoogleFonts.inter(
                                                    color: Colors.amber,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        clientPhone,
                                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryPink, size: 20),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(color: AppTheme.border, height: 1),
                            const SizedBox(height: 8),

                            // Reputation & Driver Notes Tags
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildReputationTag("Sopan & Tepat Waktu", Colors.green),
                                _buildReputationTag("Bagus", AppTheme.primaryPink),
                                _buildReputationTag("18 Trip Selesai", Colors.blueAccent),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "💬 \"Klien sangat ramah & penjemputan jelas di lobby apartemen.\" — Driver Bagas P.",
                              style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 11, fontStyle: FontStyle.italic),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                "👆 Klik Foto/Nama untuk Detail Profile & Review Mitra ➔",
                                style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Scheduled Booking Slot Info Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.fuchsiaLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryPink, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "JADWAL BOOKING TERJADWAL",
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textHighContrast,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.event_available_rounded, color: AppTheme.textMuted, size: 14),
                                  const SizedBox(width: 6),
                                  Text("Tanggal:", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                                ],
                              ),
                              Text(bookingDate, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, color: AppTheme.textMuted, size: 14),
                                  const SizedBox(width: 6),
                                  Text("Waktu:", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                                ],
                              ),
                              Text(bookingTime, style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_clock_rounded, color: Colors.amber, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "Persetujuan Anda akan otomatis mengunci slot jam & tanggal ini agar tidak bentrok.",
                                    style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Route Details Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDeep,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: AppTheme.success, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  request.pickupLocation,
                                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.flag_rounded, color: AppTheme.primaryPink, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  request.dropoffLocation,
                                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Total Payment Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Total Est. Pendapatan:", style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 12)),
                        Text(
                          "Rp ${(request.totalPrice).toStringAsFixed(0)}",
                          style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              bookingProvider.rejectBooking(request.id);
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.danger),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text("TOLAK", style: GoogleFonts.plusJakartaSans(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DriverNegotiationScreen(bookingData: request),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.primaryPink),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text("TAWAR", style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryPink.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                final success = await bookingProvider.acceptBooking(request.id);
                                if (success && mounted) {
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const DriverActiveBookingScreen()),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                "SETUJUI & KUNCI ➔",
                                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // CUSTOMER DETAIL MODAL (Preserved)
  // ============================================================
  void _showCustomerDetailSummaryModal(BuildContext context, BookingModel request) {
    final String clientName = request.client?.fullName ?? 'Siti Rahma';
    final String clientPhone = request.client?.phone ?? '+62 812-9876-5432';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: AppTheme.primaryPink.withOpacity(0.4), width: 1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Customer Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppTheme.cardDeep,
                        backgroundImage: (request.client?.avatarUrl != null && request.client!.avatarUrl!.isNotEmpty)
                            ? NetworkImage(_resolveImageUrl(request.client!.avatarUrl!))
                            : const NetworkImage('https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  clientName,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.textHighContrast,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 16),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(clientPhone, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPink.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text("VIP CLIENT • 18 TRIPS", style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 16),

                  // Stats Grid
                  Row(
                    children: [
                      _buildStatBox("⭐ 4.9", "Rating Mitra"),
                      const SizedBox(width: 10),
                      _buildStatBox("18", "Total Order"),
                      const SizedBox(width: 10),
                      _buildStatBox("0%", "Pembatalan"),
                    ],
                  ),

                  const SizedBox(height: 22),

                  Text(
                    "REPUTASI & CATATAN DRIVER LAIN",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textHighContrast,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildDriverNoteCard(
                    driverName: "Bagas Pradana (★ DIAMOND TIER)",
                    date: "26 Ags 2026",
                    riskTag: "Aman & Sopan",
                    riskColor: Colors.green,
                    note: "Klien sangat ramah, komunikatif, dan menunggu tepat di titik jemput lobby apartemen.",
                  ),
                  const SizedBox(height: 10),
                  _buildDriverNoteCard(
                    driverName: "Rayhan Putra (★ GOLD TIER)",
                    date: "14 Ags 2026",
                    riskTag: "Baik & Tepat Waktu",
                    riskColor: Colors.blueAccent,
                    note: "Pembayaran tepat waktu, rute jelas, bersikap sopan dan kooperatif sepanjang jalan.",
                  ),
                  const SizedBox(height: 10),
                  _buildDriverNoteCard(
                    driverName: "Dimas Setiawan (★ PLATINUM TIER)",
                    date: "02 Jul 2026",
                    riskTag: "Waspada",
                    riskColor: Colors.amber,
                    note: "Minta perpanjangan waktu rute secara spontan. Disarankan untuk minta klien input Freedom Request di aplikasi.",
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(modalContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cardDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppTheme.border)),
                      ),
                      child: Text("Tutup Detail Customer", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatBox(String val, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDeep,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Text(val, style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverNoteCard({
    required String driverName,
    required String date,
    required String riskTag,
    required Color riskColor,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(driverName, style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(date, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          _buildReputationTag(riskTag, riskColor),
          const SizedBox(height: 8),
          Text(note, style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildReputationTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _resolveImageUrl(String url) {
    if (url.startsWith('/uploads')) {
      return '${ApiConstants.baseUrl}$url';
    }
    return url;
  }
}

