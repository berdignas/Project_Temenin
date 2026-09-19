import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/providers/client_booking_provider.dart';
import 'dart:math';
import 'tracking_driver_screen.dart';
import 'call_lobby_screen.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic>? bookingData;
  
  const BookingConfirmationScreen({super.key, this.bookingData});

  @override
  Widget build(BuildContext context) {
    final bool isOpenOffer = bookingData?['isOpenOffer'] == true || 
                             bookingData?['is_open_offer'] == true || 
                             bookingData?['serviceType'] == 'freedom_request' || 
                             (bookingData?['driver_id'] == null && bookingData?['selectedPartner'] == null);

    final driverName = isOpenOffer 
        ? "Mitra Driver Terbuka (Open Bid)" 
        : (bookingData?['driverName'] ?? "Partner Driver");
    final driverImage = bookingData?['driverImage'] ?? '';
    final driverRating = bookingData?['driverRating'] ?? "4.9";
    final driverTrips = bookingData?['driverTrips'] ?? "450";
    final pickupLocation = bookingData?['pickup'] ?? "Senayan City Mall, Lobby Selatan";
    final destinationLocation = bookingData?['destination'] ?? "Bandara Internasional Soekarno-Hatta (T3)";
    final date = bookingData?['date'] ?? "Selasa, 24 Okt";
    final time = bookingData?['time'] ?? "14:30 WIB";
    final serviceType = bookingData?['serviceType'] ?? "antar_jemput";
    final driverClass = isOpenOffer ? "Open Bid" : (bookingData?['driverClass'] ?? "Gold");
    final vehicle = bookingData?['vehicle'] ?? "Kendaraan";
    final plateNumber = bookingData?['plateNumber'] ?? "-";

    // Pricing
    final serviceFee = bookingData?['serviceFee'] ?? 120000;
    final insuranceFee = bookingData?['insuranceFee'] ?? 10000;
    final totalPayment = bookingData?['totalPayment'] ?? 130000;
    final dp = bookingData?['dp'] ?? 65000;
    final remainingPayment = bookingData?['remainingPayment'] ?? 65000;
    final estimatedTime = bookingData?['estimatedTime'] ?? "45";

    // Addons
    final useCar = bookingData?['useCar'] ?? false;
    final rentHelmet = bookingData?['rentHelmet'] ?? false;
    final differentArea = bookingData?['differentArea'] ?? false;
    final pulangPergi = bookingData?['pulangPergi'] ?? false;
    final weekendFee = bookingData?['weekendFee'] ?? 0;

    final isVirtual = bookingData?['service_category'] == 'VIRTUAL' || 
                      bookingData?['call_type'] != null ||
                      (serviceType.toString().toLowerCase().contains('telepon')) ||
                      (serviceType.toString().toLowerCase().contains('sleep'));

    void handleBack(BuildContext context) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/client-main', (route) => false);
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBack(context);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast),
            onPressed: () => handleBack(context),
          ),
          title: Text(
            "Konfirmasi Booking",
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
              _buildDriverCard(driverName, driverImage, driverRating, driverTrips, driverClass, vehicle, plateNumber),
              const SizedBox(height: 15),
              if (isVirtual) ...[
                _buildVirtualSessionBanner(bookingData),
                const SizedBox(height: 15),
              ] else ...[
                _buildMapRouteSection(bookingData, estimatedTime),
                const SizedBox(height: 15),
                _buildLocationCard(pickupLocation, destinationLocation, serviceType, bookingData?['description']),
                const SizedBox(height: 15),
              ],
              
              // Render dynamic Multi-Layanan list
              if (bookingData?['additionalServices'] != null && (bookingData!['additionalServices'] as List).isNotEmpty) ...[
                ...(bookingData!['additionalServices'] as List).map((srv) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: _buildDynamicAdditionalServiceCard(Map<String, dynamic>.from(srv)),
                  );
                }),
              ] else ...[
                // If Multi-Layanan Antar Jemput, show its location card
                if (bookingData?['hasAntarJemput'] == true) ...[
                  _buildAdditionalServiceCard('antar_jemput', bookingData?['serviceAntarJemputFee'] ?? 0, bookingData),
                  const SizedBox(height: 15),
                ],
                // If Multi-Layanan Hangout, show its hangout card
                if (bookingData?['hasHangout'] == true) ...[
                  _buildAdditionalServiceCard('hangout', bookingData?['serviceHangoutFee'] ?? 0, bookingData),
                  const SizedBox(height: 15),
                ],
              ],
              
              _buildServiceDetailCard(
                date, 
                time, 
                serviceFee, 
                insuranceFee, 
                bookingData?['hasAntarJemput'] == true,
                bookingData?['serviceAntarJemputFee'] ?? 0,
                bookingData?['hasHangout'] == true,
                bookingData?['serviceHangoutFee'] ?? 0,
                useCar, 
                rentHelmet, 
                differentArea, 
                pulangPergi, 
                weekendFee,
                bookingData,
              ),
              const SizedBox(height: 15),
              _buildPaymentSummaryCard(totalPayment, dp, remainingPayment),
              const SizedBox(height: 25),
              _buildActionButtons(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDriverCard(String name, String image, String rating, String trips, String driverClass, String vehicle, String plateNumber) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          width: 70,
                          height: 70,
                          color: AppTheme.cardDeep,
                          child: const Icon(Icons.person, color: AppTheme.textMuted, size: 36),
                        ),
                      )
                    : Container(
                        width: 70,
                        height: 70,
                        color: AppTheme.fuchsiaLight,
                        child: const Icon(Icons.person, color: AppTheme.primaryPink, size: 36),
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.primaryPink, borderRadius: BorderRadius.circular(4)),
                child: Text(driverClass, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name, 
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "$rating ($trips Order)", 
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildBadge(vehicle),
                    _buildBadge(plateNumber),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBadge(String label) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label, 
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildMapRouteSection(Map<String, dynamic>? data, String estimatedTime) {
    final distanceKm = data?['actual_distance_km'] ?? data?['distanceKm'] ?? data?['distance'];
    final distanceText = (distanceKm != null) ? "${distanceKm.toString()} KM" : null;

    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryPink.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.alt_route_rounded, color: AppTheme.primaryPink, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      distanceText != null ? "Rute Perjalanan: $distanceText" : "Rute Terkonfirmasi",
                      style: GoogleFonts.inter(
                        color: AppTheme.textHighContrast,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Live Map",
                        style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: AppTheme.primaryPink, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "Estimasi Durasi: ±$estimatedTime Menit",
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualSessionBanner(Map<String, dynamic>? data) {
    final sType = data?['serviceType']?.toString().toLowerCase() ?? '';
    final callType = data?['call_type']?.toString().toUpperCase() ?? '';
    final isGaming = callType == 'GAMING' || sType.contains('gaming') || sType.contains('mabar');
    final isSleep = callType == 'SLEEP' || sType.contains('sleep');
    final duration = data?['call_duration_minutes'] ?? data?['duration'] ?? 60;

    IconData bannerIcon = Icons.phone_in_talk_rounded;
    Color bannerColor = AppTheme.primaryPink;
    String bannerTitle = "Detail Sesi Pendampingan Telepon";
    String row1Label = "DURASI PANGGILAN";
    String row1Value = "$duration Menit (${duration ~/ 60 > 0 ? '${duration ~/ 60} Jam ' : ''}${duration % 60 > 0 ? '${duration % 60} Menit' : ''})";
    String row2Label = "TOPIK PERCAKAPAN";
    String row2Value = "Topik: ${data?['chat_topic'] ?? 'Curhat & Mendengar'}";
    String footerNote = "Panggilan suara pribadi & terenkripsi P2P";

    if (isGaming) {
      bannerIcon = Icons.sports_esports_rounded;
      bannerColor = const Color(0xFF6366F1);
      bannerTitle = "Detail Sesi Gaming Buddy (Mabar)";
      row1Label = "GAME & MODE PERMAINAN";
      final gameName = data?['game_name'] ?? data?['plateNumber'] ?? 'Mobile Legends';
      final playMode = data?['play_mode'] ?? 'Per Jam';
      final qty = data?['quantity'] ?? 2;
      row1Value = "$gameName ($qty $playMode)";
      row2Label = "TARGET & VOICE CHAT";
      final goal = data?['gaming_goal'] ?? 'Push Rank Santai';
      final vc = data?['use_voice_chat'] == false ? 'Off' : 'On';
      final igId = data?['in_game_id']?.toString().trim();
      row2Value = "Target: $goal • Voice: $vc${igId != null && igId.isNotEmpty ? ' • ID: $igId' : ''}";
      footerNote = "Koordinasi room game & voice chat langsung dengan partner";
    } else if (isSleep) {
      bannerIcon = Icons.nightlight_round;
      bannerColor = Colors.indigoAccent;
      bannerTitle = "Detail Sesi Sleep Call";
      row2Label = "WAKTU BANGUN & METODE";
      final wakeTime = data?['wake_up_time'] != null
          ? DateTime.tryParse(data!['wake_up_time'].toString())?.toLocal().toString().substring(11, 16) ?? '05:30'
          : '05:30';
      final wakeMethod = data?['wake_up_method'] ?? 'Soft Call';
      row2Value = "Alarm: $wakeTime WIB ($wakeMethod)";
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(bannerIcon, color: bannerColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bannerTitle,
                  style: GoogleFonts.inter(
                    color: AppTheme.textHighContrast,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _locationRow(bannerColor, row1Label, row1Value),
          const SizedBox(height: 14),
          _locationRow(AppTheme.success, row2Label, row2Value),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.green, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  footerNote,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(String pickup, String destination, String type, String? description) {
    final isDetective = bookingData?['isDetective'] == true;

    if (isDetective) {
      final mission = bookingData?['detectiveMission']?.toString() ?? 'Observasi Rahasia Lapangan';
      final duration = bookingData?['detectiveDurationHours'] ?? 2;
      final photoUrl = bookingData?['target_photo_url']?.toString();
      final photoBase64 = bookingData?['target_photo_base64']?.toString();
      final targetSpots = (bookingData?['target_spots'] as List<dynamic>?) ?? [];
      final notes = bookingData?['notes']?.toString() ?? '';

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface, 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security_rounded, color: Color(0xFF818CF8), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Detail Detektif Relationship",
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "$duration Jam Pantau",
                    style: GoogleFonts.inter(color: const Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("MISI UTAMA", style: GoogleFonts.inter(color: const Color(0xFF818CF8), fontSize: 9.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(mission, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if ((photoUrl != null && photoUrl.isNotEmpty) || (photoBase64 != null && photoBase64.isNotEmpty)) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: (photoUrl != null && photoUrl.isNotEmpty)
                        ? Image.network(
                            photoUrl,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => (photoBase64 != null && photoBase64.isNotEmpty)
                                ? Image.memory(base64Decode(photoBase64), width: 54, height: 54, fit: BoxFit.cover)
                                : Container(width: 54, height: 54, color: AppTheme.cardDeep, child: const Icon(Icons.broken_image, size: 20)),
                          )
                        : (photoBase64 != null && photoBase64.isNotEmpty)
                            ? Image.memory(base64Decode(photoBase64), width: 54, height: 54, fit: BoxFit.cover)
                            : const SizedBox(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("FOTO TARGET TERSIMPAN", style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text("Foto tersimpan aman di database untuk panduan visual mitra di lapangan.", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (targetSpots.isNotEmpty) ...[
              ...targetSpots.map((spot) {
                final sMap = spot is Map ? spot : {};
                final sIndex = sMap['spotIndex'] ?? 1;
                final sName = sMap['spotName'] ?? 'Spot $sIndex';
                final sAddr = sMap['address']?.toString() ?? '';
                final sNote = sMap['notes']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _locationRow(sIndex == 1 ? AppTheme.primaryPink : const Color(0xFF818CF8), "TITIK PANTAU $sIndex ($sName)", sAddr.isNotEmpty ? sAddr : pickup),
                      if (sNote.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 22),
                          child: Text("Catatan spot: \"$sNote\"", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ] else ...[
              _locationRow(AppTheme.primaryPink, "TITIK TARGET UTAMA (GOOGLE MAPS)", pickup),
              if (destination.isNotEmpty) ...[
                const SizedBox(height: 12),
                _locationRow(AppTheme.success, "ESTIMASI TUJUAN PERPINDAHAN", destination),
              ],
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("CATATAN KHUSUS & CIRI TARGET", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(notes, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11.5, height: 1.35)),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(
                type == 'antar_jemput' 
                    ? Icons.directions_car_filled_rounded 
                    : type == 'hangout' 
                        ? Icons.people_alt_rounded 
                        : Icons.explore_rounded,
                color: AppTheme.primaryPink,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                type == 'antar_jemput' 
                    ? "Rute Antar Jemput" 
                    : type == 'hangout' 
                        ? "Lokasi Hangout" 
                        : "Detail Freedom Request",
                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (type == 'freedom_request' && description != null && description.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.fuchsiaLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryPink.withOpacity(0.2)),
              ),
              child: Text(
                "Request: \"$description\"",
                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 15),
          ],
          if (type == 'hangout' && (bookingData?['transportMode'] == null || bookingData?['transportMode'] == 'none')) ...[
            _locationRow(AppTheme.primaryPink, "SPOT KETEMUAN HANGOUT (SHARELOCK PIN)", destination.isNotEmpty ? destination : pickup),
          ] else ...[
            _locationRow(AppTheme.primaryPink, "LOKASI AWAL / PENJEMPUTAN", pickup),
            const SizedBox(height: 16),
            _locationRow(AppTheme.success, "SPOT TUJUAN HANGOUT", destination),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalServiceCard(String type, int fee, Map<String, dynamic>? data) {
    final pickup = data?['additionalPickup'] ?? '';
    final dest = data?['additionalDestination'] ?? '';
    final activity = data?['additionalActivity'] ?? '';
    final duration = data?['additionalDuration'] ?? '3';
    
    // Antar Jemput additional details
    final pickupDate = data?['additionalPickupDate'] ?? '';
    final pickupTime = data?['additionalPickupTime'] ?? '';
    final ajNotes = data?['additionalAntarJemputNotes'] ?? '';

    // Hangout additional details
    final hangoutLoc = data?['additionalHangoutLocation'] ?? '';
    final hangoutDate = data?['additionalHangoutDate'] ?? '';
    final hangoutTime = data?['additionalHangoutTime'] ?? '';
    final hgNotes = data?['additionalHangoutNotes'] ?? '';

    String fmt(int amount) {
      return "Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryPink, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        type == 'hangout' ? "Layanan Tambahan: Hangout" : "Layanan Tambahan: Antar Jemput",
                        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fmt(fee),
                style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (type == 'hangout') ...[
            Text("Aktivitas: $activity ($duration Jam)", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _locationRow(AppTheme.primaryPink, "LOKASI HANGOUT", hangoutLoc.isNotEmpty ? hangoutLoc : "Sesuai rute utama"),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: AppTheme.textMuted, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "$hangoutDate, pukul $hangoutTime", 
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (hgNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text("Catatan: \"$hgNotes\"", style: GoogleFonts.inter(color: AppTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 11)),
            ],
          ] else if (type == 'antar_jemput') ...[
            _locationRow(AppTheme.primaryPink, "JEMPUT", pickup),
            const SizedBox(height: 15),
            _locationRow(AppTheme.success, "ANTAR", dest),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: AppTheme.textMuted, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "$pickupDate, pukul $pickupTime", 
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (ajNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text("Catatan: \"$ajNotes\"", style: GoogleFonts.inter(color: AppTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 11)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDynamicAdditionalServiceCard(Map<String, dynamic> data) {
    final type = data['serviceType'] ?? '';
    final name = data['displayName'] ?? 'Layanan Tambahan';
    final fee = data['fee'] is int ? data['fee'] as int : (int.tryParse(data['fee']?.toString() ?? '0') ?? 0);

    String fmt(int amount) {
      return "Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }

    IconData icon;
    Color color;
    switch (type) {
      case 'hangout':
        icon = Icons.celebration_rounded;
        color = const Color(0xFFBE185D);
        break;
      case 'antar_jemput':
        icon = Icons.directions_car_filled_rounded;
        color = AppTheme.primaryPink;
        break;
      case 'freedom':
        icon = Icons.explore_rounded;
        color = const Color(0xFFEA580C);
        break;
      case 'sleep':
        icon = Icons.bedtime_rounded;
        color = const Color(0xFF312E81);
        break;
      case 'virtual':
        icon = Icons.phone_in_talk_rounded;
        color = const Color(0xFF7C3AED);
        break;
      case 'gaming':
        icon = Icons.sports_esports_rounded;
        color = const Color(0xFF059669);
        break;
      default:
        icon = Icons.layers_rounded;
        color = AppTheme.primaryPink;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Layanan Ekstra: $name",
                        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fmt(fee),
                style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (type == 'hangout') ...[
            Text("Aktivitas: ${data['hangoutActivity'] ?? '-'} (${data['hangoutDurationHours'] ?? 3} Jam)",
                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _locationRow(color, "LOKASI HANGOUT", data['hangoutLocation']?.toString().isNotEmpty == true ? data['hangoutLocation'] : "Sesuai rute utama"),
            if (data['hangoutNotes']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text("Catatan: \"${data['hangoutNotes']}\"", style: GoogleFonts.inter(color: AppTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 11)),
            ],
          ] else if (type == 'antar_jemput') ...[
            _locationRow(color, "JEMPUT", data['pickup']?.toString().isNotEmpty == true ? data['pickup'] : "Titik Jemput"),
            const SizedBox(height: 12),
            _locationRow(AppTheme.success, "ANTAR", data['destination']?.toString().isNotEmpty == true ? data['destination'] : "Titik Tujuan"),
            if (data['pulangPergi'] == true) ...[
              const SizedBox(height: 8),
              Text("• Termasuk Pulang Pergi (PP)", style: GoogleFonts.inter(color: color, fontSize: 11.5, fontWeight: FontWeight.bold)),
            ],
            if (data['useCar'] == true) ...[
              const SizedBox(height: 4),
              Text("• Menggunakan Mobil Ber-AC", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ] else if (type == 'freedom') ...[
            if (data['freedomTitle']?.toString().isNotEmpty == true)
              Text("Request: ${data['freedomTitle']}", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold)),
            if (data['freedomDescription']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text("\"${data['freedomDescription']}\"", style: GoogleFonts.inter(color: AppTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 12)),
            ],
            if (data['freedomLocation']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              _locationRow(color, "LOKASI PENGERJAAN", data['freedomLocation']),
            ],
          ] else if (type == 'sleep') ...[
            Text("Paket: ${data['sleepPackage'] ?? 'Sleep Call'}", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _locationRow(color, "ALARM BANGUN PAGI", data['sleepWakeTime'] ?? '06:00 WIB'),
          ] else if (type == 'virtual') ...[
            Text("Topik: ${data['virtualTopic'] ?? 'Curhat & Ngobrol'}", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _locationRow(color, "DURASI PANGGILAN", "${data['virtualDurationMinutes'] ?? 60} Menit"),
          ] else if (type == 'gaming') ...[
            Text("Game: ${data['gameTitle'] ?? 'Mobile Legends'}", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _locationRow(color, "ID / NICKNAME", data['gameId']?.toString().isNotEmpty == true ? data['gameId'] : "Sesuai room"),
            const SizedBox(height: 6),
            Text("Jumlah: ${data['gameMatches'] ?? 3} Match", style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Widget _locationRow(Color color, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Container(
            width: 10, 
            height: 10, 
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 2),
              Text(
                address, 
                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildServiceDetailCard(
    String date,
    String time,
    int serviceFee,
    int insuranceFee,
    bool hasAntarJemput,
    int antarJemputFee,
    bool hasHangout,
    int hangoutFee,
    bool useCar,
    bool rentHelmet,
    bool differentArea,
    bool pulangPergi,
    int weekendFee, [
    Map<String, dynamic>? bookingData,
  ]) {
    String fmt(int amount) {
      return "Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }

    final extraServices = (bookingData?['additionalServices'] as List<dynamic>?) ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Detail Layanan", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoBox("TANGGAL", date)),
              const SizedBox(width: 12),
              Expanded(child: _buildInfoBox("WAKTU", time)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 12),
          _priceItem("Layanan Utama", fmt(serviceFee)),
          if (extraServices.isNotEmpty) ...[
            ...extraServices.map((srv) {
              final name = srv['displayName'] ?? 'Layanan Tambahan';
              final fee = srv['fee'] is int ? srv['fee'] as int : (int.tryParse(srv['fee']?.toString() ?? '0') ?? 0);
              return _priceItem("Layanan Ekstra: $name", fmt(fee));
            }),
          ] else ...[
            if (hasAntarJemput) 
              _priceItem("Layanan Tambahan (Antar Jemput)", fmt(antarJemputFee)),
            if (hasHangout) 
              _priceItem("Layanan Tambahan (Hangout Partner)", fmt(hangoutFee)),
          ],
          if (bookingData?['selectedAddons'] != null && (bookingData!['selectedAddons'] as List).isNotEmpty) ...[
            ...((bookingData['selectedAddons'] as List)).map((addon) {
              final aMap = addon is Map ? addon : {};
              final aTitle = aMap['title'] ?? aMap['name'] ?? 'Add-on Mitra';
              final aPrice = aMap['price'] is int ? aMap['price'] as int : (int.tryParse(aMap['price']?.toString() ?? '0') ?? 0);
              return _priceItem("Add-on: $aTitle", fmt(aPrice));
            }),
          ],
          if (pulangPergi) _priceItem("Opsi Pulang Pergi (PP)", "Termasuk rute ganda"),
          if (useCar) _priceItem("Add-on: Mobil", fmt(50000)),
          if (rentHelmet) _priceItem("Add-on: Helm Ekstra", fmt(10000)),
          if (differentArea) _priceItem("Add-on: Beda Area", fmt(20000)),
          if (weekendFee > 0) _priceItem("Weekend Fee (+25%)", fmt(weekendFee)),
          _priceItem("Asuransi Perjalanan", fmt(insuranceFee)),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardDeep, 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _priceItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label, 
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value, 
            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard(int totalPayment, int dp, int remainingPayment) {
    String formatCurrency(int amount) {
      return "Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
              Expanded(
                child: Text(
                  "Total Pembayaran", 
                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(formatCurrency(totalPayment), style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          const Divider(color: AppTheme.border, height: 25),
          _priceItem("DP Wajib (50% x Total)", formatCurrency(dp)),
          _priceItem("Sisa Pelunasan di Tujuan", formatCurrency(remainingPayment)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.primaryPink,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPink.withOpacity(0.25),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryPink)),
              );

              try {
                final bookingProvider = Provider.of<ClientBookingProvider>(context, listen: false);
                final bookingDetails = Map<String, dynamic>.from(bookingData ?? {});
                final random = Random();
                final freshPin = (random.nextInt(9000) + 1000).toString();
                String freshCompPin;
                do {
                  freshCompPin = (random.nextInt(9000) + 1000).toString();
                } while (freshCompPin == freshPin);
                bookingDetails['otp'] = freshPin;
                bookingDetails['security_pin'] = freshPin;
                bookingDetails['start_otp'] = freshPin;
                bookingDetails['completion_otp'] = freshCompPin;

                // Panggil REST API Backend via ClientBookingProvider (/api/bookings)
                final result = await bookingProvider.createBookingRequest(bookingDetails);

                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // close loading dialog

                  if (result['success'] == true) {
                    final createdBooking = result['booking'] ?? result['data'];
                    final bookingId = createdBooking?['id']?.toString();

                    final isVirtual = bookingDetails['service_category'] == 'VIRTUAL' || 
                                      bookingDetails['call_type'] != null ||
                                      (bookingDetails['serviceType']?.toString().toLowerCase().contains('telepon') ?? false) ||
                                      (bookingDetails['serviceType']?.toString().toLowerCase().contains('sleep') ?? false);
                    
                    if (isVirtual) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CallLobbyScreen(
                            bookingDetails: bookingDetails,
                            bookingId: bookingId,
                          ),
                        ),
                      );
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrackingDriverScreen(
                            bookingData: bookingDetails,
                            bookingId: bookingId,
                          ),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Gagal membuat pesanan'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('❌ Exception creating booking: $e');
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // ensure loading is dismissed on error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Terjadi kesalahan: ${e.toString()}'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
            ),
            child: Text(
              (bookingData?['isOpenOffer'] == true || 
               bookingData?['is_open_offer'] == true || 
               bookingData?['serviceType'] == 'freedom_request' || 
               (bookingData?['driver_id'] == null && bookingData?['selectedPartner'] == null))
                  ? "Kirim Permintaan Terbuka"
                  : "Kirim Request ke Mitra",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
            ),
            child: Text(
              "Ubah Jadwal / Pesanan",
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 15)
            ),
          ),
        ),
      ],
    );
  }
}