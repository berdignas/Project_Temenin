// lib/modules/booking/screens/antar_jemput_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/providers/driver_provider.dart';
import 'booking_confirmation_screen.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';

class AntarJemputBookingScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedPartner;
  final String serviceType;
  
  const AntarJemputBookingScreen({
    super.key, 
    this.selectedPartner,
    this.serviceType = 'regular',
  });

  @override
  State<AntarJemputBookingScreen> createState() => _AntarJemputBookingScreenState();
}

class _AntarJemputBookingScreenState extends State<AntarJemputBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Multi-Layanan State
  bool _addAdditionalService = false;
  String _additionalServiceType = 'hangout'; // or 'freedom'
  String _addHangoutActivity = 'Ngopi';
  final _addHangoutDurationController = TextEditingController(text: '3');
  final _addFreedomDescriptionController = TextEditingController();
  final _addFreedomLocationController = TextEditingController();

  // Add-ons State
  bool _pulangPergi = false;
  bool _useCar = false;
  bool _rentHelmet = false;
  bool _differentArea = false;
  bool _isWeekendApplied = false;

  dynamic _selectedDriverId = '';
  String _selectedDriverName = '';
  String _selectedDriverImage = '';
  double _selectedDriverRating = 0.0;
  int _selectedDriverPrice = 0; // price per km
  String _selectedDriverVehicle = '';
  int _selectedDriverTrips = 0;
  String _selectedDriverClass = 'Gold';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DriverProvider>(context, listen: false).fetchDrivers();
    });

    if (widget.selectedPartner != null) {
      _selectedDriverId = widget.selectedPartner!['id'] ?? '';
      _selectedDriverName = widget.selectedPartner!['name'] ?? '';
      _selectedDriverImage = widget.selectedPartner!['image'] ?? '';
      _selectedDriverRating = widget.selectedPartner!['rating'] is String 
          ? double.parse(widget.selectedPartner!['rating']) 
          : (widget.selectedPartner!['rating']?.toDouble() ?? 0.0);
      _selectedDriverVehicle = widget.selectedPartner!['vehicle'] ?? '';
      _selectedDriverPrice = widget.selectedPartner!['price'] is int 
          ? widget.selectedPartner!['price'] 
          : 5000;
      _selectedDriverTrips = widget.selectedPartner!['kpi'] is int 
          ? (widget.selectedPartner!['kpi'] as int) * 2 
          : 120;
      _selectedDriverClass = widget.selectedPartner!['type'] ?? 'Gold';
    }
  }

  void _checkWeekend(DateTime date) {
    setState(() {
      _isWeekendApplied = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    });
  }

  Map<String, dynamic> _calculatePrice() {
    const double distance = 15.0; // Simulated trip distance of 15 km
    
    // Service 1: Antar Jemput. Pulang Pergi doubles the distance/trip fee
    double baseService1Price = (distance * _selectedDriverPrice);
    if (_pulangPergi) {
      baseService1Price *= 2.0;
    }
    int service1Fee = baseService1Price.toInt();

    // Service 2: If Multi-Layanan is checked
    int service2Fee = 0;
    if (_addAdditionalService) {
      if (_additionalServiceType == 'hangout') {
        int duration = int.tryParse(_addHangoutDurationController.text) ?? 3;
        service2Fee = duration * 50000;
      } else {
        service2Fee = 100000; // Flat fee for basic freedom request
      }
    }

    // Add-ons
    int carAddon = _useCar ? 50000 : 0;
    int helmetAddon = _rentHelmet ? 10000 : 0;
    int areaAddon = _differentArea ? 20000 : 0;

    int subtotal = service1Fee + service2Fee + carAddon + helmetAddon + areaAddon;
    
    // Weekend Surcharge +25%
    int weekendFee = _isWeekendApplied ? (subtotal * 0.25).toInt() : 0;

    int totalEstimasi = subtotal + weekendFee;
    int dp = (totalEstimasi * 0.5).toInt();
    int remainingPayment = totalEstimasi - dp;

    return {
      'service1Fee': service1Fee,
      'service2Fee': service2Fee,
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
    final prices = _calculatePrice();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          "Form Antar Jemput",
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
                _buildSectionTitle("Lokasi Penjemputan"),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _pickupController,
                  hint: "Masukkan lokasi penjemputan",
                  icon: Icons.location_on_rounded,
                ),
                const SizedBox(height: 20),
                
                _buildSectionTitle("Lokasi Tujuan"),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _destinationController,
                  hint: "Masukkan lokasi tujuan",
                  icon: Icons.flag_rounded,
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
                
                _buildSectionTitle("Pilih Driver Anda"),
                const SizedBox(height: 10),
                _buildDriverSelector(drivers),
                const SizedBox(height: 25),
                
                // Multi-Layanan Section
                _buildMultiServiceSection(),
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
                  maxLines: 3,
                ),
                const SizedBox(height: 30),
                
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
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Field ini harus diisi';
          }
          return null;
        },
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
            _dateController.text = "${date.day}/${date.month}/${date.year}";
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
            const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryPink, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _dateController.text.isEmpty ? "Pilih Tanggal" : _dateController.text,
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
            _timeController.text = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
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
            const Icon(Icons.access_time_rounded, color: AppTheme.primaryPink, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _timeController.text.isEmpty ? "Pilih Jam" : _timeController.text,
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

  Widget _buildDriverSelector(List<Map<String, dynamic>> drivers) {
    if (drivers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Text(
            "Sedang memuat data partner driver...",
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: drivers.map((driver) {
          int rateKm = driver['price'] is int ? driver['price'] : 5000;
          if (_useCar) rateKm = (rateKm * 1.5).toInt();
          final int finalRateKm = rateKm;

          return RadioListTile<dynamic>(
            value: driver['id'],
            groupValue: _selectedDriverId,
            onChanged: (value) {
              setState(() {
                _selectedDriverId = value!;
                final selectedDriver = drivers.firstWhere((d) => d['id'] == _selectedDriverId);
                _selectedDriverName = selectedDriver['name'];
                _selectedDriverImage = selectedDriver['image'] ?? '';
                _selectedDriverRating = double.tryParse(selectedDriver['rating']?.toString() ?? '0.0') ?? 4.5;
                _selectedDriverPrice = finalRateKm;
                _selectedDriverVehicle = selectedDriver['vehicle'] ?? 'Motor';
                _selectedDriverTrips = (selectedDriver['kpi'] ?? 60) * 2;
                _selectedDriverClass = selectedDriver['type'] ?? 'Gold';
              });
            },
            activeColor: AppTheme.primaryPink,
            title: Row(
              children: [
                Text(
                  driver['name'],
                  style: GoogleFonts.inter(
                    color: AppTheme.textHighContrast,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.fuchsiaLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    driver['type'] ?? 'Gold',
                    style: const TextStyle(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
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
                  "Rp $finalRateKm",
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryPink,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "/km",
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
            onTap: () => setState(() => _addAdditionalService = !_addAdditionalService),
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
                        "Pesan hangout/freedom dengan driver yang sama",
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
                  onChanged: (value) => setState(() => _addAdditionalService = value),
                  activeColor: AppTheme.primaryPink,
                ),
              ],
            ),
          ),
          if (_addAdditionalService) ...[
            const Divider(color: AppTheme.border, height: 25),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("Hangout Partner")),
                    selected: _additionalServiceType == 'hangout',
                    onSelected: (selected) {
                      if (selected) setState(() => _additionalServiceType = 'hangout');
                    },
                    selectedColor: AppTheme.primaryPink,
                    labelStyle: TextStyle(
                      color: _additionalServiceType == 'hangout' ? Colors.white : AppTheme.textHighContrast,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("Freedom Request")),
                    selected: _additionalServiceType == 'freedom',
                    onSelected: (selected) {
                      if (selected) setState(() => _additionalServiceType = 'freedom');
                    },
                    selectedColor: AppTheme.primaryPink,
                    labelStyle: TextStyle(
                      color: _additionalServiceType == 'freedom' ? Colors.white : AppTheme.textHighContrast,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (_additionalServiceType == 'hangout') ...[
              DropdownButtonFormField<String>(
                value: _addHangoutActivity,
                dropdownColor: AppTheme.surface,
                style: GoogleFonts.inter(color: AppTheme.textHighContrast),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.people_alt_rounded, color: AppTheme.primaryPink),
                  labelText: "Pilih Aktivitas Hangout",
                  labelStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
                items: ['Ngopi', 'Makan', 'Jalan-jalan', 'Shopping', 'Nonton']
                    .map((act) => DropdownMenuItem(value: act, child: Text(act)))
                    .toList(),
                onChanged: (val) => setState(() => _addHangoutActivity = val!),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _addHangoutDurationController,
                hint: "Durasi Hangout (Jam: 3, 6, atau 9)",
                icon: Icons.timer_rounded,
                keyboardType: TextInputType.number,
              ),
            ] else ...[
              _buildTextField(
                controller: _addFreedomDescriptionController,
                hint: "Deskripsi request terbuka (misal: tolong antre, dll)",
                icon: Icons.edit_note_rounded,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _addFreedomLocationController,
                hint: "Lokasi detail request pengerjaan",
                icon: Icons.location_on_rounded,
              ),
            ]
          ]
        ],
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
            onChanged: (val) => setState(() => _pulangPergi = val!),
            activeColor: AppTheme.primaryPink,
            checkColor: Colors.white,
            title: Text("Perjalanan Pulang Pergi (PP)", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text("Rute tempuh ganda otomatis (+100% biaya jemput)", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
          ),
          const Divider(color: AppTheme.border, height: 10),
          CheckboxListTile(
            value: _useCar,
            onChanged: (val) => setState(() => _useCar = val!),
            activeColor: AppTheme.primaryPink,
            checkColor: Colors.white,
            title: Text("Gunakan Mobil", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text("Mobil eksklusif ber-AC (+Rp 50.000)", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
          ),
          const Divider(color: AppTheme.border, height: 10),
          CheckboxListTile(
            value: _rentHelmet,
            onChanged: (val) => setState(() => _rentHelmet = val!),
            activeColor: AppTheme.primaryPink,
            checkColor: Colors.white,
            title: Text("Sewa Helm Ekstra", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text("Helm ekstra bersih dan steril (+Rp 10.000)", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
          ),
          const Divider(color: AppTheme.border, height: 10),
          CheckboxListTile(
            value: _differentArea,
            onChanged: (val) => setState(() => _differentArea = val!),
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
          _priceRow("Antar Jemput (15 km)", fmt(prices['service1Fee'])),
          if (_addAdditionalService)
            _priceRow(
              _additionalServiceType == 'hangout' ? "Multi-Layanan (Hangout)" : "Multi-Layanan (Freedom Request)",
              fmt(prices['service2Fee']),
            ),
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
            if (_selectedDriverId == '' || _selectedDriverId == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Pilih driver terlebih dahulu")),
              );
              return;
            }
            if (_dateController.text.isEmpty || _timeController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Pilih tanggal dan waktu terlebih dahulu")),
              );
              return;
            }
            
            const distance = 15;
            
            final bookingData = {
              'serviceType': 'antar_jemput',
              'driverId': _selectedDriverId,
              'driverName': _selectedDriverName,
              'driverImage': _selectedDriverImage,
              'driverRating': _selectedDriverRating.toString(),
              'driverTrips': _selectedDriverTrips.toString(),
              'vehicle': _selectedDriverVehicle,
              'plateNumber': 'B 1234 ${_selectedDriverName.length >= 2 ? _selectedDriverName.substring(0, 2).toUpperCase() : "JKT"}',
              'pickup': _pickupController.text,
              'destination': _destinationController.text,
              'date': _dateController.text,
              'time': _timeController.text,
              
              // Pricing Details
              'serviceFee': prices['service1Fee'],
              'insuranceFee': 10000,
              'totalPayment': prices['totalEstimasi'] + 10000,
              'dp': prices['dp'] + 5000, // DP includes 50% insurance
              'remainingPayment': prices['remaining'] + 5000,
              'estimatedTime': (distance * 3).toString(),
              
              // Multi service details
              'hasAdditionalService': _addAdditionalService,
              'additionalServiceType': _additionalServiceType,
              'additionalServiceFee': prices['service2Fee'],
              'additionalActivity': _addHangoutActivity,
              'additionalDuration': _addHangoutDurationController.text,
              'additionalDescription': _addFreedomDescriptionController.text,
              'additionalLocation': _addFreedomLocationController.text,
              
              // Addons
              'pulangPergi': _pulangPergi,
              'useCar': _useCar,
              'rentHelmet': _rentHelmet,
              'differentArea': _differentArea,
              'weekendFee': prices['weekendFee'],
              'notes': _notesController.text,
              'driverClass': _selectedDriverClass,
            };
            
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
          "Booking Sekarang",
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