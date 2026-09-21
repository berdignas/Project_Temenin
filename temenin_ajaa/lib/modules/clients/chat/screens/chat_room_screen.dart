// lib/modules/clients/chat/screens/chat_room_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/providers/auth_provider.dart';
import '../../pages/booking_history_page.dart';

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
  final ImagePicker _picker = ImagePicker();
  
  Map<String, dynamic>? _bookingData;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  bool _isConnecting = false;
  bool _showScrollToBottom = false;
  bool _isComposing = false;

  final List<String> _quickReplies = [
    "📍 Saya sudah di titik jemput",
    "⏳ Tunggu 2-3 menit ya kak",
    "👋 Halo, sudah di mana kak?",
    "🚗 Kendaraannya warna apa ya?",
    "👍 Siap, terima kasih!",
    "🚶‍♂️ Saya pakai baju hitam",
  ];

  bool _isBubbleDismissed = false;

  @override
  void initState() {
    super.initState();
    _isConnecting = true;
    _subscribeToChat();
    _fetchBookingDetails();
    _loadBubbleDismissalState();

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final isNearBottom = _scrollController.position.maxScrollExtent - _scrollController.offset < 200;
        if (_showScrollToBottom == isNearBottom) {
          setState(() {
            _showScrollToBottom = !isNearBottom;
          });
        }
      }
    });

    _msgController.addListener(() {
      final composing = _msgController.text.trim().isNotEmpty;
      if (composing != _isComposing) {
        setState(() {
          _isComposing = composing;
        });
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookingDetails() async {
    if (widget.bookingId == null || widget.bookingId!.isEmpty) return;
    try {
      final data = await Supabase.instance.client
          .from('bookings')
          .select('*')
          .eq('id', widget.bookingId!)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _bookingData = data;
        });
      }
    } catch (e) {
      debugPrint("Error fetching booking details: $e");
    }
  }

  Future<void> _loadBubbleDismissalState() async {
    if (widget.bookingId == null || widget.bookingId!.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedList = prefs.getStringList('dismissed_order_bubbles') ?? [];
      if (mounted) {
        setState(() {
          _isBubbleDismissed = dismissedList.contains(widget.bookingId);
        });
      }
    } catch (e) {
      debugPrint("Error loading bubble dismissal state: $e");
    }
  }

  Future<void> _dismissBubble() async {
    if (widget.bookingId == null || widget.bookingId!.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedList = prefs.getStringList('dismissed_order_bubbles') ?? [];
      if (!dismissedList.contains(widget.bookingId)) {
        dismissedList.add(widget.bookingId!);
        await prefs.setStringList('dismissed_order_bubbles', dismissedList);
      }
      if (mounted) {
        setState(() {
          _isBubbleDismissed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text("Gelembung pesanan dihapus. Rincian tetap tersimpan di Aktivitas."),
                ),
              ],
            ),
            backgroundColor: AppTheme.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.border),
            ),
            action: SnackBarAction(
              label: "Aktivitas",
              textColor: AppTheme.primaryPink,
              onPressed: _navigateToActivity,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving bubble dismissal: $e");
    }
  }

  void _showDeleteBubbleConfirmationDialog() {
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
            Text(
              "Hapus Gelembung?",
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textHighContrast,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          "Gelembung status pesanan ini akan dihapus dari tampilan obrolan. Riwayat pesanan tetap aman dan dapat diakses kapan saja melalui menu Aktivitas.",
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
              _dismissBubble();
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

  void _navigateToActivity() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BookingHistoryPage(),
      ),
    );
  }

  void _showClearChatConfirmation() {
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
              child: const Icon(Icons.cleaning_services_rounded, color: AppTheme.danger, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              "Bersihkan Obrolan?",
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textHighContrast,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          "Semua pesan teks dalam percakapan ini akan dibersihkan dari perangkat Anda.",
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
              setState(() {
                _messages = [];
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Riwayat chat telah dibersihkan."),
                  backgroundColor: AppTheme.card,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text("Bersihkan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _subscribeToChat() {
    if (widget.bookingId == null || widget.bookingId!.isEmpty) {
      setState(() => _isConnecting = false);
      return;
    }
    
    _streamSubscription?.cancel();

    try {
      // 1. Primary: Stream from dedicated 'booking_messages' table with Supabase Realtime
      _streamSubscription = Supabase.instance.client
          .from('booking_messages')
          .stream(primaryKey: ['id'])
          .eq('booking_id', widget.bookingId!)
          .order('created_at', ascending: true)
          .listen((List<Map<String, dynamic>> data) {
            if (mounted) {
              if (data.isNotEmpty) {
                final formatted = data.map((m) => _formatMessage(m)).toList();
                setState(() {
                  _messages = formatted;
                  _isConnecting = false;
                });
                _scrollToBottom();
              } else {
                _fetchFallbackMessages();
              }
            }
          }, onError: (err) {
            debugPrint('⚠️ booking_messages stream error: $err - fallback stream');
            _subscribeFallbackStream();
          });
    } catch (e) {
      debugPrint('⚠️ Supabase stream init error: $e');
      _subscribeFallbackStream();
    }
  }

  void _subscribeFallbackStream() {
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
                _messages = msgs?.map((m) => _formatMessage(Map<String, dynamic>.from(m as Map))).toList() ?? [];
                _isConnecting = false;
              });
              _scrollToBottom();
            }
          }, onError: (_) {
            if (mounted) setState(() => _isConnecting = false);
          });
    } catch (_) {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _fetchFallbackMessages() async {
    try {
      final rows = await Supabase.instance.client
          .from('booking_messages')
          .select('*')
          .eq('booking_id', widget.bookingId!)
          .order('created_at', ascending: true);
      if (rows.isNotEmpty && mounted) {
        final formatted = (rows as List).map((m) => _formatMessage(Map<String, dynamic>.from(m as Map))).toList();
        setState(() {
          _messages = formatted;
          _isConnecting = false;
        });
        _scrollToBottom();
        return;
      }
    } catch (_) {}

    // Legacy fallback for old bookings
    try {
      final data = await Supabase.instance.client
          .from('bookings')
          .select('additional_details')
          .eq('id', widget.bookingId!)
          .maybeSingle();
      if (data != null && mounted) {
        final details = data['additional_details'] as Map<String, dynamic>?;
        final msgs = details?['chat_messages'] as List<dynamic>?;
        if (msgs != null && msgs.isNotEmpty && _messages.isEmpty) {
          setState(() {
            _messages = msgs.map((m) => _formatMessage(Map<String, dynamic>.from(m as Map))).toList();
            _isConnecting = false;
          });
          _scrollToBottom();
        } else {
          setState(() => _isConnecting = false);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Map<String, dynamic> _formatMessage(Map<String, dynamic> raw) {
    String text = raw['message'] ?? raw['text'] ?? '';
    String sender = raw['sender_role'] ?? raw['sender'] ?? 'user';
    String time = raw['time'] ?? '';
    if (time.isEmpty && raw['created_at'] != null) {
      final dt = DateTime.tryParse(raw['created_at'].toString())?.toLocal() ?? DateTime.now();
      time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return {
      'id': raw['id'],
      'sender': (sender == 'client' || sender == 'user') ? 'user' : 'driver',
      'text': text,
      'time': time.isNotEmpty ? time : _getCurrentTime(),
      'created_at': raw['created_at'],
      'is_read': raw['is_read'] ?? true,
    };
  }

  void _sendMessage([String? customText]) async {
    final text = (customText ?? _msgController.text).trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final timeStr = _getCurrentTime();
    
    final newMsg = {
      'sender': 'user',
      'text': text,
      'time': timeStr,
      'timestamp': now.toIso8601String(),
      'is_read': false,
    };

    if (widget.bookingId == null || widget.bookingId!.isEmpty) return;

    final updatedMessages = List<Map<String, dynamic>>.from(_messages)..add(newMsg);

    setState(() {
      _messages = updatedMessages;
      if (customText == null) {
        _msgController.clear();
      }
    });
    _scrollToBottom();

    // Send via dedicated booking_messages table only
    // (Never write to bookings.additional_details to avoid race conditions with financial status)
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final senderId = user?.id ?? authProv.user?.id ?? _bookingData?['user_id'] ?? '00000000-0000-0000-0000-000000000000';

      await Supabase.instance.client.from('booking_messages').insert({
        'booking_id': widget.bookingId!,
        'sender_id': senderId,
        'sender_role': 'client',
        'message': text,
      });
    } catch (e) {
      debugPrint('Notice on booking_messages insert: $e');
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
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _showAttachmentModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppTheme.border, width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Kirim Lampiran",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textHighContrast,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachOption(
                    icon: Icons.location_on_rounded,
                    color: const Color(0xFF10B981),
                    label: "Titik Lokasi",
                    onTap: () {
                      Navigator.pop(context);
                      _sendMessage("📍 Titik Jemput: Saya menunggu di Lobi Utama / Drop-off.");
                    },
                  ),
                  _buildAttachOption(
                    icon: Icons.camera_alt_rounded,
                    color: AppTheme.primaryPink,
                    label: "Kamera",
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        final photo = await _picker.pickImage(source: ImageSource.camera, maxWidth: 800);
                        if (photo != null) {
                          _sendMessage("📷 [Foto Titik Tunggu] Foto berhasil dikirim");
                        }
                      } catch (e) {
                        debugPrint("Camera error: $e");
                      }
                    },
                  ),
                  _buildAttachOption(
                    icon: Icons.photo_library_rounded,
                    color: const Color(0xFF6366F1),
                    label: "Galeri",
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        final img = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
                        if (img != null) {
                          _sendMessage("🖼️ [Foto Gambar] Lampiran berhasil dikirim");
                        }
                      } catch (e) {
                        debugPrint("Gallery error: $e");
                      }
                    },
                  ),
                  _buildAttachOption(
                    icon: Icons.shield_rounded,
                    color: AppTheme.danger,
                    label: "Bantuan SOS",
                    onTap: () {
                      Navigator.pop(context);
                      _showSosConfirmation();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppTheme.textMediumContrast,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showSosConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.danger)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 28),
            const SizedBox(width: 10),
            Text("Pusat Bantuan Darurat", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          "Peringatan SOS akan mengirimkan notifikasi prioritas ke tim admin Temenin Aja serta menyimpan riwayat koordinat darurat Anda.",
          style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Batal", style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendMessage("🚨 [DARURAT] Klien menekan tombol SOS / Butuh Bantuan Darurat!");
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Sinyal SOS telah dikirimkan ke Tim Siaga Temenin Aja."),
                  backgroundColor: AppTheme.danger,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Kirim SOS Sekarang", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBookingDetailsSheet() {
    final serviceType = _bookingData?['service_type'] ?? 'Teman Jalan';
    final destination = _bookingData?['destination'] ?? _bookingData?['destination_address'] ?? 'Senayan City, Jakarta';
    final pickup = _bookingData?['pickup_address'] ?? _bookingData?['pickup_location'] ?? 'Lobi Mall Central Park';
    final totalCost = _bookingData?['total_price'] ?? _bookingData?['fare'] ?? 75000;
    final bookingCode = widget.bookingId != null && widget.bookingId!.length > 8 
        ? widget.bookingId!.substring(0, 8).toUpperCase() 
        : (widget.bookingId ?? "BOOK-001");

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceType.toString().toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primaryPink,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Order #$bookingCode",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textHighContrast,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Sedang Berjalan",
                          style: GoogleFonts.inter(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 12),
              _buildTripRouteItem(Icons.radio_button_checked, AppTheme.primaryPink, "Titik Jemput", pickup.toString()),
              const SizedBox(height: 14),
              _buildTripRouteItem(Icons.location_on_rounded, AppTheme.roseGold, "Tujuan Akhir", destination.toString()),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total Estimasi Tarif", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
                    Text("Rp ${(totalCost is num ? totalCost.toInt() : (int.tryParse(totalCost.toString()) ?? 0)).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}", 
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripRouteItem(IconData icon, Color iconColor, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.recipientName ?? "Partner Driver";
    final image = widget.recipientImage ?? "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80";
    final status = widget.status ?? "Aktif";
    final tag = widget.tag ?? "Partner";

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context, name, image, status, tag),
      body: Stack(
        children: [
          Column(
            children: [
              // Sticky Gelembung Aktivitas Pesanan (Interactive & Persistent)
              _buildOrderActivityBubble(),
              
              // Messages Chat Area
              Expanded(
                child: _isConnecting
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                        ),
                      )
                    : (_messages.isEmpty && _getMilestoneBubblesCount() == 0)
                        ? _buildEmptyChatState(name)
                        : ListView.builder(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: _messages.length + 1 + _getMilestoneBubblesCount(),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildSafetyNotice();
                              }
                              final milestoneCount = _getMilestoneBubblesCount();
                              if (index <= milestoneCount) {
                                return _buildMilestoneBubbleAtIndex(index - 1);
                              }
                              final msg = _messages[index - 1 - milestoneCount];
                              return _buildMessageBubble(msg);
                            },
                          ),
              ),

              // Quick Reply Suggestion Chips
              _buildQuickRepliesBar(),

              // Modern Input Bar
              _buildMessageInput(),
            ],
          ),

          // Floating Scroll to Bottom Button
          if (_showScrollToBottom)
            Positioned(
              bottom: 120,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: _scrollToBottom,
                backgroundColor: AppTheme.card,
                elevation: 4,
                shape: const CircleBorder(side: BorderSide(color: AppTheme.border)),
                child: const Icon(Icons.arrow_downward_rounded, color: AppTheme.primaryPink, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String name, String image, String status, String tag) {
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
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryPink.withOpacity(0.4), width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: AppTheme.cardDeep,
                  backgroundImage: NetworkImage(image),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 2,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textHighContrast,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3), width: 0.8),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: AppTheme.primaryPink,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Online • Pesan Teks",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w400,
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
        // Text-Only Security Badge
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_chat_read_rounded, color: Color(0xFF10B981), size: 12),
              const SizedBox(width: 4),
              Text(
                "Teks Saja",
                style: GoogleFonts.inter(
                  color: const Color(0xFF10B981),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // Detail Order Action
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, color: AppTheme.textMuted, size: 20),
          tooltip: "Detail Order",
          onPressed: _showBookingDetailsSheet,
        ),

        // More Options Popup Menu (Navigation to Activity, Clear Chat, etc.)
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textHighContrast, size: 20),
          color: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border),
          ),
          onSelected: (val) {
            if (val == 'activity') {
              _navigateToActivity();
            } else if (val == 'details') {
              _showBookingDetailsSheet();
            } else if (val == 'delete_bubble') {
              _showDeleteBubbleConfirmationDialog();
            } else if (val == 'clear') {
              _showClearChatConfirmation();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'activity',
              child: Row(
                children: [
                  const Icon(Icons.assignment_turned_in_rounded, color: AppTheme.primaryPink, size: 18),
                  const SizedBox(width: 10),
                  Text("Buka di Aktivitas", style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textHighContrast)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: AppTheme.roseGold, size: 18),
                  const SizedBox(width: 10),
                  Text("Detail Pesanan", style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textHighContrast)),
                ],
              ),
            ),
            if (!_isBubbleDismissed && widget.bookingId != null && widget.bookingId!.isNotEmpty)
              PopupMenuItem(
                value: 'delete_bubble',
                child: Row(
                  children: [
                    const Icon(Icons.visibility_off_outlined, color: AppTheme.textMuted, size: 18),
                    const SizedBox(width: 10),
                    Text("Hapus Gelembung", style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textHighContrast)),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  const Icon(Icons.cleaning_services_rounded, color: AppTheme.danger, size: 18),
                  const SizedBox(width: 10),
                  Text("Bersihkan Chat", style: GoogleFonts.inter(fontSize: 13, color: AppTheme.danger)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: AppTheme.border, height: 1.0),
      ),
    );
  }

  /// GELEMBUNG PESANAN (Sticky Order Activity Bubble)
  /// Ini tidak bisa hilang secara otomatis dari status permintaan s/d selesai,
  /// KECUALI dihapus oleh pengguna sendiri melalui tombol hapus (X).
  Widget _buildOrderActivityBubble() {
    if (_isBubbleDismissed || widget.bookingId == null || widget.bookingId!.isEmpty) {
      return const SizedBox.shrink();
    }

    final rawStatus = (_bookingData?['status'] ?? widget.status ?? 'ongoing').toString().toLowerCase();
    final isPending = rawStatus == 'pending' || rawStatus == 'requested' || rawStatus == 'searching';
    final isCompleted = rawStatus == 'completed' || rawStatus == 'paid' || rawStatus == 'selesai';

    final bookingCode = widget.bookingId!.length > 6 
        ? widget.bookingId!.substring(0, 6).toUpperCase() 
        : widget.bookingId!;

    final destination = _bookingData?['destination'] ?? _bookingData?['destination_address'] ?? 'Tujuan terdaftar';
    final pickup = _bookingData?['pickup_address'] ?? _bookingData?['pickup_location'] ?? 'Titik jemput terdaftar';
    final totalFare = _bookingData?['total_price'] ?? _bookingData?['fare'];

    String statusTitle;
    String statusSubtitle;
    Color statusColor;
    IconData statusIcon;
    int currentStep;

    if (isPending) {
      statusTitle = "Permintaan Pesanan";
      statusSubtitle = "Menunggu konfirmasi respon mitra";
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.hourglass_top_rounded;
      currentStep = 0;
    } else if (isCompleted) {
      statusTitle = "Pesanan Selesai";
      statusSubtitle = "Layanan berhasil dituntaskan";
      statusColor = const Color(0xFFA855F7);
      statusIcon = Icons.verified_rounded;
      currentStep = 2;
    } else {
      statusTitle = "Pesanan Sedang Berjalan";
      statusSubtitle = "Mitra siaga & memproses pesanan Anda";
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.directions_car_rounded;
      currentStep = 1;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.45), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _navigateToActivity,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Row with Status & Dismiss X Button
                Row(
                  children: [
                    // Pulsing Status Dot
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                statusTitle,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textHighContrast,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "#$bookingCode",
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            statusSubtitle,
                            style: GoogleFonts.inter(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tombol Hapus Gelembung (Hanya bisa hilang jika dihapus atas keinginan sendiri)
                    Tooltip(
                      message: "Hapus Gelembung Pesanan",
                      child: InkWell(
                        onTap: _showDeleteBubbleConfirmationDialog,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 3-Step Milestone Stepper Capsule
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.background.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildStepperItem("1. Permintaan", 0, currentStep, statusColor),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: currentStep >= 1 ? statusColor : AppTheme.border,
                        ),
                      ),
                      _buildStepperItem("2. Berjalan", 1, currentStep, statusColor),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: currentStep >= 2 ? statusColor : AppTheme.border,
                        ),
                      ),
                      _buildStepperItem("3. Selesai", 2, currentStep, statusColor),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Route & Price Details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.near_me_rounded, size: 14, color: AppTheme.primaryPink.withOpacity(0.8)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "$pickup ➔ $destination",
                              style: GoogleFonts.inter(
                                color: AppTheme.textMediumContrast,
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (totalFare != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        "Rp ${(totalFare is num ? totalFare.toInt() : (int.tryParse(totalFare.toString()) ?? 0)).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // Navigasi ke Aktivitas Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withOpacity(0.2),
                        statusColor.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_rounded, color: statusColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        "Buka di Aktivitas",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: statusColor, size: 13),
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

  Widget _buildStepperItem(String label, int stepIdx, int currentStep, Color activeColor) {
    final isActive = currentStep >= stepIdx;
    final isCurrent = currentStep == stepIdx;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isActive ? activeColor : AppTheme.textMuted.withOpacity(0.4),
              shape: BoxShape.circle,
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: isActive ? Colors.white : AppTheme.textMuted,
              fontSize: 9.5,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  int _getMilestoneBubblesCount() {
    if (widget.bookingId == null || widget.bookingId!.isEmpty) return 0;
    final rawStatus = (_bookingData?['status'] ?? widget.status ?? 'ongoing').toString().toLowerCase();
    final isCompleted = rawStatus == 'completed' || rawStatus == 'paid' || rawStatus == 'selesai';
    final isPending = rawStatus == 'pending' || rawStatus == 'requested' || rawStatus == 'searching';

    if (isCompleted) return 3;
    if (isPending) return 1;
    return 2; // ongoing
  }

  Widget _buildMilestoneBubbleAtIndex(int idx) {
    final bookingCode = widget.bookingId!.length > 6 
        ? widget.bookingId!.substring(0, 6).toUpperCase() 
        : widget.bookingId!;
    final serviceType = _bookingData?['service_type'] ?? widget.tag ?? 'Layanan Pendamping';

    if (idx == 0) {
      // Milestone 1: Permintaan Pesanan Diajukan
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_outlined, color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 8),
                Text(
                  "Permintaan Pesanan #$bookingCode Diajukan",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Layanan $serviceType telah diajukan. Semua koordinasi aman via pesan teks terenkripsi.",
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5, height: 1.35),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _navigateToActivity,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFFF59E0B), size: 13),
                    const SizedBox(width: 6),
                    Text(
                      "Buka di Aktivitas",
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF59E0B),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFF59E0B), size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (idx == 1) {
      // Milestone 2: Pesanan Sedang Berjalan
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car_rounded, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Text(
                  "Pesanan Sedang Berjalan",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Mitra terhubung dan siap berinteraksi. Pantau perkembangan perjalanan secara berkala.",
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5, height: 1.35),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _navigateToActivity,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.track_changes_rounded, color: Color(0xFF10B981), size: 13),
                    const SizedBox(width: 6),
                    Text(
                      "Pantau di Aktivitas",
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF10B981), size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Milestone 3: Pesanan Selesai
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA855F7).withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFFA855F7), size: 18),
                const SizedBox(width: 8),
                Text(
                  "Pesanan Selesai & Dituntaskan",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Terima kasih telah menggunakan Temenin Aja. Rincian invoice dan ulasan tersimpan aman.",
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5, height: 1.35),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _navigateToActivity,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFA855F7).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Color(0xFFA855F7), size: 13),
                    const SizedBox(width: 6),
                    Text(
                      "Lihat Rincian di Aktivitas",
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFA855F7),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFA855F7), size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSafetyNotice() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withOpacity(0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981), size: 14),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              "Pesan Teks Terenkripsi: Panggilan telepon ditiadakan demi privasi & rekam jejak aman.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatState(String name) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryPink.withOpacity(0.2),
                    AppTheme.roseGold.withOpacity(0.05),
                  ],
                ),
                border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppTheme.primaryPink,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Belum ada pesan",
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textHighContrast,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Kirim pesan atau sapa $name untuk koordinasi titik jemput dan kebutuhan Anda.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe = msg['sender'] == 'user';
    final text = msg['text']?.toString() ?? '';
    final isLocation = text.startsWith("📍");
    final isSos = text.contains("🚨");

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: isLocation 
                  ? const EdgeInsets.all(12) 
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isSos
                    ? const LinearGradient(colors: [Color(0xFF991B1B), Color(0xFFDC2626)])
                    : (isMe ? AppTheme.primaryGradient : null),
                color: (!isMe && !isSos) ? AppTheme.surface : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                ),
                border: (!isMe && !isSos) 
                    ? Border.all(color: AppTheme.border) 
                    : Border.all(color: Colors.white.withOpacity(0.15)),
                boxShadow: [
                  BoxShadow(
                    color: isMe ? AppTheme.primaryPink.withOpacity(0.18) : Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: isLocation
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Koordinat Titik Temu",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          text.replaceFirst("📍", "").trim(),
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.map_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                "Lokasi Terverifikasi",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Text(
                      text,
                      style: GoogleFonts.inter(
                        color: (isMe || isSos) ? Colors.white : AppTheme.textHighContrast,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg['time'] ?? '',
                    style: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.done_all_rounded,
                      size: 13,
                      color: AppTheme.primaryPink,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickRepliesBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final reply = _quickReplies[index];
          return InkWell(
            onTap: () => _sendMessage(reply),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Center(
                child: Text(
                  reply,
                  style: GoogleFonts.inter(
                    color: AppTheme.textMediumContrast,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 22),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1.0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment Button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.cardDeep,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(Icons.add_rounded, color: AppTheme.primaryPink, size: 20),
            ),
            tooltip: "Lampiran",
            onPressed: _showAttachmentModal,
          ),
          
          // Text Input Field
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
              ),
              child: TextField(
                controller: _msgController,
                maxLines: 4,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: "Ketik pesan untuk driver...",
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

          // Send / Voice Button
          GestureDetector(
            onTap: () => _sendMessage(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: _isComposing ? AppTheme.primaryGradient : null,
                color: !_isComposing ? AppTheme.cardDeep : null,
                shape: BoxShape.circle,
                boxShadow: _isComposing
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryPink.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                _isComposing ? Icons.send_rounded : Icons.near_me_rounded,
                color: _isComposing ? Colors.white : AppTheme.primaryPink,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}