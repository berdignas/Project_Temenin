// lib/modules/clients/booking/screens/freedom_request_booking_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'freedom_request_negotiation_screen.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/core/services/distance_service.dart';
import '../widgets/multi_service_section.dart';

class DetectiveTargetSpot {
  final TextEditingController addressController;
  final TextEditingController noteController;
  double lat;
  double lng;
  String spotName;

  DetectiveTargetSpot({
    required this.addressController,
    required this.noteController,
    required this.lat,
    required this.lng,
    required this.spotName,
  });

  void dispose() {
    addressController.dispose();
    noteController.dispose();
  }
}

class IdrCurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');

    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    int value = int.tryParse(digitsOnly) ?? 0;
    String formatted = formatIdr(value);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatIdr(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}

class FreedomRequestBookingScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedPartner;
  final String serviceType;
  final String? initialDescription;
  final String? initialDestination;
  
  const FreedomRequestBookingScreen({
    super.key, 
    this.selectedPartner,
    this.serviceType = 'freedom',
    this.initialDescription,
    this.initialDestination,
  });

  @override
  State<FreedomRequestBookingScreen> createState() => _FreedomRequestBookingScreenState();
}

class _FreedomRequestBookingScreenState extends State<FreedomRequestBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  late final TextEditingController _descriptionController;
  final _pickupController = TextEditingController();
  late final TextEditingController _destinationController;
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();
  bool _acceptDisclaimer = true;

  bool get isDetective => widget.serviceType == 'detective' || widget.serviceType == 'detektif';

  // Detective Specific State
  bool _isManualNotesMode = false;
  String _selectedMission = '📸 Konfirmasi Keberadaan & Foto Bukti';
  int _detectiveDurationHours = 2;
  XFile? _targetImageFile;
  Uint8List? _targetImageBytes;
  bool _isUploadingTargetImage = false;
  String? _uploadedTargetImageUrl;
  final ImagePicker _imagePicker = ImagePicker();
  final List<DetectiveTargetSpot> _additionalTargetSpots = [];

  final List<Map<String, dynamic>> _detectiveMissions = [
    {
      'title': '📸 Konfirmasi Keberadaan & Foto Bukti',
      'short': 'Foto Bukti',
      'badge': 'Paling Populer',
      'icon': Icons.camera_alt_rounded,
      'template': 'Misi: Observasi keberadaan target di lokasi dan ambil foto/video bukti secara rahasia dari jarak aman di tempat publik.\n\nCiri Target:\n• Pria/Wanita, perkiraan usia: ...\n• Pakaian hari ini: ...\n• Kendaraan: ... (Plat: ...)\n• Posisi/Spot di lokasi: ...',
    },
    {
      'title': '☕ Pantau Pertemuan di Cafe / Resto',
      'short': 'Pantau Cafe',
      'badge': 'Pertemuan',
      'icon': Icons.local_cafe_rounded,
      'template': 'Misi: Pantau target yang sedang nongkrong/bertemu di cafe atau restoran, laporkan situasi & dokumentasikan.\n\nCiri Target & Poin Amati:\n• Duduk di area: Outdoor / Indoor (Meja: ...)\n• Amati siapa saja yang bersama target\n• Catat durasi & suasana pertemuan',
    },
    {
      'title': '🏢 Cek Lembur Kantor (Pastikan di Kantor)',
      'short': 'Cek Kantor',
      'badge': 'Verifikasi Lokasi',
      'icon': Icons.business_rounded,
      'template': 'Misi: Konfirmasi apakah target benar-benar sedang berada di gedung kantor atau berada di lokasi lain.\n\nCiri Target & Poin Amati:\n• Gedung/Lantai/Lobby: ...\n• Cek keberadaan kendaraan di parkiran/basement (Plat: ...)\n• Laporkan status standby target',
    },
    {
      'title': '🚗 Observasi / Ikuti Pergerakan Target',
      'short': 'Tracking',
      'badge': 'Rute Bergerak',
      'icon': Icons.directions_car_filled_rounded,
      'template': 'Misi: Observasi pergerakan/rute perjalanan target dari titik mulai ke titik tujuan secara rahasia.\n\nCiri Kendaraan Target:\n• Jenis & Warna Mobil/Motor: ...\n• Plat Nomor: ...\n• Estimasi Arah Tujuan: ...',
    },
  ];

  final List<Map<String, dynamic>> _quickNotePills = [
    {'label': 'Foto plat & unit kendaraan', 'icon': Icons.camera_alt_rounded, 'text': 'Foto plat nomor & unit kendaraan target'},
    {'label': 'Status sendirian / berdua', 'icon': Icons.people_rounded, 'text': 'Konfirmasi apakah target sendirian atau bersama seseorang'},
    {'label': 'Foto situasi meja sekitar', 'icon': Icons.table_restaurant_rounded, 'text': 'Foto situasi meja dan area sekitar tempat target duduk'},
    {'label': 'Cek lobby / parkiran kantor', 'icon': Icons.business_rounded, 'text': 'Pastikan keberadaan target di lobby atau area parkiran gedung'},
    {'label': 'Observasi rute jika pindah', 'icon': Icons.alt_route_rounded, 'text': 'Amati arah rute perjalanan jika target berpindah tempat'},
    {'label': 'Catat jam tiba & jam pulang', 'icon': Icons.timer_rounded, 'text': 'Catat jam kedatangan dan jam kepulangan target di lokasi'},
    {'label': 'Observasi rahasia jarak aman', 'icon': Icons.shield_rounded, 'text': 'Lakukan pemantauan secara aman dari jarak pandang publik'},
  ];

  // Real Maps Distance & Coordinates
  double _pickupLat = -6.2099;
  double _pickupLng = 106.8502;
  double _destLat = -6.1952;
  double _destLng = 106.8208;
  double _actualDistanceKm = 5.2;
  int _estimatedDurationMinutes = 14;
  bool _isCalculatingDistance = false;
  String _routeSource = 'OpenStreetMap';

  // Dynamic Multi-Layanan List
  final List<AdditionalServiceItem> _additionalServices = [];

  // Custom Offer Price State
  final _userOfferPriceController = TextEditingController();

  bool _isWeekendApplied = false;

  String _selectedClass = 'Gold';
  dynamic _selectedDriverId = '';
  String _selectedDriverName = 'Mitra Terbuka (Open Bid)';
  String _selectedDriverImage = '';
  double _selectedDriverRating = 5.0;
  int _selectedDriverBasePrice = 70000; // default Gold
  String _selectedDriverVehicle = 'Kendaraan Fleksibel';
  int _selectedDriverTrips = 120;

  @override
  void initState() {
    super.initState();
    String defaultTitle = '';
    String defaultDesc = widget.initialDescription ?? '';
    if (widget.serviceType == 'detective' || widget.serviceType == 'detektif') {
      defaultTitle = 'Detektif Relationship & Observasi Lapangan';
      if (defaultDesc.isEmpty) {
        defaultDesc = 'Observasi situasi & konfirmasi keberadaan target di tempat publik secara rahasia dan aman...';
      }
    } else if (widget.serviceType == 'assistant') {
      defaultTitle = 'Personal Assistant Service (Asisten Harian)';
      if (defaultDesc.isEmpty) {
        defaultDesc = 'Bantuan tugas harian: bawain koper/belanjaan, asisten pendamping event/club, dll...';
      }
    } else {
      defaultTitle = 'Freedom Request (Jasa Suruh)';
      if (defaultDesc.isEmpty) {
        defaultDesc = 'Jasa suruh custom: beli barang, antre tiket, titip pesan, dll...';
      }
    }
    _titleController.text = defaultTitle;
    _descriptionController = TextEditingController(text: defaultDesc);
    _pickupController.text = "";
    _destinationController = TextEditingController(
      text: widget.initialDestination?.isNotEmpty == true
          ? widget.initialDestination!
          : "",
    );

    if (widget.selectedPartner != null) {
      _selectedDriverName = widget.selectedPartner!['name'] ?? 'Driver Partner';
      _selectedDriverImage = widget.selectedPartner!['image'] ?? widget.selectedPartner!['avatar'] ?? '';
      _selectedDriverRating = widget.selectedPartner!['rating'] is String 
          ? double.parse(widget.selectedPartner!['rating']) 
          : (widget.selectedPartner!['rating']?.toDouble() ?? 5.0);
      _selectedDriverVehicle = widget.selectedPartner!['vehicle'] ?? 'Kendaraan Driver';
      _selectedDriverId = widget.selectedPartner!['id'] ?? '';
      _selectedDriverBasePrice = widget.selectedPartner!['price'] is int 
          ? widget.selectedPartner!['price'] 
          : 70000;
      _selectedDriverTrips = widget.selectedPartner!['kpi'] is int 
          ? (widget.selectedPartner!['kpi'] as int) * 2 
          : 120;
      _selectedClass = widget.selectedPartner!['type'] ?? 'Gold';
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
    _calculateRealFreedomDistance();
  }

  Future<void> _calculateRealFreedomDistance() async {
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
        _actualDistanceKm = (result['distanceKm'] as num?)?.toDouble() ?? 5.2;
        _estimatedDurationMinutes = (result['durationMinutes'] as num?)?.toInt() ?? 14;
        _routeSource = result['source']?.toString() ?? 'OpenStreetMap';
        _isCalculatingDistance = false;
      });
      _updateRecommendedUserOfferPrice();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    _userOfferPriceController.dispose();
    for (var s in _additionalServices) {
      s.dispose();
    }
    for (var spot in _additionalTargetSpots) {
      spot.dispose();
    }
    super.dispose();
  }

  void _addAdditionalTargetSpot() {
    setState(() {
      final index = _additionalTargetSpots.length + 2;
      _additionalTargetSpots.add(
        DetectiveTargetSpot(
          addressController: TextEditingController(),
          noteController: TextEditingController(),
          lat: _pickupLat + (0.005 * (_additionalTargetSpots.length + 1)),
          lng: _pickupLng + (0.005 * (_additionalTargetSpots.length + 1)),
          spotName: "Spot $index (Lokasi Lanjutan)",
        ),
      );
    });
  }

  void _removeAdditionalTargetSpot(int index) {
    setState(() {
      _additionalTargetSpots[index].dispose();
      _additionalTargetSpots.removeAt(index);
    });
  }

  void _updateRecommendedUserOfferPrice() {
    final double distance = _actualDistanceKm > 0 ? _actualDistanceKm : 5.0;
    const double perKmRate = 7500;
    if (isDetective) {
      int base = _selectedDriverBasePrice > 0 ? _selectedDriverBasePrice : 100000;
      int durationFee = _detectiveDurationHours * 45000;
      int recommended = base + durationFee + (distance * perKmRate).toInt();
      _userOfferPriceController.text = IdrCurrencyFormatter.formatIdr(recommended);
    } else {
      int recommended = _selectedDriverBasePrice + (distance * perKmRate).toInt();
      _userOfferPriceController.text = IdrCurrencyFormatter.formatIdr(recommended);
    }
  }

  Future<void> _pickTargetImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _targetImageFile = picked;
          _targetImageBytes = bytes;
          _isUploadingTargetImage = true;
        });

        // Trigger upload to Supabase Storage in background
        _uploadTargetImageToSupabase(bytes);
      }
    } catch (e) {
      debugPrint("Error picking target image: $e");
    }
  }

  Future<String?> _uploadTargetImageToSupabase(Uint8List bytes) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'target_${timestamp}_${DateTime.now().microsecond}.jpg';
      final storagePath = 'detective-targets/$fileName';

      try {
        await Supabase.instance.client.storage
            .from('community-media')
            .uploadBinary(storagePath, bytes, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
        final url = Supabase.instance.client.storage.from('community-media').getPublicUrl(storagePath);
        if (mounted) {
          setState(() {
            _uploadedTargetImageUrl = url;
            _isUploadingTargetImage = false;
          });
        }
        return url;
      } catch (e1) {
        debugPrint('Upload to community-media bucket failed: $e1. Trying public...');
        try {
          await Supabase.instance.client.storage
              .from('public')
              .uploadBinary(storagePath, bytes, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
          final url = Supabase.instance.client.storage.from('public').getPublicUrl(storagePath);
          if (mounted) {
            setState(() {
              _uploadedTargetImageUrl = url;
              _isUploadingTargetImage = false;
            });
          }
          return url;
        } catch (e2) {
          debugPrint('Upload to public bucket failed: $e2');
        }
      }
    } catch (e) {
      debugPrint("Storage upload error: $e");
    } finally {
      if (mounted) {
        setState(() => _isUploadingTargetImage = false);
      }
    }
    return null;
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Pilih Foto Target / Kendaraan",
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primaryPink.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryPink),
                ),
                title: Text("Buka Galeri HP", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickTargetImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primaryPink.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryPink),
                ),
                title: Text("Ambil Foto dari Kamera", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickTargetImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkWeekend(DateTime date) {
    setState(() {
      _isWeekendApplied = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    });
  }

  Map<String, dynamic> _calculatePrice() {
    final double distance = _actualDistanceKm > 0 ? _actualDistanceKm : 5.0;
    const double perKmRate = 7500;
    
    int baseFee = _selectedDriverBasePrice;
    if (isDetective) {
      baseFee = (_selectedDriverBasePrice > 0 ? _selectedDriverBasePrice : 100000) + (_detectiveDurationHours * 45000);
    }
    int service1Fee = baseFee + (distance * perKmRate).toInt();

    // Multi-Layanan Dynamic Fee Sum
    int additionalServicesFee = _additionalServices.fold<int>(
      0, 
      (sum, item) => sum + item.calculateFee(),
    );

    int subtotal = service1Fee + additionalServicesFee;
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
            (widget.serviceType == 'detective' || widget.serviceType == 'detektif')
                ? "Detektif Relationship"
                : widget.serviceType == 'assistant'
                    ? "Personal Assistant Service"
                    : "Freedom Request (Jasa Suruh)",
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
                if (isDetective) ...[
                  // 1. HEADER: DRIVER PROFILE OR DETECTIVE RADAR BADGE
                  widget.selectedPartner != null
                      ? _buildSelectedDriverHeader()
                      : _buildDetectiveHeaderBadge(),
                  const SizedBox(height: 20),

                  // 2. MISI & CATATAN INVESTIGASI (MODE REKOMENDASI / MANUAL)
                  _buildDetectiveMissionAndNotesSection(),
                  const SizedBox(height: 20),

                  // 3. FOTO TARGET / KENDARAAN (OPSIONAL DENGAN STORAGE DATABASE)
                  _buildDetectivePhotoSection(),
                  const SizedBox(height: 20),

                  // 4. TITIK LOKASI TARGET & MULTI-SPOT GOOGLE MAPS
                  _buildDetectiveLocationSection(),
                  const SizedBox(height: 18),

                  _buildRouteLiveBadge(),
                  const SizedBox(height: 20),

                  // 5. ESTIMASI DURASI PANTAU
                  _buildDetectiveDurationSection(),
                  const SizedBox(height: 20),

                  // 6. WAKTU MULAI PANTAU
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, color: AppTheme.primaryPink, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Waktu Mulai Observasi: ${_dateController.text}, ${_timeController.text}",
                            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // 7. DYNAMIC MULTI-LAYANAN
                  MultiServiceSection(
                    services: _additionalServices,
                    onServicesChanged: () => setState(() {}),
                    currentPrimaryService: 'freedom',
                    defaultPickup: _pickupController.text,
                    defaultDestination: _destinationController.text,
                  ),
                  const SizedBox(height: 25),

                  // 8. BUDGET TAWARAN INVESTIGASI (FORMAT IDR DENGAN TITIK SETIAP 3 DIGIT)
                  _buildSectionTitle("Tawaran Budget Investigasi (Layanan Utama)"),
                  const SizedBox(height: 4),
                  Text(
                    "Nominal yang Anda tawarkan ke mitra detektif (otomatis berformat Rupiah).",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _userOfferPriceController,
                    hint: "150.000",
                    prefixText: "Rp ",
                    icon: Icons.payments_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [IdrCurrencyFormatter()],
                  ),
                  const SizedBox(height: 20),

                  // 9. PRIVACY & SAFETY SHIELD
                  _buildDetectivePrivacyShield(),
                  const SizedBox(height: 25),
                ] else ...[
                  // HEADER: DRIVER PROFILE OR RADAR OPEN OFFER (NO "PILIH DRIVER" LIST)
                  widget.selectedPartner != null
                      ? _buildSelectedDriverHeader()
                      : _buildRadarHeaderBadge(),
                  const SizedBox(height: 20),

                  _buildSectionTitle("Judul Request"),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _titleController,
                    hint: "Contoh: Antre Tiket Konser, Temani Beli Kado, dll.",
                    icon: Icons.label_important_rounded,
                  ),
                  const SizedBox(height: 20),

                  _buildSectionTitle("Deskripsi Request (Terbuka)"),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _descriptionController,
                    hint: "Tuliskan apa saja yang perlu dibantu (misal: antre tiket, titip makanan, bawakan barang, dll.)",
                    icon: Icons.edit_note_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),

                  _buildLocationSection(
                    sectionTitle: "Lokasi Request / Titik Mulai",
                    mapBadgeTitle: "TITIK MULAI DI GOOGLE MAPS",
                    controller: _pickupController,
                    hintText: "Contoh: Toko / Lokasi Pelaksanaan...",
                    icon: Icons.location_on_rounded,
                    lat: _pickupLat,
                    lng: _pickupLng,
                    isRequired: true,
                    onSelected: (addr, lat, lng) {
                      setState(() {
                        _pickupController.text = addr;
                        _pickupLat = lat;
                        _pickupLng = lng;
                      });
                      _calculateRealFreedomDistance();
                    },
                  ),
                  const SizedBox(height: 18),

                  _buildLocationSection(
                    sectionTitle: "Lokasi Tujuan (Opsional)",
                    mapBadgeTitle: "TITIK TUJUAN DI GOOGLE MAPS",
                    controller: _destinationController,
                    hintText: "Contoh: Warung Tekko sebelah barat, Grand Indonesia, dll.",
                    icon: Icons.flag_rounded,
                    lat: _destLat,
                    lng: _destLng,
                    isRequired: false,
                    onSelected: (addr, lat, lng) {
                      setState(() {
                        _destinationController.text = addr;
                        _destLat = lat;
                        _destLng = lng;
                      });
                      _calculateRealFreedomDistance();
                    },
                  ),
                  const SizedBox(height: 16),

                  // ROUTE LIVE DISTANCE BADGE
                  _buildRouteLiveBadge(),
                  const SizedBox(height: 20),

                  // WAKTU REQUEST
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
                            "Waktu Request: ${_dateController.text}, ${_timeController.text}",
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
                    currentPrimaryService: 'freedom',
                    defaultPickup: _pickupController.text,
                    defaultDestination: _destinationController.text,
                  ),
                  const SizedBox(height: 25),

                  _buildSectionTitle("Tawaran Harga Anda (Layanan Utama)"),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _userOfferPriceController,
                    hint: "100.000",
                    prefixText: "Rp ",
                    icon: Icons.payments_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [IdrCurrencyFormatter()],
                  ),
                  const SizedBox(height: 25),

                  // Trust & Safety Disclaimer Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPink.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: AppTheme.primaryPink, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Ketentuan Trust & Safety",
                                style: GoogleFonts.inter(
                                  color: AppTheme.textHighContrast,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Freedom Request dilarang memuat permintaan ilegal, berbahaya, atau transaksi di luar aplikasi Temenin Ajaa.",
                          style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: _acceptDisclaimer,
                          onChanged: (val) => setState(() => _acceptDisclaimer = val ?? true),
                          activeColor: AppTheme.primaryPink,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            "Saya menyetujui syarat & ketentuan norma platform",
                            style: GoogleFonts.inter(
                              color: AppTheme.textHighContrast,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                ],

                // Live Estimasi Harga
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
                        "MITRA TERPILIH",
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
                  "Kelas: $_selectedClass • $_selectedDriverVehicle",
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
              color: const Color(0xFFEA580C).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.explore_rounded, color: Color(0xFFEA580C), size: 24),
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
                        "Open Request & Penawaran Terbuka",
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
                        color: const Color(0xFFEA580C).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEA580C).withOpacity(0.3)),
                      ),
                      child: Text(
                        "Open Bid",
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEA580C),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Request Anda akan disiarkan ke mitra terdekat untuk kesepakatan harga terbaik.",
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectiveHeaderBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.psychology_alt_rounded, color: Color(0xFF6366F1), size: 24),
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
                        "Radar Detektif & Investigator",
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
                        color: const Color(0xFF6366F1).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                      ),
                      child: Text(
                        "Anonim",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF6366F1),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Mitra investigasi terdekat yang stand by akan mengonfirmasi misi lapangan.",
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectiveMissionAndNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔀 1. TAB TOGGLE: REKOMENDASI MISI vs CATATAN MANUAL BEBAS
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isManualNotesMode = false;
                      if (_descriptionController.text.trim().isEmpty) {
                        final currentMission = _detectiveMissions.firstWhere(
                          (m) => m['title'] == _selectedMission,
                          orElse: () => _detectiveMissions.first,
                        );
                        _descriptionController.text = currentMission['template'] as String;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: !_isManualNotesMode ? AppTheme.primaryPink : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: !_isManualNotesMode
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryPink.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 15,
                          color: !_isManualNotesMode ? Colors.white : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Rekomendasi Misi",
                          style: GoogleFonts.inter(
                            color: !_isManualNotesMode ? Colors.white : AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: !_isManualNotesMode ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isManualNotesMode = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _isManualNotesMode ? AppTheme.primaryPink : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: _isManualNotesMode
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryPink.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 16,
                          color: _isManualNotesMode ? Colors.white : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Tulis Manual Bebas",
                          style: GoogleFonts.inter(
                            color: _isManualNotesMode ? Colors.white : AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: _isManualNotesMode ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 🎯 2. KARTU REKOMENDASI MISI (Jika Mode Rekomendasi Aktif)
        if (!_isManualNotesMode) ...[
          _buildSectionTitle("1. Pilih Misi Utama Observasi"),
          const SizedBox(height: 4),
          Text(
            "Pilih tujuan misi untuk otomatis memuat panduan & draf instruksi.",
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Column(
            children: _detectiveMissions.map((m) {
              final isSel = _selectedMission == m['title'];
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedMission = m['title'] as String;
                    _descriptionController.text = m['template'] as String;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSel ? AppTheme.primaryPink.withValues(alpha: 0.12) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSel ? AppTheme.primaryPink : AppTheme.border,
                      width: isSel ? 1.8 : 1.0,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryPink.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.primaryPink : AppTheme.cardDeep,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          m['icon'] as IconData,
                          color: isSel ? Colors.white : AppTheme.primaryPink,
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
                                Expanded(
                                  child: Text(
                                    m['title'] as String,
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textHighContrast,
                                      fontSize: 13,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSel ? AppTheme.primaryPink : AppTheme.cardDeep,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    m['badge'] as String,
                                    style: GoogleFonts.inter(
                                      color: isSel ? Colors.white : AppTheme.textMuted,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              m['template'].toString().split('\n').first,
                              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isSel ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isSel ? AppTheme.primaryPink : AppTheme.textMuted.withValues(alpha: 0.4),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // 📝 3. CATATAN & CIRI TARGET (EDITOR)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.description_rounded, color: AppTheme.primaryPink, size: 18),
                const SizedBox(width: 6),
                Text(
                  _isManualNotesMode ? "CATATAN OBSERVASI KHUSUS" : "CIRI TARGET & INSTRUKSI MISI",
                  style: GoogleFonts.inter(
                    color: AppTheme.textHighContrast,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (!_isManualNotesMode)
                  InkWell(
                    onTap: () {
                      final currentMission = _detectiveMissions.firstWhere(
                        (m) => m['title'] == _selectedMission,
                        orElse: () => _detectiveMissions.first,
                      );
                      setState(() {
                        _descriptionController.text = currentMission['template'] as String;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        "Reset Template",
                        style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (_descriptionController.text.isNotEmpty)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _descriptionController.clear();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        "Hapus Teks",
                        style: GoogleFonts.inter(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _descriptionController,
          hint: _isManualNotesMode
              ? "Tuliskan instruksi bebas, hal yang perlu diamati, atau rincian target..."
              : "Isi ciri-ciri target, pakaian, plat nomor, atau poin pengamatan di sini...",
          icon: Icons.edit_note_rounded,
          maxLines: 4,
        ),
        const SizedBox(height: 12),

        // 💡 4. POIN OBSERVASI TAMBAHAN (INTERAKTIF CHECKLIST PILLS)
        Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFFF59E0B), size: 15),
            const SizedBox(width: 5),
            Text(
              "Poin Observasi Tambahan (Tap untuk Toggle):",
              style: GoogleFonts.inter(
                color: AppTheme.textHighContrast,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _quickNotePills.map((pill) {
            final textToFind = pill['text'] as String;
            final isIncluded = _descriptionController.text.contains(textToFind);

            return InkWell(
              onTap: () {
                setState(() {
                  final current = _descriptionController.text.trim();
                  if (isIncluded) {
                    // Remove the point
                    _descriptionController.text = current
                        .replaceAll('• $textToFind', '')
                        .replaceAll(textToFind, '')
                        .replaceAll('\n\n\n', '\n\n')
                        .trim();
                  } else {
                    // Append the point
                    if (current.isEmpty) {
                      _descriptionController.text = "• $textToFind";
                    } else {
                      _descriptionController.text = "$current\n• $textToFind";
                    }
                  }
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isIncluded ? AppTheme.primaryPink.withValues(alpha: 0.18) : AppTheme.cardDeep,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isIncluded ? AppTheme.primaryPink : AppTheme.border,
                    width: isIncluded ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isIncluded ? Icons.check_circle_rounded : (pill['icon'] as IconData),
                      size: 13,
                      color: isIncluded ? AppTheme.primaryPink : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      pill['label'] as String,
                      style: GoogleFonts.inter(
                        color: isIncluded ? AppTheme.textHighContrast : AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: isIncluded ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDetectivePhotoSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryPink, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    "FOTO TARGET / KENDARAAN (OPSIONAL)",
                    style: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (_targetImageBytes != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _targetImageFile = null;
                      _targetImageBytes = null;
                      _uploadedTargetImageUrl = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text("Hapus", style: GoogleFonts.inter(color: AppTheme.danger, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_targetImageBytes != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.5)),
                    image: DecorationImage(
                      image: MemoryImage(_targetImageBytes!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(8),
                  child: InkWell(
                    onTap: _showImageSourcePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text("Ganti Foto", style: GoogleFonts.inter(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_isUploadingTargetImage) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPink),
                      ),
                      const SizedBox(width: 6),
                      Text("Menghubungkan foto ke database...", style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 10.5)),
                    ] else ...[
                      const Icon(Icons.cloud_done_rounded, color: Color(0xFF10B981), size: 14),
                      const SizedBox(width: 5),
                      Text("Foto berhasil tersimpan di sistem & database", style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ],
            )
          else
            InkWell(
              onTap: _showImageSourcePicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_a_photo_rounded, color: AppTheme.primaryPink, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Unggah Foto Target / Kendaraan",
                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Membantu mitra mengenali target & unit di lapangan secara akurat",
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetectiveLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. TITIK MULAI PANTAU (SPOT 1)
        _buildLocationSection(
          sectionTitle: "Titik Lokasi Target (Spot Utama)",
          mapBadgeTitle: "SPOT 1: TITIK UTAMA DI MAPS",
          controller: _pickupController,
          hintText: "Contoh: Cafe Kopi Kenangan Senopati, Gedung Wisma Sudirman, dll.",
          icon: Icons.location_on_rounded,
          lat: _pickupLat,
          lng: _pickupLng,
          isRequired: true,
          onSelected: (addr, lat, lng) {
            setState(() {
              _pickupController.text = addr;
              _pickupLat = lat;
              _pickupLng = lng;
            });
            _calculateRealFreedomDistance();
          },
        ),
        const SizedBox(height: 14),

        // 2. DAFTAR TITIK PANTAU TAMBAHAN (MULTI-SPOT)
        if (_additionalTargetSpots.isNotEmpty) ...[
          ..._additionalTargetSpots.asMap().entries.map((entry) {
            final idx = entry.key;
            final spot = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF818CF8), size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "SPOT ${idx + 2}: LOKASI PANTAU LANJUTAN",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF818CF8),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => _removeAdditionalTargetSpot(idx),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 14),
                              const SizedBox(width: 2),
                              Text("Hapus", style: GoogleFonts.inter(color: AppTheme.danger, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Maps button for additional spot
                  GestureDetector(
                    onTap: () {
                      DistanceService.showLocationPickerModal(
                        context,
                        title: "Pilih Spot ${idx + 2}",
                        initialValue: spot.addressController.text,
                        initialLat: spot.lat,
                        initialLng: spot.lng,
                        onSelected: (addr, lat, lng) {
                          setState(() {
                            spot.addressController.text = addr;
                            spot.lat = lat;
                            spot.lng = lng;
                          });
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDeep,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.map_rounded, color: Color(0xFF818CF8), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              spot.addressController.text.isNotEmpty
                                  ? spot.addressController.text
                                  : "Tap untuk tandai Spot ${idx + 2} di Peta Mapbox",
                              style: GoogleFonts.inter(
                                color: spot.addressController.text.isNotEmpty ? AppTheme.textHighContrast : AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: spot.addressController.text.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF818CF8), size: 12),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Detail address / note field
                  TextFormField(
                    controller: spot.addressController,
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: "Nama tempat / detail (misal: Mall Grand Indonesia Lobby West)",
                      hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        // ➕ TOMBOL TAMBAH TITIK LOKASI TARGET
        InkWell(
          onTap: _addAdditionalTargetSpot,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35), style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_location_alt_rounded, color: Color(0xFF818CF8), size: 18),
                const SizedBox(width: 8),
                Text(
                  "+ Tambah Titik Lokasi Target Lainnya",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF818CF8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 3. ESTIMASI TUJUAN / PERPINDAHAN TARGET (OPSIONAL)
        _buildLocationSection(
          sectionTitle: "Estimasi Titik Akhir / Perpindahan (Opsional)",
          mapBadgeTitle: "TITIK AKHIR PERPINDAHAN DI MAPS",
          controller: _destinationController,
          hintText: "Jika target diprediksi pindah (misal: kantor menuju resto/rumah)",
          icon: Icons.alt_route_rounded,
          lat: _destLat,
          lng: _destLng,
          isRequired: false,
          onSelected: (addr, lat, lng) {
            setState(() {
              _destinationController.text = addr;
              _destLat = lat;
              _destLng = lng;
            });
            _calculateRealFreedomDistance();
          },
        ),
      ],
    );
  }

  Widget _buildDetectiveDurationSection() {
    final durations = [
      {'hrs': 1, 'label': '1 Jam'},
      {'hrs': 2, 'label': '2 Jam (Std)'},
      {'hrs': 3, 'label': '3 Jam'},
      {'hrs': 4, 'label': '4 Jam'},
      {'hrs': 6, 'label': 'Standby (6 Jam)'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Estimasi Durasi Pengintaian"),
        const SizedBox(height: 4),
        Text(
          "Berapa lama mitra standby memantau target di lokasi?",
          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 10),
        Row(
          children: durations.map((d) {
            final hrs = d['hrs'] as int;
            final isSel = _detectiveDurationHours == hrs;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _detectiveDurationHours = hrs;
                  });
                  _updateRecommendedUserOfferPrice();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSel ? AppTheme.primaryPink : AppTheme.cardDeep,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? AppTheme.primaryPink : AppTheme.border,
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    d['label'] as String,
                    style: GoogleFonts.inter(
                      color: isSel ? Colors.white : AppTheme.textHighContrast,
                      fontSize: 10.5,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDetectivePrivacyShield() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B).withValues(alpha: 0.8), // deep indigo
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded, color: Color(0xFF818CF8), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "100% RAHASIA & PRIVASI TERJAGA",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF818CF8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Identitas klien dirahasiakan penuh. Mitra hanya melakukan observasi visual di area publik yang aman tanpa konfrontasi fisik.",
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, height: 1.35),
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
    required bool isRequired,
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
                            : "Tap untuk membuka Peta Mapbox & pilih lokasi",
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
                      validator: isRequired
                          ? (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Alamat $sectionTitle harus diisi';
                              }
                              return null;
                            }
                          : null,
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
    bool requiredField = true,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
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
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppTheme.primaryPink, size: 20),
          prefixText: prefixText,
          prefixStyle: GoogleFonts.inter(
            color: AppTheme.primaryPink,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: requiredField
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
                  decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text("Weekend +25%", style: TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const Divider(color: AppTheme.border, height: 20),
          _priceRow("Freedom Request Flat Base", fmt(_selectedDriverBasePrice)),
          _priceRow("Estimasi Rute Jarak (${_actualDistanceKm.toStringAsFixed(1)} km)", fmt(prices['service1Fee'] - _selectedDriverBasePrice)),
          
          // Render each additional service item dynamically
          ..._additionalServices.map((service) {
            return _priceRow(
              "Layanan Ekstra: ${service.displayName}",
              fmt(service.calculateFee()),
            );
          }),

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
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Sisa Pelunasan di Tujuan", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              Text(fmt(prices['remaining']), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
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
            color: AppTheme.primaryPink.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            if (!_acceptDisclaimer) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Harap setujui syarat ketentuan norma platform")),
              );
              return;
            }

            final cleanOfferDigits = _userOfferPriceController.text.replaceAll(RegExp(r'[^0-9]'), '');
            final int userOffer = int.tryParse(cleanOfferDigits) ?? prices['service1Fee'];
            final isPreselected = widget.selectedPartner != null;

            // Prepare list of target spots for detective
            final List<Map<String, dynamic>> targetSpotsData = [
              {
                'spotIndex': 1,
                'spotName': 'Spot 1 (Lokasi Mulai/Target Utama)',
                'address': _pickupController.text,
                'latitude': _pickupLat,
                'longitude': _pickupLng,
                'notes': _notesController.text,
              }
            ];

            for (int i = 0; i < _additionalTargetSpots.length; i++) {
              final spot = _additionalTargetSpots[i];
              targetSpotsData.add({
                'spotIndex': i + 2,
                'spotName': spot.spotName,
                'address': spot.addressController.text,
                'latitude': spot.lat,
                'longitude': spot.lng,
                'notes': spot.noteController.text,
              });
            }

            final bookingData = {
              'serviceType': 'freedom_request',
              'isOpenOffer': !isPreselected,
              'driverId': isPreselected ? _selectedDriverId : null,
              'driverName': isPreselected ? _selectedDriverName : "Mitra Terbuka (Open Bid)",
              'driverImage': isPreselected ? _selectedDriverImage : "",
              'driverRating': isPreselected ? _selectedDriverRating.toString() : "5.0",
              'driverTrips': isPreselected ? _selectedDriverTrips.toString() : "120",
              'vehicle': isPreselected ? _selectedDriverVehicle : "Kendaraan Mitra",
              'plateNumber': isPreselected 
                  ? 'B 9999 ${_selectedDriverName.length >= 2 ? _selectedDriverName.substring(0, 2).toUpperCase() : "JKT"}'
                  : 'B 8888 RDR',
              'pickup': _pickupController.text,
              'destination': _destinationController.text.isEmpty ? 'Tujuan Sesuai Request' : _destinationController.text,
              'pickup_latitude': _pickupLat,
              'pickup_longitude': _pickupLng,
              'dropoff_latitude': _destLat,
              'dropoff_longitude': _destLng,
              'actual_distance_km': _actualDistanceKm,
              'date': _dateController.text,
              'time': _timeController.text,
              'description': _descriptionController.text,
              
              // Pricing Details
              'serviceFee': prices['service1Fee'],
              'userInitialPrice': userOffer,
              'insuranceFee': 10000,
              'totalPayment': prices['totalEstimasi'] + 10000,
              'dp': (prices['dp'] + 5000),
              'remainingPayment': (prices['remaining'] + 5000),
              
              // Dynamic Multi service details
              'hasAdditionalService': _additionalServices.isNotEmpty,
              'additionalServices': _additionalServices.map((s) => s.toMap()).toList(),
              'additionalServiceFee': prices['additionalServicesFee'],
              
              'isDetective': isDetective,
              'detectiveMission': isDetective ? _selectedMission : null,
              'detectiveDurationHours': isDetective ? _detectiveDurationHours : null,
              'hasTargetPhoto': _targetImageBytes != null,
              'targetImagePath': _targetImageFile?.path,
              'target_photo_url': _uploadedTargetImageUrl,
              'target_photo_base64': _targetImageBytes != null ? base64Encode(_targetImageBytes!) : null,
              'target_spots': isDetective ? targetSpotsData : null,
              'target_spots_count': isDetective ? targetSpotsData.length : 1,
              'notes': _notesController.text,
              'estimatedTime': _estimatedDurationMinutes.toString(),
              'driverClass': _selectedClass,
            };

            // Map individual service types for backward compatibility
            for (var s in _additionalServices) {
              if (s.serviceType == 'antar_jemput') {
                bookingData['hasAntarJemput'] = true;
                bookingData['serviceAntarJemputFee'] = s.calculateFee();
                bookingData['additionalPickup'] = s.pickupController.text;
                bookingData['additionalDestination'] = s.destinationController.text;
                bookingData['additionalAntarJemputNotes'] = s.antarJemputNotesController.text;
              } else if (s.serviceType == 'hangout') {
                bookingData['hasHangout'] = true;
                bookingData['serviceHangoutFee'] = s.calculateFee();
                bookingData['additionalActivity'] = s.hangoutActivity;
                bookingData['additionalDuration'] = s.hangoutDurationHours.toString();
                bookingData['additionalHangoutLocation'] = s.hangoutLocationController.text;
                bookingData['additionalHangoutNotes'] = s.hangoutNotesController.text;
              }
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FreedomRequestNegotiationScreen(bookingData: bookingData),
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
          "Lanjutkan ke Negosiasi ➔",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
