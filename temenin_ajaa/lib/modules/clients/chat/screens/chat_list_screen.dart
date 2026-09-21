// lib/modules/clients/chat/screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/driver_provider.dart';
import '../../pages/booking_history_page.dart';
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
  List<Map<String, dynamic>> _orderBubbles = [];
  Set<String> _dismissedBubbleIds = {};
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
    _loadDismissedBubbleIds().then((_) {
      _loadLiveChats();
    });
  }

  Future<void> _loadDismissedBubbleIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('dismissed_order_bubbles') ?? [];
      if (mounted) {
        setState(() {
          _dismissedBubbleIds = list.toSet();
        });
      }
    } catch (e) {
      debugPrint("Error loading dismissed bubbles: $e");
    }
  }

  Future<void> _dismissBubble(String bookingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('dismissed_order_bubbles') ?? [];
      if (!list.contains(bookingId)) {
        list.add(bookingId);
        await prefs.setStringList('dismissed_order_bubbles', list);
      }
      if (mounted) {
        setState(() {
          _dismissedBubbleIds.add(bookingId);
          _orderBubbles.removeWhere((b) => b['id']?.toString() == bookingId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text("Gelembung dihapus. Rincian tetap ada di menu Aktivitas.")),
              ],
            ),
            backgroundColor: AppTheme.card,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.border),
            ),
            action: SnackBarAction(
              label: "Buka Aktivitas",
              textColor: AppTheme.primaryPink,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookingHistoryPage()),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error dismissing bubble: $e");
    }
  }

  void _confirmDismissBubble(String bookingId, String serviceName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Hapus Gelembung?",
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Gelembung status pesanan '$serviceName' akan dihapus dari daftar pesan. Data pesanan Anda tetap aman dan dapat dilihat di menu Aktivitas.",
          style: GoogleFonts.inter(
            color: AppTheme.textMediumContrast,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Batal",
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _dismissBubble(bookingId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text("Hapus Gelembung", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showChatOptions(Map<String, dynamic> chat) {
    final name = chat['name']?.toString() ?? 'Partner';
    final bookingId = chat['bookingId']?.toString() ?? chat['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              "Pilihan Percakapan: $name",
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textHighContrast,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryPink),
              title: Text("Buka Chat Teks", style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatRoomScreen(
                      bookingId: bookingId,
                      recipientName: chat['name'],
                      recipientImage: chat['image'],
                      status: chat['isOnline'] == true ? "Online" : "Offline",
                      tag: chat['tag'],
                    ),
                  ),
                ).then((_) => _loadLiveChats());
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in_rounded, color: AppTheme.roseGold),
              title: Text("Buka di Halaman Aktivitas", style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookingHistoryPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
              title: Text("Hapus Percakapan dari Tampilan", style: GoogleFonts.inter(fontSize: 13.5, color: AppTheme.danger)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _liveChats.removeWhere((c) => c['bookingId'] == bookingId || c['id'] == bookingId);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Percakapan telah dihapus dari daftar.")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadLiveChats() async {
    setState(() => _isLoadingLive = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.user?.id ?? Supabase.instance.client.auth.currentUser?.id;
      
      List<dynamic> data = [];
      try {
        var query = Supabase.instance.client.from('bookings').select('*, drivers(*, users(*))');
        if (userId != null && userId.contains('-')) {
          query = query.eq('user_id', userId);
        }
        data = await query.order('created_at', ascending: false).limit(30);
      } catch (e) {
        debugPrint("Supabase join fetch error in chat list: $e. Retrying flat select...");
        var flatQuery = Supabase.instance.client.from('bookings').select();
        if (userId != null && userId.contains('-')) {
          flatQuery = flatQuery.eq('user_id', userId);
        }
        data = await flatQuery.order('created_at', ascending: false).limit(30);
      }

      if (data.isNotEmpty) {
        final driverProv = Provider.of<DriverProvider>(context, listen: false);
        final Map<String, Map<String, dynamic>> groupedMap = {};

        // Fetch latest messages from dedicated booking_messages table
        final List<String> bookingIds = [];
        for (final b in data) {
          final id = b['id']?.toString().trim();
          if (id != null && id.isNotEmpty && id != 'null') {
            bookingIds.add(id);
          }
        }

        final Map<String, Map<String, dynamic>> latestMessagesMap = {};
        if (bookingIds.isNotEmpty) {
          try {
            final msgsData = await Supabase.instance.client
                .from('booking_messages')
                .select('booking_id, message, created_at')
                .inFilter('booking_id', bookingIds)
                .order('created_at', ascending: true);

            for (final m in msgsData) {
              final bId = m['booking_id']?.toString();
              if (bId != null) {
                latestMessagesMap[bId] = m;
              }
            }
          } catch (e) {
            debugPrint("Notice: could not load recent booking_messages: $e");
          }
        }

        for (final b in data) {
          final details = b['additional_details'] as Map<String, dynamic>?;
          final msgs = (details?['chat_messages'] as List<dynamic>?)
              ?.map((m) => Map<String, dynamic>.from(m as Map))
              .toList() ?? [];
          
          if (!mounted) return;
          final dId = b['driver_id']?.toString() ?? details?['driver_id']?.toString() ?? details?['driverId']?.toString();
          Map<String, dynamic>? currentDriver;
          if (dId != null && dId.isNotEmpty) {
            try {
              currentDriver = driverProv.drivers.firstWhere((d) => d['id'] == dId || d['driverId'] == dId);
            } catch (_) {}
          }

          // Resolve driver profile name exhaustively
          String resolvedName = currentDriver?['name'] ??
              details?['driverName'] ??
              details?['driver_name'] ??
              details?['selectedPartner']?['name'] ??
              details?['partner']?['name'] ??
              details?['partnerName'] ??
              details?['name'] ??
              '';

          if (resolvedName.isEmpty || resolvedName == 'Driver Partner' || resolvedName == 'Mitra Driver') {
            if (b['drivers'] != null && b['drivers'] is Map) {
              final dMap = b['drivers'];
              if (dMap['users'] != null && dMap['users'] is Map && dMap['users']['full_name'] != null) {
                resolvedName = dMap['users']['full_name'].toString();
              } else if (dMap['name'] != null) {
                resolvedName = dMap['name'].toString();
              }
            }
          }

          if (resolvedName.isEmpty || resolvedName == 'Driver Partner' || resolvedName == 'Mitra Driver') {
            resolvedName = 'Budi Santoso';
          }

          // Resolve driver profile avatar image
          final driverImage = currentDriver?['image'] ??
              details?['driverImage'] ??
              details?['driver_image'] ??
              details?['selectedPartner']?['image'] ??
              details?['partner']?['image'] ??
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80';

          final latestMsgRow = latestMessagesMap[b['id']?.toString()];
          String lastMsg = 'Pesanan aktif';
          String lastTime = 'Baru saja';
          if (latestMsgRow != null) {
            lastMsg = latestMsgRow['message']?.toString() ?? 'Pesan baru';
            if (latestMsgRow['created_at'] != null) {
              final dt = DateTime.tryParse(latestMsgRow['created_at'].toString())?.toLocal() ?? DateTime.now();
              lastTime = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
            }
          } else if (msgs.isNotEmpty) {
            lastMsg = msgs.last['text']?.toString() ?? 'Mulai percakapan...';
            lastTime = msgs.last['time']?.toString() ?? 'Baru saja';
          }
          final bookingStatus = b['status']?.toString() ?? 'ongoing';
          final serviceType = b['service_type']?.toString().toLowerCase() ?? details?['serviceType']?.toString().toLowerCase() ?? 'driver';
          final isCompanion = serviceType.contains('companion') || serviceType.contains('teman') || serviceType.contains('hangout') || serviceType.contains('curhat') || serviceType.contains('counseling');

          // Key for grouping: Driver ID if available, otherwise Driver Name (lowercased)
          final partnerKey = (dId != null && dId.isNotEmpty && !dId.startsWith('mock'))
              ? dId
              : resolvedName.trim().toLowerCase();

          if (!groupedMap.containsKey(partnerKey)) {
            groupedMap[partnerKey] = {
              'id': b['id'].toString(),
              'bookingId': b['id'].toString(),
              'driverKey': partnerKey,
              'name': resolvedName,
              'image': driverImage,
              'lastMessage': lastMsg,
              'time': lastTime,
              'unread': msgs.isEmpty ? 1 : 0,
              'isOnline': true,
              'tag': isCompanion ? 'Companion' : 'Driver',
              'category': isCompanion ? 'companion' : 'driver',
              'status': bookingStatus,
              'bookingCount': 1,
            };
          } else {
            // Deduplicate: aggregate unread and update to the active/ongoing bookingId
            final existing = groupedMap[partnerKey]!;
            existing['unread'] = (existing['unread'] as int) + (msgs.isEmpty ? 1 : 0);
            if (bookingStatus == 'ongoing' || bookingStatus == 'dp_paid' || bookingStatus == 'pending') {
              existing['bookingId'] = b['id'].toString();
              existing['status'] = bookingStatus;
            }
          }
        }

        final List<Map<String, dynamic>> extractedBubbles = [];
        for (final b in data) {
          final bId = b['id']?.toString() ?? '';
          if (bId.isNotEmpty && !_dismissedBubbleIds.contains(bId)) {
            extractedBubbles.add(Map<String, dynamic>.from(b as Map));
          }
        }

        if (mounted) {
          setState(() {
            _orderBubbles = extractedBubbles;
            _liveChats = groupedMap.values.toList();
            _isLoadingLive = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _orderBubbles = [];
            _liveChats = [];
            _isLoadingLive = false;
          });
        }
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
            // Gelembung Aktivitas Pesanan (Permanent across request to completion until dismissed)
            _buildOrderActivityBubblesSection(),
            const SizedBox(height: 6),
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
          Row(
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookingHistoryPage()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.assignment_turned_in_rounded, color: AppTheme.primaryPink, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        "Aktivitas",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primaryPink,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
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
        ],
      ),
    );
  }

  /// GELEMBUNG AKTIVITAS PESANAN (Status Permintaan s/d Selesai)
  /// Ketika ditekan langsung mengarah ke halaman Aktivitas.
  /// Tidak bisa hilang otomatis, KECUALI dihapus oleh pengguna sendiri (tombol X).
  Widget _buildOrderActivityBubblesSection() {
    if (_orderBubbles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.assignment_turned_in_rounded, size: 14, color: AppTheme.primaryPink),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Gelembung Aktivitas Pesanan",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textHighContrast,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${_orderBubbles.length}",
                        style: const TextStyle(
                          color: AppTheme.primaryPink,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BookingHistoryPage()),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      children: [
                        Text(
                          "Buka Aktivitas",
                          style: GoogleFonts.inter(
                            color: AppTheme.primaryPink,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryPink, size: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _orderBubbles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final b = _orderBubbles[index];
                return _buildOrderBubbleCard(b);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderBubbleCard(Map<String, dynamic> b) {
    final bId = b['id']?.toString() ?? '';
    final code = bId.length > 6 ? bId.substring(0, 6).toUpperCase() : bId;
    final rawStatus = (b['status'] ?? 'ongoing').toString().toLowerCase();
    final isPending = rawStatus == 'pending' || rawStatus == 'requested' || rawStatus == 'searching';
    final isCompleted = rawStatus == 'completed' || rawStatus == 'paid' || rawStatus == 'selesai';

    final serviceType = b['service_type']?.toString() ?? 'Layanan Temenin';
    final pickup = b['pickup_address'] ?? b['pickup_location'] ?? 'Titik Jemput';
    final destination = b['destination'] ?? b['destination_address'] ?? 'Tujuan';
    final fare = b['total_price'] ?? b['fare'];

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isPending) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = "Permintaan Diajukan";
      statusIcon = Icons.hourglass_top_rounded;
    } else if (isCompleted) {
      statusColor = const Color(0xFFA855F7);
      statusLabel = "Pesanan Selesai";
      statusIcon = Icons.verified_rounded;
    } else {
      statusColor = const Color(0xFF10B981);
      statusLabel = "Sedang Berjalan";
      statusIcon = Icons.directions_car_rounded;
    }

    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 8,
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
              MaterialPageRoute(builder: (_) => const BookingHistoryPage()),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Status badge + Booking code + Dismiss X
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "#$code",
                    style: GoogleFonts.shareTechMono(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Tombol Hapus Gelembung (Hanya bisa hilang atas keinginan sendiri)
                  Tooltip(
                    message: "Hapus Gelembung",
                    child: InkWell(
                      onTap: () => _confirmDismissBubble(bId, serviceType),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(3.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                ],
              ),

              // Middle: Service & Route
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceType,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textHighContrast,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$pickup ➔ $destination",
                    style: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // Bottom Row: Price & Navigation to Activity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (fare != null)
                    Text(
                      "Rp ${(fare is num ? fare.toInt() : (int.tryParse(fare.toString()) ?? 0)).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Ke Aktivitas",
                        style: GoogleFonts.plusJakartaSans(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, color: statusColor, size: 12),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
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
          'img': d['image']?.toString() ?? '',
          'isMe': false,
          'role': d['role'] ?? 'Driver',
        }),
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
          onLongPress: () => _showChatOptions(chat),
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
                          if (chat['status'] != null) ...[
                            const SizedBox(width: 6),
                            _buildChatStatusBadge(chat['status'].toString()),
                          ],
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

  Widget _buildChatStatusBadge(String status) {
    final s = status.toLowerCase();
    Color col;
    String label;
    if (s == 'pending' || s == 'requested') {
      col = const Color(0xFFF59E0B);
      label = "Permintaan";
    } else if (s == 'completed' || s == 'paid' || s == 'selesai') {
      col = const Color(0xFFA855F7);
      label = "Selesai";
    } else {
      col = const Color(0xFF10B981);
      label = "Berjalan";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: col.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: col.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(color: col, fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}