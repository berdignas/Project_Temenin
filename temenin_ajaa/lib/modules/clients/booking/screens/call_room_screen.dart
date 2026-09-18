import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/routes/app_routes.dart';
import '../widgets/review_dialog.dart';

class CallRoomScreen extends StatefulWidget {
  final String partnerName;
  final String serviceType;
  final int durationMinutes;
  final bool isSleepCall;
  final String topicOrAlarm;
  final String? bookingId;

  const CallRoomScreen({
    super.key,
    required this.partnerName,
    required this.serviceType,
    required this.durationMinutes,
    this.isSleepCall = false,
    this.topicOrAlarm = '',
    this.bookingId,
  });

  @override
  State<CallRoomScreen> createState() => _CallRoomScreenState();
}

class _CallRoomScreenState extends State<CallRoomScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  int _secondsElapsed = 0;
  Timer? _timer;
  bool _hasCallEnded = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      setState(() {
        _secondsElapsed++;
      });

      // Auto-terminate call when duration is reached
      final totalAllowedSeconds = widget.durationMinutes * 60;
      if (_secondsElapsed >= totalAllowedSeconds && !_hasCallEnded) {
        _hasCallEnded = true;
        _timer?.cancel();
        _onTimeLimitReached();
      }
    });
  }

  void _onTimeLimitReached() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.timer_off_rounded, color: AppTheme.primaryPink),
            const SizedBox(width: 8),
            Text(
              "Waktu Sesi Habis",
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
            ),
          ],
        ),
        content: Text(
          "Durasi panggilan selama ${widget.durationMinutes} menit telah selesai. Terima kasih telah menggunakan layanan Temenin Aja.",
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMediumContrast),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showReviewDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("Beri Review", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedDuration {
    final minutes = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsElapsed % 60).toString().padLeft(2, '0');
    final hours = (_secondsElapsed ~/ 3600).toString().padLeft(2, '0');
    if (_secondsElapsed >= 3600) {
      return "$hours:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  void _endCall() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Akhiri Panggilan?",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
        ),
        content: Text(
          "Apakah Anda yakin ingin mengakhiri sesi ${widget.serviceType} ini?",
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMediumContrast),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Batal", style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _hasCallEnded = true;
              _timer?.cancel();
              _showReviewDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("Akhiri Sesi", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _completeBookingInSupabase() async {
    if (widget.bookingId != null && !widget.bookingId!.startsWith('mock')) {
      try {
        final dynamic queryId = int.tryParse(widget.bookingId!) ?? widget.bookingId!;
        await Supabase.instance.client.from('bookings').update({
          'status': 'completed',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', queryId);
      } catch (e) {
        debugPrint("Error updating virtual booking status: $e");
      }
    }
  }

  void _showReviewDialog() {
    final effectiveBookingId = widget.bookingId ?? 'VIRTUAL-${DateTime.now().millisecondsSinceEpoch}';
    BookingReviewDialog.show(
      context,
      driverName: widget.partnerName,
      bookingId: effectiveBookingId,
      onReviewSubmitted: () async {
        await _completeBookingInSupabase();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.clientHome, (route) => false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGaming = widget.serviceType.toLowerCase().contains('gaming') || 
                     widget.serviceType.toLowerCase().contains('mabar');
    final roomColor = isGaming 
        ? const Color(0xFF6366F1) 
        : (widget.isSleepCall ? Colors.indigoAccent : AppTheme.primaryPink);

    return Scaffold(
      backgroundColor: widget.isSleepCall ? const Color(0xFF0F172A) : AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: roomColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: roomColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isGaming 
                              ? Icons.sports_esports_rounded 
                              : (widget.isSleepCall ? Icons.bedtime_rounded : Icons.phone_in_talk_rounded),
                          size: 14,
                          color: roomColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.serviceType,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: roomColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        "Enkripsi Terjaga",
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Avatar & Name Section
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: roomColor.withOpacity(0.1),
                        ),
                      ),
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: widget.isSleepCall 
                            ? const Color(0xFF1E1B4B) 
                            : (isGaming ? const Color(0xFF312E81) : AppTheme.roseGold.withOpacity(0.3)),
                        child: Text(
                          widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : "P",
                          style: GoogleFonts.inter(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: roomColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Text(
                    widget.partnerName,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textHighContrast,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Timer Counter
                  Text(
                    _formattedDuration,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: roomColor,
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    widget.topicOrAlarm,
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMediumContrast),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Sleep Mode Banner or Gaming Banner
            if (widget.isSleepCall)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.nightlight_round, color: Colors.indigoAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Mode Sleep Call Aktif: Hemat Baterai & Inactivity Disconnect Dimatikan",
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.indigoAccent),
                      ),
                    ),
                  ],
                ),
              )
            else if (isGaming)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sports_esports_rounded, color: Color(0xFF6366F1), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Sesi Mabar Aktif: Hubungkan room in-game & voice chat bersama partner",
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6366F1), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // Call Control Buttons Bar
            Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Button
                  IconButton(
                    iconSize: 28,
                    icon: Icon(_isMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
                    color: _isMuted ? Colors.redAccent : AppTheme.textHighContrast,
                    onPressed: () => setState(() => _isMuted = !_isMuted),
                  ),

                  // End Call Button
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
                    ),
                  ),

                  // Speaker Button
                  IconButton(
                    iconSize: 28,
                    icon: Icon(_isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                    color: _isSpeakerOn ? AppTheme.primaryPink : AppTheme.textMediumContrast,
                    onPressed: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
