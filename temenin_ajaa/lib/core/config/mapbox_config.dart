// lib/core/config/mapbox_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Konfigurasi Mapbox API & Mapbox Style Tiles
class MapboxConfig {
  /// Default Public Token jika .env tidak terbaca (Placeholder aman)
  static const String _fallbackAccessToken = '';

  /// Mendapatkan Public Access Token dari .env atau fallback
  static String get accessToken {
    try {
      final envKey = dotenv.env['MAPBOX_ACCESS_TOKEN'];
      if (envKey != null && envKey.trim().isNotEmpty) {
        return envKey.trim();
      }
    } catch (_) {}
    return _fallbackAccessToken;
  }

  /// Default Google Maps API Key untuk Google Places Autocomplete cerdas (Placeholder aman)
  static const String _fallbackGoogleKey = '';

  /// Mendapatkan Google Maps / Places API Key dari .env atau fallback
  static String get googleMapsApiKey {
    try {
      final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (key != null && key.trim().isNotEmpty) {
        return key.trim();
      }
    } catch (_) {}
    return _fallbackGoogleKey;
  }

  /// Mengecek apakah Mapbox Access Token tersedia
  static bool get isEnabled => accessToken.isNotEmpty && !accessToken.contains('YOUR_MAPBOX');

  // 🗺️ URLs Template untuk Mapbox Raster Tile Layer (@2x Retina HD)
  
  /// Gaya Peta Standar Jalan Raya (Mapbox Streets v12 atau fallback OpenStreetMap)
  static String get streetsTileUrl => isEnabled
      ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Gaya Peta Mode Gelap / Cyberpunk (Mapbox Dark v11)
  static String get darkTileUrl => isEnabled
      ? 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Gaya Peta Satelit dengan Label Jalan (Mapbox Satellite Streets v12)
  static String get satelliteTileUrl => isEnabled
      ? 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Gaya Peta Navigasi Berkendara Siang (Mapbox Navigation Day v1)
  static String get navigationDayTileUrl => isEnabled
      ? 'https://api.mapbox.com/styles/v1/mapbox/navigation-day-v1/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Gaya Peta Outdoors / Topografi (Mapbox Outdoors v12)
  static String get outdoorsTileUrl => isEnabled
      ? 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}
