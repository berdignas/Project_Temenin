// lib/modules/chat/screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import '../../../../providers/auth_provider.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _mockChats = [
    {
      'id': '1',
      'name': 'Sarah Jenkins (Diamond Partner)',
      'image': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
      'lastMessage': 'Halo kak! Saya sudah standby di lobi Senopati ya ✨',
      'time': '12:45',
      'unread': 2,
      'isOnline': true,
      'tag': 'Companion',
      'category': 'companion',
    },
    {
      'id': '2',
      'name': 'Budi Santoso (Driver VIP)',
      'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80',
      'lastMessage': 'Siap meluncur jemput di titik penjemputan bandara.',
      'time': 'Kemarin',
      'unread': 0,
      'isOnline': false,
      'tag': 'Driver',
      'category': 'driver',
    },
    {
      'id': '3',
      'name': 'Jessica Mila (VVIP Escort)',
      'image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
      'lastMessage': 'Terima kasih untuk hangout dinner kemarin kak! Senang bertemu.',
      'time': '20 Okt',
      'unread': 0,
      'isOnline': true,
      'tag': 'Companion',
      'category': 'companion',
    },
    {
      'id': '4',
      'name': 'Ahmad Fauzi (Freedom Runner)',
      'image': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=150&q=80',
      'lastMessage': 'Tiket konser sudah berhasil saya belikan kak. Struknya terlampir.',
      'time': '18 Okt',
      'unread': 0,
      'isOnline': false,
      'tag': 'Runner',
      'category': 'driver',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _buildSearchBar(),
            ),
            const SizedBox(height: 10),
            _buildOnlineStories(),
            const SizedBox(height: 10),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChatList('all'),
                  _buildChatList('companion'),
                  _buildChatList('driver'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Mulai pesan baru dari daftar kontak / partner."),
              backgroundColor: AppTheme.primaryPink,
            ),
          );
        },
        backgroundColor: AppTheme.primaryPink,
        child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final avatar = auth.user?.avatarUrl ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Pesan",
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textHighContrast,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.fuchsiaLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3), width: 1.5),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.surface,
              backgroundImage: NetworkImage(avatar),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Cari percakapan...",
                hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineStories() {
    final users = [
      {'name': 'Saya', 'img': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80', 'isMe': true},
      {'name': 'Raditya', 'img': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=150&q=80', 'isMe': false},
      {'name': 'Siska', 'img': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80', 'isMe': false},
      {'name': 'Adrian', 'img': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=150&q=80', 'isMe': false},
      {'name': 'Citra', 'img': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=150&q=80', 'isMe': false},
    ];

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: users.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final user = users[index];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: user['isMe'] == false 
                          ? Border.all(color: AppTheme.primaryPink, width: 2)
                          : Border.all(color: AppTheme.border, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: AppTheme.surface,
                      backgroundImage: NetworkImage(user['img'] as String),
                    ),
                  ),
                  if (user['isMe'] == true)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryPink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                user['name'] as String,
                style: GoogleFonts.inter(
                  color: AppTheme.textHighContrast,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      height: 38,
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.primaryPink,
          borderRadius: BorderRadius.circular(20),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textMuted,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 12),
        tabs: const [
          Tab(text: "Semua"),
          Tab(text: "Companion"),
          Tab(text: "Driver"),
        ],
      ),
    );
  }

  Widget _buildChatList(String category) {
    final filteredChats = _mockChats.where((chat) {
      if (category == 'all') return true;
      return chat['category'] == category;
    }).toList();

    if (filteredChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              "Belum ada pesan pada kategori ini",
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: filteredChats.length,
      itemBuilder: (context, index) {
        final chat = filteredChats[index];
        return _buildChatTile(chat);
      },
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final hasUnread = (chat['unread'] as int) > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatRoomScreen(
                recipientName: chat['name'],
                recipientImage: chat['image'],
                status: chat['isOnline'] ? "Online" : "Offline",
                tag: chat['tag'],
              ),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.cardDeep,
              backgroundImage: NetworkImage(chat['image']),
            ),
            if (chat['isOnline'] == true)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                chat['name'],
                style: GoogleFonts.inter(
                  color: AppTheme.textHighContrast,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              chat['time'],
              style: GoogleFonts.inter(
                color: hasUnread ? AppTheme.primaryPink : AppTheme.textMuted,
                fontSize: 11,
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  chat['lastMessage'],
                  style: GoogleFonts.inter(
                    color: hasUnread ? AppTheme.textHighContrast : AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasUnread)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryPink,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    chat['unread'].toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}