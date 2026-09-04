import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/booking_model.dart';
import 'driver_negotiation_screen.dart';

class OpenOffersScreen extends StatefulWidget {
  const OpenOffersScreen({super.key});

  @override
  State<OpenOffersScreen> createState() => _OpenOffersScreenState();
}

class _OpenOffersScreenState extends State<OpenOffersScreen> {
  final List<BookingModel> _openOffers = [];

  String _formatPrice(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textHighContrast, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Tawaran & Permintaan",
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBgGradient,
        ),
        child: _openOffers.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: AppTheme.cardDeep,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inbox_rounded, color: AppTheme.textMuted, size: 54),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Belum ada tawaran terbuka saat ini.",
                      style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Permintaan pendampingan kustom akan muncul di sini.",
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _openOffers.length,
                itemBuilder: (context, index) {
                  final offer = _openOffers[index];
                  return _buildOfferCard(offer);
                },
              ),
      ),
    );
  }

  Widget _buildOfferCard(BookingModel offer) {
    final clientName = offer.client?.fullName ?? 'Client';
    final desc = offer.additionalDetails?['description'] ?? 'Deskripsi tidak tersedia';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: offer.client?.avatarUrl != null ? NetworkImage(offer.client!.avatarUrl!) : null,
                backgroundColor: AppTheme.cardDeep,
                child: offer.client?.avatarUrl == null ? const Icon(Icons.person, color: AppTheme.textMuted) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, color: AppTheme.textMuted, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "Membutuhkan ${offer.duration} Jam",
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "CUSTOM",
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              )
            ],
          ),
          const SizedBox(height: 14),
          Text(
            desc,
            style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(color: AppTheme.border, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Penawaran Harga:", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
                  Text(
                    "Rp ${_formatPrice(offer.totalPrice)}",
                    style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverNegotiationScreen(bookingData: offer),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: Text("Beli / Tawar", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          )
        ],
      ),
    );
  }
}
