// lib/modules/clients/chat/screens/chat_room_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';

class ChatRoomScreen extends StatefulWidget {
  final String? bookingId;
  final String? recipientName;
  final String? recipientImage;
  final String? status;
  final String? tag;

  const ChatRoomScreen({
    super.key,
    this.bookingId,
    this.recipientName,
    this.recipientImage,
    this.status,
    this.tag,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  List<Map<String, dynamic>> _messages = [];
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  Map<String, dynamic>? _bookingData;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    final isMock = widget.bookingId == null || 
        widget.bookingId!.isEmpty || 
        widget.bookingId!.contains('mock') || 
        widget.bookingId!.contains('support');

    if (!isMock) {
      _isConnecting = true;
      _subscribeToChat();
    } else {
      // Default initial mock messages based on ID
      if (widget.bookingId == 'mock-booking-id-1') {
        _messages.addAll([
          {'sender': 'driver', 'text': 'Halo Kak, saya sudah bersiap untuk booking kita nanti malam.', 'time': '10:30'},
          {'sender': 'user', 'text': 'Halo! Oke siap, tolong kabari ya kalau sudah jalan.', 'time': '10:35'},
          {'sender': 'driver', 'text': 'Saya sudah sampai di lokasi penjemputan. Sampai jumpa!', 'time': '10:42'},
        ]);
      } else if (widget.bookingId == 'mock-booking-id-2') {
        _messages.addAll([
          {'sender': 'user', 'text': 'Halo Adrian, nanti kita kumpul di depan lobi ya.', 'time': 'Kemarin 14:15'},
          {'sender': 'driver', 'text': 'Siap Kak, saya sudah stand by di depan lobi.', 'time': 'Kemarin 14:18'},
          {'sender': 'driver', 'text': 'Terima kasih atas perjalanan yang menyenangkan. Semoga harimu menyenangkan!', 'time': 'Kemarin 18:30'},
        ]);
      } else if (widget.bookingId == 'mock-booking-id-3') {
        _messages.addAll([
          {'sender': 'driver', 'text': 'Bisa tolong konfirmasi jam bookingnya?', 'time': 'Minggu 09:12'},
        ]);
      } else if (widget.bookingId == 'support-chat-id') {
        _messages.addAll([
          {'sender': 'driver', 'text': 'Ada yang bisa kami bantu terkait kendala transaksi Anda?', 'time': '25 Okt 08:00'},
          {'sender': 'user', 'text': 'Saya mengajukan refund untuk booking B-12948.', 'time': '25 Okt 08:15'},
          {'sender': 'driver', 'text': 'Baik, mohon tunggu sebentar ya Kak.', 'time': '25 Okt 08:20'},
          {'sender': 'driver', 'text': 'Permintaan pengembalian dana Anda telah berhasil diproses.', 'time': '25 Okt 10:00'},
        ]);
      } else {
        _messages.addAll([
          {
            'sender': 'driver',
            'text': "Halo! Saya sudah di lokasi titik jemput sesuai kesepakatan ya kak.",
            'time': "14:22",
          },
          {
            'sender': 'user',
            'text': "Siap kak! Saya baru saja keluar lift lobi utama. Menuju ke depan sekarang.",
            'time': "14:23",
          },
        ]);
      }
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToChat() {
    if (widget.bookingId == null || widget.bookingId!.isEmpty) {
      setState(() => _isConnecting = false);
      return;
    }
    try {
      _streamSubscription = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', widget.bookingId!)
          .listen((List<Map<String, dynamic>> data) {
            if (data.isNotEmpty && mounted) {
              setState(() {
                _bookingData = data.first;
                final details = _bookingData?['additional_details'] as Map<String, dynamic>?;
                final msgs = details?['chat_messages'] as List<dynamic>?;
                _messages = msgs?.map((m) => Map<String, dynamic>.from(m as Map)).toList() ?? [];
                _isConnecting = false;
              });
              _scrollToBottom();
            }
          }, onError: (err) {
            debugPrint('❌ Stream subscription error: $err');
            if (mounted) {
              setState(() => _isConnecting = false);
            }
          });
    } catch (e) {
      debugPrint('❌ Supabase stream error: $e');
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    
    final newMsg = {
      'sender': 'user',
      'text': text,
      'time': timeStr,
      'timestamp': now.toIso8601String(),
    };

    final isMock = widget.bookingId == null || 
        widget.bookingId!.isEmpty || 
        widget.bookingId!.contains('mock') || 
        widget.bookingId!.contains('support');

    if (!isMock) {
      final updatedMessages = List<Map<String, dynamic>>.from(_messages)..add(newMsg);
      final currentDetails = Map<String, dynamic>.from(_bookingData?['additional_details'] ?? {});
      currentDetails['chat_messages'] = updatedMessages;

      setState(() {
        _messages = updatedMessages;
        _msgController.clear();
      });
      _scrollToBottom();

      try {
        await Supabase.instance.client
            .from('bookings')
            .update({
              'additional_details': currentDetails,
            })
            .eq('id', widget.bookingId!);
      } catch (e) {
        debugPrint('❌ Error sending message: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal mengirim pesan: $e"), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      // Mock simulation mode
      setState(() {
        _messages.add(newMsg);
        _msgController.clear();
      });
      _scrollToBottom();

      // Mock automated reply
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          final replyTime = DateTime.now();
          final replyTimeStr = "${replyTime.hour.toString().padLeft(2, '0')}:${replyTime.minute.toString().padLeft(2, '0')}";
          setState(() {
            _messages.add({
              'sender': 'driver',
              'text': _getMockDriverReply(text),
              'time': replyTimeStr,
            });
          });
          _scrollToBottom();
        }
      });
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  String _getMockDriverReply(String userMessage) {
    final lower = userMessage.toLowerCase();
    if (lower.contains('halo') || lower.contains('hi') || lower.contains('hello')) {
      return "Halo! Ada yang bisa saya bantu untuk perjalanan Anda?";
    } else if (lower.contains('dimana') || lower.contains('posisi') || lower.contains('lokasi')) {
      return "Saya di dekat pintu lobi utama, berjaket hitam dan menggunakan kendaraan yang tertera ya.";
    } else if (lower.contains('tolong') || lower.contains('bantu')) {
      return "Siap Kak, saya bantu laksanakan sekarang. Ada instruksi tambahan?";
    } else if (lower.contains('makasih') || lower.contains('terima kasih') || lower.contains('thank')) {
      return "Sama-sama Kak! Senang bisa mendampingi perjalanannya. 🙏";
    }
    return "Baik Kak, dimengerti. Saya stand by sesuai instruksi.";
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
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
    final name = widget.recipientName ?? "Partner Driver";
    final image = widget.recipientImage ?? "https://i.pravatar.cc/300?img=14";
    final status = widget.status ?? "Online";
    final tag = widget.tag ?? "Gold";

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context, name, image, status, tag),
      body: Column(
        children: [
          Expanded(
            child: _isConnecting
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender'] == 'user';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isMe ? AppTheme.primaryPink : AppTheme.surface,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
                                  bottomRight: isMe ? Radius.zero : const Radius.circular(18),
                                ),
                                border: isMe ? null : Border.all(color: AppTheme.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                msg['text'],
                                style: GoogleFonts.inter(
                                  color: isMe ? Colors.white : AppTheme.textHighContrast,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 12),
                              child: Text(
                                msg['time'],
                                style: GoogleFonts.inter(
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
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String name, String image, String status, String tag) {
    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.cardDeep,
                backgroundImage: NetworkImage(image),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textHighContrast,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.fuchsiaLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: AppTheme.primaryPink,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                status,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone_rounded, color: AppTheme.primaryPink, size: 20),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Melakukan panggilan VOIP aman...")),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: AppTheme.border, height: 1.0),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.location_on_outlined, color: AppTheme.primaryPink),
            onPressed: () {
              setState(() {
                _messages.add({
                  'sender': 'user',
                  'text': "📍 Mengirim lokasi saat ini (Senayan City Mall)",
                  'time': _getCurrentTime(),
                });
              });
              _scrollToBottom();
            },
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
              ),
              child: TextField(
                controller: _msgController,
                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Tulis pesan...",
                  hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(10),
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
    );
  }
}