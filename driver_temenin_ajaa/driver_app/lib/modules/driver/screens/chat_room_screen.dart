import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  Timer? _pollingTimer;

  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _subscribeToChat();
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
        if (data is List && mounted) {
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

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.clientName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textHighContrast,
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
              const Text(
                "Hubungan Aman & Terenkripsi",
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
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
