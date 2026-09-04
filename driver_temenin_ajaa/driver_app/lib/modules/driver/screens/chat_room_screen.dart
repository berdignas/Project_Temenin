import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

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
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _subscribeToChat();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getMockClientReply(String driverMessage) {
    final lower = driverMessage.toLowerCase();
    if (lower.contains('halo') || lower.contains('hi') || lower.contains('hello')) {
      return "Halo Kak! Saya siap menunggu di lokasi penjemputan.";
    } else if (lower.contains('jalan') || lower.contains('menuju') || lower.contains('otw')) {
      return "Siap Kak, hati-hati di jalan ya! Kabari kalau sudah sampai.";
    } else if (lower.contains('sampai') || lower.contains('lokasi') || lower.contains('disini')) {
      return "Baik Kak, saya langsung keluar ke lobi sekarang.";
    } else if (lower.contains('terima kasih') || lower.contains('makasih') || lower.contains('thanks')) {
      return "Sama-sama Kak! 🙏";
    }
    return "Baik Kak, terima kasih infonya. Saya tunggu ya.";
  }

  void _subscribeToChat() {
    debugPrint('📡 Subscribing to chat updates for Booking: ${widget.bookingId}');
    try {
      _streamSubscription = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', widget.bookingId)
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
              setState(() {
                _isConnecting = false;
              });
            }
          });
    } catch (e) {
      debugPrint('❌ Supabase stream error: $e');
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    
    final newMsg = {
      'sender': 'driver',
      'text': text,
      'time': timeStr,
      'timestamp': now.toIso8601String(),
    };

    final updatedMessages = List<Map<String, dynamic>>.from(_messages)..add(newMsg);
    
    // Create copy of current additional details
    final currentDetails = Map<String, dynamic>.from(_bookingData?['additional_details'] ?? {});
    currentDetails['chat_messages'] = updatedMessages;

    // Optimistic UI update
    setState(() {
      _messages = updatedMessages;
      _msgController.clear();
    });
    _scrollToBottom();

    // Write to database
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({
            'additional_details': currentDetails,
          })
          .eq('id', widget.bookingId);
      debugPrint('✅ Message sent successfully to Supabase');
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
