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
    _isConnecting = true;
    _subscribeToChat();
  }

  Timer? _pollingTimer;

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToChat() {
    if (widget.bookingId == null || widget.bookingId!.isEmpty) {
      setState(() => _isConnecting = false);
      return;
    }
    
    _streamSubscription?.cancel();
    _pollingTimer?.cancel();

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

    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || widget.bookingId == null) return;
      try {
        final data = await Supabase.instance.client
            .from('bookings')
            .select()
            .eq('id', widget.bookingId!)
            .maybeSingle();
        if (data != null && mounted) {
          _bookingData = data;
          final details = data['additional_details'] as Map<String, dynamic>?;
          final msgs = details?['chat_messages'] as List<dynamic>?;
          final newMessages = msgs?.map((m) => Map<String, dynamic>.from(m as Map)).toList() ?? [];
          if (newMessages.length != _messages.length) {
            setState(() {
              _messages = newMessages;
              _isConnecting = false;
            });
            _scrollToBottom();
          }
        }
      } catch (e) {
        debugPrint("Chat polling error: $e");
      }
    });
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

    if (widget.bookingId == null || widget.bookingId!.isEmpty) return;

    final updatedMessages = List<Map<String, dynamic>>.from(_messages)..add(newMsg);

    setState(() {
      _messages = updatedMessages;
      _msgController.clear();
    });
    _scrollToBottom();

    try {
      // Fetch freshest row to avoid overwriting recent messages
      final freshRow = await Supabase.instance.client
          .from('bookings')
          .select('additional_details')
          .eq('id', widget.bookingId!)
          .maybeSingle();

      final currentDetails = Map<String, dynamic>.from(freshRow?['additional_details'] ?? _bookingData?['additional_details'] ?? {});
      final serverMsgs = (currentDetails['chat_messages'] as List<dynamic>?)
          ?.map((m) => Map<String, dynamic>.from(m as Map))
          .toList() ?? [];
      
      serverMsgs.add(newMsg);
      currentDetails['chat_messages'] = serverMsgs;

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
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
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