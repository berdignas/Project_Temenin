import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/booking_model.dart';
import '../../../providers/booking_provider.dart';
import 'driver_negotiation_screen.dart';
import 'driver_waiting_dp_screen.dart';

import 'home_screen.dart';

class DriverOrderDetailScreen extends StatefulWidget {
  final BookingModel bookingData;

  const DriverOrderDetailScreen({super.key, required this.bookingData});

  @override
  State<DriverOrderDetailScreen> createState() => _DriverOrderDetailScreenState();
}

class _DriverOrderDetailScreenState extends State<DriverOrderDetailScreen> {
  bool _isProcessing = false;
  Map<String, dynamic>? _fetchedClientData;

  @override
  void initState() {
    super.initState();
    _fetchClientProfileIfNeeded();
  }

  Future<void> _fetchClientProfileIfNeeded() async {
    final client = widget.bookingData.client;
    if (client != null && (client.avatarUrl ?? '').isNotEmpty) {
      return;
    }
    final userId = widget.bookingData.userId;
    if (userId.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.from('users').select('*').eq('id', userId).maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _fetchedClientData = Map<String, dynamic>.from(res);
        });
      }
    } catch (e) {
      debugPrint("Error fetching client profile in DriverOrderDetailScreen: $e");
    }
  }

  void _handleBackNavigation() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
      );
    }
  }

  String _formatPrice(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.bookingData;
    final client = booking.client;
    final details = booking.additionalDetails ?? {};

    final rawName = client?.fullName.isNotEmpty == true
        ? client!.fullName
        : (_fetchedClientData?['full_name'] ??
            _fetchedClientData?['name'] ??
            details['userName'] ??
            details['user_name'] ??
            details['clientName'] ??
            details['client_name'] ??
            details['name']);
    final clientName = (rawName != null && rawName.toString().isNotEmpty) ? rawName.toString() : 'Pelanggan Temenin Ajaa';

    final rawPhoto = client?.avatarUrl ??
        client?.profileImage ??
        _fetchedClientData?['avatar_url'] ??
        _fetchedClientData?['avatarUrl'] ??
        details['userImage'] ??
        details['userPhoto'] ??
        details['user_avatar'] ??
        details['avatar_url'] ??
        details['clientPhoto'] ??
        details['client_image'] ??
        details['avatar'] ??
        '';
    
    final String clientPhoto = (rawPhoto != null && rawPhoto.toString().trim().isNotEmpty)
        ? rawPhoto.toString().trim()
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(clientName)}&background=D64573&color=fff&bold=true';

    final serviceType = details['serviceType'] ?? details['service_type'] ?? 'Pendampingan Utama';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textHighContrast, size: 20),
            onPressed: _handleBackNavigation,
          ),
        title: Text(
          "Rincian Pesanan Masuk",
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
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
                              "PESANAN MASUK - MENUNGGU KONFIRMASI",
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.primaryPink,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Client Profile Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppTheme.fuchsiaLight,
                            backgroundImage: NetworkImage(clientPhoto),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        clientName,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: AppTheme.textHighContrast,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 16),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      "4.9 (Pelanggan Terverifikasi)",
                                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Order Details Bento
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
                            "DETAIL LAYANAN",
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Service type & duration
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPink.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.favorite_rounded, color: AppTheme.primaryPink, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      serviceType.toString(),
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.textHighContrast,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Durasi: ${booking.duration} Jam",
                                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(color: AppTheme.border, height: 1),
                          ),

                          // Pickup & Dropoff Timeline
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  const Icon(Icons.circle, color: Colors.greenAccent, size: 14),
                                  Container(
                                    width: 2,
                                    height: 36,
                                    color: AppTheme.border,
                                  ),
                                  const Icon(Icons.location_on_rounded, color: AppTheme.primaryPink, size: 16),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "LOKASI PENJEMPUTAN",
                                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      booking.pickupLocation,
                                      style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      "LOKASI TUJUAN",
                                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      booking.dropoffLocation,
                                      style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (details['catatan'] != null || details['notes'] != null || details['kebutuhan_khusus'] != null) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(color: AppTheme.border, height: 1),
                            ),
                            Text(
                              "CATATAN TAMBAHAN PELANGGAN",
                              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.cardDeep,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                (details['catatan'] ?? details['notes'] ?? details['kebutuhan_khusus'] ?? '-').toString(),
                                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Tariff Breakdown Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TOTAL TARIF PESANAN",
                                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Rp ${_formatPrice(booking.totalPrice)}",
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.primaryPink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Sistem Rekening Bersama (Escrow)",
                                style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: const Border(top: BorderSide(color: AppTheme.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: Consumer<BookingProvider>(
                builder: (context, bookingProvider, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          // Reject Button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isProcessing
                                  ? null
                                  : () async {
                                      setState(() => _isProcessing = true);
                                      await bookingProvider.rejectBooking(booking.id);
                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Pesanan telah ditolak."),
                                            backgroundColor: Colors.orangeAccent,
                                          ),
                                        );
                                      }
                                    },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.danger),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                "TOLAK",
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.danger,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Negotiate Button (if flexible)
                          if (booking.isFlexible) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => DriverNegotiationScreen(bookingData: booking),
                                          ),
                                        );
                                      },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.primaryPink),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  "TAWAR",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.primaryPink,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],

                          // Accept Button
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryPink.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () async {
                                        setState(() => _isProcessing = true);
                                        final success = await bookingProvider.acceptBooking(booking.id);
                                        if (mounted) {
                                          setState(() => _isProcessing = false);
                                          if (success) {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => DriverWaitingDpScreen(bookingData: booking),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(bookingProvider.errorMessage ?? "Gagal menerima pesanan"),
                                                backgroundColor: Colors.redAccent,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _isProcessing
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text(
                                        "TERIMA PESANAN ➔",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
