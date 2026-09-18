import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_sound_service.dart';
import '../../../core/utils/booking_date_helper.dart';
import '../../../data/models/booking_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
import 'active_booking_screen.dart';
import 'chat_room_screen.dart';
import 'driver_waiting_dp_screen.dart';

class DriverWaitingCountdownScreen extends StatefulWidget {
  final BookingModel bookingData;

  const DriverWaitingCountdownScreen({
    super.key,
    required this.bookingData,
  });

  @override
  State<DriverWaitingCountdownScreen> createState() => _DriverWaitingCountdownScreenState();
}

class _DriverWaitingCountdownScreenState extends State<DriverWaitingCountdownScreen> {
  Timer? _countdownTimer;
  int _remainingSeconds = 300; // Default 5 minutes prep if no future date
  bool _isCountdownFinished = false;
  bool _isStartingTrip = false;
  late BookingModel _currentBooking;

  StreamSubscription? _bookingSub;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.bookingData;

    final add = _currentBooking.additionalDetails;
    final isDpPaid = _currentBooking.status == 'dp_paid' ||
        _currentBooking.status == 'ongoing' ||
        _currentBooking.status == 'on_the_way' ||
        add?['dp_paid'] == true ||
        add?['sub_status'] == 'dp_paid' ||
        add?['countdown_ended'] == true;

    if (!isDpPaid && _currentBooking.status == 'accepted') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DriverWaitingDpScreen(bookingData: _currentBooking),
            ),
          );
        }
      });
      return;
    }

    _initCountdown();
    _listenToBookingUpdates();
  }

  void _initCountdown() {
    final bookingDt = _currentBooking.bookingDate ?? BookingDateHelper.extractScheduledDateTime(_currentBooking.additionalDetails);
    if (bookingDt != null) {
      final diff = bookingDt.difference(DateTime.now()).inSeconds;
      if (diff > 0) {
        _remainingSeconds = diff;
      } else {
        _remainingSeconds = 0;
        _isCountdownFinished = true;
      }
    } else {
      _remainingSeconds = 300; // 5 mins default prep countdown
    }

    // Check if countdown was already ended previously
    final add = _currentBooking.additionalDetails;
    if (add != null && (add['countdown_ended'] == true || add['sub_status'] == 'on_the_way')) {
      _remainingSeconds = 0;
      _isCountdownFinished = true;
      return;
    }

    if (_isCountdownFinished || _remainingSeconds <= 0) {
      _handleCountdownFinished();
      return;
    }

    _startTimer();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _handleCountdownFinished();
      }
    });
  }

  void _handleCountdownFinished() {
    setState(() {
      _remainingSeconds = 0;
      _isCountdownFinished = true;
    });

    try {
      NotificationSoundService().playOrderAlert();
    } catch (e) {
      debugPrint("Error playing notification sound: $e");
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.primaryPink, width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryPink.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.alarm_on_rounded, color: AppTheme.primaryPink, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Waktu Tunggu Selesai!",
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Waktu countdown persiapan penjemputan telah selesai. Anda sekarang dapat memulai perjalanan (OTW) menuju lokasi klien.",
          style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 13, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              "SIAP, MULAI PERJALANAN",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _listenToBookingUpdates() {
    try {
      final bookingId = _currentBooking.id;
      final dynamic queryId = int.tryParse(bookingId) ?? bookingId;
      _bookingSub?.cancel();
      _bookingSub = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', queryId)
          .listen((data) {
            if (data.isNotEmpty && mounted) {
              final row = data.first;
              final add = row['additional_details'] is Map ? row['additional_details'] as Map : null;
              if (add != null && add['countdown_ended'] == true && !_isCountdownFinished) {
                _countdownTimer?.cancel();
                _bookingSub?.cancel();
                setState(() {
                  _remainingSeconds = 0;
                  _isCountdownFinished = true;
                });
                NotificationSoundService().playOrderAlert();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Waktu tunggu telah diakhiri oleh klien dengan PIN!"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
          });
    } catch (e) {
      debugPrint("Error listening to booking stream: $e");
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _bookingSub?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    return BookingDateHelper.formatCountdownTime(totalSeconds);
  }

  String? _extractPin(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      final direct = data['otp']?.toString().trim();
      if (direct != null && direct.isNotEmpty && direct != 'null') return direct;
      if (data['additional_details'] is Map) {
        final sub = _extractPin(data['additional_details']);
        if (sub != null) return sub;
      }
      if (data['additionalDetails'] is Map) {
        final sub = _extractPin(data['additionalDetails']);
        if (sub != null) return sub;
      }
    }
    return null;
  }

  Future<void> _showPinVerificationDialog() async {
    final pinController = TextEditingController();
    String? expectedPin = _extractPin(_currentBooking.additionalDetails) ?? _extractPin(_currentBooking);

    // Fetch fresh from Supabase if null
    if (expectedPin == null || expectedPin.isEmpty) {
      try {
        final dynamic queryId = int.tryParse(_currentBooking.id) ?? _currentBooking.id;
        final freshData = await Supabase.instance.client
            .from('bookings')
            .select('additional_details')
            .eq('id', queryId)
            .maybeSingle();
        if (freshData != null) {
          expectedPin = _extractPin(freshData['additional_details']);
        }
      } catch (e) {
        debugPrint("Error fetching pin from db: $e");
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: AppTheme.primaryPink, width: 1.5),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.key_rounded, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Verifikasi PIN Klien",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textHighContrast,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Untuk mengakhiri waktu tunggu lebih cepat dan langsung berangkat OTW, masukkan 4-digit PIN keamanan dari klien:",
                    style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textHighContrast,
                      fontSize: 24,
                      letterSpacing: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: "••••",
                      hintStyle: const TextStyle(color: AppTheme.textMuted, letterSpacing: 10),
                      filled: true,
                      fillColor: AppTheme.cardDeep,
                      counterText: "",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.primaryPink, width: 2),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: GoogleFonts.inter(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    "BATAL",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final entered = pinController.text.trim();
                    if (entered.length != 4) {
                      setDialogState(() {
                        errorMessage = "Masukkan 4 digit PIN dengan lengkap.";
                      });
                      return;
                    }

                    // Compare PIN
                    bool isMatch = false;
                    if (expectedPin != null && expectedPin.isNotEmpty) {
                      isMatch = (entered == expectedPin);
                    } else {
                      // Fallback match if pin not set
                      isMatch = true;
                    }

                    if (isMatch) {
                      Navigator.pop(dialogCtx);
                      _countdownTimer?.cancel();
                      _bookingSub?.cancel();
                      setState(() {
                        _remainingSeconds = 0;
                        _isCountdownFinished = true;
                      });

                      NotificationSoundService().playOrderAlert();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("✅ PIN Berhasil Diverifikasi! Memulai perjalanan (OTW) menuju klien..."),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }

                      // Langsung berangkat OTW ke langkah selanjutnya
                      await _startTripOtw();
                    } else {
                      setDialogState(() {
                        errorMessage = "PIN tidak cocok! Tanyakan 4-digit PIN yang tampil di aplikasi Klien.";
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "VERIFIKASI PIN",
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _startTripOtw() async {
    if (_isStartingTrip) return;
    setState(() {
      _isStartingTrip = true;
    });

    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Ensure activeBooking is set on provider
    bookingProvider.setActiveBooking(_currentBooking);

    // Update status to ongoing and sub_status to on_the_way
    try {
      final dynamic queryId = int.tryParse(_currentBooking.id) ?? _currentBooking.id;
      final existingAdd = Map<String, dynamic>.from(_currentBooking.additionalDetails ?? {});
      existingAdd['sub_status'] = 'on_the_way';
      existingAdd['countdown_ended'] = true;
      existingAdd['otw_started_at'] = DateTime.now().toIso8601String();

      await Supabase.instance.client
          .from('bookings')
          .update({
            'status': 'ongoing',
            'additional_details': existingAdd,
          })
          .eq('id', queryId);

      _currentBooking = _currentBooking.copyWith(
        status: 'ongoing',
        additionalDetails: existingAdd,
      );
      bookingProvider.setActiveBooking(_currentBooking);
    } catch (e) {
      debugPrint("Error updating status to on_the_way in Supabase: $e");
    }

    try {
      await bookingProvider.updateBookingProgress(
        'on_the_way',
        authProvider: authProvider,
      );
    } catch (e) {
      debugPrint("Error updating bookingProvider to on_the_way: $e");
    }

    if (!mounted) return;
    setState(() {
      _isStartingTrip = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DriverActiveBookingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientName = _currentBooking.client?.fullName ?? 'Pelanggan';
    final clientPhone = _currentBooking.client?.phone ?? '-';
    final clientAvatar = _currentBooking.client?.avatarUrl ?? '';
    final dt = _currentBooking.bookingDate ?? _currentBooking.createdAt;
    final List<String> monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    final String bookingDateStr = "${dt.day} ${monthNames[dt.month]} ${dt.year}";
    final String bookingTimeStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB";

    // Service label
    final rawService = _currentBooking.additionalDetails?['serviceType']?.toString() ??
        _currentBooking.additionalDetails?['service_type']?.toString() ??
        'antar_jemput';
    String serviceLabel = 'Antar Jemput';
    IconData serviceIcon = Icons.directions_bike_rounded;
    if (rawService.contains('hangout')) {
      serviceLabel = 'Hangout & Teman Jalan';
      serviceIcon = Icons.coffee_rounded;
    } else if (rawService.contains('freedom')) {
      serviceLabel = 'Freedom Request';
      serviceIcon = Icons.explore_rounded;
    } else if (rawService.contains('sleep')) {
      serviceLabel = 'Sleep Call';
      serviceIcon = Icons.bedtime_rounded;
    } else if (rawService.contains('virtual') || rawService.contains('telepon')) {
      serviceLabel = 'Virtual Call';
      serviceIcon = Icons.video_call_rounded;
    } else if (rawService.contains('gaming') || rawService.contains('mabar')) {
      serviceLabel = 'Gaming Buddy';
      serviceIcon = Icons.sports_esports_rounded;
    }

    // Multi-services
    final dynamic rawExtra = _currentBooking.additionalDetails?['additionalServices'] ??
        _currentBooking.additionalDetails?['services'];
    List<Map<String, dynamic>> extraServices = [];
    if (rawExtra is List) {
      for (var item in rawExtra) {
        if (item is Map) extraServices.add(Map<String, dynamic>.from(item));
      }
    }

    final clientNotes = _currentBooking.additionalDetails?['notes']?.toString() ??
        _currentBooking.additionalDetails?['clientNotes']?.toString() ??
        _currentBooking.additionalDetails?['specialRequests']?.toString() ??
        _currentBooking.additionalDetails?['additionalAntarJemputNotes']?.toString() ??
        '';

    final totalTarif = _currentBooking.totalPrice;
    final dpAmount = totalTarif * 0.5;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          "Halaman Tunggu Keberangkatan",
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textHighContrast, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryPink),
            tooltip: "Chat Klien",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverChatRoomScreen(
                    bookingId: _currentBooking.id,
                    clientName: clientName,
                    clientImage: clientAvatar,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // COUNTDOWN CLOCK CARD
              // ==========================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.surface,
                      AppTheme.fuchsiaLight.withOpacity(0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _isCountdownFinished ? Colors.green : AppTheme.primaryPink.withOpacity(0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isCountdownFinished ? Colors.green : AppTheme.primaryPink).withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isCountdownFinished
                            ? Colors.green.withOpacity(0.15)
                            : AppTheme.primaryPink.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isCountdownFinished ? Colors.green : AppTheme.primaryPink.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isCountdownFinished ? Icons.check_circle_rounded : Icons.timer_rounded,
                            color: _isCountdownFinished ? Colors.green : AppTheme.primaryPink,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isCountdownFinished ? "WAKTU PERSIAPAN SELESAI" : "HITUNG MUNDUR KEBERANGKATAN",
                            style: GoogleFonts.inter(
                              color: _isCountdownFinished ? Colors.green : AppTheme.primaryPink,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatTime(_remainingSeconds),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: _remainingSeconds >= 86400 ? 32 : 46,
                          fontWeight: FontWeight.w900,
                          color: _isCountdownFinished ? Colors.green : AppTheme.textHighContrast,
                          letterSpacing: _remainingSeconds >= 86400 ? 1.5 : 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isCountdownFinished
                          ? "Waktu menunggu selesai. Silakan tekan tombol OTW di bawah!"
                          : "Jadwal Penjemputan: ${BookingDateHelper.getScheduleDisplay(_currentBooking.additionalDetails ?? {'date': _currentBooking.bookingDate?.toIso8601String()})}",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: _isCountdownFinished ? Colors.green : AppTheme.primaryPink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_isCountdownFinished)
                      OutlinedButton.icon(
                        onPressed: _showPinVerificationDialog,
                        icon: const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 16),
                        label: Text(
                          "⚡ Mulai Lebih Awal (Verifikasi PIN Klien)",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.amber.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ==========================================
              // JADWAL BOOKING TERKUNCI CARD
              // ==========================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDeep,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event_available_rounded, color: AppTheme.primaryPink, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Jadwal Penjemputan",
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$bookingDateStr • $bookingTimeStr",
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textHighContrast,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "TERKUNCI",
                        style: GoogleFonts.inter(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ==========================================
              // CLIENT SUMMARY CARD
              // ==========================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.cardDeep,
                          backgroundImage: clientAvatar.isNotEmpty ? NetworkImage(clientAvatar) : null,
                          child: clientAvatar.isEmpty
                              ? const Icon(Icons.person, color: AppTheme.textMuted, size: 24)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clientName,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textHighContrast,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                clientPhone,
                                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Text(
                            "Klien",
                            style: GoogleFonts.inter(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: 12),

                    // Locations
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.my_location_rounded, color: AppTheme.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Titik Penjemputan", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
                              Text(
                                _currentBooking.pickupLocation,
                                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppTheme.primaryPink, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Tujuan / Destinasi", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
                              Text(
                                _currentBooking.dropoffLocation,
                                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (clientNotes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDeep,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.note_alt_rounded, color: AppTheme.primaryPink, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Catatan: \"$clientNotes\"",
                                style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ==========================================
              // SERVICE DETAILS & MULTI-SERVICES
              // ==========================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "RINCIAN LAYANAN & MULTI-LAYANAN",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textHighContrast,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(serviceIcon, color: AppTheme.primaryPink, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            serviceLabel,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textHighContrast,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPink.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Layanan Utama",
                            style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    if (extraServices.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(color: AppTheme.border, height: 1),
                      const SizedBox(height: 10),
                      Text(
                        "Layanan Tambahan Dipilih (${extraServices.length}):",
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      ...extraServices.map((extra) {
                        final title = extra['title'] ?? extra['name'] ?? extra['type'] ?? 'Layanan Ekstra';
                        final price = extra['price'] ?? extra['fee'] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle_outline_rounded, color: Colors.green, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  title.toString(),
                                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12),
                                ),
                              ),
                              Text(
                                "+Rp ${(price as num).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                                style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 14),
                    const Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("DP Masuk (50% Terkunci):", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                        Text(
                          "Rp ${dpAmount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                          style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Total Pendapatan Trip:", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                        Text(
                          "Rp ${totalTarif.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                          style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ==========================================
              // ACTION BUTTON (LOCKED OR ACTIVE)
              // ==========================================
              if (!_isCountdownFinished)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDeep,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_clock_rounded, color: AppTheme.textMuted, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "TOMBOL OTW AKTIF SETELAH COUNTDOWN SELESAI",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPink.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isStartingTrip ? null : _startTripOtw,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isStartingTrip
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            "MULAI PERJALANAN (OTW) ➔",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
