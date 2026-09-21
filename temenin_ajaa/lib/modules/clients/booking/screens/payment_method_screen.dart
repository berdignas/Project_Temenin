import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/providers/client_booking_provider.dart';
import 'package:temenin_ajaa/modules/clients/services/payment_service.dart';
import 'tracking_driver_screen.dart';
import 'call_lobby_screen.dart';
import 'qris_payment_screen.dart';
import 'client_waiting_countdown_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final Map<String, dynamic>? bookingData;
  final String? bookingId;
  final bool isPelunasan;
  
  const PaymentMethodScreen({super.key, this.bookingData, this.bookingId, this.isPelunasan = false});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String selectedMethod = "qris";
  
  late int totalPayment;
  late int dpAmount;
  late int payAmount;

  @override
  void initState() {
    super.initState();
    final rawTotal = widget.bookingData?['totalPayment'] ?? widget.bookingData?['total_price'] ?? 250000;
    totalPayment = rawTotal is num ? rawTotal.toInt() : (int.tryParse(rawTotal.toString()) ?? 250000);
    final rawDp = widget.bookingData?['dp'];
    dpAmount = rawDp is num ? rawDp.toInt() : (int.tryParse(rawDp?.toString() ?? '') ?? (totalPayment * 0.5).toInt());
    payAmount = widget.isPelunasan ? (totalPayment - dpAmount) : dpAmount;
  }

  @override
  Widget build(BuildContext context) {
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
          "Metode Pembayaran",
          style: GoogleFonts.inter(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildTotalPaymentCard(),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Rekomendasi Utama (Instan)"),
                    const SizedBox(height: 12),
                    _buildPaymentTile(
                      id: "qris",
                      icon: Icons.qr_code_2_rounded,
                      title: "QRIS (Semua Bank & E-Wallet)",
                      subtitle: "BCA, Mandiri, BRI, GoPay, OVO, DANA, dll",
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle("Metode Lainnya & E-Wallet"),
                    const SizedBox(height: 12),
                    _buildPaymentTile(
                      id: "gopay",
                      icon: Icons.account_balance_wallet_rounded,
                      title: "GoPay",
                      subtitle: "Saldo Aktif: Rp 1.250.000",
                      isPriceSubtitle: true,
                    ),
                    const SizedBox(height: 10),
                    _buildPaymentTile(
                      id: "dana", 
                      icon: Icons.account_balance_rounded, 
                      title: "DANA", 
                      subtitle: "Terhubung otomatis",
                    ),
                    const SizedBox(height: 10),
                    _buildPaymentTile(
                      id: "ovo", 
                      icon: Icons.account_balance_wallet_outlined, 
                      title: "OVO", 
                      subtitle: "OVO Cash & Points",
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle("Virtual Account Bank"),
                    const SizedBox(height: 12),
                    _buildPaymentTile(
                      id: "bca", 
                      title: "BCA Virtual Account", 
                      logoText: "BCA",
                      subtitle: "Verifikasi otomatis 24 jam",
                    ),
                    const SizedBox(height: 10),
                    _buildPaymentTile(
                      id: "mandiri", 
                      title: "Mandiri Virtual Account", 
                      logoText: "MDR",
                      subtitle: "Verifikasi otomatis 24 jam",
                    ),
                    const SizedBox(height: 10),
                    _buildPaymentTile(
                      id: "bri", 
                      title: "BRI Virtual Account (BRIVA)", 
                      logoText: "BRI",
                      subtitle: "Verifikasi otomatis 24 jam",
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle("Kartu Debit / Kredit"),
                    const SizedBox(height: 12),
                    _buildPaymentTile(
                      id: "visa",
                      icon: Icons.credit_card_rounded,
                      title: "Visa •••• 1234",
                      subtitle: "Berlaku hingga 12/26",
                    ),
                    const SizedBox(height: 10),
                    _buildPaymentTile(
                      id: "new_card", 
                      icon: Icons.add_card_rounded, 
                      title: "Tambah Kartu Baru", 
                      subtitle: "Visa, Mastercard, JCB, GPN",
                    ),
                    
                    const SizedBox(height: 20),
                    _buildPromoCodeField(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalPaymentCard() {
    String formatCurrency(int amount) {
      return "Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isPelunasan ? "TOTAL PELUNASAN SISA (SEKARANG)" : "TOTAL DP WAJIB (SEKARANG)",
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatCurrency(payAmount),
                style: GoogleFonts.inter(
                  color: AppTheme.primaryPink,
                  fontSize: 26, 
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isPelunasan ? "DP yang telah terbayar: ${formatCurrency(dpAmount)}" : "Total transaksi penuh: ${formatCurrency(totalPayment)}",
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.fuchsiaLight, 
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryPink, size: 28),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title, 
      style: GoogleFonts.inter(
        color: AppTheme.textHighContrast, 
        fontSize: 15, 
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildPaymentTile({
    required String id,
    IconData? icon,
    required String title,
    String? subtitle,
    bool isPriceSubtitle = false,
    String? logoText,
  }) {
    bool isSelected = selectedMethod == id;

    return GestureDetector(
      onTap: () => setState(() => selectedMethod = id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.fuchsiaLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryPink : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryPink.withOpacity(0.12) : AppTheme.cardDeep,
                borderRadius: BorderRadius.circular(12),
              ),
              child: logoText != null
                  ? Center(
                      child: Text(
                        logoText, 
                        style: const TextStyle(
                          color: Color(0xFF0284C7), 
                          fontWeight: FontWeight.bold, 
                          fontSize: 13,
                        ),
                      ),
                    )
                  : Icon(
                      icon, 
                      color: isSelected ? AppTheme.primaryPink : AppTheme.textHighContrast, 
                      size: 22,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: GoogleFonts.inter(
                      color: AppTheme.textHighContrast, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle, 
                      style: GoogleFonts.inter(
                        color: isPriceSubtitle ? AppTheme.primaryPink : AppTheme.textMuted, 
                        fontSize: 12,
                        fontWeight: isPriceSubtitle ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primaryPink : AppTheme.border, 
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12, 
                        height: 12, 
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryPink, 
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCodeField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined, color: AppTheme.primaryPink, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Punya kode promo?",
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
            ),
          ),
          Text(
            "PAKAI", 
            style: GoogleFonts.inter(
              color: AppTheme.primaryPink, 
              fontWeight: FontWeight.bold, 
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    String formatCurrency(int amount) {
      return "Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                // Show loading progress dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                    ),
                  ),
                );

                final bookingDetails = Map<String, dynamic>.from(widget.bookingData ?? {});
                final existingOtp = bookingDetails['otp'] ?? 
                                   (bookingDetails['additional_details'] is Map ? bookingDetails['additional_details']['otp'] : null);
                if (widget.isPelunasan && existingOtp != null && existingOtp.toString().isNotEmpty) {
                  bookingDetails['otp'] = existingOtp.toString();
                } else {
                  final random = Random();
                  final freshOtp = (random.nextInt(9000) + 1000).toString();
                  String freshServiceOtp;
                  do {
                    freshServiceOtp = (random.nextInt(9000) + 1000).toString();
                  } while (freshServiceOtp == freshOtp);
                  String freshCompOtp;
                  do {
                    freshCompOtp = (random.nextInt(9000) + 1000).toString();
                  } while (freshCompOtp == freshOtp || freshCompOtp == freshServiceOtp);

                  bookingDetails['otp'] = freshOtp;
                  bookingDetails['security_pin'] = freshOtp;
                  bookingDetails['start_otp'] = freshOtp;
                  bookingDetails['service_pin'] = freshServiceOtp;
                  bookingDetails['start_service_pin'] = freshServiceOtp;
                  bookingDetails['service_otp'] = freshServiceOtp;
                  bookingDetails['completion_otp'] = freshCompOtp;
                }

                String? currentBookingId = widget.bookingId;

                // 1. Jika booking belum ada di server backend, buat terlebih dahulu via REST API (/api/bookings)
                if (currentBookingId == null || currentBookingId.isEmpty || currentBookingId.startsWith('mock')) {
                  final bookingProvider = Provider.of<ClientBookingProvider>(context, listen: false);
                  final createRes = await bookingProvider.createBookingRequest(bookingDetails);

                  if (createRes['success'] != true) {
                    if (mounted) {
                      Navigator.pop(context); // close loading dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(createRes['message'] ?? 'Gagal membuat pesanan'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }

                  final createdBooking = createRes['booking'] ?? createRes['data'];
                  currentBookingId = createdBooking?['id']?.toString();
                }

                if (currentBookingId == null) {
                  if (mounted) {
                    Navigator.pop(context); // close loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ID pesanan tidak valid untuk pemrosesan pembayaran.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                  return;
                }

                final paymentService = PaymentService();

                // 2. Jika metode pembayaran adalah QRIS (Xendit Sandbox / Production)
                if (selectedMethod == "qris") {
                  final qrisRes = await paymentService.createQrisPayment(
                    bookingId: currentBookingId,
                    amount: payAmount.toDouble(),
                    paymentType: widget.isPelunasan ? 'pelunasan' : 'dp',
                  );

                  if (mounted) {
                    Navigator.pop(context); // Close loading dialog

                    final qrisData = qrisRes['data'] ?? {};
                    final qrString = qrisData['qr_string']?.toString() ?? 
                        '00020101021226680016ID.CO.XENDIT.WWW01189360091430000000000215200458115303360540${payAmount.toInt()}5802ID5912TEMENIN AJAA6007JAKARTA61051219062070703A016304C7B9';

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QrisPaymentScreen(
                          bookingData: bookingDetails,
                          bookingId: currentBookingId!,
                          amount: payAmount.toDouble(),
                          paymentType: widget.isPelunasan ? 'pelunasan' : 'dp',
                          qrString: qrString,
                          qrisId: qrisData['qris_id']?.toString() ?? 'qr_simulated_${DateTime.now().millisecondsSinceEpoch}',
                          isSimulated: true,
                        ),
                      ),
                    );
                  }
                  return;
                }

                // 3. Jika metode E-Wallet / Saldo Wallet
                final paymentResult = await paymentService.processPayment(
                  bookingId: currentBookingId,
                  amount: payAmount.toDouble(),
                  paymentType: widget.isPelunasan ? 'pelunasan' : 'dp',
                  useWallet: true,
                );

                if (mounted) {
                  Navigator.pop(context); // Close loading dialog

                  if (paymentResult['success'] == true) {
                    if (widget.isPelunasan) {
                      bookingDetails['status'] = 'completed';
                      bookingDetails['sub_status'] = 'paid';
                      bookingDetails['final_paid'] = true;
                      bookingDetails['pelunasan_paid'] = true;
                    } else {
                      bookingDetails['status'] = 'ongoing';
                      bookingDetails['sub_status'] = 'dp_paid';
                      bookingDetails['dp_paid'] = true;
                    }

                    final isVirtual = bookingDetails['service_category'] == 'VIRTUAL' || 
                                      bookingDetails['call_type'] != null ||
                                      (bookingDetails['serviceType']?.toString().toLowerCase().contains('telepon') ?? false) ||
                                      (bookingDetails['serviceType']?.toString().toLowerCase().contains('sleep') ?? false);

                    if (isVirtual) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CallLobbyScreen(
                            bookingDetails: bookingDetails,
                            bookingId: currentBookingId,
                          ),
                        ),
                        (route) => false,
                      );
                    } else if (!widget.isPelunasan) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClientWaitingCountdownScreen(
                            bookingData: bookingDetails,
                            bookingId: currentBookingId,
                          ),
                        ),
                        (route) => false,
                      );
                    } else {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrackingDriverScreen(
                            bookingData: bookingDetails,
                            bookingId: currentBookingId,
                            initialStatus: 'review',
                          ),
                        ),
                        (route) => false,
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(paymentResult['message'] ?? 'Gagal memproses pembayaran'),
                        backgroundColor: Colors.redAccent,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                widget.isPelunasan ? "Pelunasan Sisa ${formatCurrency(payAmount)}" : "Bayar DP ${formatCurrency(payAmount)}",
                style: GoogleFonts.inter(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}