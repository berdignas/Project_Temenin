import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/providers/auth_provider.dart';
import 'package:temenin_ajaa/providers/driver_provider.dart';
import 'package:temenin_ajaa/providers/client_booking_provider.dart';
import 'package:temenin_ajaa/providers/client_notification_provider.dart';
import 'package:temenin_ajaa/data/models/user_model.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/modules/clients/screens/profile_completion_screen.dart';
import 'package:temenin_ajaa/modules/clients/widgets/profile_tab.dart';
import 'package:temenin_ajaa/modules/clients/driver/screens/partner_list_screen.dart';
import 'package:temenin_ajaa/modules/clients/pages/booking_history_page.dart';
import 'package:temenin_ajaa/modules/clients/chat/screens/chat_list_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/booking_type_selector_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/virtual_call_booking_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/sleep_call_booking_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/gaming_buddy_booking_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/call_lobby_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/call_room_screen.dart';
import 'package:temenin_ajaa/core/utils/booking_date_helper.dart';
import 'package:temenin_ajaa/modules/clients/pages/notifications_page.dart';
import 'package:temenin_ajaa/modules/clients/pages/rewards_page.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/antar_jemput_booking_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/hangout_booking_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/freedom_request_booking_screen.dart';
import 'package:temenin_ajaa/core/services/reward_service.dart';
import 'package:temenin_ajaa/modules/clients/community/screens/community_feed_screen.dart';
import 'package:temenin_ajaa/modules/clients/matching/screens/smart_match_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/tracking_driver_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/client_waiting_countdown_screen.dart';
import 'package:temenin_ajaa/modules/clients/driver/screens/partner_profile_screen.dart';
import 'package:temenin_ajaa/modules/clients/pages/help_center_page.dart';
import 'package:temenin_ajaa/modules/clients/events/screens/event_detail_screen.dart';
import 'package:temenin_ajaa/core/services/location_service.dart';

// ============================================================
// 02 - Color System (Clean Modern Fuchsia + Putih + Abu-abu Terang)
// ============================================================
class AppColors {
  // Core Palette - Clean Fuchsia Light Mode
  static const Color deepVoid = Color(0xFFFAFAFA);     // Clean Light Background
  static const Color obsidian = Color(0xFFFFFFFF);     // White Card Surface
  static const Color elevatedDark = Color(0xFFF5EBF2); // Soft Blush Container
  static const Color electricPink = Color(0xFFEC4899); // Fuchsia Primary
  static const Color roseGold = Color(0xFFDB2777);     // Deep Fuchsia Secondary

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Text
  static const Color textMain = Color(0xFF1E1B2E); // Deep Plum
  static const Color textMuted = Color(0xFF9B8A9D); // Muted Plum

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [electricPink, Color(0xFFDB2777)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1AEC4899), Color(0x0DEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [
      Color(0xFFFAFAFA),
      Color(0xFFFDF2F8),
      Color(0xFFFAFAFA),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// ============================================================
// DATA MODELS
// ============================================================

class Driver {
  final String id;
  final String name;
  final String imageUrl;
  final double rating;
  final String driverClass; // Bronze, Silver, Gold, Platinum, Diamond, VVIP
  final bool isAvailable;
  final String vehicleType;
  final String plateNumber;
  final int reviewCount;

  Driver({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.rating,
    required this.driverClass,
    this.isAvailable = true,
    required this.vehicleType,
    required this.plateNumber,
    this.reviewCount = 0,
  });
}

class ActiveBooking {
  final String id;
  final String driverName;
  final String driverImage;
  final double driverRating;
  final String driverClass;
  final String serviceType; // Antar Jemput, Hangout, Freedom Request
  final String status; // On The Way, Arrived, In Progress
  final String estimatedArrival;
  final String pickup;
  final String destination;
  final int totalPayment;
  final int dp;
  final int remainingPayment;

  ActiveBooking({
    required this.id,
    required this.driverName,
    required this.driverImage,
    required this.driverRating,
    required this.driverClass,
    required this.serviceType,
    required this.status,
    required this.estimatedArrival,
    required this.pickup,
    required this.destination,
    required this.totalPayment,
    required this.dp,
    required this.remainingPayment,
  });
}

class Review {
  final String name;
  final String comment;
  final double rating;
  final String date;

  Review({
    required this.name,
    required this.comment,
    required this.rating,
    required this.date,
  });
}

// ============================================================
// MAIN HOME SCREEN
// ============================================================

class HomeLoggedInScreen extends StatefulWidget {
  const HomeLoggedInScreen({super.key});

  @override
  State<HomeLoggedInScreen> createState() => _HomeLoggedInScreenState();
}

class _HomeLoggedInScreenState extends State<HomeLoggedInScreen> {
  int _selectedIndex = 0;
  final bool _isBookingActive = true; // Set to true by default for simulation

  final List<Widget> _pages = [
    const HomeContent(),
    const CommunityFeedScreen(),
    const BookingHistoryPage(),
    const ChatListScreen(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    // Otomatis cek apakah GPS/Lokasi menyala saat membuka halaman utama
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        LocationService.checkAndPromptLocation(context);
      }
    });
  }



  void _showSOSDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.obsidian,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.gpp_maybe_rounded, color: AppColors.danger, size: 28),
              const SizedBox(width: 10),
              Text(
                'DARURAT (SOS)',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apakah Anda merasa tidak aman atau mengalami keadaan darurat?',
                style: GoogleFonts.inter(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sistem akan mengirimkan sinyal darurat beserta lokasi koordinat GPS Anda ke Security Command Center Temenin Ajaa dan pihak berwajib.',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          actions: [
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sinyal SOS Terkirim! Bantuan sedang menuju lokasi Anda.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.security, color: Colors.white),
                    label: const Text('KIRIM SINYAL SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.elevatedDark),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Batal',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepVoid,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: null,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
        border: const Border(
          top: BorderSide(
            color: AppColors.elevatedDark,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Beranda', 0),
              _buildNavItem(Icons.explore_rounded, 'Komunitas', 1),
              _buildNavItem(Icons.assignment_rounded, 'Aktivitas', 2),
              _buildNavItem(Icons.chat_bubble_rounded, 'Chat', 3),
              _buildNavItem(Icons.person_rounded, 'Profil', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: isSelected ? BoxDecoration(
          color: AppColors.electricPink.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.electricPink : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: isSelected ? AppColors.electricPink : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HOME CONTENT
// ============================================================

class _PartnerData {
  final String id;
  final String name;
  final String imageUrl;
  final double rating;
  final List<String> tags;
  final String distance;
  final String price;
  final String vehicle;
  final String vehicleStnk;
  final String tier;
  final int priceVal;

  _PartnerData({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.rating,
    required this.tags,
    required this.distance,
    required this.price,
    required this.vehicle,
    required this.vehicleStnk,
    required this.tier,
    required this.priceVal,
  });
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  double _searchRadius = 5.0;
  String _selectedCategory = 'all';
  final RewardService _rewardService = RewardService();
  int _totalPoints = 0;
  String _currentTier = 'Bronze';
  bool _isLoadingPoints = true;

  bool _hasCheckedVerification = false;

  List<Map<String, dynamic>> _promos = [
    {
      'id': 'pr-1',
      'title': 'WEEKEND PROMO',
      'subtitle': 'Diskon 20% Freedom Request Malam Ini!',
      'description': 'Gunakan promo ini untuk menikmati layanan Freedom Request dengan harga lebih hemat di akhir pekan! Cukup gunakan kode: WEEKEND20 saat pembayaran.',
      'banner_url': 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=600&q=80',
      'is_active': true,
    }
  ];

  List<Map<String, dynamic>> _events = [
    {
      'id': 'ev-1',
      'title': 'We The Fest 2026',
      'date_string': '14-16 Ags 2026',
      'location': 'GBK Sports Complex, Jaksel',
      'image_url': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=600&auto=format&fit=crop',
      'ticket_url': 'https://wethefest.com',
      'category': 'Festival Musik',
      'description': 'Festival musik musim panas terbesar di Jakarta menghadirkan musisi internasional dan lokal terbaik.',
      'is_active': true,
    },
    {
      'id': 'ev-2',
      'title': 'Java Jazz Festival',
      'date_string': '28-30 Nov 2026',
      'location': 'JIExpo Kemayoran, Jakpus',
      'image_url': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?q=80&w=600&auto=format&fit=crop',
      'ticket_url': 'https://javajazzfestival.com',
      'category': 'Konser Musik',
      'description': 'Rasakan alunan jazz spektakuler dari musisi legendaris dalam dan luar negeri.',
      'is_active': true,
    },
    {
      'id': 'ev-3',
      'title': 'Indonesia Comic Con',
      'date_string': '23-25 Des 2026',
      'location': 'JCC Senayan, Jaksel',
      'image_url': 'https://images.unsplash.com/photo-1563089145-599997674d42?q=80&w=600&auto=format&fit=crop',
      'ticket_url': 'https://indonesiacomiccon.com',
      'category': 'Pameran & Pop Culture',
      'description': 'Ajang kumpul komunitas pecinta anime, cosplay, game, dan komik terbesar di Indonesia.',
      'is_active': true,
    },
  ];

  bool _isLoadingPromosEvents = false;
  List<Map<String, dynamic>> _communityReviews = [];

  @override
  void initState() {
    super.initState();
    _loadUserPoints();
    _fetchPromosAndEvents();
    _fetchCommunityReviews();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowVerificationPopup();
      try {
        context.read<DriverProvider>().fetchDrivers();
        context.read<DriverProvider>().subscribeToDriversRealtime();
      } catch (_) {}

      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        try {
          context.read<ClientBookingProvider>().subscribeToClientBookings(authProvider.user!.id);
          context.read<ClientNotificationProvider>().subscribeToNotifications(authProvider.user!.id);
        } catch (_) {}
      }
    });
  }

  Future<void> _fetchPromosAndEvents() async {
    try {
      final supabase = Supabase.instance.client;
      final promosRes = await supabase
          .from('app_promos')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final eventsRes = await supabase
          .from('app_events')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          if (promosRes is List && promosRes.isNotEmpty) {
            _promos = List<Map<String, dynamic>>.from(promosRes);
          }
          if (eventsRes is List && eventsRes.isNotEmpty) {
            _events = List<Map<String, dynamic>>.from(eventsRes);
          }
          _isLoadingPromosEvents = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching promos/events from Supabase: $e');
      if (mounted) {
        setState(() {
          _isLoadingPromosEvents = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _checkAndShowVerificationPopup() {
    if (_hasCheckedVerification) return;
    _hasCheckedVerification = true;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (authProvider.isLoggedIn && user != null) {
      final isMockEmail = user.email.endsWith('@temenin.aja');
      if (!user.isVerified || isMockEmail) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileCompletionScreen(user: user)),
        );
      }
    }
  }

  Future<void> _loadUserPoints() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isLoggedIn && authProvider.user != null) {
        final pointsResult = await _rewardService.getUserPoints(authProvider.user!.id);
        if (pointsResult['success'] == true && mounted) {
          setState(() {
            _totalPoints = pointsResult['points'];
            _updateTier();
            _isLoadingPoints = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading points: $e');
      if (mounted) {
        setState(() {
          _isLoadingPoints = false;
        });
      }
    }
  }

  Future<void> _fetchCommunityReviews() async {
    try {
      final List<dynamic> rows = await Supabase.instance.client
          .from('reviews')
          .select('*, users(full_name, avatar_url)')
          .order('created_at', ascending: false)
          .limit(10);

      if (rows.isNotEmpty && mounted) {
        setState(() {
          _communityReviews = rows.map((r) {
            final u = r['users'] ?? {};
            final author = u['full_name']?.toString().trim();
            final comment = r['comment']?.toString().trim() ?? '';
            return {
              'name': (author != null && author.isNotEmpty) ? author : 'Pelanggan',
              'role': 'Verified Review',
              'comment': comment,
              'rating': double.tryParse(r['rating']?.toString() ?? '5.0')?.toStringAsFixed(1) ?? '5.0',
              'avatar': u['avatar_url']?.toString() ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching community reviews: $e');
    }
  }

  void _updateTier() {
    if (_totalPoints >= 30000) {
      _currentTier = 'Diamond';
    } else if (_totalPoints >= 15000) {
      _currentTier = 'Platinum';
    } else if (_totalPoints >= 5000) {
      _currentTier = 'Gold';
    } else if (_totalPoints >= 1000) {
      _currentTier = 'Silver';
    } else {
      _currentTier = 'Bronze';
    }
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      return 'Selamat pagi 👋';
    } else if (hour < 15) {
      return 'Selamat siang 👋';
    } else if (hour < 19) {
      return 'Selamat sore 👋';
    } else {
      return 'Selamat malam 👋';
    }
  }



  void _showBookingModal(BuildContext context, String partnerName, double rating) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$partnerName (⭐ $rating)',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pilih jenis layanan yang ingin Anda pesan:',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              // 1. Ride Service Option
              _buildModalOption(
                context,
                icon: Icons.local_taxi_rounded,
                title: '🚕 Ride Service',
                subtitle: 'Diantar perjalanan aman & nyaman',
                color: AppColors.electricPink,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AntarJemputBookingScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              // 2. Hangout Service Option
              _buildModalOption(
                context,
                icon: Icons.wine_bar_rounded,
                title: '🍸 Hangout Service',
                subtitle: 'Teman nongkrong di cafe/restoran',
                color: AppColors.roseGold,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HangoutBookingScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              // 3. Freedom Request Option
              _buildModalOption(
                context,
                icon: Icons.explore_rounded,
                title: '✨ Freedom Request (Negosiasi)',
                subtitle: 'Tentukan acara & tawar harga sendiri',
                color: const Color(0xFFFF8552),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FreedomRequestBookingScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.elevatedDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Tutup Modal',
                    style: GoogleFonts.inter(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF2F8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0E4EC)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              title.contains('Freedom') ? 'Tawar' : 'Pilih',
              style: GoogleFonts.inter(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isLoggedIn = authProvider.isLoggedIn;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.darkBgGradient,
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => await authProvider.refreshUser(),
          color: AppColors.electricPink,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: AppColors.deepVoid,
                elevation: 0,
                floating: true,
                pinned: false,
                snap: true,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _buildHeader(context, user, isLoggedIn),
                  ),
                ),
                expandedHeight: 84, // Perbesar tinggi header navigasi atas
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 20),
                    _buildWalletCard(context, user),
                    const SizedBox(height: 16),
                    _buildActiveBookingCardForClient(context),
                    const SizedBox(height: 20),
                    _buildPromoBanner(),
                    const SizedBox(height: 20),
                    _buildPopularEventsSection(),
                    const SizedBox(height: 20),
                    _buildSmartMatchingCard(context),
                    const SizedBox(height: 24),
                    _buildCategoriesGrid(),
                    const SizedBox(height: 20),
                    _buildPartnerFeedHeader(),
                    const SizedBox(height: 16),
                    _buildPartnerList(),
                    const SizedBox(height: 28),
                    _buildSafetyTrustBanner(),
                    const SizedBox(height: 24),
                    _buildCommunityHighlightsSection(),
                    const SizedBox(height: 24),
                    _buildQuickHelpFooter(),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveBookingCardForClient(BuildContext context) {
    final clientBooking = context.watch<ClientBookingProvider>().currentBooking;
    if (clientBooking == null) return const SizedBox.shrink();

    final status = clientBooking['status']?.toString().toLowerCase() ?? 'pending';
    final activeStatuses = ['pending', 'accepted', 'confirmed', 'on_the_way', 'arrived', 'started', 'ongoing', 'in_progress', 'dp_paid'];
    if (!activeStatuses.contains(status)) return const SizedBox.shrink();

    // Check if completed/paid
    final add = clientBooking['additional_details'] is Map
        ? clientBooking['additional_details'] as Map
        : (clientBooking['additionalDetails'] is Map ? clientBooking['additionalDetails'] as Map : null);
    final sub = add?['sub_status']?.toString().toLowerCase();
    if (status == 'completed' || status == 'paid' || status == 'selesai' || sub == 'completed' || sub == 'paid' || sub == 'selesai' || add?['pelunasan_paid'] == true || add?['has_reviewed'] == true || add?['review'] != null || add?['payment_status'] == 'LUNAS') {
      return const SizedBox.shrink();
    }

    // Check if scheduled for a future date
    final now = DateTime.now();
    final scheduledDt = BookingDateHelper.extractScheduledDateTime(clientBooking);
    final isFutureSchedule = scheduledDt != null && 
        (scheduledDt.year > now.year ||
         (scheduledDt.year == now.year && scheduledDt.month > now.month) ||
         (scheduledDt.year == now.year && scheduledDt.month == now.month && scheduledDt.day > now.day));

    final bookingId = clientBooking['id']?.toString() ?? '';
    final driver = clientBooking['driver'] as Map<String, dynamic>?;
    final pickup = clientBooking['pickup_location'] ?? clientBooking['pickup'] ?? 'Lokasi Penjemputan';
    final destination = clientBooking['dropoff_location'] ?? clientBooking['destination'] ?? 'Lokasi Tujuan';

    final hasAssignedPartner = driver != null || 
                               clientBooking['driver_id'] != null || 
                               (clientBooking['driverName'] != null && 
                                !clientBooking['driverName'].toString().toLowerCase().contains('radar') &&
                                !clientBooking['driverName'].toString().toLowerCase().contains('open bid'));

    final isDpPaid = status == 'dp_paid' || add?['dp_paid'] == true || sub == 'dp_paid';

    String headerLabel = "PESANAN AKTIF";
    String statusText = 'Pesanan Sedang Diproses';
    Color statusColor = AppTheme.primaryPink;

    if (isFutureSchedule && isDpPaid) {
      final schedDisplay = BookingDateHelper.getScheduleDisplay(clientBooking);
      headerLabel = "JADWAL RESERVASI MENDATANG";
      statusText = "Jadwal Terkonfirmasi: $schedDisplay";
      statusColor = const Color(0xFF00FF7F);
    } else {
      switch (status) {
        case 'pending':
          headerLabel = "MENUNGGU RESPON";
          statusText = hasAssignedPartner 
              ? 'Menunggu Konfirmasi Partner... ⏳' 
              : 'Mencari Partner Terdekat... 📡';
          statusColor = const Color(0xFFF59E0B);
          break;
        case 'accepted':
          headerLabel = "MENUNGGU PEMBAYARAN DP";
          statusText = 'Partner Menyetujui! Silakan Bayar DP';
          statusColor = const Color(0xFFF59E0B);
          break;
        case 'confirmed':
        case 'dp_paid':
          headerLabel = "DP TERBAYAR • JADWAL AMAN";
          statusText = 'Partner Mengonfirmasi Pesanan ✔';
          statusColor = const Color(0xFF00FF7F);
          break;
        case 'on_the_way':
          headerLabel = "DRIVER MENUJU LOKASI";
          statusText = 'Driver Sedang Menuju Ke Lokasi Anda 🛵';
          statusColor = const Color(0xFF00E5FF);
          break;
        case 'arrived':
          headerLabel = "DRIVER TELAH TIBA";
          statusText = 'Driver Sudah Sampai Di Lokasi Penjemputan 📍';
          statusColor = const Color(0xFF00FF7F);
          break;
        case 'started':
        case 'ongoing':
        case 'in_progress':
          headerLabel = "PESANAN BERLANGSUNG";
          statusText = 'Perjalanan / Layanan Sedang Berlangsung ✨';
          statusColor = const Color(0xFF9D6BFF);
          break;
      }
    }

    final sTypeLower = (clientBooking['serviceType'] ?? clientBooking['service_type'] ?? add?['service_type'] ?? add?['serviceType'] ?? '').toString().toLowerCase();
    IconData cardIcon = Icons.directions_car_rounded;
    if (sTypeLower.contains('hangout')) {
      cardIcon = Icons.local_cafe_rounded;
    } else if (sTypeLower.contains('game') || sTypeLower.contains('gaming') || sTypeLower.contains('mabar')) {
      cardIcon = Icons.sports_esports_rounded;
    } else if (sTypeLower.contains('sleep')) {
      cardIcon = Icons.bedtime_rounded;
    } else if (sTypeLower.contains('curhat') || sTypeLower.contains('counseling')) {
      cardIcon = Icons.psychology_rounded;
    }

    return GestureDetector(
      onTap: () {
        final st = clientBooking['status']?.toString().toLowerCase();
        final sType = (clientBooking['serviceType'] ?? clientBooking['service_type'] ?? add?['service_type'] ?? add?['serviceType'] ?? '').toString().toLowerCase();
        final isVirtual = clientBooking['service_category'] == 'VIRTUAL' ||
                          clientBooking['is_virtual'] == true ||
                          add?['service_category'] == 'VIRTUAL' ||
                          add?['is_virtual'] == true ||
                          sType.contains('gaming') ||
                          sType.contains('mabar') ||
                          sType.contains('sleep') ||
                          sType.contains('telepon') ||
                          sType.contains('curhat') ||
                          sType.contains('counseling') ||
                          sType.contains('virtual');

        // ROUTE 1: LAYANAN VIRTUAL (Gaming Buddy, Sleep Call, Telepon Curhat)
        if (isVirtual) {
          final isOngoing = st == 'ongoing' || st == 'started' || st == 'in_progress' || sub == 'ongoing' || sub == 'started';
          final partner = clientBooking['driver'] as Map<String, dynamic>? ?? add?['driver'] as Map<String, dynamic>?;
          final partnerName = partner?['name'] ?? partner?['fullName'] ?? clientBooking['driverName'] ?? add?['driverName'] ?? 'Mitra Gamer';
          final durationMins = clientBooking['call_duration_minutes'] ?? clientBooking['duration'] ?? add?['duration'] ?? 60;
          final isSleep = sType.contains('sleep');
          final topic = clientBooking['chat_topic'] ?? add?['chat_topic'] ?? add?['game_name'] ?? 'Mabar & Voice Chat';

          if (isOngoing) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CallRoomScreen(
                  partnerName: partnerName.toString(),
                  serviceType: clientBooking['serviceType']?.toString() ?? add?['serviceType']?.toString() ?? (sType.contains('gaming') ? 'Gaming Buddy (Mabar)' : 'Pendampingan Virtual'),
                  durationMinutes: (durationMins is num) ? durationMins.toInt() : 60,
                  isSleepCall: isSleep,
                  topicOrAlarm: topic.toString(),
                  bookingId: bookingId,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CallLobbyScreen(
                  bookingDetails: clientBooking,
                  bookingId: bookingId,
                ),
              ),
            );
          }
          return;
        }

        // ROUTE 2: LAYANAN OFFLINE (Tatap Muka & Perjalanan)
        final isCountdownEnded = add?['countdown_ended'] == true;
        final isWaiting = (st == 'accepted' || st == 'dp_paid' || sub == 'dp_paid' || (sub == null && st != 'on_the_way' && st != 'arrived' && st != 'started' && st != 'ongoing' && st != 'completed' && st != 'paid'));

        if (isWaiting && !isCountdownEnded) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientWaitingCountdownScreen(
                bookingId: bookingId,
                bookingData: clientBooking,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrackingDriverScreen(
                bookingId: bookingId,
                bookingData: clientBooking,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(cardIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerLabel,
                        style: GoogleFonts.plusJakartaSans(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        statusText,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textHighContrast,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "Lacak",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF2F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_pin_circle_rounded, color: AppTheme.primaryPink, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "$pickup ➔ $destination",
                      style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserModel? user, bool isLoggedIn) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  backgroundColor: AppColors.deepVoid,
                  appBar: AppBar(
                    backgroundColor: AppColors.deepVoid,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textMain),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(
                      "Profil Saya",
                      style: GoogleFonts.plusJakartaSans(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: const ProfileTab(),
                  ),
                ),
              ),
            );
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 26, // Sedikit perbesar avatar
                  backgroundColor: AppColors.elevatedDark,
                  backgroundImage: user?.avatarUrl != null
                      ? NetworkImage(user!.avatarUrl!)
                      : const NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80') as ImageProvider,
                  onBackgroundImageError: (exception, stackTrace) {
                    // Silent fallback
                  },
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getTimeGreeting(),
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    isLoggedIn ? (user?.fullName ?? 'Faizun A.') : 'Faizun A.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Navigasi Atas: Notifikasi
        Builder(
          builder: (context) {
            final unreadCount = context.watch<ClientNotificationProvider>().unreadCount;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsPage()),
                );
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF0E4EC), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.textMain,
                      size: 26,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.electricPink,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.obsidian, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              '$unreadCount',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWalletCard(BuildContext context, UserModel? user) {
    final balance = user?.balance ?? 1450000;
    final holdBalance = 300000;
    final formattedBalance = 'Rp ' + balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
    final formattedHold = 'Rp ' + holdBalance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');

    // Determine Tier Color
    Color tierColor;
    switch (_currentTier) {
      case 'Diamond':
        tierColor = const Color(0xFF0284C7);
        break;
      case 'Platinum':
        tierColor = const Color(0xFF475569);
        break;
      case 'Gold':
        tierColor = const Color(0xFFD97706);
        break;
      case 'Silver':
        tierColor = const Color(0xFF64748B);
        break;
      default: // Bronze
        tierColor = const Color(0xFFB45309);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.electricPink.withOpacity(0.12),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.electricPink.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Left Column: Saldo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: AppColors.electricPink, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'SALDO TEMENIN',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formattedBalance,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.lock_clock_outlined, color: AppColors.warning, size: 9),
                        const SizedBox(width: 4),
                        Text(
                          'Hold: $formattedHold',
                          style: GoogleFonts.inter(
                            color: AppColors.warning,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Divider
              Container(
                height: 50,
                width: 1,
                color: AppColors.elevatedDark,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),

              // Right Column: Points
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.stars_rounded, color: tierColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'POIN & MEMBER',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_totalPoints Poin',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tierColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_currentTier Tier',
                        style: GoogleFonts.inter(
                          color: tierColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              color: AppColors.elevatedDark,
              height: 1,
            ),
          ),

          // Buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RewardsPage()),
                    );
                  },
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.electricPink,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.electricPink.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 6),
                        Text(
                          'Topup Saldo',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RewardsPage()),
                    );
                  },
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.elevatedDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.elevatedDark),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.redeem_rounded, color: AppColors.textMain, size: 13),
                        const SizedBox(width: 6),
                        Text(
                          'Tukar Poin',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textMain,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.electricPink, AppColors.roseGold],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.electricPink.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Opacity(
            opacity: 0.15,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=400&q=80'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Text(
                    'WEEKEND PROMO',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Diskon 20% Freedom Request Malam Ini!',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartMatchingCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.electricPink.withOpacity(0.18), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.electricPink.withOpacity(0.10),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.electricPink.withOpacity(0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppColors.roseGold,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Pencocokan Pintar',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.roseGold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cari Chemistry Kencanmu!',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textMain,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Temukan partner yang klop berdasarkan kepribadian, hobi, dan topik obrolan favorit.',
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SmartMatchScreen()),
                      );
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.radar_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                     .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1.seconds),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }




  Widget _buildPopularEventsSection() {
    if (_events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Populer Terdekat',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textMain,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 155,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _events.length,
            itemBuilder: (context, index) {
              final ev = _events[index];
              return GestureDetector(
                onTap: () => _showEventDetail(ev),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: NetworkImage(ev['image_url'] ?? ev['image'] ?? ''),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.4),
                        BlendMode.darken,
                      ),
                    ),
                    border: Border.all(color: AppColors.elevatedDark),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.electricPink.withOpacity(0.3),
                            AppColors.roseGold.withOpacity(0.3)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              (ev['date_string'] ?? ev['date'] ?? '').toString(),
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (ev['title'] ?? '').toString(),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: Colors.white70, size: 10),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  (ev['location'] ?? '').toString(),
                                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 9),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.touch_app_rounded, color: Colors.white, size: 10),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Lihat Detail',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 9,
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEventDetail(Map<String, dynamic> ev) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(eventData: ev),
      ),
    );
  }



  Widget _buildCategoriesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pilih Layanan',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textMain,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookingTypeSelectorScreen()),
                );
              },
              child: Row(
                children: [
                  Text(
                    'Lihat 3 Pilar',
                    style: GoogleFonts.inter(
                      color: AppColors.electricPink,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.electricPink, size: 10),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildCategoryCard('all', Icons.auto_awesome_rounded, 'Semua', width: 75),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildCategoryCard('hangout', Icons.celebration_rounded, 'Hangout', width: 85),
                    const SizedBox(width: 8),
                    _buildCategoryCard('freedom', Icons.assignment_turned_in_rounded, 'Jasa Suruh', width: 95),
                    const SizedBox(width: 8),
                    _buildCategoryCard('detektif', Icons.search_rounded, 'Detektif', width: 85),
                    const SizedBox(width: 8),
                    _buildCategoryCard('sporty_ride', Icons.two_wheeler_rounded, 'Motor Sport', width: 100),
                    const SizedBox(width: 8),
                    _buildCategoryCard('counseling', Icons.psychology_rounded, 'Konseling Curhat', width: 125),
                    const SizedBox(width: 8),
                    _buildCategoryCard('hiking', Icons.terrain_rounded, 'Hiking Partner', width: 110),
                    const SizedBox(width: 8),
                    _buildCategoryCard('assistant', Icons.badge_rounded, 'Personal Assistant', width: 130),
                    const SizedBox(width: 8),
                    _buildCategoryCard('sleep', Icons.bedtime_rounded, 'Sleep Call', width: 90),
                    const SizedBox(width: 8),
                    _buildCategoryCard('telepon', Icons.phone_in_talk_rounded, 'Telepon WA', width: 95),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String category, IconData icon, String label, {double? width}) {
    final isActive = _selectedCategory == category;
    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: isActive ? null : AppColors.obsidian,
        gradient: isActive 
          ? LinearGradient(colors: [AppColors.electricPink.withOpacity(0.18), AppColors.electricPink.withOpacity(0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight)
          : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.electricPink.withOpacity(0.5) : AppColors.elevatedDark,
          width: isActive ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive ? AppColors.electricPink.withOpacity(0.12) : Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: isActive ? AppColors.brandGradient : null,
              color: isActive ? null : AppColors.elevatedDark,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isActive ? [
                BoxShadow(color: AppColors.electricPink.withOpacity(0.3), blurRadius: 6),
              ] : null,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : AppColors.electricPink,
              size: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: isActive ? AppColors.electricPink : AppColors.textMain,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        if (category == 'all') {
          setState(() {
            _selectedCategory = 'all';
          });
          _showAllServicesBottomSheet(context);
        } else {
          setState(() {
            _selectedCategory = category;
          });
          Navigator.pushNamed(context, '/booking', arguments: {'serviceType': category});
        }
      },
      child: cardContent,
    );
  }

  void _showAllServicesBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border(
              top: BorderSide(color: AppColors.electricPink, width: 1.5),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E4EC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Semua Layanan Temenin',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pilih layanan premium yang Anda butuhkan',
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMain),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  children: [
                    // --- PILAR 1: OFFLINE COMPANION (TATAP MUKA) ---
                    _buildPillarSectionHeader("PILAR 1: OFFLINE COMPANION (TATAP MUKA)", Icons.people_alt_rounded, AppColors.electricPink),
                    const SizedBox(height: 10),
                    _buildDetailedServiceCard(
                      context,
                      title: "Hangout Partner",
                      desc: "Teman nongkrong di kafe, nonton bioskop, makan santai, atau pendamping ke pesta/kondangan/wisuda.",
                      imageUrl: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=400&auto=format&fit=crop",
                      actionText: "Booking Hangout",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HangoutBookingScreen(serviceType: 'hangout')),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDetailedServiceCard(
                      context,
                      title: "Antar Jemput Sporty (Motor Sport)",
                      desc: "Sensasi diantar/dijemput naik motor sport keren (ZX25R, CBR, Ninja, R15/R25) dengan riding gear aman & gaya stylish.",
                      imageUrl: "https://images.unsplash.com/photo-1568772585407-9361f9bf3a87?q=80&w=400&auto=format&fit=crop",
                      actionText: "Pesan Motor Sport",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AntarJemputBookingScreen(serviceType: 'sporty')),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDetailedServiceCard(
                      context,
                      title: "Hiking Partner (Mendaki Gunung)",
                      desc: "Jasa teman mendaki gunung, trekking alam bebas, safety buddy jalur pendakian, serta bantuan bawa logistik.",
                      imageUrl: "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=400&auto=format&fit=crop",
                      actionText: "Cari Hiking Partner",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HangoutBookingScreen(serviceType: 'hiking')),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDetailedServiceCard(
                      context,
                      title: "Personal Assistant Service",
                      desc: "Asisten pribadi harian serbaguna: bawain koper, bawain belanjaan, hingga personal bodyguard / escort di club & event malam.",
                      imageUrl: "https://images.unsplash.com/photo-1507679799987-c73779587ccf?q=80&w=400&auto=format&fit=crop",
                      actionText: "Sewa Personal Assistant",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FreedomRequestBookingScreen(serviceType: 'assistant')),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDetailedServiceCard(
                      context,
                      title: "Detektif Relationship",
                      desc: "Investigasi rahasia pasangan, cek kesetiaan, stalking aman & observasi situasi tempat publik secara discreet.",
                      imageUrl: "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?q=80&w=400&auto=format&fit=crop",
                      actionText: "Sewa Detektif Asmara",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FreedomRequestBookingScreen(serviceType: 'detektif')),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDetailedServiceCard(
                      context,
                      title: "Relationship Counseling (Offline)",
                      desc: "Ruang aman bercerita dan mendengarkan curhat asmara atau masalah hidup tatap muka di kafe santai.",
                      imageUrl: "https://images.unsplash.com/photo-1573497019940-1c28c88b4f3e?q=80&w=400&auto=format&fit=crop",
                      actionText: "Konseling Offline",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HangoutBookingScreen(serviceType: 'counseling_offline')),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- PILAR 2: VIRTUAL COMPANION (ONLINE) ---
                    _buildPillarSectionHeader("PILAR 2: VIRTUAL COMPANION (ONLINE)", Icons.phone_iphone_rounded, const Color(0xFF6366F1)),
                    const SizedBox(height: 10),
                    _buildDetailedServiceCard(
                      context,
                      title: "Sleep Call Companion",
                      desc: "Teman tidur malam hari untuk mengusir kesepian & alarm pengingat bangun pagi tepat waktu.",
                      imageUrl: "https://images.unsplash.com/photo-1511295742362-92c96b124e52?q=80&w=400&auto=format&fit=crop",
                      actionText: "Pesan Sleep Call",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SleepCallBookingScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDetailedServiceCard(
                      context,
                      title: "Relationship Counseling (Online & WA)",
                      desc: "Mendengarkan curhat & konsultasi asmara online secara rahasia via panggilan suara in-app atau WhatsApp call/chat.",
                      imageUrl: "https://images.unsplash.com/photo-1529156069898-49953e39b3ac?q=80&w=400&auto=format&fit=crop",
                      actionText: "Curhat Online / WA",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VirtualCallBookingScreen(serviceType: 'counseling')),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- PILAR 3: CUSTOM & FLEXIBLE ---
                    _buildPillarSectionHeader("PILAR 3: CUSTOM & FLEKSIBEL", Icons.auto_awesome_rounded, const Color(0xFFF97316)),
                    const SizedBox(height: 10),
                    _buildDetailedServiceCard(
                      context,
                      title: "Freedom Request (Jasa Suruh)",
                      desc: "Tentukan tugas / suruhan apa saja secara bebas (antri tiket, beliin barang, antar dokumen, dll) lalu tawar budget langsung.",
                      imageUrl: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=400&auto=format&fit=crop",
                      actionText: "Ajukan Jasa Suruh",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FreedomRequestBookingScreen(serviceType: 'freedom')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPillarSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedServiceCard(
    BuildContext context, {
    required String title,
    required String desc,
    required String imageUrl,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E4EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              imageUrl,
              height: 130,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 130,
                  color: AppColors.elevatedDark,
                  child: const Icon(Icons.broken_image_rounded, color: AppColors.textMuted),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.electricPink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        actionText,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomRequestDialog(BuildContext context, String serviceName, String description) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.obsidian,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.electricPink.withOpacity(0.3)),
          ),
          title: Text(
            serviceName,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textMain,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            description,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: GoogleFonts.inter(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HangoutBookingScreen(serviceType: 'freedom'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricPink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Lanjut ke Freedom Request',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPartnerFeedHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Rekomendasi Partner',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textMain,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PartnerListScreen()),
            );
          },
          child: Text(
            'Lihat Semua',
            style: GoogleFonts.inter(
              color: AppColors.electricPink,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerList() {
    final driverProvider = context.watch<DriverProvider>();
    final List<Map<String, dynamic>> realDrivers = driverProvider.drivers;

    if (driverProvider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: AppColors.electricPink),
        ),
      );
    }

    final allPartners = realDrivers.map((d) {
      final priceVal = d['price'] is int ? d['price'] as int : (int.tryParse(d['price'].toString()) ?? 50000);
      final priceFormatted = 'Rp ${priceVal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
      
      return _PartnerData(
        id: d['id'].toString(),
        name: d['name'] ?? 'Driver Partner',
        imageUrl: d['image'] ?? 'https://ui-avatars.com/api/?name=Driver',
        rating: double.tryParse(d['rating'].toString()) ?? 5.0,
        tags: ['Ride', 'Hangout', 'Verified KYC', 'Counseling', 'Curhat', 'Sporty', 'Hiking', 'Assistant', 'Event Companion'],
        distance: '1.0 KM',
        price: priceFormatted,
        vehicle: d['vehicle'] ?? 'Kendaraan Driver',
        vehicleStnk: 'B ${d['id']} DRV',
        tier: '★ ${(d['type'] ?? 'GOLD').toString().toUpperCase()} TIER',
        priceVal: priceVal,
      );
    }).toList();

    // Filter by selected category pill
    final filteredPartners = allPartners.where((partner) {
      if (_selectedCategory == 'all') return true;
      if (_selectedCategory == 'ride') return partner.tags.contains('Ride');
      if (_selectedCategory == 'hangout') return partner.tags.contains('Hangout');
      if (_selectedCategory == 'freedom') return true; // Everyone supports freedom request
      if (_selectedCategory == 'sporty') return partner.tags.contains('Sporty');
      if (_selectedCategory == 'counseling') return partner.tags.contains('Counseling');
      if (_selectedCategory == 'curhat') return partner.tags.contains('Curhat');
      if (_selectedCategory == 'hiking') return partner.tags.contains('Hiking');
      if (_selectedCategory == 'assistant') return partner.tags.contains('Assistant');
      if (_selectedCategory == 'event') return partner.tags.contains('Event Companion');
      return true;
    }).toList();

    final displayedPartners = filteredPartners.take(5).toList();

    if (displayedPartners.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 30),
        alignment: Alignment.center,
        child: Text(
          'Tidak ada partner untuk kategori ini',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayedPartners.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final partner = displayedPartners[index];
        return _buildPartnerCard(partner);
      },
    );
  }

  Widget _buildPartnerCard(_PartnerData partner) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PartnerProfileScreen(
              serviceType: _selectedCategory,
              partnerData: {
                'id': partner.id,
                'name': partner.name,
                'rating': partner.rating.toString(),
                'vehicle': partner.vehicle,
                'type': partner.tier,
                'image': partner.imageUrl,
                'status': 'Available',
                'price': partner.priceVal,
                'vehicle_stnk': partner.vehicleStnk,
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFF0E4EC),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    partner.imageUrl,
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 68,
                        height: 68,
                        color: AppColors.elevatedDark,
                        child: const Icon(Icons.person, color: AppColors.textMuted, size: 28),
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.obsidian, width: 2),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        partner.name,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textMain,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 12),
                          const SizedBox(width: 3),
                          Text(
                            partner.rating.toString(),
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFBBF24),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: partner.tags.map((tag) => _buildTag(tag)).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.textMuted, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            partner.distance,
                            style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: partner.price,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.roseGold,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: ' / Jam',
                              style: GoogleFonts.inter(
                                color: AppColors.textMuted,
                                fontSize: 10,
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
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.electricPink.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: AppColors.electricPink,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSafetyTrustBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.electricPink.withOpacity(0.12), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.electricPink.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.electricPink.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppColors.electricPink, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jaminan Keamanan & Kenyamanan 🛡️',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Setiap partner terverifikasi ketat demi pengalaman terbaik Anda',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTrustBadge(Icons.badge_rounded, '100% Verifikasi KTP'),
              _buildTrustBadge(Icons.location_on_rounded, 'Pelacakan GPS Live'),
              _buildTrustBadge(Icons.headset_mic_rounded, 'Bantuan SOS 24/7'),
              _buildTrustBadge(Icons.health_and_safety_rounded, 'Asuransi Perjalanan'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.elevatedDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.elevatedDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.roseGold, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              color: AppColors.textMain,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityHighlightsSection() {
    if (_communityReviews.isEmpty) {
      return const SizedBox.shrink();
    }
    final highlights = _communityReviews;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ulasan Nyata Komunitas ✨',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textMain,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CommunityFeedScreen()),
                );
              },
              child: Text(
                'Lihat Komunitas',
                style: GoogleFonts.inter(
                  color: AppColors.electricPink,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 135,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: highlights.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = highlights[index];
              final avatar = item['avatar']?.toString() ?? '';
              final name = item['name']?.toString() ?? 'Pelanggan';
              final comment = item['comment']?.toString().trim() ?? '';

              return Container(
                width: 260,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF0E4EC)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.electricPink.withOpacity(0.2),
                          backgroundImage: (avatar.isNotEmpty && !avatar.contains('dummy'))
                              ? NetworkImage(avatar)
                              : null,
                          child: (avatar.isEmpty || avatar.contains('dummy'))
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
                                  style: GoogleFonts.inter(color: AppColors.electricPink, fontSize: 11, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.textMain,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                item['role'] ?? 'Verified Review',
                                style: GoogleFonts.inter(
                                  color: AppColors.electricPink,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              item['rating'] ?? '5.0',
                              style: GoogleFonts.inter(
                                color: AppColors.textMain,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '"$comment"',
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickHelpFooter() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E4EC)),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.electricPink.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded, color: AppColors.electricPink, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Butuh Bantuan atau Pertanyaan?',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tim customer care siap melayani Anda 24 Jam',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpCenterPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.electricPink,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Bantuan',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MAIN ENTRY POINT (For testing)
// ============================================================

class TemeninAjaaApp extends StatelessWidget {
  const TemeninAjaaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temenin Ajaa',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.deepVoid,
        fontFamily: 'Inter',
      ),
      home: const HomeLoggedInScreen(),
    );
  }
}

void main() {
  runApp(const TemeninAjaaApp());
}