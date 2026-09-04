import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/modules/clients/chat/screens/chat_room_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/antar_jemput_booking_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/hangout_booking_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/freedom_request_booking_screen.dart';

class PartnerProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? partnerData;
  final String? serviceType;

  const PartnerProfileScreen({super.key, this.partnerData, this.serviceType});

  @override
  State<PartnerProfileScreen> createState() => _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends State<PartnerProfileScreen> {
  String _activeSubtab = 'profil';

  @override
  Widget build(BuildContext context) {
    final partnerName = widget.partnerData?['name'] ?? "Sarah Jessica";
    final partnerRating = widget.partnerData?['rating'] ?? "4.9";
    final partnerVehicle = widget.partnerData?['vehicle'] ?? "Toyota Corolla Sedan";
    final partnerType = widget.partnerData?['type'] ?? "★ PLATINUM TIER";
    final partnerImage = widget.partnerData?['image'] ?? "https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=600&auto=format&fit=crop";
    final partnerStatus = widget.partnerData?['status'] ?? "Available";
    final partnerPriceVal = widget.partnerData?['price'] ?? 150000;
    
    final formattedPrice = 'Rp ${partnerPriceVal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.'
    )}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroHeader(context, partnerName, partnerType, partnerRating, partnerImage, partnerStatus),
                  
                  _buildSubtabRow(),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: _buildActiveSubtabContent(partnerName, partnerVehicle, formattedPrice),
                  ),
                  
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomAction(
              context, 
              partnerName, 
              partnerVehicle, 
              partnerRating, 
              partnerImage, 
              partnerPriceVal,
              formattedPrice,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, String name, String type, String rating, String image, String status) {
    final age = name == 'Sarah Jessica' ? '24' : '26';
    return Stack(
      children: [
        SizedBox(
          height: 360,
          width: double.infinity,
          child: Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppTheme.cardDeep,
                child: const Icon(Icons.person, color: AppTheme.textMuted, size: 80),
              );
            },
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.3),
                  AppTheme.background,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  type,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$name, $age',
                style: GoogleFonts.inter(
                  color: AppTheme.textHighContrast,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        ' (128 Ulasan) • 📍 Jakarta',
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.success),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Online',
                          style: GoogleFonts.inter(
                            color: AppTheme.success,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubtabRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSubtabButton('profil', 'Profil'),
          _buildSubtabButton('ketersediaan', 'Ketersediaan'),
          _buildSubtabButton('pengalaman', 'Pengalaman'),
          _buildSubtabButton('ulasan', 'Ulasan'),
        ],
      ),
    );
  }

  Widget _buildSubtabButton(String key, String label) {
    final isActive = _activeSubtab == key;
    return GestureDetector(
      onTap: () => setState(() => _activeSubtab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: isActive
              ? const Border(bottom: BorderSide(color: AppTheme.primaryPink, width: 2.5))
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isActive ? AppTheme.primaryPink : AppTheme.textMuted,
            fontSize: 12.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSubtabContent(String partnerName, String vehicle, String formattedPrice) {
    switch (_activeSubtab) {
      case 'profil':
        return _buildProfilTabContent(partnerName, vehicle, formattedPrice);
      case 'ketersediaan':
        return _buildKetersediaanTabContent();
      case 'pengalaman':
        return _buildPengalamanTabContent();
      case 'ulasan':
        return _buildUlasanTabContent();
      default:
        return _buildProfilTabContent(partnerName, vehicle, formattedPrice);
    }
  }

  Widget _buildProfilTabContent(String partnerName, String vehicle, String formattedPrice) {
    final isSarah = partnerName == 'Sarah Jessica';
    final bio = isSarah
        ? "Halo! Saya Sarah, siap mendampingi perjalanan aman Anda serta menemani obrolan santai di cafe favorit Anda. Memiliki Vespa Sprint & mobil sedan premium."
        : "Halo! Saya Rayhan, pendamping perjalanan seru Anda dengan motor sport Kawasaki Ninja ZX-25R. Siap menemani aktivitas formal maupun kasual.";
    
    final vehicle1Title = isSarah ? "Toyota Corolla Sedan" : "Kawasaki Ninja ZX-25R";
    final vehicle2Title = isSarah ? "Vespa Sprint Scooter" : "Honda HR-V SUV";
    
    final vehicle1Image = isSarah
        ? "https://images.unsplash.com/photo-1549399542-7e3f8b79c341?q=80&w=400&auto=format&fit=crop"
        : "https://images.unsplash.com/photo-1558981806-ec527fa84c39?q=80&w=400&auto=format&fit=crop";
    final vehicle2Image = isSarah
        ? "https://images.unsplash.com/photo-1558981403-c5f91cbba527?q=80&w=400&auto=format&fit=crop"
        : "https://images.unsplash.com/photo-1542282088-fe8426682b8f?q=80&w=400&auto=format&fit=crop";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Biografi',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          bio,
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.fuchsiaLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tarif Dasar Pendampingan',
                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                '$formattedPrice / Jam',
                style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Kendaraan Terdaftar',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildVehicleThumbnail(vehicle1Title, vehicle1Image)),
            const SizedBox(width: 12),
            Expanded(child: _buildVehicleThumbnail(vehicle2Title, vehicle2Image)),
          ],
        ),
      ],
    );
  }

  Widget _buildVehicleThumbnail(String title, String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              imageUrl,
              height: 95,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 95,
                  color: AppTheme.cardDeep,
                  child: const Icon(Icons.directions_car_filled_rounded, color: AppTheme.textMuted, size: 30),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKetersediaanTabContent() {
    final List<int> bookedDays = [5, 12, 18, 22, 28];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
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
                  Text(
                    'Agustus 2026',
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Row(
                    children: [
                      _buildCalNavBtn('‹'),
                      const SizedBox(width: 8),
                      _buildCalNavBtn('›'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  _buildLegendItem(AppTheme.success, 'Tersedia'),
                  const SizedBox(width: 16),
                  _buildLegendItem(AppTheme.textMuted, 'Terbooking'),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'].map((day) {
                  return SizedBox(
                    width: 32,
                    child: Center(
                      child: Text(
                        day,
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              _buildCalendarDatesGrid(bookedDays),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalNavBtn(String char) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
        child: Text(
          char,
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCalendarDatesGrid(List<int> bookedDays) {
    List<Widget> cells = [];
    
    for (int i = 0; i < 5; i++) {
      cells.add(const SizedBox(width: 32, height: 32));
    }
    
    for (int day = 1; day <= 31; day++) {
      final isBooked = bookedDays.contains(day);
      cells.add(
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isBooked ? AppTheme.cardDeep : AppTheme.success.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isBooked ? AppTheme.border : AppTheme.success.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            '$day',
            style: GoogleFonts.inter(
              color: isBooked ? AppTheme.textMuted : AppTheme.textHighContrast,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    List<Widget> rows = [];
    for (int i = 0; i < cells.length; i += 7) {
      int end = i + 7;
      if (end > cells.length) end = cells.length;
      List<Widget> rowCells = cells.sublist(i, end);
      while (rowCells.length < 7) {
        rowCells.add(const SizedBox(width: 32, height: 32));
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowCells,
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildPengalamanTabContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rekam Jejak & Performa',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: [
            _buildExpStatCard('5+ Thn', 'Pengalaman Companion', AppTheme.primaryPink),
            _buildExpStatCard('1.200+', 'Jam Pendampingan VIP', const Color(0xFFD97706)),
            _buildExpStatCard('99.8%', 'On-Time Arrival Rate', AppTheme.success),
            _buildExpStatCard('0%', 'Tingkat Pembatalan', AppTheme.success),
          ],
        ),
        const SizedBox(height: 20),

        Text(
          'Sertifikasi & Kualifikasi Resmi',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildCertCard('Defensive Driving Certified', 'Sertifikat Pengemudi Aman & Profesional'),
        const SizedBox(height: 8),
        _buildCertCard('VIP Hospitality & Etiquette', 'Standar Etika & Pelayanan Client Eksklusif'),
        const SizedBox(height: 8),
        _buildCertCard('First Aid & Emergency Trained', 'Pelatihan Tanggap Darurat & P3K Dasar'),
        const SizedBox(height: 20),

        Text(
          'Keahlian Acara & Bahasa',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSkillChip('Gala Dinner & Event'),
            _buildSkillChip('Business Meeting Companion'),
            _buildSkillChip('Premium Culinary Guide'),
            _buildSkillChip('Bahasa Indonesia (Fasih)'),
            _buildSkillChip('English (Fluent Business)'),
          ],
        ),
      ],
    );
  }

  Widget _buildExpStatCard(String val, String label, Color valColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            val,
            style: GoogleFonts.inter(color: valColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildCertCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: AppTheme.primaryPink, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSkillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11.5, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildUlasanTabContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ulasan Pelanggan (128)',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildReviewCard('Faizun A.', 5.0, '"Sarah sangat ramah, berkendara halus & profesional."'),
        const SizedBox(height: 10),
        _buildReviewCard('Andi S.', 4.8, '"Pendamping yang sangat menyenangkan dan berwawasan luas."'),
        const SizedBox(height: 10),
        _buildReviewCard('Devi R.', 5.0, '"Sangat tepat waktu dan membantu mengatur kebutuhan meeting bisnis saya."'),
      ],
    );
  }

  Widget _buildReviewCard(String author, double rating, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(author, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12.5, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                  const SizedBox(width: 3),
                  Text(
                    rating.toString(),
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, height: 1.4, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(
    BuildContext context,
    String name,
    String vehicle,
    String rating,
    String image,
    int price,
    String formattedPrice,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatRoomScreen(
                      recipientName: name,
                      recipientImage: image,
                      status: "Online",
                      tag: name == 'Sarah Jessica' ? 'Platinum' : 'Gold',
                    ),
                  ),
                );
              },
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: AppTheme.fuchsiaLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryPink, size: 20),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final service = widget.serviceType;
                    if (service != null && service != 'all' && service != 'all-grid') {
                      final partnerInfo = {
                        'id': widget.partnerData?['id'] ?? 'drv-1',
                        'name': name,
                        'vehicle': vehicle,
                        'rating': rating,
                        'image': image,
                        'price': price,
                        'type': widget.partnerData?['type'] ?? 'Platinum',
                      };
                      if (service == 'ride') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HangoutBookingScreen(
                              selectedPartner: partnerInfo,
                              serviceType: 'regular',
                            ),
                          ),
                        );
                      } else if (service == 'sporty') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HangoutBookingScreen(
                              selectedPartner: partnerInfo,
                              serviceType: 'sporty',
                            ),
                          ),
                        );
                      } else if (service == 'freedom') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HangoutBookingScreen(
                              selectedPartner: partnerInfo,
                              serviceType: 'freedom',
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HangoutBookingScreen(
                              selectedPartner: partnerInfo,
                              serviceType: service,
                            ),
                          ),
                        );
                      }
                    } else {
                      _showBookingOptionsDialog(
                        context, 
                        name, 
                        vehicle, 
                        rating, 
                        image, 
                        price,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    (widget.serviceType != null && widget.serviceType != 'all' && widget.serviceType != 'all-grid')
                        ? 'PESAN SEKARANG'
                        : 'PILIH LAYANAN',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5, letterSpacing: 0.5, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingOptionsDialog(
    BuildContext context,
    String name,
    String vehicle,
    String rating,
    String image,
    int price,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        bottom: true,
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '$name (⭐ $rating)',
                style: GoogleFonts.inter(
                  color: AppTheme.textHighContrast,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pilih jenis layanan yang ingin Anda pesan:',
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildModalOption(
                        context,
                        icon: Icons.local_taxi_rounded,
                        title: '🚕 Ride Service',
                        subtitle: 'Diantar perjalanan aman & nyaman',
                        color: AppTheme.primaryPink,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                            serviceType: 'regular',
                            selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                          )));
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildModalOption(
                        context,
                        icon: Icons.sports_motorsports_rounded,
                        title: '🏎️ Antar Jemput Sporty',
                        subtitle: 'Kendaraan mewah & performa tinggi',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                            serviceType: 'sporty',
                            selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                          )));
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildModalOption(
                        context,
                        icon: Icons.wine_bar_rounded,
                        title: '🍸 Hangout Service',
                        subtitle: 'Teman nongkrong di cafe/restoran',
                        color: const Color(0xFFD97706),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                            serviceType: 'hangout',
                            selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                          )));
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildModalOption(
                        context,
                        icon: Icons.auto_awesome_rounded,
                        title: '✨ Freedom Request (Negosiasi)',
                        subtitle: 'Tentukan acara & tawar harga sendiri',
                        color: const Color(0xFFFF8552),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                            serviceType: 'freedom',
                            selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                          )));
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildModalOption(
                        context,
                        icon: Icons.psychology_rounded,
                        title: '💬 Relationship Counseling',
                        subtitle: 'Konsultasi masalah asmara profesional',
                        color: Colors.blueAccent,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                            serviceType: 'counseling',
                            selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                          )));
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildModalOption(
                        context,
                        icon: Icons.hearing_rounded,
                        title: '👂 Mendengarkan Curhat',
                        subtitle: 'Teman cerita yang penuh empati',
                        color: Colors.teal,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                            serviceType: 'curhat',
                            selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                          )));
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildModalOption(
                        context,
                        icon: Icons.policy_rounded,
                        title: '🕵️ Detektif Relationship',
                        subtitle: 'Penyelidikan rahasia & pemantauan',
                        color: Colors.redAccent,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                            serviceType: 'detective',
                            selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                          )));
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildModalOption(
                        context,
                        icon: Icons.landscape_rounded,
                        title: '🧗 Hiking Partner',
                        subtitle: 'Teman mendaki alam yang seru',
                        color: Colors.green,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                            serviceType: 'hiking',
                            selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                          )));
                        },
                      ),
                      const SizedBox(height: 10),

                      _buildModalOption(
                        context,
                        icon: Icons.business_center_rounded,
                        title: '💼 Personal Assistance',
                        subtitle: 'Bantuan harian (bawa barang, dll)',
                        color: Colors.purple,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                            serviceType: 'assistant',
                            selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                          )));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Tutup Modal',
                    style: GoogleFonts.inter(
                      color: AppTheme.textHighContrast,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardDeep,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}