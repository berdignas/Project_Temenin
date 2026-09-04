import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/providers/auth_provider.dart';
import 'package:temenin_ajaa/providers/community_provider.dart';
import 'package:temenin_ajaa/modules/clients/community/widgets/story_viewer.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/antar_jemput_booking_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/hangout_booking_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/freedom_request_booking_screen.dart';
import 'package:temenin_ajaa/modules/clients/driver/screens/partner_list_screen.dart';

class CommunityColors {
  static const Color deepVoid = AppTheme.background;
  static const Color obsidian = AppTheme.surface;
  static const Color elevatedDark = AppTheme.cardDeep;
  static const Color electricPink = AppTheme.primaryPink;
  static const Color roseGold = Color(0xFFD9A86C);
  static const Color textMuted = AppTheme.textMuted;
  static const Color textMain = AppTheme.textHighContrast;
}

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final ImagePicker _picker = ImagePicker();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityProvider>().fetchCommunityData();
    });
  }

  void _showStory(List<Map<String, dynamic>> stories, int startIndex) {
    if (stories.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StoryViewer(
          stories: stories,
          startIndex: startIndex,
          onBookingTap: (name, rating) => _showBookingModal(context, name, rating),
        ),
      ),
    );
  }

  void _showCreateStoryDialog(BuildContext context) {
    final captionCtrl = TextEditingController();
    XFile? pickedFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
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
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Buat Story 24 Jam',
                    style: GoogleFonts.inter(
                      color: AppTheme.textHighContrast,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () async {
                      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (file != null) {
                        setModalState(() {
                          pickedFile = file;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppTheme.cardDeep,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: pickedFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(File(pickedFile!.path), fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_a_photo_rounded, color: AppTheme.primaryPink, size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  'Pilih Foto dari Galeri',
                                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: captionCtrl,
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast),
                    decoration: InputDecoration(
                      hintText: 'Tuliskan caption story...',
                      hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.cardDeep,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (pickedFile != null) {
                          context.read<CommunityProvider>().addStory(
                            name: 'Saya',
                            avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
                            image: pickedFile!.path,
                            title: 'Story Saya',
                            caption: captionCtrl.text,
                            localFilePath: pickedFile!.path,
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Story berhasil dibagikan! 🎉')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Upload Story',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
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

  void _showCreatePostDialog(BuildContext context) {
    final captionCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    XFile? pickedFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
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
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Buat Postingan Feed Komunitas',
                    style: GoogleFonts.inter(
                      color: AppTheme.textHighContrast,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () async {
                      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (file != null) {
                        setModalState(() {
                          pickedFile = file;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppTheme.cardDeep,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: pickedFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(File(pickedFile!.path), fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primaryPink, size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  'Pilih Foto Momen Bersama',
                                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: locationCtrl,
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast),
                    decoration: InputDecoration(
                      hintText: 'Lokasi (misal: Senopati, Jaksel)',
                      hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.cardDeep,
                      prefixIcon: const Icon(Icons.location_on_rounded, color: AppTheme.primaryPink, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: captionCtrl,
                    maxLines: 2,
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast),
                    decoration: InputDecoration(
                      hintText: 'Tuliskan caption momen pendampingan...',
                      hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.cardDeep,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (pickedFile != null && captionCtrl.text.isNotEmpty) {
                          context.read<CommunityProvider>().addPost(
                            partnerName: 'Saya',
                            avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
                            image: pickedFile!.path,
                            caption: captionCtrl.text,
                            location: locationCtrl.text.isNotEmpty ? locationCtrl.text : 'Jakarta',
                            localFilePath: pickedFile!.path,
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Postingan berhasil dibagikan ke Feed! ✨')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Bagikan ke Feed',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
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

  void _showCommentsModal(BuildContext context, Map<String, dynamic> post) {
    final commentCtrl = TextEditingController();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userName = authProvider.user?.fullName ?? 'Pengguna Temenin';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final comments = (post['commentsList'] as List? ?? []).map((c) => Map<String, dynamic>.from(c as Map)).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Komentar Komunitas",
                      style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppTheme.border, height: 1),

                    Expanded(
                      child: comments.isEmpty
                          ? Center(
                              child: Text(
                                "Belum ada komentar. Jadilah yang pertama berkomentar!",
                                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: comments.length,
                              itemBuilder: (context, idx) {
                                final c = comments[idx];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AppTheme.fuchsiaLight,
                                        child: Text(
                                          (c['author'] ?? 'U')[0].toUpperCase(),
                                          style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c['author'] ?? 'Pengguna',
                                              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              c['text'] ?? '',
                                              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, height: 1.3),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDeep,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentCtrl,
                              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: "Tuliskan komentar Anda...",
                                hintStyle: TextStyle(color: AppTheme.textMuted),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: AppTheme.primaryPink, size: 20),
                            onPressed: () {
                              final text = commentCtrl.text.trim();
                              if (text.isNotEmpty) {
                                context.read<CommunityProvider>().addComment(post['id'], userName, text);
                                commentCtrl.clear();
                                setModalState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBookingModal(BuildContext context, String partnerName, double rating) {
    final partner = {
      'name': partnerName,
      'rating': rating.toString(),
      'image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      'vehicle': 'Vespa Primavera',
      'price': 150000,
      'type': 'Platinum',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Layanan untuk $partnerName',
                style: GoogleFonts.inter(
                  color: AppTheme.textHighContrast,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.fuchsiaLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.directions_bike_rounded, color: AppTheme.primaryPink),
                ),
                title: Text('Ride Service', style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Diantar dengan aman & tepat waktu', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AntarJemputBookingScreen(selectedPartner: partner),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.fuchsiaLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_cafe_rounded, color: AppTheme.primaryPink),
                ),
                title: Text('Hangout Service', style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Teman nongkrong di cafe/restoran', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HangoutBookingScreen(selectedPartner: partner),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.fuchsiaLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryPink),
                ),
                title: Text('Freedom Request', style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Kustomisasi acara & tawar harga sendiri', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FreedomRequestBookingScreen(selectedPartner: partner),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSearchBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cari Postingan / Partner',
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast),
                    decoration: InputDecoration(
                      hintText: 'Ketik nama partner atau kata kunci...',
                      hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryPink),
                      filled: true,
                      fillColor: AppTheme.cardDeep,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Terapkan Pencarian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  @override
  Widget build(BuildContext context) {
    final communityProvider = context.watch<CommunityProvider>();
    final stories = communityProvider.stories;
    final posts = communityProvider.posts;

    final filteredPosts = _searchQuery.isEmpty
        ? posts
        : posts.where((p) {
            final name = (p['partnerName'] ?? '').toString().toLowerCase();
            final caption = (p['caption'] ?? '').toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || caption.contains(query);
          }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<CommunityProvider>().fetchCommunityData();
          },
          color: AppTheme.primaryPink,
          backgroundColor: AppTheme.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverAppBar(
                backgroundColor: AppTheme.background,
                floating: true,
                pinned: false,
                title: Text(
                  'Komunitas Partner',
                  style: GoogleFonts.inter(
                    color: AppTheme.textHighContrast,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.fuchsiaLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primaryPink, size: 20),
                    ),
                    tooltip: 'Buat Postingan Feed',
                    onPressed: () => _showCreatePostDialog(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: AppTheme.textHighContrast, size: 22),
                    tooltip: 'Cari Postingan / Profil',
                    onPressed: () => _showSearchBottomSheet(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.people_alt_outlined, color: AppTheme.textHighContrast, size: 22),
                    tooltip: 'Available Partners',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PartnerListScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              SliverToBoxAdapter(
                child: Container(
                  height: 110,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: stories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 16, right: 12),
                          child: GestureDetector(
                            onTap: () => _showCreateStoryDialog(context),
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.border, width: 1.5),
                                  ),
                                  child: const Icon(Icons.add, color: AppTheme.primaryPink, size: 28),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Buat Story',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textHighContrast,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final story = stories[index - 1];
                      final avatarUrl = story['avatar'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb';
                      final storyName = story['name'] ?? 'Driver';

                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => _showStory(stories, index - 1),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.primaryPink, width: 2),
                                ),
                                child: CircleAvatar(
                                  backgroundImage: NetworkImage(avatarUrl),
                                  backgroundColor: AppTheme.cardDeep,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                storyName,
                                style: GoogleFonts.inter(
                                  color: AppTheme.textHighContrast,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _searchQuery.isEmpty ? 'Momen Komunitas Terkini' : 'Hasil Pencarian: "$_searchQuery"',
                        style: GoogleFonts.inter(
                          color: AppTheme.textHighContrast,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _searchQuery = ''),
                          child: Text(
                            'Reset Filter',
                            style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (filteredPosts.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.photo_library_outlined, color: AppTheme.textMuted, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada postingan komunitas',
                            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Jadilah yang pertama membagikan momen seru Anda!',
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final post = filteredPosts[index];
                      final isLiked = post['isLiked'] as bool? ?? false;
                      final likesCount = post['likes'] ?? 0;
                      final commentsCount = post['comments'] ?? 0;
                      final imgUrl = post['image'] as String? ?? '';
                      final partnerName = post['partnerName'] ?? 'Mitra Temenin Ajaa';
                      final avatar = post['avatar'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb';

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundImage: NetworkImage(avatar),
                                    onBackgroundImageError: (_, __) {},
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                partnerName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  color: AppTheme.textHighContrast,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.verified, color: AppTheme.success, size: 14),
                                          ],
                                        ),
                                        Text(
                                          "📍 ${post['location'] ?? 'Jakarta'} • ${post['time'] ?? 'Baru saja'}",
                                          style: GoogleFonts.inter(
                                            color: AppTheme.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _showBookingModal(context, partnerName, (post['rating'] as num?)?.toDouble() ?? 4.9),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryPink,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                                      minimumSize: const Size(60, 32),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      'Booking',
                                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (imgUrl.isNotEmpty)
                              ClipRRect(
                                child: AspectRatio(
                                  aspectRatio: 4 / 3,
                                  child: Image.network(
                                    imgUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppTheme.cardDeep,
                                      child: const Center(child: Icon(Icons.broken_image, color: AppTheme.textMuted, size: 36)),
                                    ),
                                  ),
                                ),
                              ),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      context.read<CommunityProvider>().toggleLike(post['id']);
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                          isLiked ? Icons.favorite : Icons.favorite_border_rounded,
                                          color: isLiked ? Colors.red : AppTheme.textHighContrast,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$likesCount',
                                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  GestureDetector(
                                    onTap: () => _showCommentsModal(context, post),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.textHighContrast, size: 20),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$commentsCount',
                                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.bookmark_border_rounded, color: AppTheme.textHighContrast, size: 22),
                                ],
                              ),
                            ),

                            if ((post['caption'] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 14, right: 14, bottom: 8, top: 2),
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, height: 1.4),
                                    children: [
                                      TextSpan(
                                        text: '$partnerName ',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(text: post['caption']),
                                    ],
                                  ),
                                ),
                              ),

                            Padding(
                              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
                              child: GestureDetector(
                                onTap: () => _showCommentsModal(context, post),
                                child: Text(
                                  commentsCount > 0
                                      ? "Lihat semua $commentsCount komentar..."
                                      : "Tambahkan komentar...",
                                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 400.ms, delay: (index * 100).ms).slideY(begin: 0.1, end: 0);
                    },
                    childCount: filteredPosts.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ),
      ),
    );
  }
}
