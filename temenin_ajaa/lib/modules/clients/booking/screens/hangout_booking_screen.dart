import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/providers/driver_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/providers/auth_provider.dart';
import 'package:temenin_ajaa/core/services/distance_service.dart';
import 'package:temenin_ajaa/core/services/location_service.dart';
import 'booking_confirmation_screen.dart';
import 'tracking_driver_screen.dart';
import 'freedom_request_negotiation_screen.dart' as temenin_ajaa_negotiation;
import '../widgets/multi_service_section.dart';

class HangoutBookingScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedPartner;
  final String serviceType;
  final String? initialDestination;
  final String? initialActivity;
  
  const HangoutBookingScreen({
    super.key, 
    this.selectedPartner,
    this.serviceType = 'hangout',
    this.initialDestination,
    this.initialActivity,
  });

  @override
  State<HangoutBookingScreen> createState() => _HangoutBookingScreenState();
}

class _HangoutBookingScreenState extends State<HangoutBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  late final TextEditingController _destinationController;
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();
  final _customActivityController = TextEditingController();

  // Mode Transport Penjemputan:
  // 'none'  : Ketemuan di Lokasi (Gratis - Rp 0)
  // 'oneway': Dijemput Companion Sekali Jalan (Tarif Ride Per-KM)
  // 'round' : Dijemput & Diantar Pulang (PP Paket Hemat)
  String _transportMode = 'none';

  // Mode Waktu Pesanan: 'now' (Pesan Sekarang OTW) vs 'scheduled' (Booking Jadwal)
  String _orderTimingMode = 'now';

  // Activity & Duration
  String _selectedActivity = 'Makan';
  int _selectedDuration = 3; // 3, 4, 6, 8 Jam
  final Map<int, int> _durationPrices = {
    3: 150000,
    4: 200000,
    6: 300000,
    8: 400000,
  };

  // Real Distance & Coordinates for transport add-on (in km)
  double _pickupLat = -6.2272; // Senayan City
  double _pickupLng = 106.7972;
  double _destLat = -6.1952; // Grand Indonesia
  double _destLng = 106.8208;
  double _estimatedDistanceKm = 6.8;
  int _estimatedDurationMinutes = 18;
  bool _isCalculatingDistance = false;
  String _routeSource = 'OpenStreetMap';

  // Driver-Provided Add-ons List & Selection State
  List<Map<String, dynamic>> _driverAddonsList = [];
  final Set<String> _selectedAddonIds = {};
  bool _isWeekendApplied = false;

  // Dynamic Multi-Layanan List
  final List<AdditionalServiceItem> _additionalServices = [];

  final List<String> _activitiesList = [
    'Ngopi', 'Makan', 'Nonton', 'Jalan-jalan', 'Shopping', 'Event', 'Kondangan', 'City Tour', 'Dinner', 'Lainnya'
  ];

  @override
  void initState() {
    super.initState();
    _destinationController = TextEditingController(
      text: widget.initialDestination ?? '',
    );
    if (widget.initialActivity != null && widget.initialActivity!.isNotEmpty) {
      _selectedActivity = widget.initialActivity!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DriverProvider>(context, listen: false).fetchDrivers();
    });

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
      _timeController.text = "14:00 WIB";
    }

    if (widget.selectedPartner != null && widget.selectedPartner!['bookingMode'] != null) {
      _orderTimingMode = widget.selectedPartner!['bookingMode'].toString();
    }

    _checkWeekend(now);
    _loadDriverAddons();

    if (widget.serviceType == 'counseling' || widget.serviceType == 'counseling_offline') {
      _selectedActivity = 'Relationship Counseling';
      _selectedDuration = 3;
    } else if (widget.serviceType == 'curhat') {
      _selectedActivity = 'Mendengarkan Curhat';
      _selectedDuration = 3;
    } else if (widget.serviceType == 'sporty') {
      _selectedActivity = 'Teman Olahraga (Sport Buddy)';
      _selectedDuration = 3;
    } else if (widget.serviceType == 'hiking') {
      _selectedActivity = 'Hiking Partner';
      _selectedDuration = 6;
    }

    _calculateRealHangoutDistance();

    // Otomatis deteksi GPS real perangkat pengguna untuk spot penjemputan awal
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null && mounted) {
        setState(() {
          _pickupLat = pos.latitude;
          _pickupLng = pos.longitude;
        });
        if (_destinationController.text.isEmpty) {
          final geo = await DistanceService.reverseGeocode(pos.latitude, pos.longitude);
          if (mounted && _destinationController.text.isEmpty) {
            setState(() {
              _destinationController.text = geo['fullAddress'] ?? geo['title'] ?? '';
              _pickupController.text = _destinationController.text;
              _destLat = pos.latitude;
              _destLng = pos.longitude;
            });
          }
        }
        _calculateRealHangoutDistance();
      }
    });
  }

  Future<void> _calculateRealHangoutDistance() async {
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
        _estimatedDistanceKm = (result['distanceKm'] as num?)?.toDouble() ?? 6.8;
        _estimatedDurationMinutes = (result['durationMinutes'] as num?)?.toInt() ?? 18;
        _routeSource = result['source']?.toString() ?? 'OpenStreetMap';
        _isCalculatingDistance = false;
      });
    }
  }

  void _loadDriverAddons() async {
    List<Map<String, dynamic>> loadedAddons = [];

    // 1. Try to load from widget.selectedPartner['addons']
    if (widget.selectedPartner != null && widget.selectedPartner!['addons'] != null) {
      final raw = widget.selectedPartner!['addons'];
      if (raw is List && raw.isNotEmpty) {
        loadedAddons = List<Map<String, dynamic>>.from(
          raw.map((a) => Map<String, dynamic>.from(a as Map)),
        );
      }
    }

    // 2. Try to parse from vehicle_stnk if available
    if (loadedAddons.isEmpty && widget.selectedPartner != null && widget.selectedPartner!['vehicle_stnk'] != null) {
      final String vStnk = widget.selectedPartner!['vehicle_stnk'].toString();
      if (vStnk.startsWith('{')) {
        try {
          final meta = jsonDecode(vStnk);
          if (meta['addons'] != null && meta['addons'] is List) {
            loadedAddons = List<Map<String, dynamic>>.from(
              (meta['addons'] as List).map((a) => Map<String, dynamic>.from(a as Map)),
            );
          }
        } catch (_) {}
      }
    }

    // 3. If driver ID is available, attempt fresh fetch from Supabase
    final driverId = widget.selectedPartner?['id'] ?? widget.selectedPartner?['driverId'];
    if (loadedAddons.isEmpty && driverId != null) {
      try {
        final res = await Supabase.instance.client
            .from('drivers')
            .select('vehicle_stnk')
            .or('id.eq.$driverId,user_id.eq.$driverId')
            .maybeSingle();

        if (res != null && res['vehicle_stnk'] != null) {
          final String vStnk = res['vehicle_stnk'].toString();
          if (vStnk.startsWith('{')) {
            final meta = jsonDecode(vStnk);
            if (meta['addons'] != null && meta['addons'] is List) {
              loadedAddons = List<Map<String, dynamic>>.from(
                (meta['addons'] as List).map((a) => Map<String, dynamic>.from(a as Map)),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching driver addons: $e');
      }
    }

    final activeAddons = loadedAddons.where((a) => a['is_active'] != false).toList();

    if (mounted) {
      setState(() {
        _driverAddonsList = activeAddons;
      });
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    _customActivityController.dispose();
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
    int hangoutBaseCost = _durationPrices[_selectedDuration] ?? 150000;
    
    int transportFee = 0;
    if (_transportMode == 'oneway') {
      transportFee = (15000 + (_estimatedDistanceKm * 4000)).round();
      if (transportFee < 35000) transportFee = 35000;
    } else if (_transportMode == 'round') {
      int single = (15000 + (_estimatedDistanceKm * 4000)).round();
      if (single < 35000) single = 35000;
      transportFee = (single * 1.8).round();
    }

    int driverAddonsFee = 0;
    List<Map<String, dynamic>> selectedAddonsList = [];
    for (final addon in _driverAddonsList) {
      final aId = addon['id']?.toString() ?? '';
      if (_selectedAddonIds.contains(aId)) {
        final p = (addon['price'] is int)
            ? addon['price'] as int
            : (int.tryParse(addon['price']?.toString() ?? '0') ?? 0);
        driverAddonsFee += p;
        selectedAddonsList.add({
          'id': aId,
          'title': addon['title'] ?? 'Add-on',
          'price': p,
          'category': addon['category'] ?? 'Layanan',
        });
      }
    }

    int weekendFee = _isWeekendApplied ? 20000 : 0;

    int additionalServicesFee = _additionalServices.fold<int>(
      0, 
      (sum, item) => sum + item.calculateFee(),
    );

    int totalEstimasi = hangoutBaseCost + transportFee + driverAddonsFee + weekendFee + additionalServicesFee;
    int dp = (totalEstimasi * 0.3).toInt();
    int remainingPayment = totalEstimasi - dp;

    return {
      'hangoutBaseCost': hangoutBaseCost,
      'transportFee': transportFee,
      'driverAddonsFee': driverAddonsFee,
      'selectedAddonsList': selectedAddonsList,
      'weekendFee': weekendFee,
      'additionalServicesFee': additionalServicesFee,
      'totalEstimasi': totalEstimasi,
      'dp': dp,
      'remaining': remainingPayment,
    };
  }

  String _getAppBarTitle() {
    switch (widget.serviceType) {
      case 'counseling':
      case 'counseling_offline':
        return "Relationship Counseling";
      case 'curhat': return "Mendengarkan Curhat";
      case 'sporty': return "Sport Buddy";
      case 'hiking': return "Hiking Partner";
      case 'assistant': return "Personal Assistant";
      case 'detektif':
      case 'detective': return "Detektif Relationship";
      default: return "Booking Hangout Partner";
    }
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
            _getAppBarTitle(),
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textHighContrast,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textHighContrast, size: 20),
            onPressed: () => _handleBack(context),
          ),
        ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // STEP 1: DRIVER & PESANAN HEADER CARD
                _buildSectionStepTitle("1", "MITRA & WAKTU PESANAN"),
                const SizedBox(height: 10),
                widget.selectedPartner != null
                    ? _buildSelectedDriverHeaderWithTiming()
                    : _buildRadarHeaderBadgeWithTiming(),
                const SizedBox(height: 24),

                // STEP 2: OPSI PENJEMPUTAN & LOKASI
                _buildSectionStepTitle("2", "OPSI PENJEMPUTAN & LOKASI"),
                const SizedBox(height: 10),
                _buildDynamicTransportSubForm(prices),
                const SizedBox(height: 14),
                _buildMapsPreviewCard(),
                const SizedBox(height: 24),

                // STEP 3: AKTIVITAS & DURASI HANGOUT
                _buildSectionStepTitle("3", "AKTIVITAS & DURASI HANGOUT"),
                const SizedBox(height: 10),
                _buildActivitySelector(),
                if (_selectedActivity == 'Lainnya') ...[
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _customActivityController,
                    hint: "Ketik jenis aktivitas kustom...",
                    icon: Icons.edit_note_rounded,
                  ),
                ],
                const SizedBox(height: 14),
                _buildDurationGrid(),
                const SizedBox(height: 24),

                // STEP 4: ADD-ONS & FASILITAS MITRA
                _buildSectionStepTitle("4", "ADD-ONS & FASILITAS MITRA"),
                const SizedBox(height: 10),
                _buildDriverAddonsSection(prices),
                const SizedBox(height: 24),

                // STEP 5: MULTI-LAYANAN TAMBAHAN
                _buildSectionStepTitle("5", "MULTI-LAYANAN TAMBAHAN (GABUNG LAYANAN LAIN)"),
                const SizedBox(height: 10),
                _buildMultiServiceSection(),
                const SizedBox(height: 24),

                if (_isWeekendApplied) ...[
                  _buildWeekendNoticeBanner(),
                  const SizedBox(height: 24),
                ],

                // STEP 6: CATATAN KHUSUS COMPANION
                _buildSectionStepTitle("6", "CATATAN KHUSUS COMPANION"),
                const SizedBox(height: 10),
                _buildManualNotesSection(),
                const SizedBox(height: 24),

                // STEP 7: RINCIAN BIAYA & PEMBAYARAN
                _buildSectionStepTitle("7", "RINCIAN BIAYA & PEMBAYARAN"),
                const SizedBox(height: 10),
                _buildBillSummaryCard(prices),
                const SizedBox(height: 28),

                // SUBMIT BUTTON
                _buildBookingSubmitButton(prices),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSectionStepTitle(String number, String title) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppTheme.primaryPink,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDriverHeaderWithTiming() {
    final name = widget.selectedPartner?['name'] ?? 'Driver Partner';
    final vehicle = widget.selectedPartner?['vehicle'] ?? 'Kendaraan Driver';
    final rating = widget.selectedPartner?['rating']?.toString() ?? '5.0';
    final rawImage = widget.selectedPartner?['image'] ?? widget.selectedPartner?['avatar'];
    final image = (rawImage != null && rawImage.toString().isNotEmpty)
        ? rawImage.toString()
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=D64573&color=fff&bold=true';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryPink.withValues(alpha: 0.15),
                backgroundImage: NetworkImage(image),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPink,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "MITRA COMPANION",
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Rating $rating",
                          style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textHighContrast,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Kendaraan: $vehicle",
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 10),
          _buildCompactTimingBar(),
        ],
      ),
    );
  }

  Widget _buildRadarHeaderBadgeWithTiming() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pencarian Otomatis Radar Companion",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textHighContrast,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Mitra terdekat akan dipasangkan otomatis",
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.fuchsiaLight,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.3)),
                ),
                child: Text(
                  "Auto Match",
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryPink,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 10),
          _buildCompactTimingBar(),
        ],
      ),
    );
  }

  Widget _buildCompactTimingBar() {
    final isNow = _orderTimingMode == 'now';
    return InkWell(
      onTap: _showTimingModeBottomSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isNow ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.fuchsiaLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isNow ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.primaryPink.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isNow
                    ? "Pesanan Langsung (Driver OTW ~15-30 mnt)"
                    : "Jadwal: ${_dateController.text}, ${_timeController.text}",
                style: GoogleFonts.inter(
                  color: isNow ? AppTheme.success : AppTheme.primaryPink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                "Ubah",
                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTimingModeBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Pilih Waktu Pesanan",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textHighContrast,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textMuted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() => _orderTimingMode = 'now');
                            setState(() {
                              _orderTimingMode = 'now';
                              _timeController.text = "Langsung OTW";
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _orderTimingMode == 'now' ? AppTheme.primaryPink : AppTheme.cardDeep,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Center(
                              child: Text(
                                "Pesan Sekarang",
                                style: GoogleFonts.inter(
                                  color: _orderTimingMode == 'now' ? Colors.white : AppTheme.textHighContrast,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() => _orderTimingMode = 'scheduled');
                            setState(() => _orderTimingMode = 'scheduled');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _orderTimingMode == 'scheduled' ? AppTheme.primaryPink : AppTheme.cardDeep,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Center(
                              child: Text(
                                "Booking Jadwal",
                                style: GoogleFonts.inter(
                                  color: _orderTimingMode == 'scheduled' ? Colors.white : AppTheme.textHighContrast,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_orderTimingMode == 'scheduled') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                _checkWeekend(date);
                                final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
                                final str = "${date.day} ${months[date.month - 1]} ${date.year}";
                                setModalState(() => _dateController.text = str);
                                setState(() => _dateController.text = str);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.cardDeep,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Text(_dateController.text, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: const TimeOfDay(hour: 14, minute: 0),
                              );
                              if (time != null) {
                                final hour = time.hour.toString().padLeft(2, '0');
                                final minute = time.minute.toString().padLeft(2, '0');
                                final str = "$hour:$minute WIB";
                                setModalState(() => _timeController.text = str);
                                setState(() => _timeController.text = str);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.cardDeep,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Text(_timeController.text, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text("Simpan Waktu", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDynamicTransportSubForm(Map<String, dynamic> prices) {
    String fmt(int val) {
      return "Rp ${val.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "PILIH TIPE PENJEMPUTAN",
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Option 1: Ketemuan di Lokasi (Gratis)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _transportMode = 'none';
                      _pickupController.text = _destinationController.text;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: _transportMode == 'none' ? AppTheme.fuchsiaLight : AppTheme.cardDeep,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _transportMode == 'none' ? AppTheme.primaryPink : AppTheme.border,
                        width: _transportMode == 'none' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Ketemuan di Tempat",
                          style: GoogleFonts.inter(
                            color: _transportMode == 'none' ? AppTheme.primaryPink : AppTheme.textHighContrast,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Gratis (Rp 0)",
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Option 2: Dijemput Sekali Jalan
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _transportMode = 'oneway'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: _transportMode == 'oneway' ? AppTheme.fuchsiaLight : AppTheme.cardDeep,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _transportMode == 'oneway' ? AppTheme.primaryPink : AppTheme.border,
                        width: _transportMode == 'oneway' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Dijemput Sekali",
                          style: GoogleFonts.inter(
                            color: _transportMode == 'oneway' ? AppTheme.primaryPink : AppTheme.textHighContrast,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Tarif Per-KM",
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Option 3: Dijemput & Diantar Pulang (PP)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _transportMode = 'round'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: _transportMode == 'round' ? AppTheme.fuchsiaLight : AppTheme.cardDeep,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _transportMode == 'round' ? AppTheme.primaryPink : AppTheme.border,
                        width: _transportMode == 'round' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Dijemput & Pulang (PP)",
                          style: GoogleFonts.inter(
                            color: _transportMode == 'round' ? AppTheme.primaryPink : AppTheme.textHighContrast,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Paket Hemat PP",
                          style: GoogleFonts.inter(color: AppTheme.success, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_transportMode == 'none') ...[
            // 📍 1. KOTAK VISUAL MAPS / SHARELOCK (Bisa Ditekan untuk Buka Peta)
            GestureDetector(
              onTap: () {
                DistanceService.showLocationPickerModal(
                  context,
                  title: "Pilih Spot Janjian Hangout",
                  initialValue: _destinationController.text,
                  initialLat: _destLat,
                  initialLng: _destLng,
                  onSelected: (addr, lat, lng) {
                    setState(() {
                      _destinationController.text = addr;
                      _pickupController.text = addr;
                      _destLat = lat;
                      _destLng = lng;
                    });
                  },
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
                      child: const Icon(Icons.share_location_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                                Text(
                                "PILIH DI PETA MAPBOX",
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
                            _destinationController.text.isNotEmpty 
                                ? _destinationController.text 
                                : "Tap untuk membuka Peta Mapbox & pilih lokasi janjian",
                            style: GoogleFonts.inter(
                              color: _destinationController.text.isNotEmpty ? AppTheme.textHighContrast : AppTheme.textMuted,
                              fontSize: 12,
                              fontWeight: _destinationController.text.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
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
            const SizedBox(height: 12),

            // 📝 2. KOLOM SPOT JANJIAN (Otomatis Terisi dari Peta & Bisa Diedit)
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
                    "SPOT JANJIAN HANGOUT",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppTheme.primaryPink, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _destinationController,
                          onChanged: (val) {
                            _pickupController.text = val;
                          },
                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: "Contoh: Warung Tekko sebelah barat, Grand Indonesia, dll.",
                            hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Client dan companion langsung bertemu di lokasi janjian tanpa penjemputan.",
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
            ),
          ] else ...[
            // 📍 1. KOTAK JEMPUT MAPBOX (Clickable)
            GestureDetector(
              onTap: () {
                DistanceService.showLocationPickerModal(
                  context,
                  title: "Pilih Titik Jemput",
                  initialValue: _pickupController.text,
                  initialLat: _pickupLat,
                  initialLng: _pickupLng,
                  onSelected: (addr, lat, lng) {
                    setState(() {
                      _pickupController.text = addr;
                      _pickupLat = lat;
                      _pickupLng = lng;
                    });
                    _calculateRealHangoutDistance();
                  },
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardDeep,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_location_rounded, color: AppTheme.primaryPink, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TITIK PENJEMPUTAN DI PETA MAPBOX",
                            style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 9.5, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pickupController.text.isNotEmpty ? _pickupController.text : "Tap untuk pilih titik jemput di peta",
                            style: GoogleFonts.inter(color: _pickupController.text.isNotEmpty ? AppTheme.textHighContrast : AppTheme.textMuted, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryPink, size: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 📝 INPUT ALAMAT PENJEMPUTAN
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardDeep,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ALAMAT PENJEMPUTAN DETAIL", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _pickupController,
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "Contoh: Apartemen / Rumah / Kantor...",
                      hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 📍 2. KOTAK TUJUAN MAPBOX (Clickable)
            GestureDetector(
              onTap: () {
                DistanceService.showLocationPickerModal(
                  context,
                  title: "Pilih Spot Tujuan Hangout",
                  initialValue: _destinationController.text,
                  initialLat: _destLat,
                  initialLng: _destLng,
                  onSelected: (addr, lat, lng) {
                    setState(() {
                      _destinationController.text = addr;
                      _destLat = lat;
                      _destLng = lng;
                    });
                    _calculateRealHangoutDistance();
                  },
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardDeep,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_location_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SPOT TUJUAN HANGOUT DI PETA MAPBOX",
                            style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _destinationController.text.isNotEmpty ? _destinationController.text : "Tap untuk pilih spot tujuan di peta",
                            style: GoogleFonts.inter(color: _destinationController.text.isNotEmpty ? AppTheme.textHighContrast : AppTheme.textMuted, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF10B981), size: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 📝 INPUT ALAMAT TUJUAN DETAIL
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardDeep,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("SPOT TUJUAN DETAIL", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _destinationController,
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "Contoh: Warung Tekko sebelah barat, Grand Indonesia, dll.",
                      hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 🛣️ JARAK & BIAYA TRANSPORT
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.fuchsiaLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _isCalculatingDistance
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPink),
                            )
                          : const Icon(Icons.route_rounded, color: AppTheme.primaryPink, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "Jarak Riil: ${_estimatedDistanceKm.toStringAsFixed(1)} km",
                        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _routeSource,
                          style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "+${fmt(prices['transportFee'])}",
                    style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getAddonIcon(String? iconName, String? category) {
    if (iconName != null) {
      switch (iconName) {
        case 'camera_alt': return Icons.camera_alt_rounded;
        case 'directions_car': return Icons.directions_car_rounded;
        case 'checkroom': return Icons.checkroom_rounded;
        case 'fastfood': return Icons.fastfood_rounded;
        case 'sports_tennis': return Icons.sports_tennis_rounded;
        case 'tour': return Icons.tour_rounded;
        case 'luggage': return Icons.luggage_rounded;
        case 'music_note': return Icons.music_note_rounded;
        case 'spa': return Icons.spa_rounded;
        case 'star': return Icons.star_rounded;
      }
    }
    switch (category) {
      case 'Dokumentasi': return Icons.camera_alt_rounded;
      case 'Kendaraan': return Icons.directions_car_rounded;
      case 'Penampilan': return Icons.checkroom_rounded;
      case 'Kuliner': return Icons.fastfood_rounded;
      case 'Aktivitas': return Icons.sports_tennis_rounded;
      case 'Panduan': return Icons.tour_rounded;
      default: return Icons.stars_rounded;
    }
  }

  Widget _buildDriverAddonsSection(Map<String, dynamic> prices) {
    String fmt(int val) {
      return "Rp ${val.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }

    if (_driverAddonsList.isEmpty) {
      return Container(
        width: double.infinity,
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
                color: AppTheme.cardDeep,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.info_outline_rounded, color: AppTheme.textMuted, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tidak Ada Add-on Mitra",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textHighContrast,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Mitra ini belum menambahkan fasilitas atau add-on ekstra mandiri.",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(
                "PILIHAN FASILITAS & ADD-ON MITRA",
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.fuchsiaLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${_driverAddonsList.length} Opsi Tersedia",
                  style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _driverAddonsList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final addon = _driverAddonsList[index];
              final addonId = addon['id']?.toString() ?? 'addon_$index';
              final isSelected = _selectedAddonIds.contains(addonId);
              final title = addon['title'] ?? addon['name'] ?? 'Add-on';
              final description = addon['description'] ?? '';
              final category = addon['category'] ?? 'Layanan';
              final price = (addon['price'] is int)
                  ? addon['price'] as int
                  : (int.tryParse(addon['price']?.toString() ?? '0') ?? 0);
              final iconName = addon['icon']?.toString();

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedAddonIds.remove(addonId);
                    } else {
                      _selectedAddonIds.add(addonId);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.fuchsiaLight : AppTheme.cardDeep,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryPink : AppTheme.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryPink.withValues(alpha: 0.2)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getAddonIcon(iconName, category),
                          color: isSelected ? AppTheme.primaryPink : AppTheme.textMuted,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPink.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    category.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      color: AppTheme.primaryPink,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textHighContrast,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                description,
                                style: GoogleFonts.inter(
                                  color: AppTheme.textMuted,
                                  fontSize: 10.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              "+${fmt(price)}",
                              style: GoogleFonts.inter(
                                color: AppTheme.primaryPink,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedAddonIds.add(addonId);
                            } else {
                              _selectedAddonIds.remove(addonId);
                            }
                          });
                        },
                        activeColor: AppTheme.primaryPink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMultiServiceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "GABUNG DENGAN LAYANAN LAINNYA",
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Anda bisa menggabungkan pesanan Hangout ini dengan layanan Temenin Ajaa lainnya sekaligus.",
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          MultiServiceSection(
            services: _additionalServices,
            onServicesChanged: () => setState(() {}),
            currentPrimaryService: 'hangout',
            defaultPickup: _pickupController.text,
            defaultDestination: _destinationController.text,
          ),
        ],
      ),
    );
  }

  Widget _buildMapsPreviewCard() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1524661135-423995f22d0b?auto=format&fit=crop&w=600&q=80'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Sharelock Pin Spot Hangout Terhubung",
                style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Text("$_estimatedDistanceKm km", style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 11)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Text("•", style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  Text("15 mnt", style: GoogleFonts.inter(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 11)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Text("•", style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  Text("Rute Hangout Active", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySelector() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _activitiesList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final act = _activitiesList[index];
          final isSelected = _selectedActivity == act;
          return GestureDetector(
            onTap: () => setState(() => _selectedActivity = act),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryPink : AppTheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryPink : AppTheme.border,
                ),
              ),
              child: Center(
                child: Text(
                  act,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : AppTheme.textHighContrast,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDurationGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.8,
      children: _durationPrices.entries.map((entry) {
        final dur = entry.key;
        final price = entry.value;
        final isSelected = _selectedDuration == dur;

        return GestureDetector(
          onTap: () => setState(() => _selectedDuration = dur),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.fuchsiaLight : AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.primaryPink : AppTheme.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("$dur Jam", style: GoogleFonts.inter(color: isSelected ? AppTheme.primaryPink : AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (isSelected) const Icon(Icons.check_circle, color: AppTheme.primaryPink, size: 14),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                  style: GoogleFonts.inter(color: isSelected ? AppTheme.primaryPink : AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildManualNotesSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextFormField(
        controller: _notesController,
        maxLines: 3,
        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
        decoration: InputDecoration(
          hintText: "Tuliskan instruksi penjemputan, dresscode companion, atau catatan khusus di sini...",
          hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildWeekendNoticeBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Weekend Surcharge", style: GoogleFonts.inter(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                Text("Pemesanan di Hari Sabtu/Minggu", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text("+Rp 20.000", style: GoogleFonts.inter(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
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
        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
          prefixIcon: Icon(icon, color: AppTheme.primaryPink, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildBillSummaryCard(Map<String, dynamic> prices) {
    String fmt(int val) {
      return "Rp ${val.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }

    String transportLabel = "Transport: Ketemuan di Lokasi";
    if (_transportMode == 'oneway') {
      transportLabel = "Transport Penjemputan (Sekali Jalan)";
    } else if (_transportMode == 'round') {
      transportLabel = "Transport Penjemputan (Pulang Pergi PP)";
    }

    final selectedAddonsList = (prices['selectedAddonsList'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "RINCIAN BIAYA",
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          const Divider(color: AppTheme.border, height: 20),

          _priceRow("Paket Hangout Platinum ($_selectedDuration Jam)", fmt(prices['hangoutBaseCost'])),
          _priceRow(transportLabel, fmt(prices['transportFee'])),

          // Selected Driver Addons
          ...selectedAddonsList.map((addon) {
            final addonName = addon['title'] ?? addon['name'] ?? 'Add-on Mitra';
            final addonPrice = (addon['price'] as num?)?.toInt() ?? 0;
            return _priceRow("Add-on: $addonName", fmt(addonPrice));
          }),

          if (_isWeekendApplied) _priceRow("Weekend Surcharge Fee", fmt(20000)),

          ..._additionalServices.map((service) {
            return _priceRow(
              "Layanan Ekstra: ${service.displayName}",
              fmt(service.calculateFee()),
            );
          }),

          const Divider(color: AppTheme.border, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Transaksi", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(fmt(prices['totalEstimasi']), style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.fuchsiaLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("DP 30% WAJIB SISTEM:", style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(fmt(prices['dp']), style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.3)),
                  ),
                  child: Text("Pelunasan 70% H-1", style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold)),
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

  Widget _buildBookingSubmitButton(Map<String, dynamic> prices) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.primaryPink,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            final bookingData = {
              'serviceType': widget.serviceType,
              'activity': _selectedActivity == 'Lainnya' ? _customActivityController.text : _selectedActivity,
              'duration': _selectedDuration,
              'pickup': _pickupController.text,
              'destination': _destinationController.text,
              'pickup_latitude': _pickupLat,
              'pickup_longitude': _pickupLng,
              'dropoff_latitude': _destLat,
              'dropoff_longitude': _destLng,
              'actual_distance_km': _estimatedDistanceKm,
              'estimatedTime': _estimatedDurationMinutes.toString(),
              'transportMode': _transportMode,
              'date': _dateController.text,
              'time': _timeController.text,
              'isWeekendApplied': _isWeekendApplied,
              'notes': _notesController.text,

              'selectedAddons': prices['selectedAddonsList'],
              'driverAddonsFee': prices['driverAddonsFee'],

              'hasAdditionalService': _additionalServices.isNotEmpty,
              'additionalServices': _additionalServices.map((s) => s.toMap()).toList(),
              'additionalServiceFee': prices['additionalServicesFee'],

              'baseCost': prices['hangoutBaseCost'],
              'transportFee': prices['transportFee'],
              'totalPayment': prices['totalEstimasi'],
              'dp': prices['dp'],
              'remainingPayment': prices['remaining'],
            };

            for (var s in _additionalServices) {
              if (s.serviceType == 'antar_jemput') {
                bookingData['hasAntarJemput'] = true;
                bookingData['serviceAntarJemputFee'] = s.calculateFee();
                bookingData['additionalPickup'] = s.pickupController.text;
                bookingData['additionalDestination'] = s.destinationController.text;
              } else if (s.serviceType == 'freedom') {
                bookingData['hasFreedom'] = true;
                bookingData['serviceFreedomFee'] = s.calculateFee();
                bookingData['additionalDescription'] = s.freedomDescriptionController.text;
              }
            }

            if (widget.selectedPartner != null) {
              bookingData.addAll({
                'driverName': widget.selectedPartner!['name'],
                'driverImage': widget.selectedPartner!['image'] ?? widget.selectedPartner!['avatar'] ?? '',
                'driverRating': widget.selectedPartner!['rating'].toString(),
                'driverTrips': widget.selectedPartner!['trips']?.toString() ?? "120",
                'driverClass': widget.selectedPartner!['type'] ?? 'Gold',
                'vehicle': widget.selectedPartner!['vehicle'] ?? 'Kendaraan Pribadi',
                'plateNumber': widget.selectedPartner!['plateNumber'] ?? 'B 1234 XYZ',
                'serviceFee': prices['hangoutBaseCost'],
                'userInitialPrice': prices['hangoutBaseCost'],
              });

              if (widget.serviceType == 'freedom') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => temenin_ajaa_negotiation.FreedomRequestNegotiationScreen(
                      bookingData: bookingData,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingConfirmationScreen(
                      bookingData: bookingData,
                    ),
                  ),
                );
              }
            } else {
              () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryPink)),
                );

                String? bookingId;
                try {
                  final currentUser = Supabase.instance.client.auth.currentUser;
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final userId = currentUser?.id ?? (auth.user != null ? (auth.user as dynamic).id?.toString() : null);

                  final insertPayload = {
                    'user_id': userId,
                    'service_type': widget.serviceType,
                    'status': 'searching',
                    'pickup_location': _pickupController.text,
                    'destination_location': _destinationController.text,
                    'price': prices['totalEstimasi'],
                    'notes': _notesController.text,
                    'booking_date': DateTime.now().toIso8601String(),
                  };

                  final response = await Supabase.instance.client
                      .from('bookings')
                      .insert(insertPayload)
                      .select('id')
                      .maybeSingle();

                  if (response != null && response['id'] != null) {
                    bookingId = response['id'].toString();
                  }
                } catch (e) {
                  debugPrint("Error creating auto-match booking: $e");
                }

                if (!context.mounted) return;
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrackingDriverScreen(
                      bookingData: bookingData,
                      bookingId: bookingId,
                    ),
                  ),
                );
              }();
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          "Lanjutkan Booking • Bayar DP Rp ${prices['dp'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}