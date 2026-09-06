import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../data/models/booking_model.dart';
import '../../../providers/community_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../auth/screens/login_screen.dart';
import 'edit_profile_screen.dart';
import 'driver_matching_prefs_screen.dart';
import 'driver_posts_screen.dart';
import 'driver_story_viewer_screen.dart';
import 'instagram_story_editor_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedScheduleDayIndex = 0;

  String _getDayName(int weekday) {
    const names = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return names[(weekday - 1) % 7];
  }

  String _getShortDayName(int weekday) {
    const names = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MING'];
    return names[(weekday - 1) % 7];
  }

  String _getMonthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return names[(month - 1) % 12];
  }

  String _getFullMonthName(int month) {
    const names = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return names[(month - 1) % 12];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final driver = auth.driverProfileData;

    final name = user?.fullName ?? 'Driver Temenin Ajaa';
    final avatar = (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
        ? user.avatarUrl!
        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80';

    final rating = (driver?['rating'] != null) ? (driver!['rating'] as num).toDouble() : 5.0;
    final totalRides = driver?['completed_trips'] ?? driver?['total_rides'] ?? 0;
    final driverClass = driver?['driver_class'] ?? 'VVIP Gold';

    // Parse registration metadata from vehicle_stnk JSON
    final String vehicleStnk = driver?['vehicle_stnk'] ?? '';
    List<Map<String, dynamic>> vehicles = [];
    int activeVehicleIndex = 0;

    if (vehicleStnk.startsWith('{')) {
      try {
        final Map<String, dynamic> metadata = jsonDecode(vehicleStnk);
        if (metadata['vehicles'] != null) {
          vehicles = List<Map<String, dynamic>>.from(
            (metadata['vehicles'] as List).map((v) => Map<String, dynamic>.from(v)),
          );
        }
        activeVehicleIndex = metadata['active_vehicle_index'] ?? 0;
      } catch (e) {
        debugPrint('Error parsing vehicle_stnk metadata: $e');
      }
    }

    // Fallback if no vehicles parsed yet, use data from root driver payload
    if (vehicles.isEmpty) {
      vehicles.add({
        'type': driver?['vehicle_type'] ?? 'Motor',
        'name': driver?['vehicle_name'] ?? 'Kendaraan Terdaftar',
        'plate_number': driver?['plate_number'] ?? 'B 1234 OK',
        'age': '< 10 Tahun',
      });
    }

    final community = context.watch<CommunityProvider>();
    final userPosts = community.posts;
    final userStories = community.stories;

    final bool hasLocalAvatar = !kIsWeb && avatar.isNotEmpty && File(avatar).existsSync();
    final ImageProvider avatarImageProvider = hasLocalAvatar
        ? FileImage(File(avatar))
        : NetworkImage(avatar.isNotEmpty ? avatar : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300') as ImageProvider;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<AuthProvider>().refreshProfile();
          await context.read<CommunityProvider>().fetchCommunityData();
        },
        color: AppTheme.primaryPink,
        backgroundColor: AppTheme.surface,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                floating: false,
                backgroundColor: AppTheme.surface,
                elevation: 0,
                expandedHeight: 360.0,
                title: Text(
                  "@${name.toLowerCase().replaceAll(' ', '')}",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
                    ),
                    onPressed: () => _showSettingsModal(context, auth),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.heroGradient,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(36),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x22D64573),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        )
                      ],
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // ===================================================
                            // 1. DRIVER PROFILE PHOTO WITH GLOW RING
                            // ===================================================
                            GestureDetector(
                              onTap: () => _showChangeProfilePhotoModal(context),
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFFE11D74),
                                          Color(0xFFF43F5E),
                                          Color(0xFFFB7185),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(3.5),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: CircleAvatar(
                                        radius: 46, // Large Profile Photo
                                        backgroundImage: avatarImageProvider,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryPink,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 6,
                                          )
                                        ],
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ===================================================
                            // 2. DRIVER NAME & VERIFIED BADGE
                            // ===================================================
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$driverClass • Driver Companion",
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // ===================================================
                            // 3. SOCIAL STATS ROW (Clean White Pill)
                            // ===================================================
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildSocialCounter("$totalRides", "Pesanan"),
                                  Container(height: 26, width: 1, color: AppTheme.border),
                                  _buildSocialCounter(rating.toStringAsFixed(1), "Rating ⭐"),
                                  Container(height: 26, width: 1, color: AppTheme.border),
                                  _buildSocialCounter("${userPosts.length + userStories.length}", "Post & Story"),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ===================================================
                            // 4. ACTION BUTTONS (Edit Profile & Add Story)
                            // ===================================================
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const EditDriverProfileScreen()),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.surface,
                                      foregroundColor: AppTheme.textHighContrast,
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.primaryPink),
                                    label: Text(
                                      "Edit Profil",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textHighContrast,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showAddStoryModal(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.22),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: Colors.white.withOpacity(0.35)),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                                    label: Text(
                                      "Tambah Story",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
                ),
              ),

            // Tab Bar Header (3 Section Tabs)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primaryPink,
                  indicatorWeight: 3,
                  labelColor: AppTheme.primaryPink,
                  unselectedLabelColor: AppTheme.textMuted,
                  labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on_rounded, size: 20), text: "Post & Story"),
                    Tab(icon: Icon(Icons.directions_car_rounded, size: 20), text: "Kendaraan"),
                    Tab(icon: Icon(Icons.calendar_month_rounded, size: 20), text: "Jadwal Saya"),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: Stories + Feed Postings
            _buildTabFeedAndStories(avatar, name, userStories, userPosts),

            // TAB 2: Kendaraan (Vehicles)
            _buildTabVehicles(vehicles, activeVehicleIndex, driver),

            // TAB 3: Jadwal Driver (Schedule & Availability)
            _buildTabSchedule(),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSocialCounter(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStoryHighlightBubble({
    required String title,
    required IconData icon,
    String? imageUrl,
    String? localFilePath,
    bool isAddButton = false,
    VoidCallback? onTap,
  }) {
    final bool hasLocalFile = !kIsWeb && localFilePath != null && localFilePath.isNotEmpty && File(localFilePath).existsSync();

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isAddButton ? AppTheme.border : AppTheme.primaryPink,
                  width: 1.8,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isAddButton ? AppTheme.fuchsiaLight : AppTheme.cardDeep,
                  shape: BoxShape.circle,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: hasLocalFile
                      ? Image.file(File(localFilePath), fit: BoxFit.cover)
                      : (imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : Icon(
                              icon,
                              color: isAddButton ? AppTheme.primaryPink : AppTheme.textHighContrast,
                              size: 20,
                            )),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 56,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 1: POST & STORY 24 JAM =================
  Widget _buildTabFeedAndStories(
    String userAvatar,
    String driverName,
    List<Map<String, dynamic>> stories,
    List<Map<String, dynamic>> posts,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(0, 16.0, 0, 100.0 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TAMPILAN BULAT STORY DI ATAS POSTINGAN
          Padding(
            padding: const EdgeInsets.only(left: 20.0, bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Story 24 Jam",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textHighContrast,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 75,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildStoryHighlightBubble(
                        title: "Buat Story",
                        icon: Icons.add,
                        isAddButton: true,
                        onTap: () => _showAddStoryModal(context),
                      ),
                      ...stories.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final story = entry.value;
                        return _buildStoryHighlightBubble(
                          title: story['title'] ?? 'Story',
                          icon: story['icon'] ?? Icons.star_rounded,
                          imageUrl: story['image'],
                          localFilePath: story['localFilePath'],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DriverStoryViewerScreen(
                                  stories: stories,
                                  initialIndex: idx,
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. ACTIVITAS & POSTINGAN FEED
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Aktivitas & Postingan",
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textHighContrast,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddPostModal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.post_add_rounded, color: Colors.white, size: 16),
                  label: Text(
                    "Buat Post",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // If no posts yet, show Empty State Card
          if (posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.photo_library_outlined, color: AppTheme.textMuted, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      "Belum Ada Postingan Aktivitas",
                      style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Bagikan momen perjalanan & unit kendaraan Anda ke calon pelanggan!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => _showAddPostModal(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryPink),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_a_photo_rounded, color: AppTheme.primaryPink, size: 16),
                      label: Text(
                        "Tambah Postingan Pertama",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primaryPink,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemBuilder: (context, index) {
                final post = posts[index];
                final List<String> multiPhotos = (post['localFilePaths'] as List?)?.map((e) => e.toString()).toList() ?? [];
                final String? localPath = post['localFilePath'];
                final String imgUrl = post['image'] ?? '';
                final bool isVideo = post['mediaType'] == 'video';
                final comments = (post['commentsList'] as List? ?? []).map((c) => Map<String, dynamic>.from(c as Map)).toList();
                final bool isLiked = post['isLiked'] as bool? ?? false;
                final int likes = post['likes'] as int? ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Post Author Header
                      ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(post['avatar'] != null && (post['avatar'] as String).isNotEmpty ? post['avatar'] : userAvatar),
                        ),
                        title: Text(
                          post['partnerName'] ?? driverName,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textHighContrast,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          "${post['location'] ?? 'Jakarta'} • ${post['time'] ?? 'Baru saja'}",
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 18),
                          onPressed: () {},
                        ),
                      ),

                      // Post Media (Support Multi-Photo Carousel or Single Media)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: multiPhotos.length > 1
                              ? Stack(
                                  children: [
                                    PageView.builder(
                                      itemCount: multiPhotos.length,
                                      itemBuilder: (context, photoIndex) {
                                        final path = multiPhotos[photoIndex];
                                        return (!kIsWeb && File(path).existsSync())
                                            ? Image.file(File(path), fit: BoxFit.cover)
                                            : Image.network(imgUrl, fit: BoxFit.cover);
                                      },
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          "${multiPhotos.length} Foto",
                                          style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : (!kIsWeb && localPath != null && File(localPath).existsSync())
                                  ? Image.file(File(localPath), fit: BoxFit.cover)
                                  : (imgUrl.isNotEmpty)
                                      ? Image.network(
                                          imgUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: AppTheme.cardDeep,
                                            child: const Center(child: Icon(Icons.broken_image_rounded, color: AppTheme.textMuted, size: 48)),
                                          ),
                                        )
                                      : Container(
                                          color: AppTheme.cardDeep,
                                          child: const Center(child: Icon(Icons.photo_rounded, color: AppTheme.textMuted, size: 48)),
                                        ),
                        ),
                      ),

                      // Post Action Footer
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    context.read<CommunityProvider>().toggleLike(post['id']);
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                        color: isLiked ? AppTheme.primaryPink : AppTheme.textMuted,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$likes",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: AppTheme.textHighContrast,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Row(
                                  children: [
                                    const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.textMuted, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${comments.length}",
                                      style: GoogleFonts.plusJakartaSans(color: AppTheme.textMediumContrast, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                const Icon(Icons.bookmark_border_rounded, color: AppTheme.textMuted, size: 20),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              post['caption'] ?? '',
                              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ================= TAB 2: KENDARAAN (VEHICLES) =================
  Widget _buildTabVehicles(List<Map<String, dynamic>> vehicles, int activeIndex, Map<String, dynamic>? driver) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kendaraan Terdaftar",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textHighContrast,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "Klik unit untuk melihat detail galeri foto & spesifikasi",
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showAddVehicleModal(context, vehicles),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPink,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: Text(
                  "Tambah Unit",
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vehicle Cards List with Compact Image Preview
          ...vehicles.asMap().entries.map((entry) {
            final idx = entry.key;
            final v = entry.value;
            final isActive = idx == activeIndex;
            final isCar = (v['type'] ?? 'Motor') == 'Mobil';
            
            // Sample compact vehicle photos
            final photoUrl = v['image'] ?? (isCar
                ? 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=600'
                : 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=600');

            return GestureDetector(
              onTap: () => _showVehicleDetailModal(context, v, isCar, isActive, idx, vehicles),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isActive ? AppTheme.primaryPink : AppTheme.border,
                    width: isActive ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isActive ? AppTheme.primaryPink.withOpacity(0.1) : Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Compact Photo Preview Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            children: [
                              Image.network(
                                photoUrl,
                                width: 90,
                                height: 68,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Color(0xB3000000),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.collections_rounded, color: Colors.white, size: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      v['name'] ?? 'Unit Kendaraan',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.textHighContrast,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardDeep,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      v['type'] ?? 'Motor',
                                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Plat: ${v['plate_number'] ?? 'B 1234 XYZ'}",
                                style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    "Lihat Foto & Detail",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.primaryPink,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryPink, size: 10),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () => _pickCropAndSaveVehiclePhoto(idx, vehicles),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.fuchsiaLight,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.crop_original_rounded, size: 12, color: AppTheme.primaryPink),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Edit Foto",
                                            style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.success.withOpacity(0.4)),
                            ),
                            child: Text(
                              "DIGUNAKAN",
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.success,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Helper method to get real bookings for a specific date from Supabase/BookingProvider
  List<BookingModel> _getBookingsForDate(DateTime date, BookingProvider provider) {
    final all = <BookingModel>[];
    if (provider.activeBooking != null) {
      all.add(provider.activeBooking!);
    }
    for (final b in provider.bookings) {
      if (!all.any((x) => x.id == b.id)) {
        all.add(b);
      }
    }

    return all.where((b) {
      if (b.status == 'cancelled') return false;
      final bDate = b.bookingDate ?? b.createdAt;
      return bDate.year == date.year && bDate.month == date.month && bDate.day == date.day;
    }).toList();
  }

  // ================= TAB 3: JADWAL DRIVER (7-COLUMN REAL MONTH CALENDAR GRID) =================
  Widget _buildTabSchedule() {
    final bookingProvider = context.watch<BookingProvider>();

    final now = DateTime.now();
    final totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final monthFullName = _getFullMonthName(now.month);

    final weekdaysHeader = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MING'];
    final firstDayWeekday = DateTime(now.year, now.month, 1).weekday; // 1 = Mon, 7 = Sun
    final leadingEmptyCount = firstDayWeekday - 1;
    final totalGridCells = leadingEmptyCount + totalDaysInMonth;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kalender Jadwal Driver 🗓️",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textHighContrast,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "$monthFullName ${now.year} • Data Booking Realtime",
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.cardDeep,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text("Ada Booking", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text("Kosong/Ready", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 7-Column Day Names Header Row
          Row(
            children: weekdaysHeader.map((w) {
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // 7-Column Big Square Dates Grid (1 to totalDaysInMonth)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalGridCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmptyCount) {
                return const SizedBox();
              }
              final dayNum = index - leadingEmptyCount + 1;
              final dateObj = DateTime(now.year, now.month, dayNum);
              final dayBookings = _getBookingsForDate(dateObj, bookingProvider);
              final isBooked = dayBookings.isNotEmpty;
              final isToday = now.day == dayNum && now.month == dateObj.month && now.year == dateObj.year;

              final Color boxColor = isBooked ? const Color(0xFFEF4444) : const Color(0xFF10B981);

              return GestureDetector(
                onTap: () {
                  _showScheduleHoursModalForDate(context, dateObj, dayBookings);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: boxColor,
                    borderRadius: BorderRadius.circular(12),
                    border: isToday
                        ? Border.all(color: Colors.white, width: 2.5)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: boxColor.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "$dayNum",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isBooked ? "BOOKING" : "READY",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Informational Banner at bottom of schedule
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, color: AppTheme.primaryPink, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Tekan salah satu kotak tanggal berwarna di atas untuk melihat rincian jam operasional atau detail pesanan yang masuk pada tanggal tersebut.",
                    style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= MODALS & DIALOGS =================

  // 1. VEHICLE DETAIL MODAL (Gallery + Specs)
  void _showVehicleDetailModal(
    BuildContext context,
    Map<String, dynamic> vehicle,
    bool isCar,
    bool isActive,
    int vehicleIndex,
    List<Map<String, dynamic>> allVehicles,
  ) {
    final List<String> photos = [];
    if (vehicle['image'] != null && (vehicle['image'] as String).isNotEmpty) {
      photos.add(vehicle['image'] as String);
    }
    photos.addAll(isCar
        ? [
            'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=800',
            'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=800',
          ]
        : [
            'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=800',
            'https://images.unsplash.com/photo-1568772585407-9361f9bf3a87?w=800',
          ]);

    int currentPhotoIndex = 0;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Modal Title & Active Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle['name'] ?? 'Detail Unit Kendaraan',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textHighContrast,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            "Plat Nomor: ${vehicle['plate_number'] ?? 'B 1234 OK'} • ${vehicle['type'] ?? 'Motor'}",
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            "AKTIF",
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Photo Gallery Carousel with Page Indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 200,
                          width: double.infinity,
                          child: PageView.builder(
                            itemCount: photos.length,
                            onPageChanged: (index) {
                              setModalState(() {
                                currentPhotoIndex = index;
                              });
                            },
                            itemBuilder: (context, idx) {
                              return Image.network(
                                photos[idx],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: AppTheme.cardDeep,
                                  child: const Center(child: Icon(Icons.directions_car_rounded, color: AppTheme.textMuted, size: 48)),
                                ),
                              );
                            },
                          ),
                        ),
                        // Page Dots Indicator
                        Positioned(
                          bottom: 10,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(photos.length, (idx) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: currentPhotoIndex == idx ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: currentPhotoIndex == idx ? AppTheme.primaryPink : Colors.white70,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              );
                            }),
                          ),
                        ),
                        // Swipe Hint Badge
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xB3000000),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.swipe_rounded, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  "${currentPhotoIndex + 1}/${photos.length} Foto",
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Button to Upload / Change Vehicle Image
                  OutlinedButton.icon(
                    onPressed: isUploading
                        ? null
                        : () async {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                            if (image != null) {
                              setModalState(() => isUploading = true);
                              String finalPath = image.path;
                              try {
                                final cropped = await ImageCropper().cropImage(
                                  sourcePath: image.path,
                                  uiSettings: [
                                    AndroidUiSettings(
                                      toolbarTitle: 'Potong & Sesuaikan Foto Kendaraan',
                                      toolbarColor: AppTheme.surface,
                                      toolbarWidgetColor: AppTheme.textHighContrast,
                                      activeControlsWidgetColor: AppTheme.primaryPink,
                                      initAspectRatio: CropAspectRatioPreset.ratio4x3,
                                      aspectRatioPresets: [CropAspectRatioPreset.ratio4x3, CropAspectRatioPreset.square],
                                    ),
                                    IOSUiSettings(title: 'Potong Foto Kendaraan'),
                                  ],
                                );
                                if (cropped != null) finalPath = cropped.path;
                              } catch (_) {}

                              final uploadedUrl = await context.read<AuthProvider>().uploadImageFile(File(finalPath), folder: 'vehicles');
                              vehicle['image'] = uploadedUrl;
                              allVehicles[vehicleIndex]['image'] = uploadedUrl;

                              await _saveVehiclesMetadata(allVehicles, vehicleIndex);
                              if (mounted) {
                                setState(() {});
                                setModalState(() {
                                  if (!photos.contains(uploadedUrl)) {
                                    photos.insert(0, uploadedUrl);
                                  }
                                  isUploading = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("✨ Foto kendaraan berhasil diubah & disimpan!"), backgroundColor: AppTheme.success),
                                );
                              }
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryPink),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    icon: isUploading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPink))
                        : const Icon(Icons.add_a_photo_rounded, color: AppTheme.primaryPink, size: 16),
                    label: Text(
                      isUploading ? "Mengunggah Gambar..." : "Ubah / Upload Foto Unit 📸",
                      style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Vehicle Specifications Grid
                  Text(
                    "Spesifikasi & Kondisi Unit",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textHighContrast,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSpecTile(Icons.branding_watermark_rounded, "Plat", vehicle['plate_number'] ?? 'B 1234 OK'),
                      _buildSpecTile(Icons.speed_rounded, "Transmisi", "Otomatis (Matik)"),
                      _buildSpecTile(Icons.airline_seat_recline_extra_rounded, "Kapasitas", isCar ? "5 Penumpang" : "2 Penumpang"),
                      _buildSpecTile(Icons.verified_user_rounded, "STNK & Pajak", "Terverifikasi Aktif ✔"),
                      _buildSpecTile(Icons.clean_hands_rounded, "Kebersihan", "Steril & Rutin Servis"),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!isActive) {
                          await _saveVehiclesMetadata(allVehicles, vehicleIndex);
                          if (mounted) setState(() {});
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Kendaraan aktif diubah ke ${vehicle['name']}"),
                              backgroundColor: AppTheme.primaryPink,
                            ),
                          );
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive ? AppTheme.cardDeep : AppTheme.primaryPink,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        isActive ? "UNIT SEDANG DIGUNAKAN" : "GUNAKAN KENDARAAN INI",
                        style: GoogleFonts.plusJakartaSans(
                          color: isActive ? AppTheme.textMuted : Colors.white,
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
      },
    );
  }

  Widget _buildSpecTile(IconData icon, String label, String value) {
    return Container(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryPink, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCropAndSaveVehiclePhoto(int vehicleIndex, List<Map<String, dynamic>> allVehicles) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null) {
      String finalPath = image.path;
      try {
        final cropped = await ImageCropper().cropImage(
          sourcePath: image.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Potong & Sesuaikan Foto Kendaraan',
              toolbarColor: AppTheme.surface,
              toolbarWidgetColor: AppTheme.textHighContrast,
              activeControlsWidgetColor: AppTheme.primaryPink,
              initAspectRatio: CropAspectRatioPreset.ratio4x3,
              aspectRatioPresets: [CropAspectRatioPreset.ratio4x3, CropAspectRatioPreset.square],
            ),
            IOSUiSettings(title: 'Potong Foto Kendaraan'),
          ],
        );
        if (cropped != null) finalPath = cropped.path;
      } catch (e) {
        debugPrint('Cropping error: $e');
      }

      final uploadedUrl = await context.read<AuthProvider>().uploadImageFile(File(finalPath), folder: 'vehicles');
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        allVehicles[vehicleIndex]['image'] = uploadedUrl;
        await _saveVehiclesMetadata(allVehicles, vehicleIndex);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✨ Foto kendaraan berhasil diubah & disimpan!"),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    }
  }

  // 2. SCHEDULE HOURS MODAL (Real booking details or availability for Driver & Client)
  void _showScheduleHoursModalForDate(
    BuildContext context,
    DateTime date,
    List<BookingModel> dayBookings,
  ) {
    final isBooked = dayBookings.isNotEmpty;
    final dayName = _getDayName(date.weekday);
    final monthName = _getFullMonthName(date.month);
    final dateFormatted = "$dayName, ${date.day} $monthName ${date.year}";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Date Title & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFormatted,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textHighContrast,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          "Rincian Booking & Jadwal Operasional",
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBooked
                          ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                          : const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isBooked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      ),
                    ),
                    child: Text(
                      isBooked ? "🔴 TERISI BOOKING" : "🟢 READY / KOSONG",
                      style: GoogleFonts.plusJakartaSans(
                        color: isBooked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (isBooked) ...[
                Text(
                  "Daftar Rincian Pesanan Terisi (${dayBookings.length}):",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textHighContrast,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                ...dayBookings.map((b) {
                  final clientName = b.client?.fullName ?? b.additionalDetails?['client_name'] ?? 'Klien Temenin';
                  final startTimeStr = b.additionalDetails?['start_time'] ?? (b.bookingDate != null ? "${b.bookingDate!.hour.toString().padLeft(2, '0')}:${b.bookingDate!.minute.toString().padLeft(2, '0')}" : "09:00");
                  final startHour = int.tryParse(startTimeStr.split(':').first) ?? 9;
                  final endHour = (startHour + (b.duration > 0 ? b.duration : 2)) % 24;
                  final timeRangeStr = "$startTimeStr - ${endHour.toString().padLeft(2, '0')}:00 WIB";

                  final formattedPrice = b.totalPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDeep,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "👤 $clientName",
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textHighContrast,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPink.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                b.status.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time_filled_rounded, color: AppTheme.primaryPink, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "Jam: $timeRangeStr (${b.duration} Jam)",
                              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppTheme.textMuted, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "${b.pickupLocation} ➔ ${b.dropoffLocation}",
                                style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.payments_rounded, color: AppTheme.success, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "Total Tarif: Rp $formattedPrice",
                              style: GoogleFonts.plusJakartaSans(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "HARI INI BEBAS ORDER / KOSONG",
                              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Mitra Driver aktif & siap menerima pesanan dari pukul 08:00 - 22:00 WIB.",
                              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Done Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardDeep,
                    foregroundColor: AppTheme.textHighContrast,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                  child: Text(
                    "TUTUP",
                    style: GoogleFonts.plusJakartaSans(
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

  Future<void> _showChangeProfilePhotoModal(BuildContext context) async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Ganti Foto Profil Driver",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textHighContrast,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Pilih foto profil terbaik untuk akun mitra Anda",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                ListTile(
                  tileColor: AppTheme.cardDeep,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.fuchsiaLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryPink),
                  ),
                  title: Text(
                    "Ambil dari Kamera 📸",
                    style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text("Buka kamera dan ambil foto langsung", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                    if (photo != null) {
                      await _cropAndSaveAvatar(photo.path);
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  tileColor: AppTheme.cardDeep,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF0284C7)),
                  ),
                  title: Text(
                    "Pilih dari Galeri 🖼️",
                    style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text("Pilih gambar dari galeri album HP", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (image != null) {
                      await _cropAndSaveAvatar(image.path);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _cropAndSaveAvatar(String sourcePath) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong & Sesuaikan Foto Profil',
            toolbarColor: AppTheme.surface,
            toolbarWidgetColor: AppTheme.textHighContrast,
            statusBarColor: Colors.white,
            activeControlsWidgetColor: AppTheme.primaryPink,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
          ),
          IOSUiSettings(
            title: 'Potong Foto Profil',
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
          ),
        ],
      );

      if (cropped != null) {
        if (mounted) {
          await context.read<AuthProvider>().updateAvatar(cropped.path);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "✨ Foto profil driver berhasil diperbarui dan disimpan!",
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Crop avatar error: $e");
    }
  }

  void _showAddStoryModal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InstagramStoryEditorScreen()),
    );
  }

  void _showAddPostModal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DriverPostsScreen()),
    );
  }

  Future<void> _saveVehiclesMetadata(List<Map<String, dynamic>> vehiclesList, int activeIndex) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user != null) {
      final metadata = {
        'vehicles': vehiclesList,
        'active_vehicle_index': activeIndex,
      };
      final jsonString = jsonEncode(metadata);
      try {
        await Supabase.instance.client.from('drivers').update({
          'vehicle_stnk': jsonString,
          'vehicle_name': vehiclesList[activeIndex]['name'],
          'plate_number': vehiclesList[activeIndex]['plate_number'],
          'vehicle_type': vehiclesList[activeIndex]['type'],
        }).or('user_id.eq.${user.id},id.eq.${user.id}');
        await auth.refreshProfile();
      } catch (e) {
        debugPrint('Error updating vehicles metadata: $e');
      }
    }
  }

  void _showAddVehicleModal(BuildContext context, List<Map<String, dynamic>> currentVehicles) {
    final nameController = TextEditingController();
    final plateController = TextEditingController();
    String type = 'Motor';
    String? vehiclePhotoUrl;
    bool isUploadingPhoto = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tambah Unit Kendaraan Baru",
                    style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Motor 🛵"),
                          selected: type == 'Motor',
                          selectedColor: AppTheme.fuchsiaLight,
                          labelStyle: TextStyle(
                            color: type == 'Motor' ? AppTheme.primaryPink : AppTheme.textHighContrast,
                            fontWeight: type == 'Motor' ? FontWeight.bold : FontWeight.normal,
                          ),
                          side: BorderSide(color: type == 'Motor' ? AppTheme.primaryPink : AppTheme.border),
                          onSelected: (selected) {
                            if (selected) setModalState(() => type = 'Motor');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Mobil 🚘"),
                          selected: type == 'Mobil',
                          selectedColor: AppTheme.fuchsiaLight,
                          labelStyle: TextStyle(
                            color: type == 'Mobil' ? AppTheme.primaryPink : AppTheme.textHighContrast,
                            fontWeight: type == 'Mobil' ? FontWeight.bold : FontWeight.normal,
                          ),
                          side: BorderSide(color: type == 'Mobil' ? AppTheme.primaryPink : AppTheme.border),
                          onSelected: (selected) {
                            if (selected) setModalState(() => type = 'Mobil');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: AppTheme.textHighContrast),
                    decoration: InputDecoration(
                      hintText: "Nama/Model (cth: Yamaha NMAX 155)",
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.cardDeep,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryPink, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: plateController,
                    style: const TextStyle(color: AppTheme.textHighContrast),
                    decoration: InputDecoration(
                      hintText: "Nomor Plat (cth: B 5678 TAA)",
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.cardDeep,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryPink, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Vehicle Photo Input
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (photo != null) {
                        setModalState(() => isUploadingPhoto = true);
                        String finalPhotoPath = photo.path;
                        try {
                          final cropped = await ImageCropper().cropImage(
                            sourcePath: photo.path,
                            uiSettings: [
                              AndroidUiSettings(
                                toolbarTitle: 'Potong & Sesuaikan Foto Kendaraan',
                                toolbarColor: AppTheme.surface,
                                toolbarWidgetColor: AppTheme.textHighContrast,
                                activeControlsWidgetColor: AppTheme.primaryPink,
                                initAspectRatio: CropAspectRatioPreset.ratio4x3,
                                aspectRatioPresets: [CropAspectRatioPreset.ratio4x3, CropAspectRatioPreset.square],
                              ),
                              IOSUiSettings(title: 'Potong Foto Kendaraan'),
                            ],
                          );
                          if (cropped != null) finalPhotoPath = cropped.path;
                        } catch (_) {}

                        final uploaded = await context.read<AuthProvider>().uploadImageFile(File(finalPhotoPath), folder: 'vehicles');
                        setModalState(() {
                          vehiclePhotoUrl = uploaded;
                          isUploadingPhoto = false;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDeep,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: vehiclePhotoUrl != null ? AppTheme.primaryPink : AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          if (isUploadingPhoto)
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPink))
                          else if (vehiclePhotoUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(vehiclePhotoUrl!, width: 40, height: 32, fit: BoxFit.cover),
                            )
                          else
                            const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryPink, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              vehiclePhotoUrl != null ? "Foto Kendaraan Terpilih ✔" : "Unggah & Potong Foto Kendaraan 📸",
                              style: GoogleFonts.plusJakartaSans(
                                color: vehiclePhotoUrl != null ? AppTheme.primaryPink : AppTheme.textMediumContrast,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isNotEmpty && plateController.text.isNotEmpty) {
                          final newV = {
                            'type': type,
                            'name': nameController.text.trim(),
                            'plate_number': plateController.text.toUpperCase().trim(),
                            'image': vehiclePhotoUrl,
                            'age': '< 5 Tahun',
                          };
                          currentVehicles.add(newV);
                          await _saveVehiclesMetadata(currentVehicles, 0);
                          if (mounted) setState(() {});
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("✨ Kendaraan baru berhasil ditambahkan & disimpan!"), backgroundColor: AppTheme.primaryPink),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("Simpan Kendaraan", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSettingsModal(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.fuchsiaLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.settings_rounded, color: AppTheme.primaryPink, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Pengaturan Driver",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textHighContrast,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          "Kelola profil, operasional, & akun Mitra Driver",
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // SECTION 1: PROFIL & PREFERENSI
                _buildSettingsHeader("PROFIL & PREFERENSI"),
                _buildSettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: "Edit Profil & Informasi",
                  subtitle: "Ubah nama, nomor telepon, foto profil, & bio",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditDriverProfileScreen()));
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.tune_rounded,
                  title: "Preferensi Matching Klien",
                  subtitle: "Atur kriteria klien, jenis kendaraan, & kategori tour",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverMatchingPrefsScreen()));
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.photo_library_outlined,
                  title: "Kelola Feed & Postingan Aktivitas",
                  subtitle: "Buat atau hapus postingan galeri di profil driver",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverPostsScreen()));
                  },
                ),
                const SizedBox(height: 16),

                // SECTION 2: OPERASIONAL & NOTIFIKASI
                _buildSettingsHeader("OPERASIONAL & NOTIFIKASI"),
                _buildSettingsTile(
                  icon: Icons.notifications_active_outlined,
                  title: "Notifikasi & Dering Request Order",
                  subtitle: "Suara nada dering, getar, & pop-up pesanan baru",
                  trailingWidget: Switch(
                    value: true,
                    activeColor: AppTheme.primaryPink,
                    onChanged: (val) {},
                  ),
                ),
                _buildSettingsTile(
                  icon: Icons.map_outlined,
                  title: "Area Operasi & Radius Penjemputan",
                  subtitle: "Jakarta, Tangerang, Bandung, & sekitarnya",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Area operasional aktif di Jabodetabek & Bandung")),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // SECTION 3: BANTUAN & PRIVASI
                _buildSettingsHeader("KEAMANAN & BANTUAN"),
                _buildSettingsTile(
                  icon: Icons.support_agent_rounded,
                  title: "Pusat Bantuan & CS 24/7",
                  subtitle: "Hubungi tim dukungan jika ada pertanyaan/kendala",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Layanan CS Temenin Ajaa Siap 24/7 di WhatsApp: 0812-3456-7890")),
                    );
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: "Keamanan Akun & Kata Sandi",
                  subtitle: "Kelola kata sandi & otentikasi dua langkah",
                  onTap: () {},
                ),
                const SizedBox(height: 20),

                // SECTION 4: KELUAR / LOGOUT
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      auth.logout();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const DriverLoginScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: AppTheme.danger,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.3), width: 1),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(
                      "KELUAR DARI AKUN DRIVER",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.primaryPink,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailingWidget,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.fuchsiaLight,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primaryPink, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
        ),
        trailing: trailingWidget ?? const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
        onTap: onTap,
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
