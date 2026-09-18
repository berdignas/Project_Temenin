// lib/modules/clients/booking/screens/interactive_map_picker_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:latlong2/latlong.dart' as osm_latlong;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/core/config/mapbox_config.dart';
import 'package:temenin_ajaa/core/services/distance_service.dart';
import 'package:temenin_ajaa/core/services/location_service.dart';

class InteractiveMapPickerScreen extends StatefulWidget {
  final String title;
  final String initialAddress;
  final double initialLat;
  final double initialLng;

  const InteractiveMapPickerScreen({
    super.key,
    required this.title,
    required this.initialAddress,
    this.initialLat = -6.2099, // Jakarta default
    this.initialLng = 106.8502,
  });

  @override
  State<InteractiveMapPickerScreen> createState() => _InteractiveMapPickerScreenState();
}

class _InteractiveMapPickerScreenState extends State<InteractiveMapPickerScreen> with TickerProviderStateMixin {
  late final osm.MapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  late double _currentLat;
  late double _currentLng;
  double _currentZoom = 16.0;

  String _selectedAddressTitle = "Memuat alamat...";
  String _selectedFullAddress = "";
  bool _isLoadingAddress = false;
  bool _isLocatingUser = false;
  bool _isSearching = false;
  
  // Posisi GPS Asli Pengguna (Blue Dot Indicator)
  osm_latlong.LatLng? _myGpsLocation;

  // Gaya Peta Mapbox: 'streets' | 'dark' | 'satellite'
  String _currentMapStyle = 'streets';

  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;
  Timer? _mapIdleDebounce;

  late AnimationController _pinAnimController;
  late Animation<double> _pinJumpAnimation;

  bool _isMapReady = false;
  osm_latlong.LatLng? _pendingTarget;
  double? _pendingZoom;

  void _safeMoveMap(double lat, double lng, [double? zoom]) {
    final z = zoom ?? _currentZoom;
    if (mounted) {
      setState(() {
        _currentLat = lat;
        _currentLng = lng;
        _currentZoom = z;
      });
    }
    if (_isMapReady) {
      try {
        _mapController.move(osm_latlong.LatLng(lat, lng), z);
      } catch (e) {
        debugPrint('SafeMoveMap error: $e');
      }
    } else {
      _pendingTarget = osm_latlong.LatLng(lat, lng);
      _pendingZoom = z;
    }
  }

  /// Gerakan Kamera Peta Halus & Mulus (Google Maps Gliding Motion)
  void _animatedMoveMap(osm_latlong.LatLng destLocation, double destZoom) {
    if (!_isMapReady) {
      _safeMoveMap(destLocation.latitude, destLocation.longitude, destZoom);
      return;
    }

    final camera = _mapController.camera;
    final latTween = Tween<double>(begin: camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);

    final animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    final animation = CurvedAnimation(parent: animController, curve: Curves.easeInOutCubic);

    animController.addListener(() {
      try {
        _mapController.move(
          osm_latlong.LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation),
        );
      } catch (_) {}
    });

    animController.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        animController.dispose();
      }
    });

    if (mounted) {
      setState(() {
        _currentLat = destLocation.latitude;
        _currentLng = destLocation.longitude;
        _currentZoom = destZoom;
      });
    }

    animController.forward();
  }

  @override
  void initState() {
    super.initState();
    _mapController = osm.MapController();

    // Utamakan lokasi yang di-pass jika custom, atau lokasi terakhir yang diketahui dari GPS
    final lastPos = LocationService.lastKnownPosition;
    final bool isCustomCoord = (widget.initialLat != -6.2099 &&
        widget.initialLat != -6.2272 &&
        widget.initialLat != -6.1952 &&
        widget.initialLat != 0.0);

    if (isCustomCoord) {
      _currentLat = widget.initialLat;
      _currentLng = widget.initialLng;
    } else if (lastPos != null) {
      _currentLat = lastPos.latitude;
      _currentLng = lastPos.longitude;
    } else {
      _currentLat = -6.2099;
      _currentLng = 106.8502;
    }

    _selectedAddressTitle = widget.initialAddress.isNotEmpty 
        ? widget.initialAddress.split(',').first.trim() 
        : "Lokasi Terpilih";
    _selectedFullAddress = widget.initialAddress;

    _pinAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _pinJumpAnimation = Tween<double>(begin: 0.0, end: -16.0).animate(
      CurvedAnimation(parent: _pinAnimController, curve: Curves.easeOut),
    );

    // Otomatis deteksi GPS pengguna saat pertama kali membuka peta
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isCustomCoord || widget.initialAddress.isEmpty) {
        _getUserCurrentLocation(silent: true);
      } else {
        _reverseGeocodeCoordinate(_currentLat, _currentLng);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _mapIdleDebounce?.cancel();
    _pinAnimController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// 1. Cari Tempat Real-time via Mapbox Places API dengan Proximity Terdekat
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await DistanceService.searchPlaces(
        query,
        proximityLat: _currentLat,
        proximityLng: _currentLng,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  /// 2. Submit Search dari Keyboard (Enter / Tombol Cari)
  void _onSearchSubmitted(String query) async {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) return;

    if (_searchResults.isNotEmpty) {
      final first = _searchResults.first;
      _selectLocation(
        name: first['name'] as String,
        fullAddress: first['fullAddress'] ?? first['address'] ?? first['name'],
        lat: (first['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (first['lng'] as num?)?.toDouble() ?? 0.0,
        placeId: first['placeId'] as String?,
      );
      return;
    }

    setState(() => _isSearching = true);
    final results = await DistanceService.searchPlaces(
      query,
      proximityLat: _currentLat,
      proximityLng: _currentLng,
    );
    if (mounted) {
      setState(() => _isSearching = false);
      if (results.isNotEmpty) {
        final first = results.first;
        _selectLocation(
          name: first['name'] as String,
          fullAddress: first['fullAddress'] ?? first['address'] ?? first['name'],
          lat: (first['lat'] as num?)?.toDouble() ?? 0.0,
          lng: (first['lng'] as num?)?.toDouble() ?? 0.0,
          placeId: first['placeId'] as String?,
        );
      } else {
        _selectLocation(
          name: query.trim(),
          fullAddress: "${query.trim()} (Titik Peta Terpilih)",
          lat: _currentLat,
          lng: _currentLng,
          moveCamera: false,
        );
        _showToast("Menggunakan titik pin untuk '$query'");
      }
    }
  }

  /// 3. Pilih Hasil Pencarian dan Geser Kamera Peta Otomatis (Resolusi Koordinat Google / Mapbox)
  Future<void> _selectLocation({
    required String name,
    required String fullAddress,
    required double lat,
    required double lng,
    String? placeId,
    bool moveCamera = true,
  }) async {
    _searchFocus.unfocus();

    double targetLat = lat;
    double targetLng = lng;

    // Jika hasil dari Google Places Autocomplete belum memiliki Lat/Lng, ambil koordinat presisi via Place ID
    if ((targetLat == 0.0 || targetLng == 0.0) && placeId != null && placeId.isNotEmpty) {
      setState(() => _isLoadingAddress = true);
      final coords = await DistanceService.getGooglePlaceCoordinates(placeId);
      if (coords != null) {
        targetLat = coords['lat'] ?? targetLat;
        targetLng = coords['lng'] ?? targetLng;
      }
    }

    if (!mounted) return;

    setState(() {
      _searchResults = [];
      _searchController.text = name;
      _selectedAddressTitle = name;
      _selectedFullAddress = fullAddress.isNotEmpty ? fullAddress : name;
      _currentLat = targetLat;
      _currentLng = targetLng;
      _isLoadingAddress = false;
    });

    if (moveCamera && targetLat != 0.0 && targetLng != 0.0) {
      _pinAnimController.forward().then((_) => _pinAnimController.reverse());
      _animatedMoveMap(osm_latlong.LatLng(targetLat, targetLng), 16.5);
    }
  }

  /// 4. Tap Langsung Pada Peta (Tap-to-Pin)
  void _onTapMap(double lat, double lng) {
    _searchFocus.unfocus();
    setState(() {
      _searchResults = [];
      _currentLat = lat;
      _currentLng = lng;
    });

    _pinAnimController.forward().then((_) => _pinAnimController.reverse());
    _safeMoveMap(lat, lng, _currentZoom);
    _reverseGeocodeCoordinate(lat, lng);
  }

  /// 5. Deteksi Lokasi Saat Ini (Google Maps Style - Cepat, Akurat & Fallback Anti-Gagal)
  Future<void> _getUserCurrentLocation({bool silent = false}) async {
    setState(() => _isLocatingUser = true);
    if (!silent && mounted) {
      _showToast("Mencari titik lokasi GPS Anda... 📡");
    }

    try {
      double? lat;
      double? lng;

      // 1. Coba ambil dari Geolocator (Native Mobile / Browser HTML5 Geolocation)
      try {
        if (!kIsWeb) {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            if (!silent && mounted) {
              _showToast("GPS ponsel belum aktif. Silakan aktifkan GPS.");
              try {
                await Geolocator.openLocationSettings();
              } catch (_) {}
            }
          }
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
          // A. Fast Cache Fix (0ms)
          final cachedPos = await Geolocator.getLastKnownPosition();
          if (cachedPos != null && mounted) {
            lat = cachedPos.latitude;
            lng = cachedPos.longitude;
            setState(() {
              _myGpsLocation = osm_latlong.LatLng(lat!, lng!);
            });
            _animatedMoveMap(osm_latlong.LatLng(lat, lng), 16.5);
            _reverseGeocodeCoordinate(lat, lng);
          }

          // B. High Accuracy / Fused GPS Fix
          final position = await Geolocator.getCurrentPosition();
          lat = position.latitude;
          lng = position.longitude;
        }
      } catch (geoErr) {
        debugPrint("Geolocator GPS fallback trigger: $geoErr");
      }

      // 2. Multi-tier Fallback IP Geolocation (Jika akses web HTTP / GPS browser diblokir / timeout)
      if (lat == null || lng == null) {
        try {
          final ipRes = await http.get(Uri.parse('https://ipwho.is/')).timeout(const Duration(seconds: 4));
          if (ipRes.statusCode == 200) {
            final data = json.decode(utf8.decode(ipRes.bodyBytes));
            if (data['success'] == true && data['latitude'] != null && data['longitude'] != null) {
              lat = (data['latitude'] as num).toDouble();
              lng = (data['longitude'] as num).toDouble();
            }
          }
        } catch (_) {
          try {
            final ipRes2 = await http.get(Uri.parse('https://freeipapi.com/api/json')).timeout(const Duration(seconds: 4));
            if (ipRes2.statusCode == 200) {
              final data = json.decode(utf8.decode(ipRes2.bodyBytes));
              if (data['latitude'] != null && data['longitude'] != null) {
                lat = (data['latitude'] as num).toDouble();
                lng = (data['longitude'] as num).toDouble();
              }
            }
          } catch (_) {}
        }
      }

      // 3. Terapkan koordinat GPS ke Peta & Luncurkan Gerakan Halus
      if (lat != null && lng != null && mounted) {
        final targetCoord = osm_latlong.LatLng(lat, lng);
        setState(() {
          _myGpsLocation = targetCoord;
          _currentLat = lat!;
          _currentLng = lng!;
        });

        _animatedMoveMap(targetCoord, 16.5);
        _pinAnimController.forward().then((_) => _pinAnimController.reverse());
        await _reverseGeocodeCoordinate(lat, lng);
        if (!silent && mounted) _showToast("Lokasi Anda berhasil ditemukan 📍");
      } else {
        if (!silent && mounted) _showToast("Gagal mendeteksi GPS. Silakan geser pin secara manual.");
      }
    } catch (e) {
      debugPrint("Error GPS: $e");
      if (!silent && mounted) _showToast("Gagal mendeteksi GPS, geser pin peta secara manual.");
    } finally {
      if (mounted) setState(() => _isLocatingUser = false);
    }
  }

  /// 6. Reverse Geocoding: Dapatkan nama jalan/tempat saat pin selesai digeser
  Future<void> _reverseGeocodeCoordinate(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isLoadingAddress = true);

    try {
      final geo = await DistanceService.reverseGeocode(lat, lng);
      if (mounted) {
        setState(() {
          _selectedAddressTitle = geo['title'] ?? 'Lokasi Terpilih';
          _selectedFullAddress = geo['fullAddress'] ?? geo['title'] ?? '';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedAddressTitle = "Titik Koordinat Terpilih";
          _selectedFullAddress = "Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}";
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _zoomIn() {
    final currentZoom = _isMapReady ? _mapController.camera.zoom : _currentZoom;
    if (currentZoom < 18.5) {
      _animatedMoveMap(osm_latlong.LatLng(_currentLat, _currentLng), currentZoom + 1.0);
    }
  }

  void _zoomOut() {
    final currentZoom = _isMapReady ? _mapController.camera.zoom : _currentZoom;
    if (currentZoom > 4.5) {
      _animatedMoveMap(osm_latlong.LatLng(_currentLat, _currentLng), currentZoom - 1.0);
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 12)),
        backgroundColor: AppTheme.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getActiveTileUrl() {
    switch (_currentMapStyle) {
      case 'dark':
        return MapboxConfig.darkTileUrl;
      case 'satellite':
        return MapboxConfig.satelliteTileUrl;
      case 'streets':
      default:
        return MapboxConfig.streetsTileUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // 🗺️ 1. MAPBOX HIGH-DEFINITION MAP WIDGET
          osm.FlutterMap(
            mapController: _mapController,
            options: osm.MapOptions(
              initialCenter: osm_latlong.LatLng(_currentLat, _currentLng),
              initialZoom: _currentZoom,
              minZoom: 3.0,
              maxZoom: 19.0,
              interactionOptions: const osm.InteractionOptions(
                flags: osm.InteractiveFlag.all,
              ),
              onMapReady: () {
                _isMapReady = true;
                final target = _pendingTarget ?? osm_latlong.LatLng(_currentLat, _currentLng);
                final zoom = _pendingZoom ?? _currentZoom;
                _pendingTarget = null;
                _pendingZoom = null;
                try {
                  _mapController.move(target, zoom);
                } catch (_) {}
              },
              onTap: (_, point) => _onTapMap(point.latitude, point.longitude),
              onPositionChanged: (camera, hasGesture) {
                _currentZoom = camera.zoom;
                if (hasGesture) {
                  _pinAnimController.forward();
                  _mapIdleDebounce?.cancel();
                  _mapIdleDebounce = Timer(const Duration(milliseconds: 300), () {
                    _pinAnimController.reverse();
                    _currentLat = camera.center.latitude;
                    _currentLng = camera.center.longitude;
                    _reverseGeocodeCoordinate(camera.center.latitude, camera.center.longitude);
                  });
                }
              },
            ),
            children: [
              osm.TileLayer(
                urlTemplate: _getActiveTileUrl(),
                userAgentPackageName: 'com.temeninajaa.app',
                maxZoom: 19,
                fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              if (_myGpsLocation != null)
                osm.MarkerLayer(
                  markers: [
                    osm.Marker(
                      point: _myGpsLocation!,
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0x334285F4),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4285F4),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 📍 2. FIXED CENTER PIN WITH BOUNCE & BADGE (Non-blocking touch)
          IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _pinAnimController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -28 + _pinJumpAnimation.value),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(color: AppTheme.primaryPink, width: 1.5),
                          ),
                          child: Text(
                            widget.title,
                            style: GoogleFonts.inter(
                              color: AppTheme.textHighContrast,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppTheme.primaryPink,
                          size: 46,
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // 🔍 3. TOP SEARCH BAR & MAPBOX STYLE SWITCHER
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                            border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.5)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            onSubmitted: _onSearchSubmitted,
                            textInputAction: TextInputAction.search,
                            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "Cari spot hangout, cafe, mall, alamat...",
                              hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12.5),
                              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryPink, size: 20),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPink),
                                      ),
                                    )
                                  : _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                                          onPressed: () {
                                            _searchController.clear();
                                            _onSearchChanged('');
                                          },
                                        )
                                      : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 🔄 MAPBOX STYLE SWITCHER (Streets, Dark, Satelit)
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6),
                          ],
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildStyleChip("🗺️ Streets", "streets"),
                            const SizedBox(width: 2),
                            _buildStyleChip("🌙 Dark", "dark"),
                            const SizedBox(width: 2),
                            _buildStyleChip("🛰️ Satelit", "satellite"),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // 📋 DROPDOWN SEARCH SUGGESTIONS (Detailed Places & Hangouts)
                  if (_searchResults.isNotEmpty || (_searchController.text.trim().length >= 2 && !_isSearching))
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 14),
                        ],
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          // 📌 Opsi 1: Gunakan Teks Pencarian Custom Pengguna
                          if (_searchController.text.trim().isNotEmpty) ...[
                            ListTile(
                              dense: true,
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit_location_alt_rounded, color: Color(0xFF10B981), size: 18),
                              ),
                              title: Text(
                                "Gunakan: '${_searchController.text.trim()}'",
                                style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: Text(
                                "Pasang pin di titik pusat peta saat ini",
                                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                              ),
                              onTap: () {
                                final query = _searchController.text.trim();
                                _selectLocation(
                                  name: query,
                                  fullAddress: "$query (Titik Peta Terpilih)",
                                  lat: _currentLat,
                                  lng: _currentLng,
                                  moveCamera: false,
                                );
                              },
                            ),
                            if (_searchResults.isNotEmpty)
                              const Divider(color: AppTheme.border, height: 1),
                          ],

                          // 📍 Daftar Hasil Pencarian Terverifikasi (Google Places & Mapbox)
                          ..._searchResults.map((item) {
                            final source = item['source']?.toString() ?? 'mapbox';
                            final isGoogle = source == 'google';
                            final isOsm = source == 'osm';

                            IconData iconData = Icons.pin_drop_rounded;
                            Color iconColor = AppTheme.primaryPink;
                            Color bgColor = AppTheme.primaryPink.withValues(alpha: 0.12);

                            if (isGoogle) {
                              iconData = Icons.auto_awesome_rounded;
                              iconColor = const Color(0xFF6366F1);
                              bgColor = const Color(0xFF6366F1).withValues(alpha: 0.15);
                            } else if (isOsm) {
                              iconData = Icons.storefront_rounded;
                              iconColor = const Color(0xFFF59E0B);
                              bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.15);
                            }

                            return ListTile(
                              dense: true,
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(iconData, color: iconColor, size: 18),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['name'],
                                      style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isGoogle)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 0.8),
                                      ),
                                      child: Text(
                                        "SMART",
                                        style: GoogleFonts.inter(color: const Color(0xFF818CF8), fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                item['address'] ?? '',
                                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                _selectLocation(
                                  name: item['name'] as String,
                                  fullAddress: item['fullAddress'] ?? item['address'] ?? item['name'],
                                  lat: (item['lat'] as num?)?.toDouble() ?? 0.0,
                                  lng: (item['lng'] as num?)?.toDouble() ?? 0.0,
                                  placeId: item['placeId'] as String?,
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 🎛️ 4. ZOOM CONTROLS & GPS FLOATING BUTTONS
          Positioned(
            right: 16,
            bottom: 240,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom In
                FloatingActionButton.small(
                  heroTag: 'btn_zoom_in',
                  backgroundColor: AppTheme.surface,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add_rounded, color: AppTheme.textHighContrast, size: 20),
                ),
                const SizedBox(height: 8),
                // Zoom Out
                FloatingActionButton.small(
                  heroTag: 'btn_zoom_out',
                  backgroundColor: AppTheme.surface,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove_rounded, color: AppTheme.textHighContrast, size: 20),
                ),
                const SizedBox(height: 12),
                // GPS "Lokasi Saya" Button
                FloatingActionButton(
                  heroTag: 'btn_gps_my_loc',
                  backgroundColor: AppTheme.surface,
                  onPressed: () => _getUserCurrentLocation(silent: false),
                  child: _isLocatingUser
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPink),
                        )
                      : const Icon(Icons.my_location_rounded, color: AppTheme.primaryPink, size: 24),
                ),
              ],
            ),
          ),

          // 🏁 5. BOTTOM CONFIRMATION SHEET
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPink.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.title.toUpperCase(),
                            style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Mapbox HD • Geser pin",
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppTheme.primaryPink, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _isLoadingAddress
                            ? Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPink),
                                  ),
                                  const SizedBox(width: 8),
                                  Text("Mendeteksi nama lokasi...", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedAddressTitle,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.textHighContrast,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_selectedFullAddress.isNotEmpty)
                                    Text(
                                      _selectedFullAddress,
                                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context, {
                          'address': _selectedFullAddress.isNotEmpty ? _selectedFullAddress : _selectedAddressTitle,
                          'title': _selectedAddressTitle,
                          'lat': _currentLat,
                          'lng': _currentLng,
                        });
                      },
                      child: Text(
                        "GUNAKAN TITIK LOKASI INI",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleChip(String label, String styleKey) {
    final isSelected = _currentMapStyle == styleKey;
    return InkWell(
      onTap: () {
        setState(() {
          _currentMapStyle = styleKey;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPink : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : AppTheme.textMuted,
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
