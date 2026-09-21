import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

class DriverChatRoomScreen extends StatefulWidget {
  final String bookingId;
  final String clientName;
  final String clientImage;

  const DriverChatRoomScreen({
    super.key,
    required this.bookingId,
    required this.clientName,
    required this.clientImage,
  });

  @override
  State<DriverChatRoomScreen> createState() => _DriverChatRoomScreenState();
}

class _DriverChatRoomScreenState extends State<DriverChatRoomScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _bookingData;
  bool _isBubbleDismissed = false;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  Timer? _pollingTimer;

  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _subscribeToChat();
    _fetchBookingDetails();
    _loadBubbleDismissalState();
  }

  Future<void> _fetchBookingDetails() async {
    if (widget.bookingId.isEmpty) return;
    try {
      final data = await Supabase.instance.client
          .from('bookings')
          .select()
          .eq('id', widget.bookingId)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _bookingData = data;
        });
      }
    } catch (e) {
      debugPrint("Driver booking fetch error: $e");
    }
  }

  Future<void> _loadBubbleDismissalState() async {
    if (widget.bookingId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('dismissed_order_bubbles') ?? [];
      if (mounted) {
        setState(() {
          _isBubbleDismissed = list.contains(widget.bookingId);
        });
      }
    } catch (_) {}
  }

  Future<void> _dismissBubble() async {
    if (widget.bookingId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('dismissed_order_bubbles') ?? [];
      if (!list.contains(widget.bookingId)) {
        list.add(widget.bookingId);
        await prefs.setStringList('dismissed_order_bubbles', list);
      }
      if (mounted) {
        setState(() {
          _isBubbleDismissed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gelembung pesanan telah dihapus dari obrolan."),
            backgroundColor: AppTheme.card,
          ),
        );
      }
    } catch (_) {}
  }

  void _showDeleteBubbleDialog() {
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
            const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 22),
            const SizedBox(width: 10),
            Text(
              "Hapus Gelembung?",
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          "Gelembung status ini akan dihapus dari layar chat Anda. Rincian pesanan tetap tersimpan di riwayat aktivitas.",
          style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _dismissBubble();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Hapus", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToChat() {
    debugPrint('📡 Subscribing to chat updates for Booking: ${widget.bookingId}');
    if (widget.bookingId.isEmpty) {
      setState(() => _isConnecting = false);
      return;
    }

    _streamSubscription?.cancel();
    _pollingTimer?.cancel();

    try {
      _streamSubscription = Supabase.instance.client
          .from('booking_messages')
          .stream(primaryKey: ['id'])
          .eq('booking_id', widget.bookingId)
          .order('created_at', ascending: true)
          .listen((List<Map<String, dynamic>> data) {
            if (mounted) {
              final formatted = data.map((m) {
                final sender = m['sender_role'] ?? m['sender'] ?? 'driver';
                String time = '';
                if (m['created_at'] != null) {
                  final dt = DateTime.tryParse(m['created_at'].toString())?.toLocal() ?? DateTime.now();
                  time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                }
                return {
                  'id': m['id'],
                  'sender': (sender == 'driver') ? 'driver' : 'user',
                  'text': m['message'] ?? m['text'] ?? '',
                  'time': time.isNotEmpty ? time : _getCurrentTime(),
                  'timestamp': m['created_at'],
                };
              }).toList();

              setState(() {
                _messages = formatted;
                _isConnecting = false;
              });
              _scrollToBottom();
            }
          }, onError: (err) {
            debugPrint('❌ Stream subscription error: $err');
            if (mounted) {
              setState(() {
                _isConnecting = false;
              });
            }
          });
    } catch (e) {
      debugPrint('❌ Supabase stream error: $e');
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }

    // Polling fallback every 3 seconds for instant sync via booking_messages
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || widget.bookingId.isEmpty) return;
      try {
        final data = await Supabase.instance.client
            .from('booking_messages')
            .select()
            .eq('booking_id', widget.bookingId)
            .order('created_at', ascending: true);
        if (mounted) {
          final formatted = data.map((m) {
            final sender = m['sender_role'] ?? m['sender'] ?? 'driver';
            String time = '';
            if (m['created_at'] != null) {
              final dt = DateTime.tryParse(m['created_at'].toString())?.toLocal() ?? DateTime.now();
              time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
            }
            return {
              'id': m['id'],
              'sender': (sender == 'driver') ? 'driver' : 'user',
              'text': m['message'] ?? m['text'] ?? '',
              'time': time.isNotEmpty ? time : _getCurrentTime(),
              'timestamp': m['created_at'],
            };
          }).toList();

          if (formatted.length != _messages.length) {
            setState(() {
              _messages = formatted;
              _isConnecting = false;
            });
            _scrollToBottom();
          }
        }
      } catch (e) {
        debugPrint("Driver chat polling error: $e");
      }
    });
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final timeStr = _getCurrentTime();
    
    final newMsg = {
      'sender': 'driver',
      'text': text,
      'time': timeStr,
      'timestamp': now.toIso8601String(),
    };

    final updatedMessages = List<Map<String, dynamic>>.from(_messages)..add(newMsg);

    // Optimistic UI update
    setState(() {
      _messages = updatedMessages;
      _msgController.clear();
    });
    _scrollToBottom();

    if (widget.bookingId.isNotEmpty) {
      // Write to dedicated booking_messages table (Never write to bookings.additional_details)
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final user = Supabase.instance.client.auth.currentUser;
        final senderId = user?.id ?? auth.user?.id ?? '00000000-0000-0000-0000-000000000000';

        await Supabase.instance.client.from('booking_messages').insert({
          'booking_id': widget.bookingId,
          'sender_id': senderId,
          'sender_role': 'driver',
          'message': text,
        });
        debugPrint('✅ Message sent successfully to Supabase booking_messages');
      } catch (e) {
        debugPrint('❌ Failed to update messages in Supabase: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Gagal mengirim pesan: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBgGradient,
        ),
        child: Column(
          children: [
            // Sticky persistent Order Activity Bubble if not dismissed
            if (!_isBubbleDismissed && widget.bookingId.isNotEmpty)
              _buildOrderActivityBubble(),

            Expanded(
              child: _isConnecting
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                      ),
                    )
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg['sender'] == 'driver';

                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isMe ? AppTheme.primaryPink : AppTheme.surface,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(20),
                                        topRight: const Radius.circular(20),
                                        bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
                                        bottomRight: isMe ? Radius.zero : const Radius.circular(20),
                                      ),
                                      border: isMe 
                                          ? null 
                                          : Border.all(color: AppTheme.border),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isMe ? AppTheme.primaryPink.withOpacity(0.15) : Colors.black.withOpacity(0.02),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      msg['text'] ?? '',
                                      style: GoogleFonts.poppins(
                                        color: isMe ? Colors.white : AppTheme.textHighContrast,
                                        fontSize: 14,
                                        fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5, bottom: 15, left: 4, right: 4),
                                    child: Text(
                                      msg['time'] ?? '',
                                      style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textHighContrast, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(widget.clientImage),
            backgroundColor: AppTheme.cardDeep,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.clientName,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textHighContrast,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "Client",
                        style: GoogleFonts.poppins(
                          color: AppTheme.primaryPink,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
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
                    const Text(
                      "Pesan Teks • Aman & Terenkripsi",
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Text-only indicator badge (Strict text-only communication)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Color(0xFF10B981)),
              const SizedBox(width: 4),
              Text(
                "Teks Saja",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textHighContrast),
          color: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.border)),
          onSelected: (val) {
            if (val == 'activity') {
              Navigator.pop(context);
            } else if (val == 'delete_bubble') {
              _showDeleteBubbleDialog();
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'activity',
              child: Row(
                children: [
                  Icon(Icons.assignment_outlined, size: 18, color: AppTheme.primaryPink),
                  SizedBox(width: 10),
                  Text("Ke Layar Aktivitas", style: TextStyle(color: AppTheme.textHighContrast, fontSize: 13)),
                ],
              ),
            ),
            if (!_isBubbleDismissed)
              const PopupMenuItem(
                value: 'delete_bubble',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
                    SizedBox(width: 10),
                    Text("Hapus Gelembung Pesanan", style: TextStyle(color: AppTheme.danger, fontSize: 13)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderActivityBubble() {
    final status = (_bookingData?['status'] ?? 'active').toString().toLowerCase();

    String statusTitle = "Pesanan Berjalan";
    Color statusColor = const Color(0xFF10B981);
    IconData statusIcon = Icons.directions_bike_rounded;
    int currentStep = 2;

    if (status.contains('request') || status.contains('pending')) {
      statusTitle = "Permintaan Pesanan";
      statusColor = const Color(0xFF3B82F6);
      statusIcon = Icons.hourglass_top_rounded;
      currentStep = 1;
    } else if (status.contains('complete') || status.contains('done')) {
      statusTitle = "Pesanan Selesai";
      statusColor = const Color(0xFF8B5CF6);
      statusIcon = Icons.check_circle_outline_rounded;
      currentStep = 3;
    } else if (status.contains('cancel')) {
      statusTitle = "Pesanan Dibatalkan";
      statusColor = AppTheme.danger;
      statusIcon = Icons.cancel_outlined;
    }

    final pickup = _bookingData?['pickup_address'] ?? _bookingData?['pickup_location'] ?? 'Lokasi Penjemputan';
    final dest = _bookingData?['destination_address'] ?? _bookingData?['destination'] ?? 'Tujuan';
    final bookingCode = widget.bookingId.length > 8 ? widget.bookingId.substring(0, 8).toUpperCase() : widget.bookingId;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 13, color: statusColor),
                          const SizedBox(width: 5),
                          Text(
                            statusTitle,
                            style: GoogleFonts.poppins(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "#$bookingCode",
                      style: GoogleFonts.poppins(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _buildDriverStepCircle("1", currentStep >= 1),
                        _buildDriverStepLine(currentStep >= 2),
                        _buildDriverStepCircle("2", currentStep >= 2),
                        _buildDriverStepLine(currentStep >= 3),
                        _buildDriverStepCircle("3", currentStep >= 3),
                      ],
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showDeleteBubbleDialog,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.radio_button_checked_rounded, size: 12, color: AppTheme.primaryPink),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        pickup.toString(),
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHighContrast),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        dest.toString(),
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHighContrast),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                        const Icon(Icons.lock_clock_rounded, size: 11, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          "Permanen • Hapus manual",
                          style: GoogleFonts.poppins(fontSize: 9.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Buka Aktivitas",
                            style: GoogleFonts.poppins(
                              color: AppTheme.primaryPink,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.primaryPink),
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
  }

  Widget _buildDriverStepCircle(String text, bool active) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: active ? AppTheme.primaryPink : AppTheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: active ? AppTheme.primaryPink : AppTheme.border),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: active ? Colors.white : AppTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDriverStepLine(bool active) {
    return Container(
      width: 10,
      height: 2,
      color: active ? AppTheme.primaryPink : AppTheme.border,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.primaryPink.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: AppTheme.primaryPink,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Mulai Obrolan",
              style: GoogleFonts.poppins(color: AppTheme.textHighContrast, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Kirim pesan ke client untuk mengabarkan posisi Anda atau koordinasi penjemputan.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final quickReplies = [
      "Saya sedang menuju lokasi ya.",
      "Saya sudah sampai di lokasi.",
      "Saya menggunakan helm & jaket pendamping.",
      "Siap Kak, terima kasih!",
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.only(top: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: quickReplies.length,
              itemBuilder: (context, index) {
                final reply = quickReplies[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    label: Text(
                      reply,
                      style: GoogleFonts.poppins(
                        color: AppTheme.primaryPink,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: AppTheme.primaryPink.withOpacity(0.08),
                    side: BorderSide(color: AppTheme.primaryPink.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onPressed: () {
                      _msgController.text = reply;
                      _sendMessage();
                    },
                  ),
                );
              },
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.my_location_rounded, color: AppTheme.primaryPink),
                  onPressed: () {
                    _msgController.text = "Saya sudah berada dekat lokasi penjemputan Anda.";
                  },
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDeep,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: "Tulis pesan ke client...",
                        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryPink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
