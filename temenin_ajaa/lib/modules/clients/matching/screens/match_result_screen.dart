import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/providers/driver_provider.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/antar_jemput_booking_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/hangout_booking_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/freedom_request_booking_screen.dart';

class MatchResultScreen extends StatelessWidget {
  final String activity;
  final String vibe;
  final String topic;

  const MatchResultScreen({
    super.key,
    required this.activity,
    required this.vibe,
    required this.topic,
  });

  void _showBookingModal(BuildContext context, Map<String, dynamic> partner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Temani ${partner['name']}',
                style: GoogleFonts.inter(
                  color: AppTheme.textHighContrast,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${partner['rating']} • Partner Terverifikasi KYC',
                    style: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildBookingOption(
                context: context,
                icon: Icons.directions_bike_rounded,
                title: 'Ride Service',
                subtitle: 'Temani perjalanan / antar-jemput dengan kendaraan',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AntarJemputBookingScreen(selectedPartner: partner)),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildBookingOption(
                context: context,
                icon: Icons.local_cafe_rounded,
                title: 'Hangout Partner',
                subtitle: 'Teman ngafe, nonton bioskop, atau deep talk',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HangoutBookingScreen(selectedPartner: partner)),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildBookingOption(
                context: context,
                icon: Icons.auto_awesome_rounded,
                title: 'Freedom Request',
                subtitle: 'Kustomisasi kencan & pendampingan sesuai kebutuhan',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FreedomRequestBookingScreen(selectedPartner: partner)),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookingOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppTheme.primaryPink, size: 20),
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
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driverProvider = context.watch<DriverProvider>();
    final realDrivers = driverProvider.drivers;
    final Map<String, dynamic> matchedPartner = realDrivers.isNotEmpty
        ? {
            'id': realDrivers.first['id'],
            'name': realDrivers.first['name'] ?? 'Driver Partner',
            'avatar': realDrivers.first['image'] ?? 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=300&q=80',
            'rating': double.tryParse(realDrivers.first['rating'].toString()) ?? 5.0,
            'matchPercentage': 98,
            'hobbies': ['Ngafe', 'Deep Talk', realDrivers.first['vehicle'] ?? 'Riding'],
            'price': 'Rp ${realDrivers.first['price'] ?? 50000}',
          }
        : {
            'id': 'mock-1',
            'name': 'Kiara Putri',
            'avatar': 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=300&q=80',
            'rating': 4.9,
            'matchPercentage': 98,
            'hobbies': ['Ngafe', 'Deep Talk', 'Vespa Riding'],
            'price': 'Rp 150.000',
          };

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textHighContrast, size: 24),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  Text(
                    'HASIL MATCHING',
                    style: GoogleFonts.inter(
                      color: AppTheme.textHighContrast,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // Match Percentage Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.fuchsiaLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite_rounded, color: AppTheme.primaryPink, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '${matchedPartner['matchPercentage']}% Match Rate',
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryPink,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade().scale(duration: 400.ms),

                    const SizedBox(height: 20),

                    // Partner Avatar
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryPink,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryPink.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(75),
                              child: Image.network(
                                matchedPartner['avatar'].toString(),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.success,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.verified, color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'KYC',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),

                    const SizedBox(height: 16),

                    // Name & Rating
                    Text(
                      matchedPartner['name'].toString(),
                      style: GoogleFonts.inter(
                        color: AppTheme.textHighContrast,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fade(delay: 300.ms),

                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          matchedPartner['rating'].toString(),
                          style: GoogleFonts.inter(
                            color: AppTheme.textHighContrast,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: AppTheme.textMuted)),
                        const SizedBox(width: 8),
                        Text(
                          'Aktif 5 mnt lalu',
                          style: GoogleFonts.inter(
                            color: AppTheme.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ).animate().fade(delay: 350.ms),

                    const SizedBox(height: 24),

                    // Matching Explanations
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kenapa kalian sangat cocok?',
                            style: GoogleFonts.inter(
                              color: AppTheme.textHighContrast,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildMatchReason(
                            icon: Icons.checklist_rounded,
                            title: 'Aktivitas Cocok',
                            desc: 'Sama-sama menyukai kencan berkonsep Coffee Date.',
                          ),
                          const SizedBox(height: 12),
                          _buildMatchReason(
                            icon: Icons.face_rounded,
                            title: 'Vibe Klop',
                            desc: 'Sifat Extrovert partner melengkapi kepribadian Anda.',
                          ),
                          const SizedBox(height: 12),
                          _buildMatchReason(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'Obrolan Nyambung',
                            desc: 'Kalian berdua menyukai obrolan mendalam (Deep Talk).',
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 450.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // Bottom CTA
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _showBookingModal(context, matchedPartner),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    'BOOKING SEKARANG',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchReason({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.fuchsiaLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryPink, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AppTheme.textHighContrast,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
