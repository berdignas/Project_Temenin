// lib/core/services/location_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';

class LocationService {
  static Position? _lastKnownPosition;
  static bool _hasPromptedLocationDialog = false;

  /// Mengambil lokasi terakhir yang tersimpan di memori
  static Position? get lastKnownPosition => _lastKnownPosition;

  /// Cek & minta izin lokasi + nyalakan GPS saat pertama kali masuk aplikasi
  static Future<void> checkAndPromptLocation(BuildContext context, {bool forceShow = false}) async {
    if (_hasPromptedLocationDialog && !forceShow) return;

    try {
      // 1. Cek apakah layanan GPS perangkat aktif
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _hasPromptedLocationDialog = true;
        if (context.mounted) {
          _showEnableGPSDialog(context);
        }
        return;
      }

      // 2. Cek izin lokasi
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _hasPromptedLocationDialog = true;
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _hasPromptedLocationDialog = true;
        if (context.mounted) {
          _showPermissionSettingsDialog(context);
        }
        return;
      }

      // 3. Jika izin aktif dan GPS hidup, ambil koordinat instan dari cache OS (0ms)
      _hasPromptedLocationDialog = true;
      final cachedPos = await Geolocator.getLastKnownPosition();
      if (cachedPos != null) {
        _lastKnownPosition = cachedPos;
      }

      // 4. Update koordinat terbaru di background secara asynchronous
      getCurrentLocation();
    } catch (e) {
      debugPrint('ℹ️ Note on LocationService check: $e');
    }
  }

  /// Mengambil koordinat GPS pengguna secara akurat, cepat & bebas macet (multi-tier fallback)
  static Future<Position?> getCurrentLocation({bool requestIfDenied = true}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _lastKnownPosition ?? await Geolocator.getLastKnownPosition();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestIfDenied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return _lastKnownPosition;
      }

      // Tier 1: Cek cache OS instan (0-5ms) untuk respon super cepat
      final cachedPos = await Geolocator.getLastKnownPosition();
      if (cachedPos != null) {
        _lastKnownPosition = cachedPos;
      }

      // Tier 2: Ambil posisi akurasi tinggi / Fused Location (GPS + Wi-Fi + BTS)
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        _lastKnownPosition = position;
        return position;
      } catch (e) {
        debugPrint('ℹ️ High accuracy timeout/error, mencoba medium accuracy...');
      }

      // Tier 3: Fallback ke Medium / Network Location
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 6),
        );
        _lastKnownPosition = position;
        return position;
      } catch (_) {}

      return _lastKnownPosition ?? cachedPos;
    } catch (e) {
      debugPrint('⚠️ LocationService getCurrentLocation error: $e');
      return _lastKnownPosition;
    }
  }

  /// Popup dialog modern jika GPS ponsel belum aktif
  static void _showEnableGPSDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryPink.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_off_rounded, color: AppTheme.primaryPink, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nyalakan GPS Lokasi',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Layanan Temenin Aja & peta Mapbox memerlukan akses GPS aktif untuk mendeteksi titik penjemputan dan mitra terdekat di sekitar Anda.',
          style: GoogleFonts.inter(
            color: AppTheme.textMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Nanti Saja',
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
            },
            child: Text(
              'Nyalakan GPS',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Popup dialog jika izin lokasi ditolak permanen
  static void _showPermissionSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryPink.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security_rounded, color: AppTheme.primaryPink, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Izin Lokasi Ditolak',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Izin akses lokasi dinonaktifkan di pengaturan ponsel. Mohon izinkan akses lokasi agar peta dapat memuat tempat dan lokasi Anda secara otomatis.',
          style: GoogleFonts.inter(
            color: AppTheme.textMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openAppSettings();
            },
            child: Text(
              'Buka Pengaturan HP',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
