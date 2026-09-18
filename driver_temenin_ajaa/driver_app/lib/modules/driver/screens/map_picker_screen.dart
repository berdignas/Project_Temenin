import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_theme.dart';
import '../../../core/config/mapbox_config.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> with TickerProviderStateMixin {
  LatLng _selectedLocation = const LatLng(-6.2088, 106.8456); // Jakarta Pusat Default
  LatLng? _myCurrentLocation; // Real-time HP GPS position (blue dot)
  final MapController _mapController = MapController();
  String _selectedAddress = "Monas, Jakarta Pusat (Peta Mapbox)";
  bool _isLocating = false;

  final List<Map<String, dynamic>> _presetLocations = [
    {"name": "Monumen Nasional (Monas)", "lat": -6.1754, "lng": 106.8272, "addr": "Monas, Jakarta Pusat"},
    {"name": "SCBD Sudirman", "lat": -6.2253, "lng": 106.8097, "addr": "SCBD Sudirman, Jakarta Selatan"},
    {"name": "Bandara Soekarno Hatta", "lat": -6.1275, "lng": 106.6537, "addr": "Bandara Soetta, Tangerang"},
    {"name": "Alun-Alun Bandung", "lat": -6.9218, "lng": 107.6072, "addr": "Alun-Alun, Bandung"},
  ];

  void _animatedMoveMap(LatLng destLocation, double destZoom) {
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
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
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
        _selectedLocation = destLocation;
      });
    }

    animController.forward();
  }

  @override
  void initState() {
    super.initState();
    // Otomatis meminta izin & mendeteksi lokasi GPS saat peta dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchGPSLocation();
    });
  }

  Future<String> _reverseGeocode(double lat, double lon) async {
    final token = MapboxConfig.accessToken;

    // A. Mapbox Reverse Geocoding
    if (token.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$lon,$lat.json?types=address,poi,neighborhood,locality,place&language=id&access_token=$token',
        );
        final response = await http.get(url).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final features = data['features'] as List? ?? [];
          if (features.isNotEmpty) {
            final placeName = features.first['place_name']?.toString();
            if (placeName != null && placeName.isNotEmpty) {
              return placeName;
            }
          }
        }
      } catch (e) {
        debugPrint("Mapbox Driver Geocoding error: $e");
      }
    }

    // B. Fallback Nominatim
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'TemeninAjaaDriverApp/1.0 (contact@temeninajaa.id)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];
        if (address != null) {
          final road = address['road'] ?? address['suburb'] ?? address['neighbourhood'] ?? address['amenity'] ?? '';
          final city = address['city'] ?? address['town'] ?? address['municipality'] ?? address['county'] ?? '';
          if (road.isNotEmpty && city.isNotEmpty) {
            return "$road, $city";
          } else if (data['display_name'] != null) {
            final parts = (data['display_name'] as String).split(',');
            return parts.take(3).join(',').trim();
          }
        }
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
    return "Titik GPS (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})";
  }

  Future<void> _fetchGPSLocation() async {
    setState(() => _isLocating = true);
    try {
      double? lat;
      double? lng;

      // 1. Coba ambil dari Geolocator (Native Mobile / Browser HTML5 Geolocation)
      try {
        if (!kIsWeb) {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Layanan GPS perangkat belum aktif. Mohon aktifkan GPS ponsel Anda.')),
              );
            }
          }
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
          // A. Fast Cache Fix (0ms)
          final cached = await Geolocator.getLastKnownPosition();
          if (cached != null && mounted) {
            lat = cached.latitude;
            lng = cached.longitude;
            final cachedPoint = LatLng(lat, lng);
            _animatedMoveMap(cachedPoint, 16.5);
            setState(() {
              _myCurrentLocation = cachedPoint;
              _selectedLocation = cachedPoint;
              _selectedAddress = "Mencari nama jalan...";
            });
            _reverseGeocode(lat, lng).then((addr) {
              if (mounted) setState(() => _selectedAddress = addr);
            });
          }

          // B. High Accuracy / Fused GPS Fix
          final position = await Geolocator.getCurrentPosition();
          lat = position.latitude;
          lng = position.longitude;
        }
      } catch (geoErr) {
        debugPrint("Driver Geolocator fallback trigger: $geoErr");
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
        final myPoint = LatLng(lat, lng);
        _animatedMoveMap(myPoint, 16.5);

        setState(() {
          _myCurrentLocation = myPoint;
          _selectedLocation = myPoint;
          _selectedAddress = "Mencari nama jalan...";
        });

        final addressName = await _reverseGeocode(lat, lng);

        if (mounted) {
          setState(() {
            _selectedAddress = addressName;
          });
        }
      }
    } catch (e) {
      debugPrint("GPS error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _onTapMap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _selectedLocation = point;
      _selectedAddress = "Mencari nama jalan...";
    });

    final addressName = await _reverseGeocode(point.latitude, point.longitude);

    if (mounted) {
      setState(() {
        _selectedAddress = addressName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0910),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14101E),
        title: Text(
          "Pilih Lokasi di Mapbox HD",
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. MAPBOX HIGH-DEFINITION INTERACTIVE WIDGET
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 14.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: _onTapMap,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  _selectedLocation = camera.center;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: MapboxConfig.streetsTileUrl,
                userAgentPackageName: 'com.temeninajaa.driver',
                fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  // Blue Dot (Posisi HP GPS Asli Pengguna)
                  if (_myCurrentLocation != null)
                    Marker(
                      point: _myCurrentLocation!,
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0x332196F3),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Pin Merah Muda (Titik Lokasi Terpilih)
                  Marker(
                    point: _selectedLocation,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryPink,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))
                        ],
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. QUICK PRESET LOCATION CHIPS AT TOP
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _presetLocations.map((loc) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: const Color(0xED14101E),
                      side: const BorderSide(color: AppTheme.primaryPink, width: 1),
                      avatar: const Icon(Icons.near_me_rounded, color: AppTheme.primaryPink, size: 14),
                      label: Text(
                        loc['name'],
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        final target = LatLng(loc['lat'], loc['lng']);
                        _mapController.move(target, 15.0);
                        setState(() {
                          _selectedLocation = target;
                          _selectedAddress = loc['addr'];
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 3. FLOATING GPS MY LOCATION BUTTON
          Positioned(
            bottom: 140 + MediaQuery.of(context).padding.bottom,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'gps_btn',
              backgroundColor: const Color(0xFF14101E),
              onPressed: _isLocating ? null : _fetchGPSLocation,
              icon: _isLocating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppTheme.primaryPink, strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded, color: AppTheme.primaryPink),
              label: Text(
                _isLocating ? "Mencari GPS..." : "📍 Lokasi Saya Sekarang",
                style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // 4. BOTTOM PANEL & CONFIRMATION BUTTON
          Positioned(
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xF014101E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place_rounded, color: AppTheme.primaryPink, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Lokasi Terpilih (Mapbox HD)", style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              _selectedAddress,
                              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, _selectedAddress);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      label: Text(
                        "GUNAKAN LOKASI INI",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
}
