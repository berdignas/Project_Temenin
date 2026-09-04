import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/community_provider.dart';
import 'driver_posts_screen.dart';
import 'driver_story_viewer_screen.dart';
import 'instagram_story_editor_screen.dart';

class DriverCommunityScreen extends StatefulWidget {
  const DriverCommunityScreen({super.key});

  @override
  State<DriverCommunityScreen> createState() => _DriverCommunityScreenState();
}

class _DriverCommunityScreenState extends State<DriverCommunityScreen> {
  void _showStoryDetail(BuildContext context, List<Map<String, dynamic>> stories, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverStoryViewerScreen(
          stories: stories,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
  void _showInstagramCommentsModal(BuildContext context, Map<String, dynamic> post) {
    final commentCtrl = TextEditingController();
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final userName = user?.fullName ?? 'Driver Temenin Ajaa';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final comments = (post['commentsList'] as List? ?? []).map((c) => Map<String, dynamic>.from(c as Map)).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Komentar Postingan Instagram",
                      style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppTheme.border, height: 1),

                    // Comments List
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
                                        backgroundColor: AppTheme.primaryPink.withOpacity(0.12),
                                        child: Text(
                                          (c['author'] ?? 'D')[0].toUpperCase(),
                                          style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c['author'] ?? 'Driver Partner',
                                              style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              c['text'] ?? '',
                                              style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12, height: 1.3),
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

                    // Input Textfield
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
                                hintText: "Tambahkan komentar Anda...",
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

  @override
  Widget build(BuildContext context) {
    final community = context.watch<CommunityProvider>();
    final stories = community.stories;
    final posts = community.posts;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Text(
          'Komunitas Partner',
          style: GoogleFonts.plusJakartaSans(
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
                color: AppTheme.primaryPink.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_box_rounded, color: AppTheme.primaryPink, size: 20),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DriverPostsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkBgGradient),
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<CommunityProvider>().fetchCommunityData();
          },
          color: AppTheme.primaryPink,
          backgroundColor: AppTheme.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
            // Stories Bar (Instagram Story Highlights)
            SliverToBoxAdapter(
              child: Container(
                height: 110,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: stories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 16, right: 12),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const InstagramStoryEditorScreen()),
                            );
                          },
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.border, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.add, color: AppTheme.primaryPink, size: 24),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Buat Story',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textHighContrast,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final story = stories[index - 1];
                    final String? localPath = story['localFilePath'];
                    final String imgUrl = story['image'] ?? story['avatar'] ?? '';

                    return GestureDetector(
                      onTap: () => _showStoryDetail(context, stories, index - 1),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.heroGradient,
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: AppTheme.surface,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: (localPath != null && localPath.isNotEmpty && File(localPath).existsSync())
                                      ? Image.file(File(localPath), fit: BoxFit.cover)
                                      : Image.network(imgUrl, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (story['title'] ?? story['name'] ?? 'Story').split(' ')[0],
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textHighContrast,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
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

            // Postingan Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Postingan Terkini (${posts.length})',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textHighContrast,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.tune_rounded, color: AppTheme.textMuted, size: 18),
                  ],
                ),
              ),
            ),

            // Empty State if no posts yet
            if (posts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPink.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.photo_camera_back_rounded, color: AppTheme.primaryPink, size: 48),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Komunitas Masih Sepi',
                          style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Jadilah Mitra Driver pertama yang mengunggah foto / video reels Instagram hari ini!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const DriverPostsScreen()));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPink,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 16),
                          label: Text(
                            'Buat Postingan Pertama',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
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
                    final post = posts[index];
                    final String? localPath = post['localFilePath'];
                    final String imgUrl = post['image'] ?? '';
                    final isVideo = post['mediaType'] == 'video';
                    final comments = (post['commentsList'] as List? ?? []).map((c) => Map<String, dynamic>.from(c as Map)).toList();

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.border),
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
                          // Header Author Profile
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppTheme.heroGradient,
                                  ),
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundImage: NetworkImage(post['avatar']),
                                  ),
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
                                              post['partnerName'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 14),
                                        ],
                                      ),
                                      Text(
                                        "📍 ${post['location'] ?? 'Jakarta'} • ${post['time']}",
                                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 20),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),

                          // Instagram Post Image / Video Media Box (Double tap to like)
                          GestureDetector(
                            onDoubleTap: () {
                              context.read<CommunityProvider>().toggleLike(post['id']);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: (post['localFilePaths'] != null && (post['localFilePaths'] as List).length > 1)
                                    ? Stack(
                                        children: [
                                          PageView.builder(
                                            itemCount: (post['localFilePaths'] as List).length,
                                            itemBuilder: (context, photoIndex) {
                                              final path = (post['localFilePaths'] as List)[photoIndex].toString();
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
                                                color: Colors.black.withOpacity(0.7),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                "📸 ${(post['localFilePaths'] as List).length} Foto",
                                                style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          (localPath != null && localPath.isNotEmpty && File(localPath).existsSync())
                                              ? Image.file(File(localPath), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                                              : (imgUrl.isNotEmpty
                                                  ? Image.network(imgUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                                                  : Container(
                                                      color: AppTheme.cardDeep,
                                                      child: const Center(child: Icon(Icons.photo_rounded, color: AppTheme.textMuted, size: 48)),
                                                    )),
                                          if (isVideo)
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                                            ),
                                        ],
                                      ),
                              ),
                            ),
                          ),

                          // Instagram Actions Bar (Like, Comment, Share, Bookmark)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    context.read<CommunityProvider>().toggleLike(post['id']);
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        (post['isLiked'] as bool? ?? false) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                        color: (post['isLiked'] as bool? ?? false) ? AppTheme.primaryPink : AppTheme.textMuted,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${post['likes'] ?? 0}',
                                        style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),

                                // Comment Trigger Button
                                GestureDetector(
                                  onTap: () => _showInstagramCommentsModal(context, post),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.textMuted, size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${comments.length}',
                                        style: GoogleFonts.plusJakartaSans(color: AppTheme.textMediumContrast, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                const Icon(Icons.send_rounded, color: AppTheme.textMuted, size: 18),
                                const Spacer(),
                                const Icon(Icons.bookmark_border_rounded, color: AppTheme.textMuted, size: 20),
                              ],
                            ),
                          ),

                          // Caption & Hashtags
                          Padding(
                            padding: const EdgeInsets.only(left: 14, right: 14, bottom: 16, top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, height: 1.4),
                                    children: [
                                      TextSpan(
                                        text: '${post['partnerName']} ',
                                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
                                      ),
                                      TextSpan(text: post['caption']),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Instagram Comment Drawer Trigger Text
                                GestureDetector(
                                  onTap: () => _showInstagramCommentsModal(context, post),
                                  child: Text(
                                    comments.isNotEmpty
                                        ? "Lihat semua ${comments.length} komentar..."
                                        : "Tambahkan komentar...",
                                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: posts.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 50)),
          ],
        ),
      ),
    ),
  );
}
}
