import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_sound_service.dart';
import '../../../core/utils/booking_date_helper.dart';
import '../../../data/models/booking_model.dart';
import 'chat_room_screen.dart';
import 'driver_waiting_countdown_screen.dart';

class DriverWaitingDpScreen extends StatefulWidget {
  final BookingModel bookingData;

  const DriverWaitingDpScreen({
    super.key,
    required this.bookingData,
  });

  @override
  State<DriverWaitingDpScreen> createState() => _DriverWaitingDpScreenState();
}

class _DriverWaitingDpScreenState extends State<DriverWaitingDpScreen> with SingleTickerProviderStateMixin {
  late BookingModel _currentBooking;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSub;
  Timer? _pollTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.bookingData;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkInitialStatusAndListen();
  }

  void _checkInitialStatusAndListen() {
    // Check if already dp_paid
    final add = _currentBooking.additionalDetails;
    final isDpPaid = add?['dp_paid'] == true || 
                     add?['sub_status'] == 'dp_paid' || 
                     _currentBooking.status == 'dp_paid' ||
                     _currentBooking.status == 'ongoing' ||
                     add?['countdown_ended'] == true;

    if (isDpPaid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _proceedToCountdown(_currentBooking);
      });
      return;
    }

    // Stream updates from Supabase
    try {
      final bId = _currentBooking.id;
      final dynamic queryId = int.tryParse(bId) ?? bId;

      _streamSub = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', queryId)
          .listen(
            (data) {
              if (data.isNotEmpty && mounted && !_isTransitioning) {
                final row = data.first;
                final rowAdd = row['additional_details'] is Map 
                    ? row['additional_details'] as Map 
                    : (row['additionalDetails'] is Map ? row['additionalDetails'] as Map : null);
                final subStatus = rowAdd?['sub_status']?.toString();
                final rawStatus = row['status']?.toString();
                final isPaid = rowAdd?['dp_paid'] == true || 
                               subStatus == 'dp_paid' || 
                               rawStatus == 'dp_paid' ||
                               rawStatus == 'ongoing' ||
                               rowAdd?['countdown_ended'] == true;

                if (rawStatus == 'cancelled') {
                  if (mounted) {
                    try {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Pesanan telah dibatalkan oleh klien."),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    } catch (_) {}
                    Navigator.pop(context);
                  }
                  return;
                }

                if (isPaid) {
                  final updatedBooking = BookingModel.fromJson(row);
                  _proceedToCountdown(updatedBooking);
                }
              }
            },
            onError: (err) {
              debugPrint("Driver waiting DP stream error: $err");
            },
          );
    } catch (e) {
      debugPrint("Error listening to DP status: $e");
    }

    // Periodic poll fallback in case realtime stream is delayed
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_isTransitioning || !mounted) return;
      try {
        final bId = _currentBooking.id;
        final dynamic queryId = int.tryParse(bId) ?? bId;
        final row = await Supabase.instance.client
            .from('bookings')
            .select()
            .eq('id', queryId)
            .maybeSingle();

        if (row != null && mounted && !_isTransitioning) {
          final rowAdd = row['additional_details'] is Map 
              ? row['additional_details'] as Map 
              : (row['additionalDetails'] is Map ? row['additionalDetails'] as Map : null);
          final subStatus = rowAdd?['sub_status']?.toString();
          final rawStatus = row['status']?.toString();
          final isPaid = rowAdd?['dp_paid'] == true || 
                         subStatus == 'dp_paid' || 
                         rawStatus == 'dp_paid' ||
                         rawStatus == 'ongoing' ||
                         rowAdd?['countdown_ended'] == true;

          if (isPaid) {
            final updatedBooking = BookingModel.fromJson(row);
            _proceedToCountdown(updatedBooking);
          }
        }
      } catch (_) {}
    });
  }

  void _proceedToCountdown(BookingModel booking) {
    if (_isTransitioning || !mounted) return;
    _isTransitioning = true;

    try {
      NotificationSoundService().playOrderAlert();
    } catch (e) {
      debugPrint("Error sound: $e");
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🎉 DP 50% Berhasil Diterima dari Klien! Melanjutkan ke hitung mundur jadwal..."),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DriverWaitingCountdownScreen(bookingData: booking),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _streamSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  String _formatCurrency(num amount) {
    return "Rp ${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  Future<void> _handleCancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Text(
          "Batalkan Pesanan?",
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Apakah Anda yakin ingin membatalkan pesanan ini karena klien belum membayar DP?",
          style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("TIDAK", style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("YA, BATALKAN", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final dynamic queryId = int.tryParse(_currentBooking.id) ?? _currentBooking.id;
        await Supabase.instance.client
            .from('bookings')
            .update({
              'status': 'cancelled',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', queryId);

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint("Error cancelling booking: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = _currentBooking.client;
    final rawClientName = client?.fullName ??
        _currentBooking.additionalDetails?['userName'] ??
        _currentBooking.additionalDetails?['user_name'] ??
        _currentBooking.additionalDetails?['clientName'] ??
        _currentBooking.additionalDetails?['client_name'] ??
        _currentBooking.additionalDetails?['name'];
    final clientName = (rawClientName != null && rawClientName.toString().trim().isNotEmpty)
        ? rawClientName.toString().trim()
        : 'Klien Temenin';

    final rawClientPhoto = client?.avatarUrl ??
        client?.profileImage ??
        _currentBooking.additionalDetails?['userImage'] ??
        _currentBooking.additionalDetails?['userPhoto'] ??
        _currentBooking.additionalDetails?['user_avatar'] ??
        _currentBooking.additionalDetails?['avatar'] ??
        '';
    String clientImage = (rawClientPhoto != null && rawClientPhoto.toString().trim().isNotEmpty)
        ? rawClientPhoto.toString().trim()
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(clientName)}&background=D64573&color=fff&bold=true';
    if (clientImage.startsWith('/uploads')) {
      clientImage = '${ApiConstants.baseUrl}$clientImage';
    }
    final clientPhone = client?.phone ?? _currentBooking.additionalDetails?['clientPhone']?.toString() ?? '-';

    final totalVal = _currentBooking.totalPrice > 0 
        ? _currentBooking.totalPrice 
        : ((_currentBooking.additionalDetails?['totalPayment'] ?? _currentBooking.additionalDetails?['total_price'] ?? 100000) as num).toDouble();
    final dpVal = (totalVal * 0.5).toInt();
    final sisaVal = totalVal.toInt() - dpVal;

    final scheduleText = BookingDateHelper.getScheduleDisplay(
      _currentBooking.additionalDetails ?? {'date': _currentBooking.bookingDate?.toIso8601String()}
    );

    final serviceType = _currentBooking.additionalDetails?['serviceType']?.toString().toUpperCase() ?? 'PENDAMPINGAN';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textHighContrast, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Menunggu DP Klien",
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. STATUS BADGE
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryPink.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryPink,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "STATUS: ORDER DITERIMA • MENUNGGU DP",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primaryPink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. PULSING ICON ANIMATION
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.withOpacity(0.2),
                        AppTheme.primaryPink.withOpacity(0.2),
                      ],
                    ),
                    border: Border.all(color: Colors.amber.withOpacity(0.6), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 44),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "Menunggu Pembayaran DP Klien",
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Order telah Anda setujui! Klien $clientName saat ini sedang melakukan transfer atau scan QRIS untuk pembayaran DP 50%.",
                style: GoogleFonts.inter(
                  color: AppTheme.textMediumContrast,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // 3. PAYMENT SUMMARY CARD
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Total Biaya Layanan", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
                        Text(_formatCurrency(totalVal), style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const Divider(color: AppTheme.border, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 6),
                            Text("DP Wajib (50%)", style: GoogleFonts.inter(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        Text(
                          _formatCurrency(dpVal),
                          style: GoogleFonts.plusJakartaSans(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ],
                    ),
                    const Divider(color: AppTheme.border, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Sisa Pelunasan Selesai Layanan", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                        Text(_formatCurrency(sisaVal), style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. ORDER & CLIENT DETAILS
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
                    // Client Info Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppTheme.fuchsiaLight,
                          child: ClipOval(
                            child: Image.network(
                              clientImage,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: AppTheme.primaryPink, size: 22),
                            ),
                          ),
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
                                clientPhone != '-' ? "Layanan: $serviceType • $clientPhone" : "Layanan: $serviceType",
                                style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DriverChatRoomScreen(
                                  bookingId: _currentBooking.id,
                                  clientName: clientName,
                                  clientImage: clientImage,
                                ),
                              ),
                            );
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPink.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chat_bubble_rounded, color: AppTheme.primaryPink, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: AppTheme.border, height: 24),

                    // Schedule Info
                    Row(
                      children: [
                        const Icon(Icons.event_note_rounded, color: AppTheme.primaryPink, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Jadwal: $scheduleText",
                            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Pickup
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.my_location_rounded, color: Colors.green, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _currentBooking.pickupLocation,
                            style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Dropoff
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _currentBooking.dropoffLocation,
                            style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. LIVE HINT NOTE
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Layar ini akan otomatis berganti ke hitung mundur jadwal begitu klien menyelesaikan pembayaran DP 50%. Anda tidak perlu me-refresh.",
                        style: GoogleFonts.inter(color: Colors.blueAccent.shade100, fontSize: 11, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 6. CANCEL BUTTON
              OutlinedButton.icon(
                onPressed: _handleCancelBooking,
                icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
                label: Text(
                  "Batalkan Pesanan Ini",
                  style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
