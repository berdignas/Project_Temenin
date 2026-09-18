import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // TDS Colors - Signature Electric Pink + Cyberpunk Dark Obsidian
  static const Color background = Color(0xFFFAFAFA); // Clean Light Background
  static const Color surface = Color(0xFFFFFFFF);    // White Surface
  static const Color card = Color(0xFFFFFFFF);       // White Card
  static const Color cardDeep = Color(0xFFF8F0F5);   // Soft Blush Sub-surface
  static const Color border = Color(0xFFF0E4EC);     // Soft Pink Border
  static const Color primaryPink = Color(0xFFEC4899); // Fuchsia Primary
  static const Color roseGold = Color(0xFFDB2777);    // Deep Fuchsia
  static const Color fuchsiaLight = Color(0x33EC4899); // Subtle Fuchsia Glow

  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFEF4444);  // Crimson Red
  static const Color info = Color(0xFF3B82F6);    // Royal Blue

  // Text Colors (Light Mode Hierarchy)
  static const Color textHighContrast = Color(0xFF1E1B2E); // Deep Plum
  static const Color textMediumContrast = Color(0xFF6B5B6E); // Medium Plum
  static const Color textMuted = Color(0xFF9B8A9D); // Muted Plum

  // Alias Compatibility
  static const Color darkBackground = background;
  static const Color darkCard = card;
  static const Color textSecondary = textMuted;
  static const Color secondaryPink = roseGold;

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFFDB2777), Color(0xFFBE185D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPink, Color(0xFFDB2777)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [
      Color(0xFFFAFAFA),
      Color(0xFFFDF2F8),
      Color(0xFFFAFAFA),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFDF2F8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient safetyGradient = LinearGradient(
    colors: [Color(0xFFFDF2F8), Color(0xFFF8F0F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassBorderGradient = LinearGradient(
    colors: [Color(0x40EC4899), Color(0x1AEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primaryPink,
      cardColor: surface,
      dividerColor: border,
      colorScheme: const ColorScheme.light(
        primary: primaryPink,
        secondary: roseGold,
        surface: surface,
        background: background,
        error: danger,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5EBF2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryPink, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(
          color: textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.inter(
          color: textMuted,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPink,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size(64, 52),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SmoothPageTransitionsBuilder(),
          TargetPlatform.iOS: SmoothPageTransitionsBuilder(),
          TargetPlatform.macOS: SmoothPageTransitionsBuilder(),
          TargetPlatform.windows: SmoothPageTransitionsBuilder(),
          TargetPlatform.linux: SmoothPageTransitionsBuilder(),
        },
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textHighContrast,
          letterSpacing: -0.64,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textHighContrast,
          letterSpacing: -0.24,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textHighContrast,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textHighContrast,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: textMediumContrast,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: textMediumContrast,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: textMuted,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}

class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      ),
      child: child,
    );
  }
}