import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import 'chat_room_screen.dart';

class DriverChatListScreen extends StatefulWidget {
  const DriverChatListScreen({super.key});

  @override
  State<DriverChatListScreen> createState() => _DriverChatListScreenState();
}

class _ChatRoomItem {
  final String bookingId;
  final String name;
  final String msg;
  final String time;
  final int unread;
  final String img;
  final String tag;
  final bool isSupport;

  _ChatRoomItem({
    required this.bookingId,
    required this.name,
    required this.msg,
    required this.time,
    required this.unread,
    required this.img,
    required this.tag,
    this.isSupport = false,
  });
}

class _DriverChatListScreenState extends State<DriverChatListScreen> {
  List<_ChatRoomItem> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    _loadMockChats();
  }

  void _loadMockChats() {
    if (!mounted) return;
    setState(() {
      _conversations = [];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton(
        onPressed: _loadConversations,
        backgroundColor: AppTheme.primaryPink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBgGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadConversations,
                        color: AppTheme.primaryPink,
                        backgroundColor: const Color(0xFF16141D),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10),
                              _buildSearchBar(),
                              const SizedBox(height: 25),
                              _buildChatList(),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final avatar = auth.user?.avatarUrl ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Chat Klien",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textHighContrast,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cardDeep,
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.cardDeep,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty ? const Icon(Icons.person, color: AppTheme.primaryPink, size: 18) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
        decoration: InputDecoration(
          icon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
          hintText: "Cari percakapan klien...",
          hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppTheme.cardDeep,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.textMuted, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                "Belum ada riwayat percakapan.",
                style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                "Chat dengan klien aktif akan tampil di sini.",
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _conversations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final chat = _conversations[index];
        bool hasUnread = chat.unread > 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DriverChatRoomScreen(
                  bookingId: chat.bookingId,
                  clientName: chat.name,
                  clientImage: chat.img,
                ),
              ),
            ).then((_) {
              _loadConversations();
            });
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasUnread
                    ? AppTheme.primaryPink
                    : AppTheme.border,
                width: hasUnread ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasUnread ? AppTheme.primaryPink.withOpacity(0.08) : Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildChatAvatar(chat),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            chat.name,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textHighContrast,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            chat.time,
                            style: GoogleFonts.inter(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.msg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: hasUnread
                                    ? AppTheme.primaryPink
                                    : AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: chat.isSupport
                                  ? Colors.blue.withOpacity(0.12)
                                  : AppTheme.primaryPink.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              chat.tag,
                              style: GoogleFonts.plusJakartaSans(
                                color: chat.isSupport ? Colors.blue : AppTheme.primaryPink,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
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
      },
    );
  }

  Widget _buildChatAvatar(_ChatRoomItem chat) {
    bool hasUnread = chat.unread > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.cardDeep,
          backgroundImage: chat.img.isNotEmpty ? NetworkImage(chat.img) : null,
          child: chat.isSupport
              ? const Icon(Icons.headset_mic_rounded, color: AppTheme.primaryPink, size: 22)
              : (chat.img.isEmpty ? const Icon(Icons.person, color: AppTheme.textMuted, size: 22) : null),
        ),
        if (hasUnread)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: AppTheme.primaryPink, shape: BoxShape.circle),
              child: Text(
                chat.unread.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

