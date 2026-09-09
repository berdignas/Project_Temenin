// lib/modules/clients/widgets/bottom_nav_bar.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24), // Float above bottom edge
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.border,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.black,
          elevation: 0,
          selectedItemColor: AppTheme.primaryPink,
          unselectedItemColor: AppTheme.textMuted,
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 11, 
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 11, 
            fontWeight: FontWeight.w500,
          ),
          items: [
            _buildNavItem(Icons.home_outlined, Icons.home_filled, 'Home', 0),
            _buildNavItem(Icons.directions_bike_outlined, Icons.directions_bike_rounded, 'Partner', 1),
            _buildNavItem(Icons.book_online_outlined, Icons.book_online_rounded, 'Booking', 2),
            _buildNavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat', 3),
            _buildNavItem(Icons.person_outline, Icons.person, 'Profil', 4),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
    IconData inactiveIcon, 
    IconData activeIcon, 
    String label, 
    int index,
  ) {
    final isActive = selectedIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        padding: EdgeInsets.symmetric(vertical: isActive ? 6 : 4, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive 
              ? AppTheme.primaryPink.withOpacity(0.12) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          isActive ? activeIcon : inactiveIcon,
          size: isActive ? 24 : 22,
        ),
      ),
      label: label,
    );
  }
}