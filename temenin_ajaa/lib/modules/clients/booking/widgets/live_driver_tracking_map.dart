import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:latlong2/latlong.dart' as osm_latlong;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';

class LiveDriverTrackingMap extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final double height;
  final bool isMiniMap;
  final VoidCallback? onTap;
  final Function(double distanceKm, int etaMinutes, String arrivalTime)? onEtaUpdated;

  const LiveDriverTrackingMap({
    super.key,
    required this.bookingData,
    this.height = 240.0,
    this.isMiniMap = true,
    this.onTap,
    this.onEtaUpdated,
  });

  @override
  State<LiveDriverTrackingMap> createState() => _LiveDriverTrackingMapState();
}

class _LiveDriverTrackingMapState extends State<LiveDriverTrackingMap> with SingleTickerProviderStateMixin {
  late final osm.MapController _mapController;
  StreamSubscription<List<Map<String, dynamic>>>? _bookingStreamSub;
  Timer? _simulatedMovementTimer;
  late AnimationController _pulseController;

  late osm_latlong.LatLng _pickupLocation;
  late osm_latlong.LatLng _driverLocation;

  double _distanceKm = 10.0;
  int _etaMinutes = 24;
  String _arrivalTimeStr = "--:-- WIB";
  bool _isLiveGps = false;

  @override
  void initState() {
    super.initState();
    _mapController = osm.MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _resolveInitialLocations();
    _calculateDistanceAndEta();
    _subscribeToDriverGps();
  }

  @override
  void didUpdateWidget(LiveDriverTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookingData != oldWidget.bookingData) {
      _extractCoordinates(widget.bookingData);
      _calculateDistanceAndEta();
    }
  }

  @override
  void dispose() {
    _bookingStreamSub?.cancel();
    _simulatedMovementTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _resolveInitialLocations() {
    // 1. Pickup location
    double pLat = _parseCoordinate(
      widget.bookingData['pickup_lat'] ??
      widget.bookingData['pickupLat'] ??
      _getAdditionalDetail('pickup_lat') ??
      _getAdditionalDetail('pickupLat'),
      fallback: -6.2297, // Default Central Jakarta
    );
    double pLng = _parseCoordinate(
      widget.bookingData['pickup_lng'] ??
      widget.bookingData['pickupLng'] ??
      _getAdditionalDetail('pickup_lng') ??
      _getAdditionalDetail('pickupLng'),
      fallback: 106.8295,
    );
    _pickupLocation = osm_latlong.LatLng(pLat, pLng);

    // 2. Driver location
    dynamic dLatRaw = widget.bookingData['driver_lat'] ??
        widget.bookingData['driverLat'] ??
        _getAdditionalDetail('driver_lat') ??
        _getAdditionalDetail('driverLat');
    dynamic dLngRaw = widget.bookingData['driver_lng'] ??
        widget.bookingData['driverLng'] ??
        _getAdditionalDetail('driver_lng') ??
        _getAdditionalDetail('driverLng');

    if (dLatRaw != null && dLngRaw != null) {
      _driverLocation = osm_latlong.LatLng(
        _parseCoordinate(dLatRaw, fallback: pLat + 0.075),
        _parseCoordinate(dLngRaw, fallback: pLng + 0.055),
      );
      _isLiveGps = true;
    } else {
      // Create initial ~10 km realistic offset from pickup point
      _driverLocation = osm_latlong.LatLng(pLat + 0.072, pLng + 0.052);
      _isLiveGps = false;
      _startSimulatedDriverMovement();
    }
  }

  dynamic _getAdditionalDetail(String key) {
    final add = widget.bookingData['additional_details'] ?? widget.bookingData['additionalDetails'];
    if (add is Map) return add[key];
    if (add is String) {
      try {
        final decoded = jsonDecode(add);
        if (decoded is Map) return decoded[key];
      } catch (_) {}
    }
    return null;
  }

  double _parseCoordinate(dynamic val, {required double fallback}) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) {
      final parsed = double.tryParse(val.trim());
      if (parsed != null && parsed != 0.0) return parsed;
    }
    return fallback;
  }

  void _calculateDistanceAndEta() {
    try {
      final distanceMeters = Geolocator.distanceBetween(
        _driverLocation.latitude,
        _driverLocation.longitude,
        _pickupLocation.latitude,
        _pickupLocation.longitude,
      );

      final distKm = (distanceMeters / 1000.0);
      // City driving average speed: ~25 km/h
      final etaMin = (distKm / 25.0 * 60.0).round().clamp(1, 240);
      final arrivalDt = DateTime.now().add(Duration(minutes: etaMin));
      final arrivalStr = "${arrivalDt.hour.toString().padLeft(2, '0')}:${arrivalDt.minute.toString().padLeft(2, '0')} WIB";

      if (mounted) {
        setState(() {
          _distanceKm = distKm;
          _etaMinutes = etaMin;
          _arrivalTimeStr = arrivalStr;
        });
      }

      widget.onEtaUpdated?.call(_distanceKm, _etaMinutes, _arrivalTimeStr);
    } catch (e) {
      debugPrint("Error calculating distance and ETA: $e");
    }
  }

  void _extractCoordinates(Map<String, dynamic> data) {
    dynamic dLatRaw = data['driver_lat'] ??
        data['driverLat'] ??
        _getAdditionalDetail('driver_lat') ??
        _getAdditionalDetail('driverLat');
    dynamic dLngRaw = data['driver_lng'] ??
        data['driverLng'] ??
        _getAdditionalDetail('driver_lng') ??
        _getAdditionalDetail('driverLng');

    if (dLatRaw != null && dLngRaw != null) {
      final newDLat = _parseCoordinate(dLatRaw, fallback: _driverLocation.latitude);
      final newDLng = _parseCoordinate(dLngRaw, fallback: _driverLocation.longitude);
      _driverLocation = osm_latlong.LatLng(newDLat, newDLng);
      _isLiveGps = true;
      _simulatedMovementTimer?.cancel();
    }
  }

  void _subscribeToDriverGps() {
    final bId = widget.bookingData['id']?.toString();
    if (bId == null || bId.isEmpty) return;
    final dynamic queryId = int.tryParse(bId) ?? bId;

    try {
      _bookingStreamSub = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', queryId)
          .listen(
            (rows) {
              if (rows.isNotEmpty && mounted) {
                _extractCoordinates(rows.first);
                _calculateDistanceAndEta();
              }
            },
            onError: (err) {
              debugPrint("Live map stream error: $err");
            },
          );
    } catch (e) {
      debugPrint("Error subscribing to driver GPS stream: $e");
    }
  }

  void _startSimulatedDriverMovement() {
    _simulatedMovementTimer?.cancel();
    // Simulate slight movement toward client if no hardware GPS stream is transmitting
    _simulatedMovementTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || _isLiveGps) {
        timer.cancel();
        return;
      }
      final double latDiff = _pickupLocation.latitude - _driverLocation.latitude;
      final double lngDiff = _pickupLocation.longitude - _driverLocation.longitude;
      
      // Move 0.6% closer every 4 seconds
      if (latDiff.abs() > 0.0005 || lngDiff.abs() > 0.0005) {
        setState(() {
          _driverLocation = osm_latlong.LatLng(
            _driverLocation.latitude + (latDiff * 0.006),
            _driverLocation.longitude + (lngDiff * 0.006),
          );
        });
        _calculateDistanceAndEta();
      }
    });
  }

  void _fitMapBounds() {
    try {
      final double midLat = (_driverLocation.latitude + _pickupLocation.latitude) / 2.0;
      final double midLng = (_driverLocation.longitude + _pickupLocation.longitude) / 2.0;
      final centerPoint = osm_latlong.LatLng(midLat, midLng);

      // Estimate zoom level based on distance
      double zoom = 13.0;
      if (_distanceKm > 15) zoom = 11.5;
      else if (_distanceKm > 8) zoom = 12.5;
      else if (_distanceKm > 4) zoom = 13.5;
      else if (_distanceKm > 1.5) zoom = 14.5;
      else zoom = 15.5;

      _mapController.move(centerPoint, zoom);
    } catch (e) {
      debugPrint("Error fitting map bounds: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final double midLat = (_driverLocation.latitude + _pickupLocation.latitude) / 2.0;
    final double midLng = (_driverLocation.longitude + _pickupLocation.longitude) / 2.0;
    final centerPoint = osm_latlong.LatLng(midLat, midLng);

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primaryPink.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 1. OPENSTREETMAP LIVE ENGINE
            osm.FlutterMap(
              mapController: _mapController,
              options: osm.MapOptions(
                initialCenter: centerPoint,
                initialZoom: 12.8,
                minZoom: 5.0,
                maxZoom: 18.0,
                interactionOptions: osm.InteractionOptions(
                  flags: widget.isMiniMap
                      ? (osm.InteractiveFlag.pinchZoom | osm.InteractiveFlag.drag)
                      : osm.InteractiveFlag.all,
                ),
                onMapReady: () {
                  _fitMapBounds();
                },
              ),
              children: [
                osm.TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.temeninajaa.app',
                  maxZoom: 19,
                ),

                // ROUTE POLYLINE (Driver -> Client)
                osm.PolylineLayer(
                  polylines: [
                    osm.Polyline(
                      points: [_driverLocation, _pickupLocation],
                      color: AppTheme.primaryPink,
                      strokeWidth: 4.5,
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

                // MARKERS (Driver & Client)
                osm.MarkerLayer(
                  markers: [
                    // A. CLIENT PICKUP POINT (Rumah / Penjemputan)
                    osm.Marker(
                      point: _pickupLocation,
                      width: 48,
                      height: 48,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 36 + (_pulseController.value * 12),
                                height: 36 + (_pulseController.value * 12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.green.withOpacity(0.3 * (1.0 - _pulseController.value)),
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.home_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // B. DRIVER LIVE LOCATION (Mitra Driver OTW)
                    osm.Marker(
                      point: _driverLocation,
                      width: 52,
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF43F5E), Color(0xFFD946EF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(color: Colors.white, width: 2.8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD946EF).withOpacity(0.55),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.two_wheeler_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 2. FLOATING REAL-TIME ETA & DISTANCE BADGE
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryPink.withOpacity(0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: AppTheme.primaryPink,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Jarak: ${_distanceKm.toStringAsFixed(1)} km",
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textHighContrast,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (_isLiveGps ? Colors.green : Colors.amber).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _isLiveGps ? Colors.green : Colors.amber,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isLiveGps ? "Live GPS" : "Estimasi",
                                      style: GoogleFonts.inter(
                                        color: _isLiveGps ? Colors.green : Colors.amber[800],
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Estimasi Tiba: ~$_etaMinutes Menit (Tiba $_arrivalTimeStr)",
                            style: GoogleFonts.inter(
                              color: AppTheme.textMediumContrast,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. RECENTER BUTTON
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: _fitMapBounds,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: AppTheme.primaryPink,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
