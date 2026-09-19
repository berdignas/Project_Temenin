import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/notification_sound_service.dart';
import '../../../../core/utils/booking_date_helper.dart';
import 'tracking_driver_screen.dart';

class ClientWaitingCountdownScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final String? bookingId;

  const ClientWaitingCountdownScreen({
    super.key,
    required this.bookingData,
    this.bookingId,
  });

  @override
  State<ClientWaitingCountdownScreen> createState() => _ClientWaitingCountdownScreenState();
}

class _ClientWaitingCountdownScreenState extends State<ClientWaitingCountdownScreen> {
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  int _remainingSeconds = 300; // 5 minutes default prep
  bool _isCountdownFinished = false;
  bool _isNavigating = false;
  String _securityPin = "1234";
  late Map<String, dynamic> _currentDetails;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSub;

  Map<String, dynamic>? _parseMap(dynamic data) {
    if (data == null) return null;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _currentDetails = Map<String, dynamic>.from(widget.bookingData);
    _ensurePinAndInitCountdown();
    _subscribeToStatusUpdates();
  }

  void _ensurePinAndInitCountdown() {
    // 1. PIN Resolution
    String? pin = _extractPin(_currentDetails);
    if (pin == null || pin.isEmpty) {
      final random = Random();
      pin = (random.nextInt(9000) + 1000).toString();
      _currentDetails['otp'] = pin;
      _savePinToDatabase(pin);
    }
    _securityPin = pin;

    // 2. Countdown Resolution
    final scheduledDt = BookingDateHelper.extractScheduledDateTime(_currentDetails);
    if (scheduledDt != null) {
      final diff = scheduledDt.difference(DateTime.now()).inSeconds;
      if (diff > 0) {
        _remainingSeconds = diff;
      } else {
        _remainingSeconds = 0;
        _isCountdownFinished = true;
      }
    } else {
      _remainingSeconds = 300;
    }

    // Check if countdown ended or trip already started in DB/bookingData
    final add = _parseMap(_currentDetails['additional_details']) ?? _parseMap(_currentDetails['additionalDetails']);
    final st = _currentDetails['status']?.toString().toLowerCase();
    final sub = add?['sub_status']?.toString().toLowerCase();
    final isCountdownEnded = add?['countdown_ended'] == true || add?['countdown_ended'] == 'true';

    // If still in dp_paid or pending driver arrival and countdown not ended, DO NOT skip countdown
    final isWaitingPrep = !isCountdownEnded && (sub == 'dp_paid' || st == 'dp_paid' || (sub == null && st == 'accepted'));
    final isTripStarted = isCountdownEnded ||
        sub == 'on_the_way' ||
        (st == 'on_the_way' && sub != 'dp_paid') ||
        sub == 'arrived' ||
        sub == 'started' ||
        sub == 'completed';

    if (!isWaitingPrep && isTripStarted) {
      _remainingSeconds = 0;
      _isCountdownFinished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateToTracking(nextStatus: sub ?? (st == 'ongoing' ? 'on_the_way' : st) ?? 'on_the_way');
        }
      });
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
      NotificationSoundService().playNotificationSound();
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
              child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryPink, size: 24),
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
          "Waktu countdown jadwal layanan telah tiba! Mitra pengemudi Anda kini bersiap untuk memulai perjalanan (OTW) menuju lokasi Anda.",
          style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 13, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToTracking();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              "LIHAT PELACAKAN (OTW)",
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  bool _isShowingEarlyRequestDialog = false;

  void _checkStatusAndNavigate(Map<String, dynamic> row) {
    if (!mounted || _isNavigating) return;

    final status = row['status']?.toString().toLowerCase();
    final add = _parseMap(row['additional_details']) ?? _parseMap(row['additionalDetails']);
    final subStatus = add?['sub_status']?.toString().toLowerCase();
    final isCountdownEnded = add?['countdown_ended'] == true || add?['countdown_ended'] == 'true';
    final earlyReq = add?['early_start_request']?.toString();

    // Check if driver sent an early start request ('pending')
    if (earlyReq == 'pending' && !_isShowingEarlyRequestDialog && !_isNavigating) {
      _isShowingEarlyRequestDialog = true;
      _showEarlyStartRequestDialog(row);
      return;
    }

    // If still waiting for schedule (dp_paid) and countdown has not ended, stay on countdown!
    if (!isCountdownEnded && (subStatus == 'dp_paid' || status == 'dp_paid' || (subStatus == null && status == 'accepted'))) {
      return;
    }

    final shouldNavigate = isCountdownEnded ||
        subStatus == 'on_the_way' ||
        (subStatus != 'dp_paid' && status == 'on_the_way') ||
        subStatus == 'arrived' ||
        subStatus == 'started' ||
        subStatus == 'completed';

    if (shouldNavigate) {
      _isNavigating = true;
      _countdownTimer?.cancel();
      _pollingTimer?.cancel();
      _streamSub?.cancel();

      setState(() {
        _remainingSeconds = 0;
        _isCountdownFinished = true;
        _currentDetails = Map<String, dynamic>.from(row);
      });

      try {
        NotificationSoundService().playNotificationSound();
      } catch (e) {
        debugPrint("Error playing notification sound: $e");
      }

      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🚀 Driver telah memulai perjalanan (OTW) menuju lokasi Anda!"), backgroundColor: Colors.green,)); } });

      final nextStatus = (subStatus != null && subStatus.isNotEmpty) ? subStatus : (status == 'ongoing' ? 'on_the_way' : status ?? 'on_the_way');
      _navigateToTracking(nextStatus: nextStatus);
    }
  }

  Future<void> _showEarlyStartRequestDialog(Map<String, dynamic> row) async {
    if (!mounted) return;
    try {
      NotificationSoundService().playNotificationSound();
    } catch (_) {}

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
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
                  color: AppTheme.primaryPink.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hail_rounded, color: AppTheme.primaryPink, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Permintaan Keberangkatan",
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
            "Mitra Driver meminta persetujuan untuk mengakhiri waktu tunggu persiapan dan langsung berangkat (OTW) ke lokasi Anda sekarang. Apakah Anda setuju?",
            style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 13, height: 1.4),
          ),
          actions: [
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                _isShowingEarlyRequestDialog = false;

                final bId = widget.bookingId ?? _currentDetails['id']?.toString();
                if (bId != null) {
                  final String strId = bId.toString();
                  final dynamic numId = int.tryParse(strId);
                  final existingAdd = _parseMap(row['additional_details']) ??
                      _parseMap(row['additionalDetails']) ??
                      <String, dynamic>{};
                  existingAdd['early_start_request'] = 'rejected';
                  existingAdd['early_start_rejected_at'] = DateTime.now().toIso8601String();

                  try {
                    await Supabase.instance.client
                        .from('bookings')
                        .update({'additional_details': existingAdd})
                        .eq('id', strId);
                  } catch (_) {}
                  if (numId != null) {
                    try {
                      await Supabase.instance.client
                          .from('bookings')
                          .update({'additional_details': existingAdd})
                          .eq('id', numId);
                    } catch (_) {}
                  }
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("❌ Permintaan Driver ditolak. Waktu persiapan berlanjut."),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "TOLAK",
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                _isShowingEarlyRequestDialog = false;
                _countdownTimer?.cancel();
                _pollingTimer?.cancel();
                setState(() {
                  _remainingSeconds = 0;
                  _isCountdownFinished = true;
                });

                final bId = widget.bookingId ?? _currentDetails['id']?.toString();
                if (bId != null) {
                  final String strId = bId.toString();
                  final dynamic numId = int.tryParse(strId);
                  final existingAdd = _parseMap(row['additional_details']) ??
                      _parseMap(row['additionalDetails']) ??
                      <String, dynamic>{};
                  existingAdd['early_start_request'] = 'approved';
                  existingAdd['countdown_ended'] = true;
                  existingAdd['sub_status'] = 'on_the_way';
                  existingAdd['early_start_approved_at'] = DateTime.now().toIso8601String();

                  try {
                    await Supabase.instance.client
                        .from('bookings')
                        .update({
                          'status': 'ongoing',
                          'additional_details': existingAdd,
                        })
                        .eq('id', strId);
                  } catch (_) {}
                  if (numId != null) {
                    try {
                      await Supabase.instance.client
                          .from('bookings')
                          .update({
                            'status': 'ongoing',
                            'additional_details': existingAdd,
                          })
                          .eq('id', numId);
                    } catch (_) {}
                  }
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("🚀 Disetujui! Driver sedang OTW menuju lokasi Anda."),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _navigateToTracking(nextStatus: 'on_the_way');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "YA, SETUJU (OTW)",
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      _isShowingEarlyRequestDialog = false;
    });
  }

  void _subscribeToStatusUpdates() {
    final bId = widget.bookingId ?? _currentDetails['id']?.toString();
    if (bId == null || bId.isEmpty) return;

    final dynamic queryId = int.tryParse(bId) ?? bId;

    try {
      _streamSub = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', queryId)
          .listen((rows) {
            if (rows.isNotEmpty && mounted) {
              _checkStatusAndNavigate(rows.first);
            }
          });
    } catch (e) {
      debugPrint("Error in client booking stream: $e");
    }

    // Fallback polling every 2 seconds
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || _isNavigating) return;
      try {
        final res = await Supabase.instance.client
            .from('bookings')
            .select()
            .eq('id', queryId)
            .maybeSingle();
        if (res != null && mounted) {
          _checkStatusAndNavigate(res);
        }
      } catch (e) {
        debugPrint("Error in client countdown polling fallback: $e");
      }
    });
  }

  Future<void> _savePinToDatabase(String pin) async {
    final bId = widget.bookingId ?? _currentDetails['id']?.toString();
    if (bId == null || bId.isEmpty) return;

    try {
      final String strId = bId.toString();
      final dynamic numId = int.tryParse(strId);
      final existingAdd = _currentDetails['additional_details'] is Map
          ? Map<String, dynamic>.from(_currentDetails['additional_details'])
          : (_currentDetails['additionalDetails'] is Map
              ? Map<String, dynamic>.from(_currentDetails['additionalDetails'])
              : <String, dynamic>{});
      existingAdd['otp'] = pin;
      existingAdd['security_pin'] = pin;

      try {
        await Supabase.instance.client
            .from('bookings')
            .update({'additional_details': existingAdd})
            .eq('id', strId);
      } catch (_) {}

      if (numId != null) {
        try {
          await Supabase.instance.client
              .from('bookings')
              .update({'additional_details': existingAdd})
              .eq('id', numId);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Error saving PIN to Supabase: $e");
    }
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

  Future<void> _showEarlyEndPinDialog() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) {
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
                  color: AppTheme.primaryPink.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: AppTheme.primaryPink, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Konfirmasi Keberangkatan",
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
            "Apakah Anda ingin mengakhiri waktu tunggu persiapan sekarang dan meminta Driver untuk langsung berangkat (OTW)?",
            style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 13, height: 1.4),
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
                Navigator.pop(dialogCtx);
                _countdownTimer?.cancel();
                _pollingTimer?.cancel();
                setState(() {
                  _remainingSeconds = 0;
                  _isCountdownFinished = true;
                });

                // Notify Supabase countdown ended and trip on the way
                final bId = widget.bookingId ?? _currentDetails['id']?.toString();
                if (bId != null) {
                  try {
                    final String strId = bId.toString();
                    final dynamic numId = int.tryParse(strId);
                    final existingAdd = _parseMap(_currentDetails['additional_details']) ??
                        _parseMap(_currentDetails['additionalDetails']) ??
                        <String, dynamic>{};
                    existingAdd['countdown_ended'] = true;
                    existingAdd['countdown_ended_at'] = DateTime.now().toIso8601String();
                    existingAdd['sub_status'] = 'on_the_way';
                    
                    try {
                      await Supabase.instance.client
                          .from('bookings')
                          .update({
                            'status': 'ongoing',
                            'additional_details': existingAdd,
                          })
                          .eq('id', strId);
                    } catch (_) {}

                    if (numId != null) {
                      try {
                        await Supabase.instance.client
                            .from('bookings')
                            .update({
                              'status': 'ongoing',
                              'additional_details': existingAdd,
                            })
                            .eq('id', numId);
                      } catch (_) {}
                    }
                  } catch (e) {
                    debugPrint("Error updating countdown_ended: $e");
                  }
                }

                try {
                  NotificationSoundService().playNotificationSound();
                } catch (_) {}

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("🚀 Konfirmasi Berhasil! Melanjutkan ke pelacakan keberangkatan Driver."),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _navigateToTracking(nextStatus: 'on_the_way');
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "YA, MINTA DRIVER OTW",
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToTracking({String? nextStatus}) {
    if (_isNavigating) return;
    _isNavigating = true;
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    _streamSub?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TrackingDriverScreen(
          bookingData: _currentDetails,
          bookingId: widget.bookingId ?? _currentDetails['id']?.toString(),
          initialStatus: nextStatus ?? _currentDetails['status']?.toString() ?? 'on_the_way',
        ),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    return BookingDateHelper.formatCountdownTime(totalSeconds);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    _streamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driverData = _currentDetails['driver'] ?? _currentDetails['partner'];
    final driverName = driverData is Map ? (driverData['fullName'] ?? driverData['name'] ?? 'Mitra Pengemudi') : 'Mitra Pengemudi';
    final driverPhone = driverData is Map ? (driverData['phone'] ?? '-') : '-';
    final driverPlate = driverData is Map ? (driverData['plateNumber'] ?? driverData['plate_number'] ?? 'B 1234 TEM') : 'B 1234 TEM';
    final driverVehicle = driverData is Map ? (driverData['vehicle'] ?? driverData['vehicleType'] ?? 'Motor') : 'Motor';
    final driverAvatar = driverData is Map ? (driverData['avatarUrl'] ?? driverData['avatar'] ?? '') : '';

    final pickup = _currentDetails['pickupLocation'] ?? _currentDetails['pickup_location'] ?? 'Lokasi Penjemputan';
    final dropoff = _currentDetails['dropoffLocation'] ?? _currentDetails['dropoff_location'] ?? 'Lokasi Tujuan';

    final rawService = _currentDetails['serviceType']?.toString() ??
        _currentDetails['service_type']?.toString() ??
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

    final dynamic rawExtra = _currentDetails['additionalServices'] ??
        _currentDetails['additional_services'] ??
        (_currentDetails['additional_details'] is Map ? _currentDetails['additional_details']['additionalServices'] : null);
    List<Map<String, dynamic>> extraServices = [];
    if (rawExtra is List) {
      for (var item in rawExtra) {
        if (item is Map) extraServices.add(Map<String, dynamic>.from(item));
      }
    }

    final num totalPayment = _currentDetails['totalPayment'] ?? _currentDetails['totalPrice'] ?? _currentDetails['total_price'] ?? 0;
    final num dpAmount = _currentDetails['dp'] ?? (totalPayment * 0.5);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          "Menunggu Jadwal Layanan",
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
                            _isCountdownFinished ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                            color: _isCountdownFinished ? Colors.green : AppTheme.primaryPink,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isCountdownFinished ? "WAKTU TUNGGU SELESAI" : "HITUNG MUNDUR PENJEMPUTAN",
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
                          ? "Waktu tunggu telah selesai! Driver Anda sedang bersiap."
                          : "Jadwal Penjemputan: ${BookingDateHelper.getScheduleDisplay(_currentDetails)}",
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
                        onPressed: _showEarlyEndPinDialog,
                        icon: const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 16),
                        label: Text(
                          "⚡ Minta Driver Berangkat Sekarang (OTW)",
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
              // SECURITY PIN CARD
              // ==========================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primaryPink.withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPink.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_user_rounded, color: AppTheme.primaryPink, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "STATUS PERSIAPAN LAYANAN",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.primaryPink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text(
                      "Driver Anda sedang bersiap untuk penjemputan. Anda dapat menekan tombol di bawah untuk meminta keberangkatan lebih awal.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ==========================================
              // DRIVER SUMMARY CARD
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
                      "MITRA DRIVER BERTUGAS",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.cardDeep,
                          backgroundImage: driverAvatar.isNotEmpty ? NetworkImage(driverAvatar) : null,
                          child: driverAvatar.isEmpty
                              ? const Icon(Icons.person, color: AppTheme.textMuted, size: 24)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driverName,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textHighContrast,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$driverVehicle • $driverPlate",
                                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
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
                            "Siap Antar",
                            style: GoogleFonts.inter(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ==========================================
              // ROUTE & SERVICE DETAILS
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
                      "DETAIL PESANAN & LOKASI",
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
                        Icon(serviceIcon, color: AppTheme.primaryPink, size: 16),
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
                      ],
                    ),

                    if (extraServices.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        "Layanan Tambahan (+${extraServices.length}):",
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      ...extraServices.map((extra) {
                        final title = extra['title'] ?? extra['name'] ?? extra['type'] ?? 'Layanan Ekstra';
                        final price = extra['price'] ?? extra['fee'] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle_outline_rounded, color: Colors.green, size: 12),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(title.toString(), style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12)),
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

                    const SizedBox(height: 12),
                    const Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: 10),

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
                              Text(pickup, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600)),
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
                              Text(dropoff, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("DP Dibayar (50%):", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                        Text(
                          "Rp ${dpAmount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                          style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Total Biaya Layanan:", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                        Text(
                          "Rp ${totalPayment.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                          style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==========================================
              // ACTION BUTTON (GO TO TRACKING IF FINISHED)
              // ==========================================
              if (_isCountdownFinished)
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
                    onPressed: _navigateToTracking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      "LIHAT PELACAKAN PERJALANAN ➔",
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
