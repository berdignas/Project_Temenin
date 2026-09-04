import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
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

    final bool hasLocalAvatar = avatar.isNotEmpty && File(avatar).existsSync();
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
    final bool hasLocalFile = localFilePath != null && localFilePath.isNotEmpty && File(localFilePath).existsSync();

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
                                        return File(path).existsSync()
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
                              : (localPath != null && File(localPath).existsSync())
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
              onTap: () => _showVehicleDetailModal(context, v, isCar, isActive, idx),
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

  // ================= TAB 3: JADWAL DRIVER (FULL MONTH SQUARE DATE BOXES) =================
  Widget _buildTabSchedule() {
    final bookingProvider = context.watch<BookingProvider>();
    final activeBooking = bookingProvider.activeBooking;
    final bookingsList = bookingProvider.bookings;

    final now = DateTime.now();
    final totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final monthName = _getMonthName(now.month);
    final monthFullName = _getFullMonthName(now.month);

    final days = List.generate(totalDaysInMonth, (i) {
      final date = DateTime(now.year, now.month, i + 1);
      final dayName = _getDayName(date.weekday);
      final shortDay = _getShortDayName(date.weekday);
      final dateNum = (i + 1).toString().padLeft(2, '0');
      final isBooked = (i == 3 || i == 6 || i == 14 || i == 21);

      return {
        'day': dayName,
        'shortDay': shortDay,
        'dateNum': dateNum,
        'date': '$dateNum $monthName',
        'fullDate': '$dayName, $dateNum $monthFullName ${now.year}',
        'hours': isBooked ? '09:00 - 17:00 WIB (Terisi Penugasan)' : '08:00 - 22:00 WIB (Siap Order)',
        'status': isBooked ? 'Booked' : 'Available',
      };
    });

    final safeIndex = _selectedScheduleDayIndex < days.length ? _selectedScheduleDayIndex : 0;
    final selectedDay = days[safeIndex];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Jadwal & Ketersediaan Jam Kerja",
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textHighContrast,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            "Klik kotak tanggal di bawah untuk melihat deskripsi jam operasional",
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // SQUARE DATE BOXES ROW
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedScheduleDayIndex;
                final d = days[index];
                final isBooked = d['status'] == 'Booked';

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedScheduleDayIndex = index;
                    });
                    // Open detailed schedule modal on click
                    _showScheduleHoursModal(context, d, activeBooking, bookingsList);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryPink : AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryPink
                            : (isBooked ? AppTheme.primaryPink.withOpacity(0.5) : AppTheme.border),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryPink.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          d['shortDay']!,
                          style: GoogleFonts.plusJakartaSans(
                            color: isSelected ? Colors.white70 : AppTheme.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d['dateNum']!,
                          style: GoogleFonts.plusJakartaSans(
                            color: isSelected ? Colors.white : AppTheme.textHighContrast,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Colors.white
                                : (isBooked ? AppTheme.primaryPink : AppTheme.success),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Selected Square Date Summary Card
          GestureDetector(
            onTap: () => _showScheduleHoursModal(context, selectedDay, activeBooking, bookingsList),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selectedDay['status'] == 'Booked'
                      ? AppTheme.primaryPink.withOpacity(0.5)
                      : AppTheme.border,
                ),
                boxShadow: [
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time_filled_rounded, color: AppTheme.primaryPink, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "${selectedDay['day']}, ${selectedDay['date']}",
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textHighContrast,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: selectedDay['status'] == 'Booked'
                              ? AppTheme.primaryPink.withOpacity(0.12)
                              : AppTheme.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          selectedDay['status'] == 'Booked' ? "ADA PENUGASAN" : "KOSONG / READY",
                          style: GoogleFonts.plusJakartaSans(
                            color: selectedDay['status'] == 'Booked' ? AppTheme.primaryPink : AppTheme.success,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "⏰ Jam Kerja: ${selectedDay['hours']}",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textHighContrast,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Klik di sini untuk melihat deskripsi lengkap jam operasional untuk Driver & Klien ➔",
                    style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
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
  ) {
    final photos = isCar
        ? [
            'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=800',
            'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=800',
            'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=800',
          ]
        : [
            'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=800',
            'https://images.unsplash.com/photo-1568772585407-9361f9bf3a87?w=800',
            'https://images.unsplash.com/photo-1558981806-ec527fa84c39?w=800',
          ];

    int currentPhotoIndex = 0;

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
                  const SizedBox(height: 18),

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
                      onPressed: () {
                        if (!isActive) {
                          setState(() {});
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

  // 2. SCHEDULE HOURS MODAL (Operational Description for Driver & Client)
  void _showScheduleHoursModal(
    BuildContext context,
    Map<String, dynamic> dayData,
    dynamic activeBooking,
    List<dynamic> bookingsList,
  ) {
    final isBooked = dayData['status'] == 'Booked' || activeBooking != null || bookingsList.isNotEmpty;

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

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${dayData['day']}, ${dayData['date']}",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textHighContrast,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        "Jadwal & Ketersediaan Jam Kerja Driver",
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBooked
                          ? AppTheme.primaryPink.withValues(alpha: 0.12)
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isBooked ? AppTheme.primaryPink : Colors.green.shade300,
                      ),
                    ),
                    child: Text(
                      isBooked ? "TERISI PENUGASAN" : "READY / KOSONG",
                      style: GoogleFonts.plusJakartaSans(
                        color: isBooked ? AppTheme.primaryPink : AppTheme.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Hours Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPink.withValues(alpha: 0.25),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.alarm_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "JAM OPERASIONAL MITRA",
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          dayData['hours'] ?? '08:00 - 22:00 WIB',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Detailed Description (for both Driver & Client)
              Text(
                "Deskripsi Ketersediaan Jam (Driver & Klien)",
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardDeep,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppTheme.primaryPink, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isBooked
                                ? "Pada tanggal ${dayData['date']}, Mitra Driver telah terisi pesanan penugasan khusus dari pukul 09:00 hingga 17:00 WIB. Pelanggan dapat memesan di luar jam penugasan tersebut."
                                : "Pada tanggal ${dayData['date']}, Mitra Driver aktif dan siap menerima orderan pendampingan, perjalan lokal, maupun luar kota dari pukul ${dayData['hours']}.",
                            style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: AppTheme.border, height: 20),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "Dapat disesuaikan secara fleksibel dengan Klien",
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Close / Done Button
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
                    "MENGERTI / TUTUP",
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

  void _showAddVehicleModal(BuildContext context, List<Map<String, dynamic>> currentVehicles) {
    final nameController = TextEditingController();
    final plateController = TextEditingController();
    String type = 'Motor';

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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isNotEmpty && plateController.text.isNotEmpty) {
                          setState(() {
                            currentVehicles.add({
                              'type': type,
                              'name': nameController.text.trim(),
                              'plate_number': plateController.text.toUpperCase().trim(),
                              'age': '< 5 Tahun',
                            });
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Kendaraan baru berhasil ditambahkan!"), backgroundColor: AppTheme.primaryPink),
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
