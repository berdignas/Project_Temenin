// lib/modules/clients/booking/screens/freedom_request_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/providers/driver_provider.dart';
import 'freedom_request_negotiation_screen.dart';

class FreedomRequestBookingScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedPartner;
  final String? initialDescription;
  final String? initialDestination;
  
  const FreedomRequestBookingScreen({
    super.key, 
    this.selectedPartner,
    this.initialDescription,
    this.initialDestination,
  });

  @override
  State<FreedomRequestBookingScreen> createState() => _FreedomRequestBookingScreenState();
}

class _FreedomRequestBookingScreenState extends State<FreedomRequestBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  final _pickupController = TextEditingController();
  late final TextEditingController _destinationController;
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();

  // Multi-Layanan State
  bool _addAdditionalService = false;
  bool _addAntarJemput = false;
  bool _addHangout = false;

  // Additional Antar Jemput
  final _addPickupController = TextEditingController();
  final _addDestinationController = TextEditingController();
  final _addPickupDateController = TextEditingController();
  final _addPickupTimeController = TextEditingController();
  final _addAntarJemputNotesController = TextEditingController();

  // Additional Hangout
  String _addHangoutActivity = 'Ngopi';
  final _addHangoutLocationController = TextEditingController();
  final _addHangoutDateController = TextEditingController();
  final _addHangoutTimeController = TextEditingController();
  final _addHangoutNotesController = TextEditingController();
  int _selectedAddHangoutDurationIndex = 0;

  // Custom Offer Price State
  final _userOfferPriceController = TextEditingController();

  // Add-ons State (Inside Antar Jemput only)
  bool _useCar = false;
  bool _rentHelmet = false;
  bool _differentArea = false;
  bool _isWeekendApplied = false;

  String _selectedClass = 'Gold';
  dynamic _selectedDriverId = '';
  String _selectedDriverName = '';
  String _selectedDriverImage = '';
  double _selectedDriverRating = 0.0;
  int _selectedDriverBasePrice = 70000; // default Gold
  String _selectedDriverVehicle = '';
  int _selectedDriverTrips = 0;

  final List<String> _classes = ['Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'VVIP'];

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.initialDescription ?? '');
    _destinationController = TextEditingController(text: widget.initialDestination ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DriverProvider>(context, listen: false).fetchDrivers();
    });

    if (widget.selectedPartner != null) {
      _selectedDriverName = widget.selectedPartner!['name'] ?? '';
      _selectedDriverImage = widget.selectedPartner!['image'] ?? '';
      _selectedDriverRating = widget.selectedPartner!['rating'] is String 
          ? double.parse(widget.selectedPartner!['rating']) 
          : (widget.selectedPartner!['rating']?.toDouble() ?? 0.0);
      _selectedDriverVehicle = widget.selectedPartner!['vehicle'] ?? '';
      _selectedDriverId = widget.selectedPartner!['id'] ?? '';
      _selectedDriverBasePrice = widget.selectedPartner!['price'] is int 
          ? widget.selectedPartner!['price'] 
          : 70000;
      _selectedDriverTrips = widget.selectedPartner!['kpi'] is int 
          ? (widget.selectedPartner!['kpi'] as int) * 2 
          : 120;
      
      final incomingClass = widget.selectedPartner!['type'] ?? 'Gold';
      if (_classes.contains(incomingClass)) {
        _selectedClass = incomingClass;
      }
    }
  }

  void _updateRecommendedUserOfferPrice() {
    double distance = 10.0;
    double perKmRate = 0;
    switch (_selectedClass) {
      case 'Bronze':
        perKmRate = 4000;
        break;
      case 'Silver':
        perKmRate = 5500;
        break;
      case 'Gold':
        perKmRate = 7500;
        break;
      case 'Platinum':
        perKmRate = 10000;
        break;
      case 'Diamond':
        perKmRate = 15000;
        break;
      case 'VVIP':
        perKmRate = 25000;
        break;
      default:
        perKmRate = 7500;
    }
    int recommended = _selectedDriverBasePrice + (distance * perKmRate).toInt();
    _userOfferPriceController.text = recommended.toString();
  }

  void _checkWeekend(DateTime date) {
    setState(() {
      _isWeekendApplied = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    });
  }

  Map<String, dynamic> _calculatePrice() {
    double distance = 10.0;
    double perKmRate = 0;
    switch (_selectedClass) {
      case 'Bronze':
        perKmRate = 4000;
        break;
      case 'Silver':
        perKmRate = 5500;
        break;
      case 'Gold':
        perKmRate = 7500;
        break;
      case 'Platinum':
        perKmRate = 10000;
        break;
      case 'Diamond':
        perKmRate = 15000;
        break;
      case 'VVIP':
        perKmRate = 25000;
        break;
      default:
        perKmRate = 7500;
    }
    int service1Fee = _selectedDriverBasePrice + (distance * perKmRate).toInt();

    int serviceAntarJemputFee = 0;
    int serviceHangoutFee = 0;

    if (_addAdditionalService) {
      if (_addAntarJemput) {
        serviceAntarJemputFee = (15.0 * 5000).toInt();
      }
      if (_addHangout) {
        int duration = [3, 6, 9][_selectedAddHangoutDurationIndex];
        serviceHangoutFee = duration * 50000;
      }
    }

    int service2Fee = serviceAntarJemputFee + serviceHangoutFee;

    int carAddon = (_addAntarJemput && _useCar) ? 50000 : 0;
    int helmetAddon = (_addAntarJemput && _rentHelmet) ? 10000 : 0;
    int areaAddon = (_addAntarJemput && _differentArea) ? 20000 : 0;

    int subtotal = service1Fee + service2Fee + carAddon + helmetAddon + areaAddon;
    int weekendFee = _isWeekendApplied ? (subtotal * 0.25).toInt() : 0;

    int totalEstimasi = subtotal + weekendFee;
    int dp = (totalEstimasi * 0.5).toInt();
    int remainingPayment = totalEstimasi - dp;

    return {
      'service1Fee': service1Fee,
      'service2Fee': service2Fee,
      'serviceAntarJemputFee': serviceAntarJemputFee,
      'serviceHangoutFee': serviceHangoutFee,
      'weekendFee': weekendFee,
      'totalEstimasi': totalEstimasi,
      'dp': dp,
      'remaining': remainingPayment,
    };
  }

  @override
  Widget build(BuildContext context) {
    final driverProvider = Provider.of<DriverProvider>(context);
    final drivers = driverProvider.drivers;

    final Map<String, List<Map<String, dynamic>>> driversByClass = {
      'Bronze': [],
      'Silver': [],
      'Gold': [],
      'Platinum': [],
      'Diamond': [],
      'VVIP': [],
    };

    for (var d in drivers) {
      final type = d['type'] ?? 'Gold';
      if (driversByClass.containsKey(type)) {
        driversByClass[type]!.add(d);
      } else {
        driversByClass['Gold']!.add(d);
      }
    }

    final currentClassDrivers = driversByClass[_selectedClass] ?? [];
    if (_selectedDriverId == '' && currentClassDrivers.isNotEmpty) {
      final defaultDriver = currentClassDrivers[0];
      _selectedDriverId = defaultDriver['id'];
      _selectedDriverName = defaultDriver['name'];
      _selectedDriverImage = defaultDriver['image'];
      _selectedDriverRating = double.tryParse(defaultDriver['rating']?.toString() ?? '0.0') ?? 4.5;
      _selectedDriverBasePrice = defaultDriver['price'];
      _selectedDriverVehicle = defaultDriver['vehicle'];
      _selectedDriverTrips = defaultDriver['kpi'] * 2;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateRecommendedUserOfferPrice();
      });
    }

    final prices = _calculatePrice();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          "Freedom Request",
          style: GoogleFonts.inter(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast),
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
                _buildSectionTitle("Deskripsi Request (Terbuka)"),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _descriptionController,
                  hint: "Tuliskan apa saja yang perlu dibantu (misal: antre tiket, titip makanan, bawakan barang, dll.)",
                  icon: Icons.edit_note_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),

                _buildSectionTitle("Lokasi Request / Titik Mulai"),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _pickupController,
                  hint: "Masukkan titik pengerjaan / lokasi toko / pengambilan",
                  icon: Icons.location_on_rounded,
                ),
                const SizedBox(height: 20),

                _buildSectionTitle("Lokasi Tujuan (Opsional)"),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _destinationController,
                  hint: "Masukkan lokasi pengantaran / tujuan akhir",
                  icon: Icons.flag_rounded,
                  requiredField: false,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("Tanggal"),
                          const SizedBox(height: 10),
                          _buildDateField(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("Waktu"),
                          const SizedBox(height: 10),
                          _buildTimeField(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                _buildSectionTitle("Klasifikasi Driver"),
                const SizedBox(height: 10),
                _buildClassChips(),
                const SizedBox(height: 20),

                _buildSectionTitle("Pilih Partner (${_selectedClass})"),
                const SizedBox(height: 10),
                _buildDriverSelector(driversByClass),
                const SizedBox(height: 25),

                // Multi-Layanan Section
                _buildMultiServiceSection(),
                const SizedBox(height: 25),

                _buildSectionTitle("Tawaran Harga Anda (Layanan Utama)"),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _userOfferPriceController,
                  hint: "Masukkan penawaran harga Anda (misal: 150000)",
                  icon: Icons.payments_rounded,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 30),

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
        validator: requiredField
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'Field ini harus diisi';
                }
                return null;
              }
            : null,
      ),
    );
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
            final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
            final dayName = days[date.weekday - 1];
            _dateController.text = "$dayName, ${date.day} ${months[date.month - 1]} ${date.year}";
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryPink, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _dateController.text.isEmpty ? "Pilih tanggal" : _dateController.text,
                style: GoogleFonts.inter(
                  color: _dateController.text.isEmpty ? AppTheme.textMuted : AppTheme.textHighContrast,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
          initialTime: TimeOfDay.now(),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: AppTheme.primaryPink, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _timeController.text.isEmpty ? "Pilih waktu" : _timeController.text,
                style: GoogleFonts.inter(
                  color: _timeController.text.isEmpty ? AppTheme.textMuted : AppTheme.textHighContrast,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassChips() {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _classes.length,
        itemBuilder: (context, index) {
          final c = _classes[index];
          final isSelected = _selectedClass == c;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedClass = c;
                _selectedDriverId = '';
                _updateRecommendedUserOfferPrice();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryPink : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppTheme.primaryPink : AppTheme.border),
              ),
              child: Text(
                c,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : AppTheme.textHighContrast,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDriverSelector(Map<String, List<Map<String, dynamic>>> driversByClass) {
    final list = driversByClass[_selectedClass] ?? [];
    
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        alignment: Alignment.center,
        child: Text(
          "Tidak ada mitra kelas $_selectedClass yang aktif",
          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: list.map((driver) {
          return RadioListTile<dynamic>(
            value: driver['id'],
            groupValue: _selectedDriverId,
            onChanged: (value) {
              setState(() {
                _selectedDriverId = value!;
                final match = list.firstWhere((d) => d['id'] == _selectedDriverId);
                _selectedDriverName = match['name'];
                _selectedDriverImage = match['image'];
                _selectedDriverRating = double.tryParse(match['rating']?.toString() ?? '0.0') ?? 4.5;
                _selectedDriverBasePrice = match['price'];
                _selectedDriverVehicle = match['vehicle'];
                _selectedDriverTrips = match['kpi'] * 2;
                _updateRecommendedUserOfferPrice();
              });
            },
            activeColor: AppTheme.primaryPink,
            title: Text(
              driver['name'],
              style: GoogleFonts.inter(
                color: AppTheme.textHighContrast,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              "${driver['vehicle']} • ⭐ ${driver['rating']} • ${driver['gender']}",
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
            secondary: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Rp ${driver['price'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryPink,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "Base Request",
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMultiServiceSection() {
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              _addAdditionalService = !_addAdditionalService;
              if (!_addAdditionalService) {
                _addAntarJemput = false;
                _addHangout = false;
                _useCar = false;
                _rentHelmet = false;
                _differentArea = false;
              }
            }),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Multi-Layanan (Tambah Layanan)",
                        style: GoogleFonts.inter(
                          color: AppTheme.textHighContrast,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Pesan layanan lain dengan driver yang sama sekaligus",
                        style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Switch(
                  value: _addAdditionalService,
                  onChanged: (value) => setState(() {
                    _addAdditionalService = value;
                    if (!value) {
                      _addAntarJemput = false;
                      _addHangout = false;
                      _useCar = false;
                      _rentHelmet = false;
                      _differentArea = false;
                    }
                  }),
                  activeColor: AppTheme.primaryPink,
                ),
              ],
            ),
          ),
          if (_addAdditionalService) ...[
            const Divider(color: AppTheme.border, height: 25),
            
            // Checkbox 1: Antar Jemput
            CheckboxListTile(
              value: _addAntarJemput,
              onChanged: (val) => setState(() {
                _addAntarJemput = val!;
                if (!val) {
                  _useCar = false;
                  _rentHelmet = false;
                  _differentArea = false;
                }
              }),
              activeColor: AppTheme.primaryPink,
              checkColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              title: Text("Layanan Antar Jemput", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text("Tambahkan rute perjalanan antar-jemput", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
            ),
            if (_addAntarJemput) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDeep,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _addPickupController,
                      hint: "Lokasi Penjemputan Tambahan",
                      icon: Icons.location_on_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _addDestinationController,
                      hint: "Lokasi Tujuan Antar Tambahan",
                      icon: Icons.flag_rounded,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCustomDateField(
                            controller: _addPickupDateController,
                            label: "Pilih tanggal",
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCustomTimeField(
                            controller: _addPickupTimeController,
                            label: "Pilih waktu",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _addAntarJemputNotesController,
                      hint: "Catatan khusus (misal: jemput di lobi timur)",
                      icon: Icons.note_add_rounded,
                    ),
                    const Divider(color: AppTheme.border, height: 25),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Add-ons & Biaya Tambahan (Antar Jemput)",
                        style: TextStyle(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 5),
                    CheckboxListTile(
                      value: _useCar,
                      onChanged: (val) => setState(() => _useCar = val!),
                      activeColor: AppTheme.primaryPink,
                      checkColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      title: Text("Gunakan Mobil", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13)),
                      subtitle: Text("Sesuai standar operasional premium (+Rp 50.000)", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
                    ),
                    CheckboxListTile(
                      value: _rentHelmet,
                      onChanged: (val) => setState(() => _rentHelmet = val!),
                      activeColor: AppTheme.primaryPink,
                      checkColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      title: Text("Sewa Helm Ekstra", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13)),
                      subtitle: Text("Helm ekstra bersih dan steril (+Rp 10.000)", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
                    ),
                    CheckboxListTile(
                      value: _differentArea,
                      onChanged: (val) => setState(() => _differentArea = val!),
                      activeColor: AppTheme.primaryPink,
                      checkColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      title: Text("Beda Area Layanan", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13)),
                      subtitle: Text("Biaya tambahan penugasan beda wilayah (+Rp 20.000)", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
                    ),
                  ],
                ),
              ),
            ],
            
            const Divider(color: AppTheme.border, height: 25),
            
            // Checkbox 2: Hangout Partner
            CheckboxListTile(
              value: _addHangout,
              onChanged: (val) => setState(() => _addHangout = val!),
              activeColor: AppTheme.primaryPink,
              checkColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              title: Text("Layanan Hangout Partner", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text("Tambahkan aktivitas hangout bersama", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
            ),
            if (_addHangout) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDeep,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pilih Aktivitas Hangout",
                      style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ['Ngopi', 'Makan', 'Jalan-jalan', 'Shopping', 'Nonton'].map((activity) {
                          final isSelected = _addHangoutActivity == activity;
                          return GestureDetector(
                            onTap: () => setState(() => _addHangoutActivity = activity),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryPink : AppTheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primaryPink : AppTheme.border,
                                ),
                              ),
                              child: Text(
                                activity,
                                style: GoogleFonts.inter(
                                  color: isSelected ? Colors.white : AppTheme.textHighContrast,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _addHangoutLocationController,
                      hint: "Lokasi Hangout",
                      icon: Icons.location_on_rounded,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Pilih Paket Durasi",
                      style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(3, (index) {
                        final d = [3, 6, 9][index];
                        final isSelected = _selectedAddHangoutDurationIndex == index;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedAddHangoutDurationIndex = index),
                            child: Container(
                              margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryPink : AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? AppTheme.primaryPink : AppTheme.border),
                              ),
                              child: Text(
                                "$d Jam",
                                style: GoogleFonts.inter(
                                  color: isSelected ? Colors.white : AppTheme.textHighContrast,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCustomDateField(
                            controller: _addHangoutDateController,
                            label: "Pilih tanggal",
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCustomTimeField(
                            controller: _addHangoutTimeController,
                            label: "Pilih waktu",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _addHangoutNotesController,
                      hint: "Catatan (misal: tolong temani belanja pakaian)",
                      icon: Icons.note_add_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ]
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
          _priceRow("Freedom Request Flat Base", fmt(_selectedDriverBasePrice)),
          _priceRow("Estimasi Rute Jarak Jauh (10 km)", fmt(prices['service1Fee'] - _selectedDriverBasePrice)),
          if (_addAdditionalService && _addAntarJemput)
            _priceRow("Multi-Layanan (Antar Jemput)", fmt(prices['serviceAntarJemputFee'])),
          if (_addAdditionalService && _addHangout)
            _priceRow("Multi-Layanan (Hangout Partner)", fmt(prices['serviceHangoutFee'])),
          if (_useCar) _priceRow("Add-on Mobil", fmt(50000)),
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
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Sisa Pelunasan di Tujuan", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              Text(fmt(prices['remaining']), style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
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
          Text(label, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
          Text(value, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCustomDateField({required TextEditingController controller, required String label}) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (date != null) {
          setState(() {
            final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
            final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
            final dayName = days[date.weekday - 1];
            controller.text = "$dayName, ${date.day} ${months[date.month - 1]} ${date.year}";
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryPink, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.text.isEmpty ? label : controller.text,
                style: GoogleFonts.inter(
                  color: controller.text.isEmpty ? AppTheme.textMuted : AppTheme.textHighContrast,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTimeField({required TextEditingController controller, required String label}) {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time != null) {
          setState(() {
            final hour = time.hour.toString().padLeft(2, '0');
            final minute = time.minute.toString().padLeft(2, '0');
            controller.text = "$hour:$minute WIB";
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: AppTheme.primaryPink, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.text.isEmpty ? label : controller.text,
                style: GoogleFonts.inter(
                  color: controller.text.isEmpty ? AppTheme.textMuted : AppTheme.textHighContrast,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
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
            if (_dateController.text.isEmpty || _timeController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Pilih tanggal dan waktu terlebih dahulu")),
              );
              return;
            }

            final int userOffer = int.tryParse(_userOfferPriceController.text) ?? prices['service1Fee'];

            final bookingData = {
              'serviceType': 'freedom_request',
              'driverId': _selectedDriverId,
              'driverName': _selectedDriverName,
              'driverImage': _selectedDriverImage,
              'driverRating': _selectedDriverRating.toString(),
              'driverTrips': _selectedDriverTrips.toString(),
              'vehicle': _selectedDriverVehicle,
              'plateNumber': 'B 9999 ${_selectedDriverName.length >= 2 ? _selectedDriverName.substring(0, 2).toUpperCase() : "JKT"}',
              'pickup': _pickupController.text,
              'destination': _destinationController.text.isEmpty ? 'Tujuan Sesuai Request' : _destinationController.text,
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
              
              // Multi service details
              'hasAdditionalService': _addAdditionalService,
              'hasAntarJemput': _addAntarJemput,
              'hasHangout': _addHangout,
              'additionalServiceFee': prices['service2Fee'],
              'serviceAntarJemputFee': prices['serviceAntarJemputFee'],
              'serviceHangoutFee': prices['serviceHangoutFee'],
              
              // Antar Jemput details
              'additionalPickup': _addPickupController.text,
              'additionalDestination': _addDestinationController.text,
              'additionalPickupDate': _addPickupDateController.text.isNotEmpty ? _addPickupDateController.text : _dateController.text,
              'additionalPickupTime': _addPickupTimeController.text.isNotEmpty ? _addPickupTimeController.text : _timeController.text,
              'additionalAntarJemputNotes': _addAntarJemputNotesController.text,
              
              // Hangout details
              'additionalActivity': _addHangoutActivity,
              'additionalHangoutLocation': _addHangoutLocationController.text,
              'additionalDuration': ([3, 6, 9][_selectedAddHangoutDurationIndex]).toString(),
              'additionalHangoutDate': _addHangoutDateController.text.isNotEmpty ? _addHangoutDateController.text : _dateController.text,
              'additionalHangoutTime': _addHangoutTimeController.text.isNotEmpty ? _addHangoutTimeController.text : _timeController.text,
              'additionalHangoutNotes': _addHangoutNotesController.text,
              
              // Addons
              'useCar': _useCar,
              'rentHelmet': _rentHelmet,
              'differentArea': _differentArea,
              'weekendFee': prices['weekendFee'],
              'notes': _notesController.text,
              'estimatedTime': '35',
              'driverClass': _selectedClass,
            };

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
          "Lanjutkan ke Negosiasi",
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
