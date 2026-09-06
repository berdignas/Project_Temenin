// lib/modules/booking/screens/payment_method_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import '../../../../providers/auth_provider.dart';
import 'tracking_driver_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final Map<String, dynamic>? bookingData;
  final String? bookingId;
  
  const PaymentMethodScreen({super.key, this.bookingData, this.bookingId});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String selectedMethod = "gopay";
  
  late int totalPayment;
  late int dpAmount;

  @override
  void initState() {
    super.initState();
    totalPayment = widget.bookingData?['totalPayment'] ?? 250000;
    dpAmount = widget.bookingData?['dp'] ?? 125000;
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
                    _buildSectionTitle("Metode Utama & E-Wallet"),
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
                "TOTAL DP WAJIB (SEKARANG)",
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatCurrency(dpAmount),
                style: GoogleFonts.inter(
                  color: AppTheme.primaryPink,
                  fontSize: 26, 
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Total transaksi penuh: ${formatCurrency(totalPayment)}",
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

                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final userId = authProvider.user?.id;
                
                final bookingDetails = Map<String, dynamic>.from(widget.bookingData ?? {});
                final existingOtp = bookingDetails['otp'] ?? 
                                   (bookingDetails['additional_details'] is Map ? bookingDetails['additional_details']['otp'] : null);
                if (existingOtp != null && existingOtp.toString().isNotEmpty) {
                  bookingDetails['otp'] = existingOtp.toString();
                } else {
                  final random = Random();
                  bookingDetails['otp'] = (random.nextInt(9000) + 1000).toString();
                }

                String? bookingId = widget.bookingId;
                try {
                  if (userId != null) {
                    if (bookingId != null && !bookingId.startsWith('mock')) {
                      bookingDetails['sub_status'] = 'dp_paid';
                      bookingDetails['dp_paid'] = true;
                      String? updateDriverId = bookingDetails['driverId'] ?? bookingDetails['partnerId'] ?? bookingDetails['driver_id'];
                      final updateData = <String, dynamic>{
                        'status': 'ongoing',
                        'additional_details': bookingDetails,
                      };
                      if (updateDriverId != null && !updateDriverId.startsWith('mock') && !updateDriverId.startsWith('drv-') && !updateDriverId.startsWith('d1')) {
                        updateData['driver_id'] = updateDriverId;
                      }
                      await Supabase.instance.client
                          .from('bookings')
                          .update(updateData)
                          .eq('id', bookingId);
                    } else {
                      // Resolve target driver ID
                      String? driverId = bookingDetails['driverId'] ?? 
                                         bookingDetails['partnerId'] ?? 
                                         bookingDetails['selectedPartner']?['id'] ??
                                         bookingDetails['partner']?['id'];
                      
                      if (driverId == null || driverId.isEmpty || driverId.startsWith('mock') || driverId.startsWith('drv-') || driverId.startsWith('d1')) {
                        try {
                          final onlineDriver = await Supabase.instance.client
                              .from('drivers')
                              .select('id')
                              .eq('is_available', true)
                              .limit(1)
                              .maybeSingle();
                          if (onlineDriver != null && onlineDriver['id'] != null) {
                            driverId = onlineDriver['id'].toString();
                          } else {
                            final approvedDriver = await Supabase.instance.client
                                .from('drivers')
                                .select('id')
                                .limit(1)
                                .maybeSingle();
                            if (approvedDriver != null && approvedDriver['id'] != null) {
                              driverId = approvedDriver['id'].toString();
                            }
                          }
                        } catch (e) {
                          debugPrint("Error fetching default driver: $e");
                        }
                      }

                      String? validDriverId;
                      if (driverId != null && !driverId.startsWith('mock') && !driverId.startsWith('drv-') && !driverId.startsWith('d1')) {
                        validDriverId = driverId;
                      }

                      final totalPriceVal = bookingDetails['totalPrice'] ?? bookingDetails['price'] ?? bookingDetails['totalPayment'] ?? 50000;
                      final numPrice = totalPriceVal is num ? totalPriceVal.toDouble() : (double.tryParse(totalPriceVal.toString()) ?? 50000.0);

                      bookingDetails['sub_status'] = 'dp_paid';
                      bookingDetails['dp_paid'] = true;
                      final insertPayload = <String, dynamic>{
                        'user_id': userId,
                        'status': 'ongoing',
                        'pickup_location': bookingDetails['pickup'] ?? bookingDetails['location'] ?? 'Lokasi Penjemputan',
                        'dropoff_location': bookingDetails['destination'] ?? bookingDetails['location'] ?? 'Tujuan',
                        'total_price': numPrice,
                        'additional_details': bookingDetails,
                      };
                      if (validDriverId != null && validDriverId.isNotEmpty) {
                        insertPayload['driver_id'] = validDriverId;
                      }

                      try {
                        final response = await Supabase.instance.client
                            .from('bookings')
                            .insert(insertPayload)
                            .select('id')
                            .single();
                        bookingId = response['id']?.toString();
                      } catch (err) {
                        debugPrint("First insert attempt failed in payment: $err. Retrying without driver_id...");
                        insertPayload.remove('driver_id');
                        final response = await Supabase.instance.client
                            .from('bookings')
                            .insert(insertPayload)
                            .select('id')
                            .single();
                        bookingId = response['id']?.toString();
                      }
                    }
                  }
                } catch (e) {
                  debugPrint("Failed saving booking to Supabase: $e");
                }

                if (mounted) {
                  Navigator.pop(context); // Close loading dialog
                  
                  // Update local state so TrackingDriverScreen knows DP is paid
                  bookingDetails['status'] = 'dp_paid';
                  bookingDetails['sub_status'] = 'dp_paid';
                  bookingDetails['dp_paid'] = true;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TrackingDriverScreen(
                        bookingData: bookingDetails,
                        bookingId: bookingId,
                      ),
                    ),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                "Bayar DP ${formatCurrency(dpAmount)}",
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