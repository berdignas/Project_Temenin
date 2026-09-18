
/// Konfigurasi Mapbox API & Mapbox Style Tiles untuk Driver App
class MapboxConfig {
  /// Default Public Token (Placeholder aman - token rahasia dioper via environment/--dart-define)
  static const String _defaultAccessToken =
      String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: '');

  static String get accessToken => _defaultAccessToken;

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

  /// Gaya Peta Navigasi Driver (Mapbox Navigation Day v1)
  static String get navigationDayTileUrl => isEnabled
      ? 'https://api.mapbox.com/styles/v1/mapbox/navigation-day-v1/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}
