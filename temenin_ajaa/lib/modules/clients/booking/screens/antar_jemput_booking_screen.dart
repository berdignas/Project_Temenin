// lib/modules/booking/screens/antar_jemput_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'booking_confirmation_screen.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/core/services/distance_service.dart';
import 'package:temenin_ajaa/core/services/location_service.dart';
import 'package:temenin_ajaa/core/services/pricing_service.dart';
import '../widgets/multi_service_section.dart';

class AntarJemputBookingScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedPartner;
  final String serviceType;
  final String? initialDestination;
  
  const AntarJemputBookingScreen({
    super.key, 
    this.selectedPartner,
    this.serviceType = 'regular',
    this.initialDestination,
  });

  @override
  State<AntarJemputBookingScreen> createState() => _AntarJemputBookingScreenState();
}

class _AntarJemputBookingScreenState extends State<AntarJemputBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  late final TextEditingController _destinationController;
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _returnTimeController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Real Maps & Route Coordinates State
  double _pickupLat = -6.2099; // Stasiun Manggarai default
  double _pickupLng = 106.8502;
  double _destLat = -6.1952; // Grand Indonesia default
  double _destLng = 106.8208;
  double _actualDistanceKm = 7.4;
  int _estimatedDurationMinutes = 18;
  bool _isCalculatingDistance = false;
  String _routeSource = 'OpenStreetMap';

  // Dynamic Multi-Layanan List
  final List<AdditionalServiceItem> _additionalServices = [];

  // Add-ons State
  bool _pulangPergi = false;
  bool _useCar = false;
  bool _rentHelmet = false;
  bool _differentArea = false;
  bool _isWeekendApplied = false;

  dynamic _selectedDriverId = '';
  String _selectedDriverName = 'Mitra Radar Temenin';
  String _selectedDriverImage = '';
  double _selectedDriverRating = 4.9;
  int _selectedDriverPrice = 5000; // price per km
  String _selectedDriverVehicle = 'Motor Mitra Terverifikasi';
  int _selectedDriverTrips = 120;
  String _selectedDriverClass = 'Gold';
  
  @override
  void initState() {
    super.initState();
    _pickupController.text = "";
    _destinationController = TextEditingController(
      text: widget.initialDestination?.isNotEmpty == true 
          ? widget.initialDestination! 
          : "",
    );

    if (widget.selectedPartner != null) {
      _selectedDriverId = widget.selectedPartner!['id'] ?? '';
      _selectedDriverName = widget.selectedPartner!['name'] ?? 'Driver Partner';
      _selectedDriverImage = widget.selectedPartner!['image'] ?? widget.selectedPartner!['avatar'] ?? '';
      _selectedDriverRating = widget.selectedPartner!['rating'] is String 
          ? double.parse(widget.selectedPartner!['rating']) 
          : (widget.selectedPartner!['rating']?.toDouble() ?? 4.9);
      _selectedDriverVehicle = widget.selectedPartner!['vehicle'] ?? 'Kendaraan Driver';
      _selectedDriverPrice = widget.selectedPartner!['price'] is int 
          ? widget.selectedPartner!['price'] 
          : 5000;
      _selectedDriverTrips = widget.selectedPartner!['kpi'] is int 
          ? (widget.selectedPartner!['kpi'] as int) * 2 
          : 120;
      _selectedDriverClass = widget.selectedPartner!['type'] ?? 'Gold';
    }

    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    if (widget.selectedPartner != null && widget.selectedPartner!['selectedDate'] != null) {
      _dateController.text = widget.selectedPartner!['selectedDate'].toString();
    } else {
      _dateController.text = "${now.day} ${months[now.month - 1]} ${now.year}";
    }

    if (widget.selectedPartner != null && widget.selectedPartner!['selectedTime'] != null) {
      _timeController.text = widget.selectedPartner!['selectedTime'].toString();
    } else {
      _timeController.text = "Pesan Sekarang (Langsung OTW)";
    }

    _checkWeekend(now);
    _loadOfficialPricing();
    _calculateRealRouteDistance();

    // Auto-detect GPS perangkat real untuk titik penjemputan
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null && mounted) {
        setState(() {
          _pickupLat = pos.latitude;
          _pickupLng = pos.longitude;
        });
        if (_pickupController.text.isEmpty) {
          final geo = await DistanceService.reverseGeocode(pos.latitude, pos.longitude);
          if (mounted && _pickupController.text.isEmpty) {
            setState(() {
              _pickupController.text = geo['fullAddress'] ?? geo['title'] ?? '';
            });
          }
        }
        _calculateRealRouteDistance();
      }
    });
  }

  Future<void> _calculateRealRouteDistance() async {
    if (!mounted) return;
    setState(() => _isCalculatingDistance = true);

    final result = await DistanceService.calculateRouteDistance(
      startLat: _pickupLat,
      startLng: _pickupLng,
      destLat: _destLat,
      destLng: _destLng,
    );

    if (mounted) {
      setState(() {
        _actualDistanceKm = (result['distanceKm'] as num?)?.toDouble() ?? 7.4;
        _estimatedDurationMinutes = (result['durationMinutes'] as num?)?.toInt() ?? 18;
        _routeSource = result['source']?.toString() ?? 'OpenStreetMap';
        _isCalculatingDistance = false;
      });
    }
  }

  Future<void> _loadOfficialPricing() async {
    await PricingService().fetchPricingConfig();
    if (mounted) {
      setState(() {
        final isSporty = widget.serviceType == 'sporty' || widget.serviceType == 'sporty_ride';
        _selectedDriverPrice = isSporty 
            ? PricingService().pricePerKmSporty 
            : PricingService().pricePerKm;
      });
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _returnTimeController.dispose();
    _notesController.dispose();
    for (var s in _additionalServices) {
      s.dispose();
    }
    super.dispose();
  }

  void _checkWeekend(DateTime date) {
    setState(() {
      _isWeekendApplied = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    });
  }

  Map<String, dynamic> _calculatePrice() {
    final double distance = _actualDistanceKm > 0 ? _actualDistanceKm : 5.0;
    
    // Service 1: Antar Jemput. Pulang Pergi doubles the distance/trip fee
    double baseService1Price = (distance * _selectedDriverPrice);
    if (_pulangPergi) {
      baseService1Price *= 2.0;
    }
    // Batas minimum tarif perjalanan dari admin
    final minRide = PricingService().minRidePrice.toDouble();
    if (baseService1Price < minRide) {
      baseService1Price = minRide;
    }
    int service1Fee = baseService1Price.toInt();

    // Multi-Layanan Dynamic Fee Sum
    int additionalServicesFee = _additionalServices.fold<int>(
      0, 
      (sum, item) => sum + item.calculateFee(),
    );

    // Add-ons
    int carAddon = _useCar ? 50000 : 0;
    int helmetAddon = _rentHelmet ? 10000 : 0;
    int areaAddon = _differentArea ? 20000 : 0;

    int subtotal = service1Fee + additionalServicesFee + carAddon + helmetAddon + areaAddon;
    
    // Weekend Surcharge +25%
    int weekendFee = _isWeekendApplied ? (subtotal * 0.25).toInt() : 0;

    int totalEstimasi = subtotal + weekendFee;
    int dp = (totalEstimasi * 0.5).toInt();
    int remainingPayment = totalEstimasi - dp;

    return {
      'service1Fee': service1Fee,
      'additionalServicesFee': additionalServicesFee,
      'weekendFee': weekendFee,
      'totalEstimasi': totalEstimasi,
      'dp': dp,
      'remaining': remainingPayment,
      'distanceKm': distance,
      'durationMinutes': _estimatedDurationMinutes,
    };
  }

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/client-main', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prices = _calculatePrice();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            (widget.serviceType == 'sporty' || widget.serviceType == 'sporty_ride')
                ? "Antar Jemput Sporty (Motor Sport)"
                : "Form Antar Jemput Aman",
            style: GoogleFonts.inter(
              color: AppTheme.textHighContrast,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast),
            onPressed: () => _handleBack(context),
          ),
        ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.serviceType == 'sporty' || widget.serviceType == 'sporty_ride') ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF06B6D4).withOpacity(0.15), const Color(0xFF3B82F6).withOpacity(0.15)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Text("🏍️", style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Sensasi Riding Motor Sport Eksklusif",
                                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Antar/jemput dengan armada motor sport (ZX25R, CBR, Ninja, R-Series) + helm bersih.",
                                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // HEADER: DRIVER PROFILE OR RADAR MATCHING (NO "PILIH DRIVER" LIST)
                widget.selectedPartner != null
                    ? _buildSelectedDriverHeader()
                    : _buildRadarHeaderBadge(),
                const SizedBox(height: 20),

                _buildLocationSection(
                  sectionTitle: "Lokasi Penjemputan",
                  mapBadgeTitle: "TITIK JEMPUT DI GOOGLE MAPS",
                  controller: _pickupController,
                  hintText: "Contoh: Apartemen / Rumah / Stasiun...",
                  icon: Icons.location_on_rounded,
                  lat: _pickupLat,
                  lng: _pickupLng,
                  onSelected: (address, lat, lng) {
                    setState(() {
                      _pickupController.text = address;
                      _pickupLat = lat;
                      _pickupLng = lng;
                    });
                    _calculateRealRouteDistance();
                  },
                ),
                const SizedBox(height: 18),
                
                _buildLocationSection(
                  sectionTitle: "Lokasi Tujuan",
                  mapBadgeTitle: "TITIK TUJUAN DI GOOGLE MAPS",
                  controller: _destinationController,
                  hintText: "Contoh: Warung Tekko sebelah barat, Grand Indonesia, dll.",
                  icon: Icons.flag_rounded,
                  lat: _destLat,
                  lng: _destLng,
                  onSelected: (address, lat, lng) {
                    setState(() {
                      _destinationController.text = address;
                      _destLat = lat;
                      _destLng = lng;
                    });
                    _calculateRealRouteDistance();
                  },
                ),
                const SizedBox(height: 16),

                // ROUTE LIVE DISTANCE BADGE (OSRM REAL-TIME)
                _buildRouteLiveBadge(),
                const SizedBox(height: 20),
                
                // WAKTU PENJEMPUTAN
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: AppTheme.primaryPink, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Waktu Penjemputan: ${_dateController.text}, ${_timeController.text}",
                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                
                // DYNAMIC MULTI-LAYANAN (KOTAK-KOTAK LAYANAN TAMBAHAN)
                MultiServiceSection(
                  services: _additionalServices,
                  onServicesChanged: () => setState(() {}),
                  currentPrimaryService: 'antar_jemput',
                  defaultPickup: _pickupController.text,
                  defaultDestination: _destinationController.text,
                ),
                const SizedBox(height: 25),
                
                _buildSectionTitle("Add-ons & Biaya Tambahan"),
                const SizedBox(height: 10),
                _buildAddonsCard(),
                const SizedBox(height: 25),
                
                _buildSectionTitle("Catatan Tambahan"),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _notesController,
                  hint: "Contoh: Bawa jas hujan, pakai helm pink, dll.",
                  icon: Icons.note_add_rounded,
                  maxLines: 2,
                  isRequired: false,
                ),
                const SizedBox(height: 30),
                
                // ESTIMASI BIAYA & SUMMARY
                _buildPricingCard(prices),
                const SizedBox(height: 30),
                
                _buildBookingButton(prices),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSelectedDriverHeader() {
    final rawImage = _selectedDriverImage;
    final image = (rawImage.isNotEmpty)
        ? rawImage
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_selectedDriverName)}&background=D64573&color=fff&bold=true';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.primaryPink.withOpacity(0.2),
            backgroundImage: NetworkImage(image),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "MITRA DRIVER TERPILIH",
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "⭐ ${_selectedDriverRating.toStringAsFixed(1)}",
                      style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedDriverName,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textHighContrast,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "Kendaraan: $_selectedDriverVehicle",
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarHeaderBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.fuchsiaLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.radar_rounded, color: AppTheme.primaryPink, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Radar Auto-Match Mitra",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textHighContrast,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.fuchsiaLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                      ),
                      child: Text(
                        "Otomatis",
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryPink,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Mitra driver terdekat yang stand by akan dipasangkan otomatis.",
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection({
    required String sectionTitle,
    required String mapBadgeTitle,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required double lat,
    required double lng,
    required Function(String address, double lat, double lng) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(sectionTitle),
        const SizedBox(height: 8),

        // 📍 1. KOTAK VISUAL MAPS / SHARELOCK (Bisa Ditekan untuk Buka Peta)
        GestureDetector(
          onTap: () {
            DistanceService.showLocationPickerModal(
              context,
              title: "Pilih $sectionTitle",
              initialValue: controller.text,
              initialLat: lat,
              initialLng: lng,
              onSelected: onSelected,
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPink.withValues(alpha: 0.15),
                  AppTheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPink.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppTheme.primaryPink.withValues(alpha: 0.4), blurRadius: 6),
                    ],
                  ),
                  child: const Icon(Icons.share_location_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            mapBadgeTitle,
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryPink,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPink.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "Tap Peta ➔",
                              style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        controller.text.isNotEmpty 
                            ? controller.text 
                            : "Tap untuk membuka Google Maps & pilih lokasi",
                        style: GoogleFonts.inter(
                          color: controller.text.isNotEmpty ? AppTheme.textHighContrast : AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: controller.text.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryPink, size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 📝 2. KOLOM DETAIL ALAMAT (Otomatis Terisi dari Peta & Bisa Diedit Manual)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardDeep,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "DETAIL / CATATAN ALAMAT",
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(icon, color: AppTheme.primaryPink, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      onChanged: (val) {
                        setState(() {});
                      },
                      style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Alamat $sectionTitle harus diisi';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRouteLiveBadge() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryPink.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: _isCalculatingDistance
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPink),
                  )
                : const Icon(Icons.alt_route_rounded, color: AppTheme.primaryPink, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _isCalculatingDistance
                          ? "Menghitung rute rute..."
                          : "Jarak Rute: ${_actualDistanceKm.toStringAsFixed(1)} KM",
                      style: GoogleFonts.inter(
                        color: AppTheme.textHighContrast,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _routeSource,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF10B981),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Estimasi waktu tempuh: ±$_estimatedDurationMinutes menit (Rute Jalan Raya)",
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: AppTheme.textHighContrast,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppTheme.primaryPink, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: isRequired
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Field ini harus diisi';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildAddonsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: _pulangPergi,
            onChanged: (val) => setState(() => _pulangPergi = val ?? false),
            activeColor: AppTheme.primaryPink,
            checkColor: Colors.white,
            title: Text("Perjalanan Pulang Pergi (PP)", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text("Rute tempuh ganda otomatis (+100% biaya jemput)", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
          ),
          if (_pulangPergi) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
              child: GestureDetector(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 17, minute: 0),
                  );
                  if (time != null) {
                    setState(() {
                      _returnTimeController.text = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} WIB";
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryPink.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: AppTheme.primaryPink, size: 18),
                      const SizedBox(width: 10),
                      // PREVENT RIGHT OVERFLOW: Wrapped in Expanded
                      Expanded(
                        child: Text(
                          _returnTimeController.text.isEmpty
                              ? "Pilih Estimasi Jam Kepulangan (Opsional)"
                              : "Jam Pulang: ${_returnTimeController.text}",
                          style: GoogleFonts.inter(
                            color: _returnTimeController.text.isEmpty ? AppTheme.textMuted : AppTheme.textHighContrast,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const Divider(color: AppTheme.border, height: 10),
          CheckboxListTile(
            value: _useCar,
            onChanged: (val) => setState(() => _useCar = val ?? false),
            activeColor: AppTheme.primaryPink,
            checkColor: Colors.white,
            title: Text("Gunakan Mobil", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text("Mobil eksklusif ber-AC (+Rp 50.000)", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
          ),
          const Divider(color: AppTheme.border, height: 10),
          CheckboxListTile(
            value: _rentHelmet,
            onChanged: (val) => setState(() => _rentHelmet = val ?? false),
            activeColor: AppTheme.primaryPink,
            checkColor: Colors.white,
            title: Text("Sewa Helm Ekstra", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text("Helm ekstra bersih dan steril (+Rp 10.000)", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
          ),
          const Divider(color: AppTheme.border, height: 10),
          CheckboxListTile(
            value: _differentArea,
            onChanged: (val) => setState(() => _differentArea = val ?? false),
            activeColor: AppTheme.primaryPink,
            checkColor: Colors.white,
            title: Text("Beda Area Layanan", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text("Biaya tambahan penugasan beda wilayah (+Rp 20.000)", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(Map<String, dynamic> prices) {
    String fmt(int val) {
      return "Rp ${val.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Estimasi Biaya", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 16)),
              if (_isWeekendApplied)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text("Weekend +25%", style: TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const Divider(color: AppTheme.border, height: 20),
          _priceRow("Antar Jemput (${_actualDistanceKm.toStringAsFixed(1)} km)", fmt(prices['service1Fee'])),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppTheme.primaryPink, size: 13),
                const SizedBox(width: 5),
                Text(
                  "Tarif Resmi: ${fmt(_selectedDriverPrice)}/Km • Ditetapkan Admin (Harga Pas)",
                  style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          
          // Render each additional service item dynamically
          ..._additionalServices.map((service) {
            return _priceRow(
              "Layanan Ekstra: ${service.displayName}",
              fmt(service.calculateFee()),
            );
          }),

          if (_useCar) _priceRow("Add-on Mobil Ber-AC", fmt(50000)),
          if (_rentHelmet) _priceRow("Sewa Helm Ekstra", fmt(10000)),
          if (_differentArea) _priceRow("Beda Area Layanan", fmt(20000)),
          if (_isWeekendApplied) _priceRow("Weekend Fee (25%)", fmt(prices['weekendFee'])),
          const Divider(color: AppTheme.border, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Estimasi", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.w600, fontSize: 14)),
              Text(fmt(prices['totalEstimasi']), style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("DP Wajib (50%)", style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(fmt(prices['dp']), style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.cardDeep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Harga pas diatur resmi oleh Admin. Transaksi bebas tawar-menawar (Non-Nego) demi kenyamanan bersama.",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label, 
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBookingButton(Map<String, dynamic> prices) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.primaryPink,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            final double distance = _actualDistanceKm > 0 ? _actualDistanceKm : 5.0;
            final isPreselected = widget.selectedPartner != null;

            final bookingData = {
              'serviceType': 'antar_jemput',
              'is_flexible': false,
              'isFlexible': false,
              'price_per_km': _selectedDriverPrice,
              'isOpenOffer': !isPreselected,
              'driverId': isPreselected ? _selectedDriverId : null,
              'driverName': isPreselected ? _selectedDriverName : "Mitra Radar Otomatis",
              'driverImage': isPreselected ? _selectedDriverImage : "",
              'driverRating': isPreselected ? _selectedDriverRating.toString() : "5.0",
              'driverTrips': isPreselected ? _selectedDriverTrips.toString() : "150",
              'vehicle': isPreselected ? _selectedDriverVehicle : (_useCar ? "Mobil Mitra" : "Motor Mitra"),
              'plateNumber': isPreselected 
                  ? 'B 1234 ${_selectedDriverName.length >= 2 ? _selectedDriverName.substring(0, 2).toUpperCase() : "JKT"}'
                  : 'B 9999 RDR',
              'pickup': _pickupController.text,
              'destination': _destinationController.text,
              'pickup_latitude': _pickupLat,
              'pickup_longitude': _pickupLng,
              'dropoff_latitude': _destLat,
              'dropoff_longitude': _destLng,
              'actual_distance_km': distance,
              'date': _dateController.text,
              'time': _timeController.text,
              
              // Pricing Details
              'serviceFee': prices['service1Fee'],
              'insuranceFee': 10000,
              'totalPayment': prices['totalEstimasi'] + 10000,
              'dp': prices['dp'] + 5000, // DP includes 50% insurance
              'remainingPayment': prices['remaining'] + 5000,
              'estimatedTime': _estimatedDurationMinutes.toString(),
              
              // Dynamic Multi service details
              'hasAdditionalService': _additionalServices.isNotEmpty,
              'additionalServices': _additionalServices.map((s) => s.toMap()).toList(),
              'additionalServiceFee': prices['additionalServicesFee'],
              
              // Addons
              'pulangPergi': _pulangPergi,
              'useCar': _useCar,
              'rentHelmet': _rentHelmet,
              'differentArea': _differentArea,
              'weekendFee': prices['weekendFee'],
              'notes': _notesController.text,
              'driverClass': _selectedDriverClass,
            };

            // Map individual service types for backward compatibility
            for (var s in _additionalServices) {
              if (s.serviceType == 'hangout') {
                bookingData['hasHangout'] = true;
                bookingData['serviceHangoutFee'] = s.calculateFee();
                bookingData['additionalActivity'] = s.hangoutActivity;
                bookingData['additionalDuration'] = s.hangoutDurationHours.toString();
                bookingData['additionalHangoutLocation'] = s.hangoutLocationController.text;
                bookingData['additionalHangoutNotes'] = s.hangoutNotesController.text;
              } else if (s.serviceType == 'freedom') {
                bookingData['hasFreedom'] = true;
                bookingData['serviceFreedomFee'] = s.calculateFee();
                bookingData['additionalDescription'] = s.freedomDescriptionController.text;
                bookingData['additionalLocation'] = s.freedomLocationController.text;
              }
            }
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookingConfirmationScreen(bookingData: bookingData),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          "Booking Sekarang ➔",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}