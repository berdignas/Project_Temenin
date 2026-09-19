import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'antar_jemput_booking_screen.dart';
import 'hangout_booking_screen.dart';
import 'freedom_request_booking_screen.dart';
import 'virtual_call_booking_screen.dart';
import 'sleep_call_booking_screen.dart';
import 'gaming_buddy_booking_screen.dart';

class BookingTypeSelectorScreen extends StatefulWidget {
  final int initialPillarIndex;

  const BookingTypeSelectorScreen({
    super.key,
    this.initialPillarIndex = 0,
  });

  @override
  State<BookingTypeSelectorScreen> createState() => _BookingTypeSelectorScreenState();
}

class _BookingTypeSelectorScreenState extends State<BookingTypeSelectorScreen> with SingleTickerProviderStateMixin {
  late int _selectedPillarIndex;
  int? _selectedServiceId;

  final List<PillarCategory> _pillars = [
    PillarCategory(
      id: 0,
      title: "Virtual",
      icon: Icons.phone_iphone_rounded,
      subtitle: "Online & Jarak Jauh",
      activeColor: const Color(0xFF6366F1),
    ),
    PillarCategory(
      id: 1,
      title: "Offline",
      icon: Icons.people_alt_rounded,
      subtitle: "Tatap Muka & Aktivitas",
      activeColor: AppTheme.primaryPink,
    ),
    PillarCategory(
      id: 2,
      title: "Custom",
      icon: Icons.auto_awesome_rounded,
      subtitle: "Bebas & Fleksibel",
      activeColor: const Color(0xFFF97316),
    ),
  ];

  final Map<int, List<ServiceItem>> _servicesByPillar = {
    0: [
      ServiceItem(
        id: 101,
        title: "Sleep Call Companion",
        subtitle: "Teman tidur malam hari & pengingat bangun pagi tepat waktu",
        badge: "Mode Tidur & Alarm",
        priceHint: "Mulai Rp 45.000 / paket",
        icon: Icons.bedtime_rounded,
        color: const Color(0xFF312E81),
        accentColor: const Color(0xFF818CF8),
      ),
      ServiceItem(
        id: 102,
        title: "Relationship Counseling Online (Call & WA)",
        subtitle: "Curhat asmara & konseling rahasia via telepon in-app atau WhatsApp",
        badge: "Konseling Online & WA",
        priceHint: "Mulai Rp 35.000 / jam",
        icon: Icons.phone_in_talk_rounded,
        color: const Color(0xFF7C3AED),
        accentColor: const Color(0xFFA78BFA),
      ),
      ServiceItem(
        id: 103,
        title: "Gaming Buddy (Mabar)",
        subtitle: "Teman main game online bareng (MLBB, PUBG, Valorant, dll)",
        badge: "Mabar Seru & Push Rank",
        priceHint: "Mulai Rp 15.000 / match",
        icon: Icons.sports_esports_rounded,
        color: const Color(0xFF4F46E5),
        accentColor: const Color(0xFF818CF8),
      ),
    ],
    1: [
      ServiceItem(
        id: 201,
        title: "Hangout Partner",
        subtitle: "Teman ngopi, nonton bioskop, dinner, hingga pendamping kondangan/wisuda",
        badge: "Plus-One & Hangout",
        priceHint: "Mulai Rp 50.000 / jam",
        icon: Icons.celebration_rounded,
        color: const Color(0xFFBE185D),
        accentColor: const Color(0xFFFB7185),
      ),
      ServiceItem(
        id: 202,
        title: "Antar Jemput Sporty (Motor Sport)",
        subtitle: "Sensasi naik motor sport keren (Ninja, CBR, ZX25R, R-Series) aman & berkelas",
        badge: "Riding Motor Sport",
        priceHint: "Tarif transparan per Km",
        icon: Icons.two_wheeler_rounded,
        color: AppTheme.primaryPink,
        accentColor: const Color(0xFFF472B6),
      ),
      ServiceItem(
        id: 203,
        title: "Hiking Partner (Mendaki Gunung)",
        subtitle: "Teman mendaki gunung & trekking alam, safety buddy dan bantu bawa logistik",
        badge: "Hiking & Outdoor",
        priceHint: "Mulai Rp 150.000 / trip",
        icon: Icons.terrain_rounded,
        color: const Color(0xFF059669),
        accentColor: const Color(0xFF34D399),
      ),
      ServiceItem(
        id: 204,
        title: "Personal Assistant Service",
        subtitle: "Asisten pribadi harian: bawain koper, belanjaan, hingga bodyguard di club malam",
        badge: "Asisten & Bodyguard",
        priceHint: "Tarif fleksibel per jam / shift",
        icon: Icons.badge_rounded,
        color: const Color(0xFF0D9488),
        accentColor: const Color(0xFF2DD4BF),
      ),
      ServiceItem(
        id: 205,
        title: "Detektif Relationship",
        subtitle: "Investigasi kesetiaan pasangan & observasi rahasia di tempat publik secara aman",
        badge: "Investigasi & Cek Bukti",
        priceHint: "Paket investigasi discreet",
        icon: Icons.search_rounded,
        color: const Color(0xFF475569),
        accentColor: const Color(0xFF94A3B8),
      ),
      ServiceItem(
        id: 206,
        title: "Relationship Counseling (Offline)",
        subtitle: "Ruang aman bercerita & konseling curhat asmara tatap muka langsung di kafe santai",
        badge: "Curhat Tatap Muka",
        priceHint: "Mulai Rp 60.000 / jam",
        icon: Icons.psychology_rounded,
        color: const Color(0xFF8B5CF6),
        accentColor: const Color(0xFFC4B5FD),
      ),
    ],
    2: [
      ServiceItem(
        id: 301,
        title: "Freedom Request (Jasa Suruh)",
        subtitle: "Jasa suruh & tugas apa saja bebas (antri tiket, beliin barang, antar dokumen) tawar budget Anda",
        badge: "Bebas Tawar Budget",
        priceHint: "Harga disepakati bersama",
        icon: Icons.assignment_turned_in_rounded,
        color: const Color(0xFFEA580C),
        accentColor: const Color(0xFFFB923C),
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedPillarIndex = widget.initialPillarIndex;
    _selectedServiceId = _servicesByPillar[_selectedPillarIndex]?.first.id;
  }

  void _navigateToService(int serviceId) {
    switch (serviceId) {
      case 101:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SleepCallBookingScreen()),
        );
        break;
      case 102:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VirtualCallBookingScreen(serviceType: 'counseling')),
        );
        break;
      case 103:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF6366F1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.engineering_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Fitur Gaming Buddy (Mabar) sedang dalam tahap pengembangan!",
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
        break;
      case 201:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HangoutBookingScreen(serviceType: 'hangout')),
        );
        break;
      case 202:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AntarJemputBookingScreen(serviceType: 'sporty')),
        );
        break;
      case 203:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HangoutBookingScreen(serviceType: 'hiking')),
        );
        break;
      case 204:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FreedomRequestBookingScreen(serviceType: 'assistant')),
        );
        break;
      case 205:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FreedomRequestBookingScreen(serviceType: 'detektif')),
        );
        break;
      case 206:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HangoutBookingScreen(serviceType: 'counseling_offline')),
        );
        break;
      case 301:
      default:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FreedomRequestBookingScreen(serviceType: 'freedom')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPillar = _pillars[_selectedPillarIndex];
    final currentServices = _servicesByPillar[_selectedPillarIndex] ?? [];

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
          "Pilih Layanan Temenin",
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textHighContrast,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              
              // Header Title
              Text(
                "3 Pilar Layanan Utama",
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textHighContrast,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Pilih kategori pendampingan yang sesuai dengan kebutuhan Anda",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),

              const SizedBox(height: 20),

              // 3-Pillar Segmented Tab Bar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: _pillars.map((pillar) {
                    final isSelected = _selectedPillarIndex == pillar.id;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPillarIndex = pillar.id;
                            _selectedServiceId = _servicesByPillar[pillar.id]?.first.id;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? pillar.activeColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: pillar.activeColor.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                pillar.icon,
                                color: isSelected ? Colors.white : AppTheme.textMuted,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pillar.title,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? Colors.white : AppTheme.textMediumContrast,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // Pillar Subtitle Badge
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: currentPillar.activeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Sub-Layanan: ${currentPillar.subtitle}",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: currentPillar.activeColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // List of Sub-Services in Selected Pillar
              ...currentServices.map((service) {
                final isSelected = _selectedServiceId == service.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedServiceId = service.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isSelected ? service.color.withValues(alpha: 0.12) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? service.color : AppTheme.border,
                          width: isSelected ? 1.8 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: service.color.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSelected ? service.color : service.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  service.icon,
                                  color: isSelected ? Colors.white : service.accentColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            service.title,
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textHighContrast,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: service.color.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: service.color.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            service.badge,
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: service.accentColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      service.subtitle,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppTheme.textMediumContrast,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppTheme.border),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.local_offer_outlined, size: 14, color: service.accentColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    service.priceHint,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: service.accentColor,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton(
                                onPressed: () => _navigateToService(service.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: service.color,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  "Pilih Form",
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),

              // Bottom Direct Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _selectedServiceId != null ? () => _navigateToService(_selectedServiceId!) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentPillar.activeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        "Lanjut ke Form Pemesanan",
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
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

class PillarCategory {
  final int id;
  final String title;
  final IconData icon;
  final String subtitle;
  final Color activeColor;

  PillarCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.activeColor,
  });
}

class ServiceItem {
  final int id;
  final String title;
  final String subtitle;
  final String badge;
  final String priceHint;
  final IconData icon;
  final Color color;
  final Color accentColor;

  ServiceItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.priceHint,
    required this.icon,
    required this.color,
    required this.accentColor,
  });
}