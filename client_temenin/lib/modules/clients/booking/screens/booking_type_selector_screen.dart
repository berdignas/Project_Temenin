import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'hangout_booking_screen.dart';

class BookingTypeSelectorScreen extends StatefulWidget {
  const BookingTypeSelectorScreen({super.key});

  @override
  State<BookingTypeSelectorScreen> createState() => _BookingTypeSelectorScreenState();
}

class _BookingTypeSelectorScreenState extends State<BookingTypeSelectorScreen> {
  int? _selectedIndex;

  final List<BookingType> _bookingTypes = [
    BookingType(
      id: 0,
      title: "Antar Jemput",
      subtitle: "Perjalanan dari titik A ke B dengan partner profesional",
      icon: Icons.directions_car_filled_rounded,
      gradientColors: [AppTheme.primaryPink, const Color(0xFFBE185D)],
      lightColor: AppTheme.primaryPink,
      darkColor: AppTheme.surface,
    ),
    BookingType(
      id: 1,
      title: "Hangout Partner",
      subtitle: "Temani harimu, dari ngopi, jalan-jalan, sampai acara khusus",
      icon: Icons.people_alt_rounded,
      gradientColors: [const Color(0xFFBE185D), const Color(0xFF9D174D)],
      lightColor: AppTheme.roseGold,
      darkColor: AppTheme.surface,
    ),
    BookingType(
      id: 2,
      title: "Freedom Request",
      subtitle: "Minta tolong apa saja (antre tiket, belanja, dll) secara bebas",
      icon: Icons.explore_rounded,
      gradientColors: [const Color(0xFFF97316), const Color(0xFFEA580C)],
      lightColor: const Color(0xFFF97316),
      darkColor: AppTheme.surface,
    ),
  ];

  void _handleBooking() {
    if (_selectedIndex == null) return;

    final selectedType = _bookingTypes[_selectedIndex!];

    if (selectedType.title == "Antar Jemput") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HangoutBookingScreen(serviceType: 'regular'),
        ),
      );
    } else if (selectedType.title == "Hangout Partner") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HangoutBookingScreen(serviceType: 'hangout'),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HangoutBookingScreen(serviceType: 'freedom'),
        ),
      );
    }
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
          "Temenin Ajaa",
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryPink,
            letterSpacing: 0.5,
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
              const SizedBox(height: 12),
              _buildTitleSection(),
              const SizedBox(height: 24),

              // Booking Type Cards
              ...List.generate(_bookingTypes.length, (index) {
                final type = _bookingTypes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildBookingCard(
                    type: type,
                    isSelected: _selectedIndex == index,
                    onTap: () => setState(() => _selectedIndex = index),
                  ),
                );
              }),

              const SizedBox(height: 30),

              // Primary Action Button
              _buildContinueButton(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Pilih Layanan",
          style: GoogleFonts.inter(
            color: AppTheme.textHighContrast,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Tentukan tipe perjalanan atau bantuan yang kamu butuhkan",
          style: GoogleFonts.inter(
            color: AppTheme.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBookingCard({
    required BookingType type,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: type.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppTheme.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: type.lightColor.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : type.lightColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                type.icon,
                color: isSelected ? Colors.white : type.lightColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.title,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : AppTheme.textHighContrast,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type.subtitle,
                    style: GoogleFonts.inter(
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : AppTheme.textMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Selection Indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : Colors.transparent,
                border: Border.all(
                  color: isSelected ? Colors.white : AppTheme.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      color: type.lightColor,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    final isSelected = _selectedIndex != null;
    
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isSelected ? _handleBooking : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? AppTheme.primaryPink : const Color(0xFFCBD5E1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isSelected ? 4 : 0,
        ),
        child: Text(
          isSelected ? "Lanjut ke Pemesanan" : "Pilih salah satu layanan",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class BookingType {
  final int id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final Color lightColor;
  final Color darkColor;

  BookingType({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.lightColor,
    required this.darkColor,
  });
}