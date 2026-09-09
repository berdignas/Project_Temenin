// lib/modules/clients/chat/screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/driver_provider.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _liveChats = [];
  bool _isLoadingLive = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    _loadLiveChats();
  }

  Future<void> _loadLiveChats() async {
    setState(() => _isLoadingLive = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.user?.id ?? Supabase.instance.client.auth.currentUser?.id;
      
      var query = Supabase.instance.client.from('bookings').select();
      if (userId != null && userId.contains('-')) {
        query = query.eq('user_id', userId);
      }
      
      final data = await query.order('created_at', ascending: false).limit(15);
      if (data.isNotEmpty) {
        final List<Map<String, dynamic>> loaded = [];
        for (final b in data) {
          final details = b['additional_details'] as Map<String, dynamic>?;
          final msgs = (details?['chat_messages'] as List<dynamic>?)
              ?.map((m) => Map<String, dynamic>.from(m as Map))
              .toList() ?? [];
          
          if (!mounted) return;
          final driverProv = Provider.of<DriverProvider>(context, listen: false);
          final dId = b['driver_id']?.toString() ?? details?['driver_id']?.toString();
          Map<String, dynamic>? currentDriver;
          if (dId != null) {
            try {
              currentDriver = driverProv.drivers.firstWhere((d) => d['id'] == dId || d['driverId'] == dId);
            } catch (_) {}
          }
          final driverName = currentDriver?['name'] ?? details?['driverName'] ?? details?['driver_name'] ?? 'Driver Partner';
          final driverImage = currentDriver?['image'] ?? details?['driverImage'] ?? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80';
          final lastMsg = msgs.isNotEmpty ? msgs.last['text']?.toString() ?? 'Mulai percakapan...' : 'Pesanan baru aktif';
          final lastTime = msgs.isNotEmpty ? msgs.last['time']?.toString() ?? 'Baru saja' : 'Baru saja';
          final bookingStatus = b['status']?.toString() ?? 'ongoing';
          final serviceType = b['service_type']?.toString().toLowerCase() ?? 'driver';
          final isCompanion = serviceType.contains('companion') || serviceType.contains('teman');
          
          loaded.add({
            'id': b['id'].toString(),
            'bookingId': b['id'].toString(),
            'name': driverName,
            'image': driverImage,
            'lastMessage': lastMsg,
            'time': lastTime,
            'unread': msgs.isEmpty ? 1 : 0,
            'isOnline': true,
            'tag': isCompanion ? 'Companion' : 'Driver',
            'category': isCompanion ? 'companion' : 'driver',
            'status': bookingStatus,
          });
        }
        if (mounted) {
          setState(() {
            _liveChats = loaded;
            _isLoadingLive = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingLive = false);
      }
    } catch (e) {
      debugPrint("Error loading live chats: $e");
      if (mounted) setState(() => _isLoadingLive = false);
    }
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
            const SizedBox(height: 8),
            _buildOnlineStories(),
            const SizedBox(height: 8),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text("Bantuan CS 24/7 Temenin Aja siap membantu.", style: GoogleFonts.inter(fontSize: 12.5)),
                ],
              ),
              backgroundColor: AppTheme.surface,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.primaryPink)),
            ),
          );
        },
        backgroundColor: AppTheme.primaryPink,
        elevation: 4,
        icon: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 20),
        label: Text(
          "Bantuan",
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final avatar = auth.user?.avatarUrl ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pesan & Aktivitas",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textHighContrast,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Hubungi mitra & teman perjalanan Anda",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: AppTheme.surface,
                  backgroundImage: NetworkImage(avatar),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.background, width: 2),
                  ),
                ),
              ),
            ],
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
        border: Border.all(color: _searchQuery.isNotEmpty ? AppTheme.primaryPink : AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppTheme.primaryPink, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Cari nama driver, teman, atau pesan...",
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
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
              },
              child: const Icon(Icons.cancel_rounded, color: AppTheme.textMuted, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildOnlineStories() {
    final driverProv = Provider.of<DriverProvider>(context, listen: false);
    final drivers = driverProv.drivers;

    // List of active companions / drivers
    final List<Map<String, dynamic>> stories = [
      {'name': 'Saya', 'img': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80', 'isMe': true, 'role': 'Akun'},
      if (drivers.isNotEmpty)
        ...drivers.take(6).map((d) => {
          'name': (d['name']?.toString() ?? 'Partner').split(' ').first,
          'img': d['image']?.toString() ?? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80',
          'isMe': false,
          'role': d['role'] ?? 'Driver',
        })
      else ...[
        {'name': 'Budi', 'img': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80', 'isMe': false, 'role': 'Driver'},
        {'name': 'Sarah', 'img': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80', 'isMe': false, 'role': 'Teman'},
        {'name': 'Dimas', 'img': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=150&q=80', 'isMe': false, 'role': 'Driver'},
      ]
    ];

    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final user = stories[index];
          final isMe = user['isMe'] == true;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: !isMe ? AppTheme.primaryGradient : null,
                      border: isMe ? Border.all(color: AppTheme.border, width: 2) : null,
                    ),
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: AppTheme.cardDeep,
                      backgroundImage: NetworkImage(user['img'] as String),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppTheme.background,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.primaryPink : AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                        child: isMe 
                            ? const Icon(Icons.add_rounded, color: Colors.white, size: 8)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                user['name'] as String,
                style: GoogleFonts.inter(
                  color: AppTheme.textHighContrast,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.primaryPink,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPink.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textMuted,
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
        tabs: const [
          Tab(text: "Semua"),
          Tab(text: "Companion"),
          Tab(text: "Driver"),
        ],
      ),
    );
  }

  Widget _buildChatList(String category) {
    if (_isLoadingLive) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
        ),
      );
    }

    final filteredChats = _liveChats.where((chat) {
      final matchesCategory = category == 'all' || chat['category'] == category;
      if (!matchesCategory) return false;

      if (_searchQuery.isEmpty) return true;
      final name = chat['name']?.toString().toLowerCase() ?? '';
      final lastMsg = chat['lastMessage']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery) || lastMsg.contains(_searchQuery);
    }).toList();

    if (filteredChats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded, size: 28, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              Text(
                _searchQuery.isNotEmpty 
                    ? "Tidak ditemukan percakapan '$_searchQuery'"
                    : "Belum ada riwayat percakapan",
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                "Saat Anda memesan driver atau teman jalan, ruang obrolan akan muncul otomatis di sini.",
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLiveChats,
      color: AppTheme.primaryPink,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: filteredChats.length,
        itemBuilder: (context, index) {
          final chat = filteredChats[index];
          return _buildChatTile(chat);
        },
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final hasUnread = (chat['unread'] as int) > 0;
    final tag = chat['tag']?.toString() ?? 'Partner';
    final isCompanion = tag == 'Companion';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: hasUnread ? AppTheme.cardDeep.withOpacity(0.9) : AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasUnread ? AppTheme.primaryPink.withOpacity(0.4) : AppTheme.border,
          width: hasUnread ? 1.2 : 1.0,
        ),
        boxShadow: [
          if (hasUnread)
            BoxShadow(
              color: AppTheme.primaryPink.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatRoomScreen(
                  bookingId: chat['bookingId'] ?? chat['id'],
                  recipientName: chat['name'],
                  recipientImage: chat['image'],
                  status: chat['isOnline'] ? "Online" : "Offline",
                  tag: tag,
                ),
              ),
            ).then((_) => _loadLiveChats());
          },
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                // Avatar with Live Status
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasUnread ? AppTheme.primaryPink : AppTheme.border,
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.cardDeep,
                        backgroundImage: NetworkImage(chat['image']),
                      ),
                    ),
                    if (chat['isOnline'] == true)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.surface, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Name & Message Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                chat['name'],
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textHighContrast,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isCompanion 
                                      ? const Color(0xFF6366F1).withOpacity(0.15) 
                                      : AppTheme.primaryPink.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: isCompanion ? const Color(0xFF818CF8) : AppTheme.primaryPink,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
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
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat['lastMessage'],
                              style: GoogleFonts.inter(
                                color: hasUnread ? AppTheme.textHighContrast : AppTheme.textMuted,
                                fontSize: 12.5,
                                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}