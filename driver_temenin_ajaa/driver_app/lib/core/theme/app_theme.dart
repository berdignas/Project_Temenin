import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // TDS Colors - Signature Pink Fuchsia + Soft Pearl Off-White (Nyaman di mata, tidak silau)
  static const Color background = Color(0xFFF4F5F8);     // Soft Pearl Off-White (Sangat adem di mata)
  static const Color surface = Color(0xFFFAFAFC);        // Soft Velvet Off-White (Tidak silau)
  static const Color card = Color(0xFFFAFAFC);           // Elevated Soft Card
  static const Color cardDeep = Color(0xFFEDEDF2);       // Soft Tinted Grey Container
  static const Color border = Color(0xFFE2E4EB);         // Subtle Soft Border
  static const Color primaryPink = Color(0xFFE11D74);    // Signature Pink Fuchsia
  static const Color fuchsiaLight = Color(0xFFFDF2F8);   // Soft Fuchsia Glow Tint
  static const Color roseGold = Color(0xFFDB2777);       // Deep Fuchsia Rose Accent
  static const Color fuchsiaDark = Color(0xFF9D174D);    // Deep Fuchsia Burgundy

  // Status Colors
  static const Color success = Color(0xFF16A34A); // Emerald Green (Online / Selesai)
  static const Color warning = Color(0xFFD97706); // Amber (Pending / Menunggu)
  static const Color danger = Color(0xFFDC2626);  // Crimson Red (Tolak / Darurat)
  static const Color info = Color(0xFF2563EB);    // Royal Blue

  // Text Colors (Eye-friendly Slate hierarchy)
  static const Color textHighContrast = Color(0xFF1E293B); // Charcoal Slate 800 (Mudah dibaca)
  static const Color textMediumContrast = Color(0xFF475569); // Slate 600 (Body Text)
  static const Color textMuted = Color(0xFF64748B); // Slate 500 (Muted Text)

  // Gradients (Vibrant Fuchsia with smooth, premium transitions)
  static const LinearGradient heroGradient = LinearGradient(
    colors: [
      Color(0xFFE11D74), // Signature Pink Fuchsia
      Color(0xFFF43F5E), // Coral Rose
      Color(0xFFFB7185), // Soft Fuchsia Blossom
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPink, Color(0xFFBE185D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [
      Color(0xFFFAFAFC),
      Color(0xFFFDF2F8), // Soft subtle fuchsia glow
      Color(0xFFF4F5F8),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFAFAFC), Color(0xFFF4F5F8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroCardGradient = LinearGradient(
    colors: [Color(0xFFFAFAFC), Color(0xFFF4F5F8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassBorderGradient = LinearGradient(
    colors: [Color(0x33E11D74), Color(0x1AE2E4EB)],
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
        error: danger,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          minimumSize: const Size(64, 52),
          elevation: 0,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
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
          fontWeight: FontWeight.w800,
          color: textHighContrast,
          letterSpacing: -0.6,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: textHighContrast,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textHighContrast,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textHighContrast,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
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
          fontWeight: FontWeight.w700,
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
