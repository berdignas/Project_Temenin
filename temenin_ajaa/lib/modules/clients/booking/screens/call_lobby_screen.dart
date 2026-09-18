import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/data/models/booking_model.dart';
import 'call_room_screen.dart';
import 'payment_method_screen.dart';

class CallLobbyScreen extends StatefulWidget {
  final BookingModel? booking;
  final Map<String, dynamic>? bookingDetails;
  final String? bookingId;

  const CallLobbyScreen({
    super.key,
    this.booking,
    this.bookingDetails,
    this.bookingId,
  });

  @override
  State<CallLobbyScreen> createState() => _CallLobbyScreenState();
}

class _CallLobbyScreenState extends State<CallLobbyScreen> with SingleTickerProviderStateMixin {
  late String _status;
  Map<String, dynamic>? _currentBookingDetails;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;
  Timer? _pollingTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _currentBookingDetails = widget.bookingDetails ?? widget.booking?.additionalDetails ?? {};
    
    final subStatus = _currentBookingDetails?['sub_status']?.toString();
    final isDpPaid = _currentBookingDetails?['dp_paid'] == true || subStatus == 'dp_paid';
    
    if (isDpPaid) {
      _status = 'dp_paid';
    } else {
      _status = _currentBookingDetails?['status']?.toString() ?? widget.booking?.status ?? 'pending';
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _listenToBookingStatus();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _realtimeSub?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _listenToBookingStatus() {
    final bookingId = widget.bookingId ?? widget.booking?.id;
    if (bookingId == null || bookingId.startsWith('mock')) {
      // Auto-simulate matching for test / mock scenarios
      if (_status == 'pending') {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _status == 'pending') {
            setState(() {
              _status = 'accepted';
              _currentBookingDetails?['driverName'] = _currentBookingDetails?['driverName'] ?? 'Sarah Cantika (Partner)';
              _currentBookingDetails?['driverRating'] = '4.9';
            });
          }
        });
      }
      return;
    }

    final dynamic queryId = int.tryParse(bookingId) ?? bookingId;

    try {
      _realtimeSub = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', queryId)
          .listen((List<Map<String, dynamic>> data) {
            if (data.isNotEmpty && mounted) {
              _handleStatusUpdate(data.first);
            }
          });
    } catch (_) {}

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        final data = await Supabase.instance.client
            .from('bookings')
            .select()
            .eq('id', queryId)
            .maybeSingle();
        if (data != null && mounted) {
          _handleStatusUpdate(data);
        }
      } catch (_) {}
    });
  }

  void _handleStatusUpdate(Map<String, dynamic> data) {
    final addDetails = data['additional_details'] is Map ? data['additional_details'] as Map : {};
    final subStatus = addDetails['sub_status']?.toString();
    final isDpPaid = addDetails['dp_paid'] == true || subStatus == 'dp_paid';
    final dbStatus = data['status']?.toString() ?? 'pending';

    String resolvedStatus = subStatus ?? dbStatus;
    if (isDpPaid) {
      resolvedStatus = 'dp_paid';
    }

    setState(() {
      _status = resolvedStatus;
      _currentBookingDetails = Map<String, dynamic>.from(addDetails);
    });
  }

  void _cancelBooking() async {
    final bookingId = widget.bookingId ?? widget.booking?.id;
    if (bookingId != null && !bookingId.startsWith('mock')) {
      try {
        final dynamic queryId = int.tryParse(bookingId) ?? bookingId;
        await Supabase.instance.client.from('bookings').update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', queryId);
      } catch (_) {}
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatCurrency(int amount) {
    return "Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    final details = _currentBookingDetails ?? {};
    final serviceType = details['serviceType']?.toString() ?? "Pendampingan Telepon";
    final sTypeLower = serviceType.toLowerCase();
    final callType = details['call_type']?.toString().toUpperCase() ?? '';
    
    final isGaming = callType == 'GAMING' || sTypeLower.contains('gaming') || sTypeLower.contains('mabar');
    final isSleepCall = callType == 'SLEEP' || sTypeLower.contains('sleep');

    // Check if this booking was made directly from a partner profile
    final hasSelectedPartner = details['driver_id'] != null || 
                               details['driver'] != null || 
                               (details['driverName'] != null && 
                                !details['driverName'].toString().toLowerCase().contains('radar') &&
                                !details['driverName'].toString().toLowerCase().contains('open bid') &&
                                !details['driverName'].toString().toLowerCase().contains('mitra virtual'));

    final partnerName = details['driverName']?.toString() ?? 
                        details['partnerName']?.toString() ?? 
                        (hasSelectedPartner ? "Partner Pilihan" : "Mitra Temenin");
    final partnerAvatar = details['driverImage']?.toString() ?? 
                          (details['driver'] is Map ? (details['driver']['avatar_url'] ?? details['driver']['image'])?.toString() : null) ?? '';

    final gameName = details['game_name'] ?? details['plateNumber'] ?? 'Mobile Legends';
    final durationMins = details['call_duration_minutes'] ?? widget.booking?.duration ?? (isGaming ? 120 : 60);
    final topicOrAlarm = isSleepCall 
        ? "Alarm Bangun: ${details['wake_up_time'] != null ? DateTime.tryParse(details['wake_up_time'].toString())?.toLocal().toString().substring(11, 16) ?? '05:30' : '05:30'} WIB"
        : (isGaming 
            ? "Mabar $gameName (${details['gaming_goal'] ?? 'Push Rank'})" 
            : "Topik: ${details['chat_topic'] ?? 'Curhat & Mendengar'}");

    final totalPayment = details['totalPayment'] ?? (isGaming ? 60000 : 35000);
    final numTotal = totalPayment is num ? totalPayment.toInt() : (int.tryParse(totalPayment.toString()) ?? 35000);
    final dpAmount = details['dp'] ?? (numTotal * 0.5).round();

    // Theme color based on service
    final Color serviceColor = isGaming 
        ? const Color(0xFF6366F1) 
        : (isSleepCall ? const Color(0xFF312E81) : AppTheme.primaryPink);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isGaming 
              ? "Lobi Gaming Buddy (Mabar)"
              : (isSleepCall ? "Lobi Sleep Call" : "Lobi Pendampingan Telepon"),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textHighContrast,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Animated Icon / Avatar Section
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.08);
                  return Transform.scale(
                    scale: (_status == 'pending') ? scale : 1.0,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_status == 'pending')
                                ? serviceColor.withOpacity(0.1 + (_pulseController.value * 0.1))
                                : serviceColor.withOpacity(0.15),
                          ),
                        ),
                        if (_status == 'pending' && hasSelectedPartner) ...[
                          // DIRECT PROFILE BOOKING: Show Partner Avatar with Pending Badge
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: serviceColor, width: 3),
                                  color: AppTheme.cardDeep,
                                ),
                                child: ClipOval(
                                  child: partnerAvatar.isNotEmpty
                                      ? Image.network(
                                          partnerAvatar,
                                          width: 110,
                                          height: 110,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            isGaming ? Icons.sports_esports_rounded : Icons.person_rounded,
                                            color: serviceColor,
                                            size: 48,
                                          ),
                                        )
                                      : Icon(
                                          isGaming ? Icons.sports_esports_rounded : Icons.person_rounded,
                                          color: serviceColor,
                                          size: 48,
                                        ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.surface, width: 2.5),
                                ),
                                child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                        ] else ...[
                          // RADAR / ACCEPTED / PAID: Icon Circle
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _status == 'pending'
                                    ? (isGaming 
                                        ? [const Color(0xFF6366F1), const Color(0xFF4338CA)] 
                                        : [AppTheme.primaryPink, const Color(0xFFE11D48)])
                                    : (_status == 'accepted'
                                        ? [const Color(0xFF059669), const Color(0xFF10B981)]
                                        : (isSleepCall 
                                            ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)] 
                                            : (isGaming 
                                                ? [const Color(0xFF4338CA), const Color(0xFF6366F1)] 
                                                : [AppTheme.primaryPink, const Color(0xFFBE185D)]))),
                              ),
                            ),
                            child: Icon(
                              _status == 'pending'
                                  ? Icons.radar_rounded
                                  : (_status == 'accepted' 
                                      ? Icons.check_circle_outline_rounded 
                                      : (isGaming 
                                          ? Icons.sports_esports_rounded 
                                          : (isSleepCall ? Icons.bedtime_rounded : Icons.phone_in_talk_rounded))),
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // Title & Subtitle based on State & Booking Source
              if (_status == 'pending') ...[
                Text(
                  hasSelectedPartner 
                      ? "Menunggu Konfirmasi Partner" 
                      : (isGaming 
                          ? "Mencari Teman Mabar Online... 🎮" 
                          : (isSleepCall ? "Mencari Partner Sleep Call... 🌙" : "Mencari Partner Online... 📡")),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textHighContrast,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasSelectedPartner
                      ? (isGaming 
                          ? "Permintaan mabar $gameName telah dikirim ke $partnerName. Menunggu konfirmasi ketersediaan partner..."
                          : (isSleepCall 
                              ? "Permintaan sesi sleep call telah dikirim ke $partnerName. Menunggu konfirmasi jadwal partner..."
                              : "Permintaan pendampingan telepon telah dikirim ke $partnerName. Menunggu respon dari partner..."))
                      : (isGaming
                          ? "Sistem radar sedang mencarikan partner gaming online yang siap mabar $gameName..."
                          : (isSleepCall 
                              ? "Sistem radar sedang menghubungkanmu dengan partner sleep call yang siap menemani..."
                              : "Sistem radar sedang menghubungkanmu dengan partner virtual yang siap mendengarkan...")),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textMediumContrast,
                    height: 1.5,
                  ),
                ),
              ] else if (_status == 'accepted') ...[
                Text(
                  hasSelectedPartner ? "Pesanan Diterima! 🎉" : "Partner Ditemukan! 🎉",
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isGaming
                      ? "Partner $partnerName siap mabar $gameName bareng kamu! Silakan bayar DP untuk memulai sesi permainan."
                      : (isSleepCall 
                          ? "Partner $partnerName siap menemani sleep call Anda. Silakan bayar DP untuk konfirmasi jadwal."
                          : "Partner $partnerName siap menemani sesi Anda. Silakan bayar DP untuk masuk ruang panggilan."),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textMediumContrast,
                    height: 1.5,
                  ),
                ),
              ] else ...[
                Text(
                  "Pembayaran Berhasil! ✅",
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryPink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isGaming 
                      ? "Partner $partnerName telah siap di room mabar. Selamat bermain!"
                      : "Partner $partnerName telah siap di ruang panggilan.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textMediumContrast,
                    height: 1.5,
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // Session Summary Details Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Layanan", style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMediumContrast)),
                        Text(
                          isGaming ? "Gaming Buddy (Mabar)" : serviceType, 
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
                        ),
                      ],
                    ),
                    if (isGaming) ...[
                      const Divider(height: 20, color: AppTheme.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Game & Mode", style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMediumContrast)),
                          Text(
                            "$gameName (${details['quantity'] ?? 2} ${details['play_mode'] ?? 'Jam'})", 
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: AppTheme.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Target Mabar", style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMediumContrast)),
                          Expanded(
                            child: Text(
                              details['gaming_goal'] ?? 'Push Rank Santai',
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textHighContrast),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: AppTheme.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Voice Chat", style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMediumContrast)),
                          Text(
                            details['use_voice_chat'] == false ? "Nonaktif" : "Aktif (Discord/In-game)", 
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Divider(height: 24, color: AppTheme.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Durasi Sesi", style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMediumContrast)),
                          Text("$durationMins Menit", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast)),
                        ],
                      ),
                      const Divider(height: 24, color: AppTheme.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Detail Sesi", style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMediumContrast)),
                          Expanded(
                            child: Text(
                              topicOrAlarm,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isSleepCall ? Colors.indigoAccent : AppTheme.primaryPink),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_status == 'accepted') ...[
                      const Divider(height: 20, color: AppTheme.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("DP Wajib (50%)", style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMediumContrast)),
                          Text(
                            _formatCurrency(dpAmount),
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryPink),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // Action Buttons based on Status
              if (_status == 'pending') ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _cancelBooking,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      hasSelectedPartner ? "Batalkan Permintaan" : "Batalkan Pencarian",
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.redAccent),
                    ),
                  ),
                ),
              ] else if (_status == 'accepted') ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentMethodScreen(
                            bookingData: details,
                            bookingId: widget.bookingId ?? widget.booking?.id,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isGaming ? const Color(0xFF6366F1) : AppTheme.primaryPink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          "Bayar DP ${_formatCurrency(dpAmount)} & Mulai",
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallRoomScreen(
                            partnerName: partnerName,
                            serviceType: serviceType,
                            durationMinutes: durationMins,
                            isSleepCall: isSleepCall,
                            topicOrAlarm: topicOrAlarm,
                            bookingId: widget.bookingId ?? widget.booking?.id,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isGaming 
                          ? const Color(0xFF6366F1) 
                          : (isSleepCall ? const Color(0xFF312E81) : AppTheme.primaryPink),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isGaming 
                              ? Icons.sports_esports_rounded 
                              : (isSleepCall ? Icons.bedtime_rounded : Icons.call_rounded), 
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isGaming 
                              ? "Masuk Room Mabar ➔" 
                              : (isSleepCall ? "Masuk Room Sleep Call" : "Mulai Panggilan Telepon"),
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
