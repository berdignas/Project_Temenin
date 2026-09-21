import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/modules/clients/services/payment_service.dart';
import 'tracking_driver_screen.dart';
import 'call_lobby_screen.dart';
import 'client_waiting_countdown_screen.dart';

class QrisPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final String bookingId;
  final double amount;
  final String paymentType; // 'dp' or 'pelunasan'
  final String qrString;
  final String? qrisId;
  final bool isSimulated;

  const QrisPaymentScreen({
    super.key,
    required this.bookingData,
    required this.bookingId,
    required this.amount,
    required this.paymentType,
    required this.qrString,
    this.qrisId,
    this.isSimulated = false,
  });

  @override
  State<QrisPaymentScreen> createState() => _QrisPaymentScreenState();
}

class _QrisPaymentScreenState extends State<QrisPaymentScreen> {
  bool _isProcessingSimulation = false;
  bool _isPaymentConfirmed = false;
  StreamSubscription? _bookingSubscription;
  Timer? _pollingTimer;

  int _countdownSeconds = 900; // 15 minutes
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _listenToBookingStatus();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _bookingSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdownSeconds > 0) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  String _formatCurrency(double amount) {
    return "Rp ${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  void _listenToBookingStatus() {
    try {
      // 1. Real-time stream from Supabase bookings table
      _bookingSubscription = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', widget.bookingId)
          .handleError((err) {
            debugPrint('Realtime booking stream error handled: $err');
          })
          .listen(
            (List<Map<String, dynamic>> records) {
              if (!mounted || _isPaymentConfirmed) return;
              if (records.isNotEmpty) {
                final b = records.first;
                _checkIfPaidAndProceed(b);
              }
            },
            onError: (err) {
              debugPrint('Realtime booking stream error: $err');
            },
            cancelOnError: false,
          );
    } catch (e) {
      debugPrint('Realtime booking stream exception: $e');
    }

    // 2. Fallback polling every 4 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted || _isPaymentConfirmed) {
        timer.cancel();
        return;
      }
      try {
        final res = await Supabase.instance.client
            .from('bookings')
            .select('*')
            .eq('id', widget.bookingId)
            .maybeSingle();
        if (res != null) {
          _checkIfPaidAndProceed(res);
        }
      } catch (_) {}
    });
  }

  void _checkIfPaidAndProceed(Map<String, dynamic> booking) {
    final status = booking['status']?.toString().toLowerCase();
    final addDetails = booking['additional_details'] is Map ? booking['additional_details'] as Map : {};
    final isDp = widget.paymentType == 'dp';

    final isPaid = isDp
        ? (addDetails['dp_paid'] == true || status == 'ongoing' || addDetails['sub_status'] == 'dp_paid')
        : (addDetails['pelunasan_paid'] == true || addDetails['final_paid'] == true || status == 'completed');

    if (isPaid && !_isPaymentConfirmed) {
      _isPaymentConfirmed = true;
      _bookingSubscription?.cancel();
      _pollingTimer?.cancel();
      _countdownTimer?.cancel();

      if (!mounted) return;

      try {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Pembayaran QRIS berhasil diverifikasi!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (_) {}

      final isVirtual = widget.bookingData['service_category'] == 'VIRTUAL' ||
          widget.bookingData['call_type'] != null ||
          (widget.bookingData['serviceType']?.toString().toLowerCase().contains('telepon') ?? false) ||
          (widget.bookingData['serviceType']?.toString().toLowerCase().contains('sleep') ?? false);

      final updatedBookingData = Map<String, dynamic>.from(widget.bookingData);
      if (isDp) {
        updatedBookingData['status'] = 'ongoing';
        updatedBookingData['sub_status'] = 'dp_paid';
        updatedBookingData['dp_paid'] = true;
      } else {
        updatedBookingData['status'] = 'completed';
        updatedBookingData['sub_status'] = 'paid';
        updatedBookingData['final_paid'] = true;
      }

      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        if (isVirtual) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => CallLobbyScreen(
                bookingDetails: updatedBookingData,
                bookingId: widget.bookingId,
              ),
            ),
            (route) => false,
          );
        } else if (isDp) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => ClientWaitingCountdownScreen(
                bookingData: updatedBookingData,
                bookingId: widget.bookingId,
              ),
            ),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => TrackingDriverScreen(
                bookingData: updatedBookingData,
                bookingId: widget.bookingId,
                initialStatus: 'review',
              ),
            ),
            (route) => false,
          );
        }
      });
    }
  }

  Future<void> _handleSimulatePaid() async {
    setState(() => _isProcessingSimulation = true);
    final isDp = widget.paymentType == 'dp';

    try {
      final paymentService = PaymentService();
      final res = await paymentService.simulateQrisPaid(
        bookingId: widget.bookingId,
        amount: widget.amount,
        paymentType: widget.paymentType,
      );

      if (res['success'] == true) {
        if (!mounted) return;
        setState(() => _isProcessingSimulation = false);
        _checkIfPaidAndProceed({
          'id': widget.bookingId,
          'status': isDp ? 'ongoing' : 'completed',
          'additional_details': {
            if (isDp) 'dp_paid': true else 'pelunasan_paid': true,
          }
        });
        return;
      } else {
        debugPrint('Backend simulate returned: ${res['message']}. Using direct Supabase fallback...');
      }
    } catch (e) {
      debugPrint('Backend simulate error: $e. Using direct Supabase fallback...');
    }

    // Direct Supabase fallback (ensures client can always simulate payment successfully in sandbox)
    try {
      final existingBooking = await Supabase.instance.client
          .from('bookings')
          .select('*')
          .eq('id', widget.bookingId)
          .maybeSingle();

      final addDetails = Map<String, dynamic>.from(existingBooking?['additional_details'] ?? {});
      final updatePayload = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isDp) {
        updatePayload['status'] = 'ongoing';
        addDetails['dp_paid'] = true;
        addDetails['sub_status'] = 'dp_paid';
        addDetails['dp_payment_status'] = 'paid';
        addDetails['dp_amount'] = widget.amount;
        addDetails['escrow_balance'] = widget.amount;
      } else {
        updatePayload['status'] = 'completed';
        addDetails['pelunasan_paid'] = true;
        addDetails['final_paid'] = true;
        addDetails['sub_status'] = 'paid';
        addDetails['payment_status'] = 'LUNAS';
      }
      updatePayload['additional_details'] = addDetails;

      await Supabase.instance.client
          .from('bookings')
          .update(updatePayload)
          .eq('id', widget.bookingId);

      if (!mounted) return;
      setState(() => _isProcessingSimulation = false);

      _checkIfPaidAndProceed({
        'id': widget.bookingId,
        'status': isDp ? 'ongoing' : 'completed',
        'additional_details': addDetails,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingSimulation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal simulasi pembayaran: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrImageUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(widget.qrString)}';

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
          "Pembayaran QRIS",
          style: GoogleFonts.inter(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // Countdown & Status Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Selesaikan Dalam",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatTimer(_countdownSeconds),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Total Amount Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.paymentType == 'dp' ? "Total DP Wajib Dibayar" : "Total Pelunasan",
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatCurrency(widget.amount),
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryPink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "ID Pesanan: #${widget.bookingId.substring(0, widget.bookingId.length > 8 ? 8 : widget.bookingId.length)}",
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Official QRIS Box Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // QRIS Brand Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "QRIS",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Standar Pembayaran Nasional",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    Text(
                      "TEMENIN AJAA OFFICIAL",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "NMID: ID1024392819208",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // QR Code Image
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300, width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          qrImageUrl,
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return SizedBox(
                              width: 220,
                              height: 220,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                      : null,
                                  color: AppTheme.primaryPink,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => SizedBox(
                            width: 220,
                            height: 220,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.qr_code_2_rounded, size: 80, color: AppTheme.textMuted),
                                const SizedBox(height: 8),
                                Text(
                                  "Gagal memuat visual QR",
                                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "Bisa discan GoPay, OVO, DANA, BCA, Mandiri, dll",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Sandbox Testing Button (Hanya tampil di mode Debug / Development)
              if (kDebugMode) ...[
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isProcessingSimulation ? null : _handleSimulatePaid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isProcessingSimulation
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Simulasikan Bayar Sukses (Sandbox)",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Copy QR String Action
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.qrString));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Kode string QRIS berhasil disalin"),
                      backgroundColor: Colors.black87,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.textHighContrast),
                label: Text(
                  "Salin Payload String QRIS",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textHighContrast,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
