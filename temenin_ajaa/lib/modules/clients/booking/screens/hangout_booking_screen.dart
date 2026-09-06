// lib/modules/clients/booking/screens/hangout_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/providers/driver_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/providers/auth_provider.dart';
import 'booking_confirmation_screen.dart';
import 'tracking_driver_screen.dart';
import 'freedom_request_negotiation_screen.dart' as temenin_ajaa_negotiation;

class HangoutBookingScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedPartner;
  final String serviceType;
  
  const HangoutBookingScreen({
    super.key, 
    this.selectedPartner,
    this.serviceType = 'hangout',
  });

  @override
  State<HangoutBookingScreen> createState() => _HangoutBookingScreenState();
}

class _HangoutBookingScreenState extends State<HangoutBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController(text: 'Apartemen Senopati Tower A, Jaksel');
  final _destinationController = TextEditingController(text: 'Senayan City Lobby Main Mall, Jaksel');
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();
  final _customActivityController = TextEditingController();
  final _customRequestChipController = TextEditingController();

  // Jenis Perjalanan: 'oneway' (Sekali Jalan) or 'round' (Pulang Pergi PP)
  String _tripType = 'oneway';

  // Aktivitas & Durasi
  String _selectedActivity = 'Makan';
  int _selectedDuration = 3; // 3, 4, 6, 8 Jam
  final Map<int, int> _durationPrices = {
    3: 150000,
    4: 200000,
    6: 300000,
    8: 400000,
  };

  // Request Khusus Chips
  final List<String> _requestChips = [
    'Casual outfit',
    'Formal outfit',
    'Komunikatif',
    'Bisa bantu foto/video',
    'Bisa rekomendasi tempat',
    'Bisa bahasa Inggris',
  ];
  final Set<String> _selectedRequestChips = {'Casual outfit', 'Komunikatif', 'Bisa bantu foto/video'};
  bool _isAddingChip = false;

  // Add-ons & Bundling State
  bool _rentProPhoto = false;
  bool _addTransportBundling = false;
  bool _isWeekendApplied = false;

  final List<String> _activitiesList = [
    'Ngopi', 'Makan', 'Nonton', 'Jalan-jalan', 'Shopping', 'Event', 'Kondangan', 'City Tour', 'Dinner', 'Lainnya'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DriverProvider>(context, listen: false).fetchDrivers();
    });

    // Default current date & time
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    _dateController.text = "${now.day} ${months[now.month - 1]} ${now.year}";
    _timeController.text = "13:30 WIB";
    _checkWeekend(now);

    // Customize based on serviceType
    if (widget.serviceType == 'counseling') {
      _selectedActivity = 'Relationship Counseling';
      _requestChips.clear();
      _requestChips.addAll([
        'Rahasia Terjamin',
        'Komunikatif',
        'Sertifikasi Psikologi',
        'Empati Tinggi',
        'Pendengar Baik',
        'Solutif',
      ]);
      _selectedRequestChips.clear();
      _selectedRequestChips.addAll(['Rahasia Terjamin', 'Komunikatif', 'Empati Tinggi']);
      _selectedDuration = 3;
    } else if (widget.serviceType == 'curhat') {
      _selectedActivity = 'Mendengarkan Curhat';
      _requestChips.clear();
      _requestChips.addAll([
        'Pendengar Baik',
        'Tanpa Menghakimi',
        'Teman Diskusi',
        'Rahasia Aman',
        'Bisa Online/Offline',
      ]);
      _selectedRequestChips.clear();
      _selectedRequestChips.addAll(['Pendengar Baik', 'Tanpa Menghakimi', 'Rahasia Aman']);
      _selectedDuration = 3;
    }
  }

  void _checkWeekend(DateTime date) {
    setState(() {
      _isWeekendApplied = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    });
  }

  Map<String, dynamic> _calculatePrice() {
    int hangoutBaseCost = _durationPrices[_selectedDuration] ?? 150000;
    
    // Bundling Transport
    int transportAddon = 0;
    if (_addTransportBundling) {
      transportAddon = _tripType == 'round' ? 150000 : 100000;
    }

    // Add-on Photo
    int photoAddon = _rentProPhoto ? 25000 : 0;

    // Weekend Surcharge
    int weekendFee = _isWeekendApplied ? 20000 : 0;

    // Total Transaksi
    int totalEstimasi = hangoutBaseCost + transportAddon + photoAddon + weekendFee;

    // DP 30% Wajib Sistem
    int dp = (totalEstimasi * 0.3).toInt();

    // Sisa 70% Pelunasan H-1
    int remainingPayment = totalEstimasi - dp;

    return {
      'hangoutBaseCost': hangoutBaseCost,
      'transportAddon': transportAddon,
      'photoAddon': photoAddon,
      'weekendFee': weekendFee,
      'totalEstimasi': totalEstimasi,
      'dp': dp,
      'remaining': remainingPayment,
    };
  }

  String _getAppBarTitle() {
    switch (widget.serviceType) {
      case 'counseling': return "Relationship Counseling";
      case 'curhat': return "Teman Curhat (Offline/Online)";
      case 'hiking': return "Hiking Partner";
      case 'assistant': return "Personal Assistance";
      case 'detective': return "Detektif Relationship";
      default: return "Booking Hangout Partner";
    }
  }

  @override
  Widget build(BuildContext context) {
    final prices = _calculatePrice();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textHighContrast),
          onPressed: () => Navigator.pop(context),
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
                // HEADER: AUTODETECT RADAR MATCHING
                _buildRadarHeaderBadge(),
                const SizedBox(height: 20),

                // STEP 1: LOKASI PERTEMUAN & HANGOUT
                _buildSectionTitle("Rute & Titik Lokasi Hangout"),
                const SizedBox(height: 10),
                _buildRouteInputsCard(),
                const SizedBox(height: 16),

                // STEP 2: MAPS PREVIEW VIEWPORT
                _buildMapsPreviewCard(),
                const SizedBox(height: 20),

                // STEP 3: JENIS PERJALANAN COMPANION
                _buildSectionTitle("Jenis Perjalanan Companion"),
                const SizedBox(height: 10),
                _buildTripTypeSelector(),
                const SizedBox(height: 20),

                // STEP 4: PILIH AKTIVITAS
                _buildSectionTitle("Pilih Aktivitas"),
                const SizedBox(height: 10),
                _buildActivitySelector(),
                if (_selectedActivity == 'Lainnya') ...[
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _customActivityController,
                    hint: "Ketik jenis aktivitas kustom Anda...",
                    icon: Icons.edit_note_rounded,
                  ),
                ],
                const SizedBox(height: 20),

                // STEP 5: DURASI HANGOUT
                _buildSectionTitle("Durasi Hangout"),
                const SizedBox(height: 10),
                _buildDurationGrid(),
                const SizedBox(height: 20),

                // STEP 6: REQUEST KHUSUS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle("Request Khusus"),
                    Text("Klik [×] untuk hapus", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                _buildRequestChipsFlow(),
                const SizedBox(height: 20),

                // STEP 7: JADWAL PENJEMPUTAN & PERTEMUAN
                _buildSectionTitle("Jadwal Penjemputan & Pertemuan"),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildDateField()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTimeField()),
                  ],
                ),
                if (_isWeekendApplied) ...[
                  const SizedBox(height: 10),
                  _buildWeekendNoticeBanner(),
                ],
                const SizedBox(height: 20),

                // STEP 8: ADD-ON SEWA DOKUMENTASI PRO
                _buildSectionTitle("Add-on Layanan Hangout"),
                const SizedBox(height: 10),
                _buildAddonCard(),
                const SizedBox(height: 16),

                // STEP 9: BUTTON MULTILAYANAN BUNDLING TRANSPORT
                _buildTransportBundlingButton(),
                const SizedBox(height: 20),

                // STEP 10: CATATAN UNTUK COMPANION
                _buildSectionTitle("Catatan Khusus untuk Companion"),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _notesController,
                  hint: "Instruksi khusus penjemputan & hangout (opsional)...",
                  icon: Icons.note_add_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 25),

                // STEP 11: RINCIAN BILL USER & HIGHLIGHT DP 30%
                _buildBillSummaryCard(prices),
                const SizedBox(height: 30),

                // STEP 12: BUTTON BOOKING SEKARANG
                _buildBookingSubmitButton(prices),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
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
                  "Mitra companion terdekat akan dipasangkan otomatis",
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.fuchsiaLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
            ),
            child: Text(
              "Auto Match",
              style: GoogleFonts.inter(
                color: AppTheme.primaryPink,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        color: AppTheme.textHighContrast,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildRouteInputsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // Pickup Location
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardDeep,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppTheme.primaryPink, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "LOKASI PENJEMPUTAN / PERTEMUAN",
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      TextFormField(
                        controller: _pickupController,
                        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Destination Location
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardDeep,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.navigation_rounded, color: AppTheme.success, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "LOKASI TEMPAT HANGOUT",
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      TextFormField(
                        controller: _destinationController,
                        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapsPreviewCard() {
    return Container(
      height: 140,
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
          // Turn Banner
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.turn_right_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "300m lagi tiba di Senayan City Main Entrance",
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Stats Badge
          Positioned(
            bottom: 10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Text("4.8 km", style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 11)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text("•", style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  Text("12 mnt", style: GoogleFonts.inter(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 11)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text("•", style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  Text("Rute Hangout Terdekat", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tripType = 'oneway'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: _tripType == 'oneway' ? AppTheme.fuchsiaLight : AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _tripType == 'oneway' ? AppTheme.primaryPink : AppTheme.border,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _tripType == 'oneway' ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    size: 16,
                    color: _tripType == 'oneway' ? AppTheme.primaryPink : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Sekali Jalan (Ketemu di Lokasi)",
                      style: GoogleFonts.inter(
                        color: _tripType == 'oneway' ? AppTheme.primaryPink : AppTheme.textHighContrast,
                        fontSize: 11,
                        fontWeight: _tripType == 'oneway' ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tripType = 'round'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: _tripType == 'round' ? AppTheme.fuchsiaLight : AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _tripType == 'round' ? AppTheme.primaryPink : AppTheme.border,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _tripType == 'round' ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    size: 16,
                    color: _tripType == 'round' ? AppTheme.primaryPink : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Pulang Pergi (PP)",
                      style: GoogleFonts.inter(
                        color: _tripType == 'round' ? AppTheme.primaryPink : AppTheme.textHighContrast,
                        fontSize: 11,
                        fontWeight: _tripType == 'round' ? FontWeight.bold : FontWeight.normal,
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
    );
  }

  Widget _buildActivitySelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _activitiesList.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final act = _activitiesList[index];
          final isSelected = _selectedActivity == act;
          return GestureDetector(
            onTap: () => setState(() => _selectedActivity = act),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryPink : AppTheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryPink : AppTheme.border,
                ),
              ),
              child: Text(
                act,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : AppTheme.textHighContrast,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: _durationPrices.keys.map((dur) {
        final isSelected = _selectedDuration == dur;
        final price = _durationPrices[dur]!;
        return GestureDetector(
          onTap: () => setState(() => _selectedDuration = dur),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.fuchsiaLight : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
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

  Widget _buildRequestChipsFlow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._requestChips.map((chipText) {
          final isSelected = _selectedRequestChips.contains(chipText);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedRequestChips.remove(chipText);
                } else {
                  _selectedRequestChips.add(chipText);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.fuchsiaLight : AppTheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryPink : AppTheme.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chipText,
                    style: GoogleFonts.inter(
                      color: isSelected ? AppTheme.primaryPink : AppTheme.textHighContrast,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _requestChips.remove(chipText);
                        _selectedRequestChips.remove(chipText);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.border,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 12, color: AppTheme.textHighContrast),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // Add Custom Request Chip Input / Button
        if (_isAddingChip) ...[
          Container(
            padding: const EdgeInsets.only(left: 12, right: 6, top: 4, bottom: 4),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.primaryPink),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _customRequestChipController,
                    autofocus: true,
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: "Ketik request...",
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onSubmitted: (val) => _confirmAddCustomChip(),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _confirmAddCustomChip,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryPink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          GestureDetector(
            onTap: () => setState(() => _isAddingChip = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.fuchsiaLight,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 14, color: AppTheme.primaryPink),
                  const SizedBox(width: 4),
                  Text(
                    "Tambah Request",
                    style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ]
      ],
    );
  }

  void _confirmAddCustomChip() {
    final text = _customRequestChipController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _requestChips.add(text);
        _selectedRequestChips.add(text);
        _customRequestChipController.clear();
        _isAddingChip = false;
      });
    } else {
      setState(() => _isAddingChip = false);
    }
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (date != null) {
          _checkWeekend(date);
          setState(() {
            final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
            _dateController.text = "${date.day} ${months[date.month - 1]} ${date.year}";
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryPink, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("TANGGAL", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                Text(_dateController.text, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField() {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: const TimeOfDay(hour: 13, minute: 30),
        );
        if (time != null) {
          setState(() {
            final hour = time.hour.toString().padLeft(2, '0');
            final minute = time.minute.toString().padLeft(2, '0');
            _timeController.text = "$hour:$minute WIB";
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: AppTheme.primaryPink, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("JAM", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                Text(_timeController.text, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekendNoticeBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Weekend Surcharge", style: GoogleFonts.inter(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.bold)),
              Text("Pemesanan di Hari Sabtu/Minggu", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
          Text("+Rp 20.000", style: GoogleFonts.inter(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAddonCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: CheckboxListTile(
        value: _rentProPhoto,
        onChanged: (val) => setState(() => _rentProPhoto = val!),
        activeColor: AppTheme.primaryPink,
        checkColor: Colors.white,
        title: Text("Dokumentasi Kamera Pro (iPhone 15 Pro)", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text("Hasil Foto Cinematic & Story-ready (+Rp 25.000)", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
      ),
    );
  }

  Widget _buildTransportBundlingButton() {
    return GestureDetector(
      onTap: () => setState(() => _addTransportBundling = !_addTransportBundling),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: _addTransportBundling ? AppTheme.fuchsiaLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _addTransportBundling ? AppTheme.primaryPink : AppTheme.border,
            width: _addTransportBundling ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _addTransportBundling ? Icons.check_circle_rounded : Icons.add_rounded,
              size: 18,
              color: AppTheme.primaryPink,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "+ Tambah Layanan Antar Jemput (PP / Sekali Jalan +Rp 100.000)",
                style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
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
          Text("Rincian Bill Hangout", style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14)),
          const Divider(color: AppTheme.border, height: 20),

          _priceRow("Paket Hangout Platinum ($_selectedDuration Jam)", fmt(prices['hangoutBaseCost'])),
          if (_addTransportBundling) _priceRow("Bundling Transport Antar Jemput", fmt(prices['transportAddon'])),
          if (_rentProPhoto) _priceRow("Add-on Foto Kamera Pro", fmt(25000)),
          if (_isWeekendApplied) _priceRow("Weekend Surcharge Fee", fmt(20000)),

          const Divider(color: AppTheme.border, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Transaksi", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(fmt(prices['totalEstimasi']), style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),

          // Highlight Box DP 30% Wajib Sistem
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.fuchsiaLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryPink.withOpacity(0.35)),
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
                    color: AppTheme.primaryPink.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
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
          Text(label, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
          Text(value, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBookingSubmitButton(Map<String, dynamic> prices) {
    final isRide = widget.serviceType == 'regular' || widget.serviceType == 'ride' || widget.serviceType == 'sporty';
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
            final bookingData = {
              'serviceType': widget.serviceType,
              'activity': _selectedActivity == 'Lainnya' ? _customActivityController.text : _selectedActivity,
              'duration': _selectedDuration,
              'pickup': _pickupController.text,
              'destination': _destinationController.text,
              'tripType': _tripType,
              'date': _dateController.text,
              'time': _timeController.text,
              'requestChips': _selectedRequestChips.toList(),
              'rentProPhoto': _rentProPhoto,
              'addTransportBundling': _addTransportBundling,
              'isWeekendApplied': _isWeekendApplied,
              'notes': _notesController.text,

              // Pricing
              'baseCost': prices['hangoutBaseCost'],
              'totalPayment': prices['totalEstimasi'],
              'dp': prices['dp'],
              'remainingPayment': prices['remaining'],
            };

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

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => temenin_ajaa_negotiation.FreedomRequestNegotiationScreen(
                    bookingData: bookingData,
                  ),
                ),
              );
            } else {
              () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryPink)),
                );

                String? bookingId;
                try {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final userId = auth.user?.id ?? Supabase.instance.client.auth.currentUser?.id;
                  if (userId != null) {
                    final totalPriceVal = bookingData['totalPayment'] ?? 130000;
                    final numPrice = totalPriceVal is num ? totalPriceVal.toDouble() : (double.tryParse(totalPriceVal.toString()) ?? 130000.0);
                    final insertPayload = <String, dynamic>{
                      'user_id': userId,
                      'status': 'pending',
                      'pickup_location': bookingData['pickup'] ?? 'Lokasi Penjemputan',
                      'dropoff_location': bookingData['destination'] ?? 'Tujuan',
                      'total_price': numPrice,
                      'additional_details': bookingData,
                    };
                    final response = await Supabase.instance.client
                        .from('bookings')
                        .insert(insertPayload)
                        .select('id')
                        .single();
                    bookingId = response['id']?.toString();
                    debugPrint("✅ Radar booking created in Supabase: $bookingId");
                  }
                } catch (e) {
                  debugPrint("Error inserting radar booking: $e");
                }

                if (mounted) {
                  Navigator.pop(context); // close loader
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TrackingDriverScreen(
                        bookingData: bookingData,
                        bookingId: bookingId ?? 'mock-bkg-${DateTime.now().millisecondsSinceEpoch}',
                      ),
                    ),
                  );
                }
              }();
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(
          isRide ? "Konfirmasi Radar Anter ➔" : "Konfirmasi Radar Hangout ➔",
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}