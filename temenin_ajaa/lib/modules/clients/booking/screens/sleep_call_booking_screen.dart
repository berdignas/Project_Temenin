import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'booking_confirmation_screen.dart';

class SleepCallBookingScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedPartner;

  const SleepCallBookingScreen({super.key, this.selectedPartner});

  @override
  State<SleepCallBookingScreen> createState() => _SleepCallBookingScreenState();
}

class _SleepCallBookingScreenState extends State<SleepCallBookingScreen> {
  int _selectedHours = 6; // default 6 jam paket malam
  TimeOfDay _wakeUpTime = const TimeOfDay(hour: 5, minute: 30);
  String _selectedAlarmMethod = 'Nada Alarm Soft + Panggil Nama';
  final TextEditingController _notesController = TextEditingController();

  final Map<int, int> _packagePrices = {
    4: 45000, // Paket 4 jam = Rp 45.000
    6: 60000, // Paket 6 jam = Rp 60.000
    8: 75000, // Paket 8 jam = Rp 75.000
  };

  final List<String> _alarmMethods = [
    'Nada Alarm Soft + Panggil Nama',
    'Panggilan Suara Langsung (Bisik / Santai)',
    'Spam Call / Panggil Berulang Sampai Bangun',
  ];

  int get _calculatedPrice => _packagePrices[_selectedHours] ?? 60000;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectWakeUpTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _wakeUpTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryPink,
              onPrimary: Colors.white,
              surface: AppTheme.surface,
              onSurface: AppTheme.textHighContrast,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _wakeUpTime) {
      setState(() => _wakeUpTime = picked);
    }
  }

  void _proceedToConfirmation() {
    final now = DateTime.now();
    final wakeUpDateTime = DateTime(
      now.year,
      now.month,
      now.day + (now.hour >= 18 ? 1 : 0), // if ordered at night, wake up is tomorrow
      _wakeUpTime.hour,
      _wakeUpTime.minute,
    );

    final Map<String, dynamic> bookingDetails = {
      'serviceType': 'Sleep Call (Night Companion)',
      'service_category': 'VIRTUAL',
      'call_type': 'SLEEP',
      'call_duration_minutes': _selectedHours * 60,
      'duration': _selectedHours * 60,
      'wake_up_time': wakeUpDateTime.toIso8601String(),
      'wake_up_method': _selectedAlarmMethod,
      'serviceFee': _calculatedPrice,
      'insuranceFee': 0,
      'totalPayment': _calculatedPrice,
      'baseCost': _calculatedPrice,
      'dp': (_calculatedPrice * 0.5).round(),
      'remainingPayment': (_calculatedPrice * 0.5).round(),
      'note': 'Sleep Call Paket $_selectedHours Jam. Alarm: ${_wakeUpTime.format(context)} ($_selectedAlarmMethod). ${_notesController.text.trim()}',
      'pickup': 'Sesi Sleep Call (${_selectedHours} Jam)',
      'destination': 'Alarm Bangun: ${_wakeUpTime.format(context)}',
      'date': 'Malam Ini, ${now.day}/${now.month}/${now.year}',
      'time': 'Mulai Sekarang s/d ${_wakeUpTime.format(context)} WIB',
      'estimatedTime': '${_selectedHours * 60}',
      'vehicle': 'Sleep Call Mode',
      'plateNumber': 'Enkripsi P2P',
      'driverClass': 'Night Companion',
    };

    if (widget.selectedPartner != null) {
      bookingDetails['driver'] = widget.selectedPartner;
      bookingDetails['driver_id'] = widget.selectedPartner!['id'] ?? widget.selectedPartner!['driverId'];
      bookingDetails['driverName'] = widget.selectedPartner!['full_name'] ?? widget.selectedPartner!['name'] ?? 'Mitra Temenin';
      bookingDetails['driverRating'] = widget.selectedPartner!['rating']?.toString() ?? '5.0';
      bookingDetails['driverImage'] = widget.selectedPartner!['avatar_url'] ?? widget.selectedPartner!['image'] ?? '';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(bookingData: bookingDetails),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Sleep Call (Night Companion)",
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textHighContrast,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF312E81).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bedtime_rounded, color: Colors.amber, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Teman Tidur & Wake-Up Call",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Menemani tidur agar merasa tenang & aman, serta dibangunkan tepat waktu di pagi hari.",
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Paket Durasi Malam
              Text(
                "Pilih Paket Jam Malam",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
              ),
              const SizedBox(height: 10),
              Row(
                children: _packagePrices.keys.map((hours) {
                  final price = _packagePrices[hours]!;
                  final isSelected = _selectedHours == hours;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedHours = hours),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryPink.withOpacity(0.15) : AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryPink : AppTheme.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "$hours Jam",
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppTheme.primaryPink : AppTheme.textHighContrast,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Rp ${price ~/ 1000}rb",
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMediumContrast),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Jam Bangun Tidur (Wake up Time)
              Text(
                "Jadwal Bangun Tidur (Wake-Up Alarm)",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _selectWakeUpTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alarm_rounded, color: AppTheme.primaryPink),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Jam Alarm Bangun Pagi",
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMediumContrast),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _wakeUpTime.format(context),
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textHighContrast,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_calendar_rounded, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Metode Membangunkan
              Text(
                "Metode Membangunkan",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
              ),
              const SizedBox(height: 10),
              Column(
                children: _alarmMethods.map((method) {
                  final isSelected = _selectedAlarmMethod == method;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedAlarmMethod = method),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryPink.withOpacity(0.1) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryPink : AppTheme.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? AppTheme.primaryPink : AppTheme.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                method,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: AppTheme.textHighContrast,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Notes
              Text(
                "Catatan Khusus (Optional)",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textHighContrast),
                decoration: InputDecoration(
                  hintText: "Contoh: Mohon putarkan lagu bedtime story sebelum tidur...",
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Price Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total Paket Malam",
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMediumContrast),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Rp ${_calculatedPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryPink,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _proceedToConfirmation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        "Lanjut Pembayaran",
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
