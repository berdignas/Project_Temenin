import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng _selectedLocation = const LatLng(-6.2088, 106.8456); // Jakarta Pusat Default
  LatLng? _myCurrentLocation; // Real-time HP GPS position (blue dot)
  final MapController _mapController = MapController();
  String _selectedAddress = "Monas, Jakarta Pusat (Peta Asli)";
  bool _isLocating = false;

  final List<Map<String, dynamic>> _presetLocations = [
    {"name": "Monumen Nasional (Monas)", "lat": -6.1754, "lng": 106.8272, "addr": "Monas, Jakarta Pusat"},
    {"name": "SCBD Sudirman", "lat": -6.2253, "lng": 106.8097, "addr": "SCBD Sudirman, Jakarta Selatan"},
    {"name": "Bandara Soekarno Hatta", "lat": -6.1275, "lng": 106.6537, "addr": "Bandara Soetta, Tangerang"},
    {"name": "Alun-Alun Bandung", "lat": -6.9218, "lng": 107.6072, "addr": "Alun-Alun, Bandung"},
  ];

  @override
  void initState() {
    super.initState();
    // Otomatis meminta izin & mendeteksi lokasi GPS saat peta dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchGPSLocation();
    });
  }

  Future<String> _reverseGeocode(double lat, double lon) async {
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
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Layanan GPS perangkat belum aktif. Mohon aktifkan GPS ponsel Anda.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Izin lokasi ditolak oleh pengguna.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak secara permanen. Mohon aktifkan di Pengaturan HP.')),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final myPoint = LatLng(position.latitude, position.longitude);
      _mapController.move(myPoint, 16.5);

      setState(() {
        _myCurrentLocation = myPoint;
        _selectedLocation = myPoint;
        _selectedAddress = "Mencari nama jalan...";
      });

      final addressName = await _reverseGeocode(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _selectedAddress = addressName;
        });
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
          "Pilih Lokasi di Peta Asli",
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
          // 1. OPENSTREETMAP INTERACTIVE WIDGET
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 14.0,
              onTap: _onTapMap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.temeninajaa.driver',
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
                            Text("Lokasi Terpilih", style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
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
