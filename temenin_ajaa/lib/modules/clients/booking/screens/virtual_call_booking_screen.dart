import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'booking_confirmation_screen.dart';

class VirtualCallBookingScreen extends StatefulWidget {
  final String serviceType; // e.g. 'telepon' or 'virtual_chat'
  final Map<String, dynamic>? selectedPartner;
  
  const VirtualCallBookingScreen({
    super.key,
    this.serviceType = 'telepon',
    this.selectedPartner,
  });

  @override
  State<VirtualCallBookingScreen> createState() => _VirtualCallBookingScreenState();
}

class _VirtualCallBookingScreenState extends State<VirtualCallBookingScreen> {
  int _selectedDuration = 60; // minutes
  String _selectedTopic = 'Relationship Counseling & Masalah Pasangan';
  String _callType = 'VOICE'; // 'VOICE' or 'VC'
  String _callPlatform = 'WA'; // 'WA' (WhatsApp Call) or 'APP' (In-App Call)
  final TextEditingController _waPhoneController = TextEditingController();
  DateTime _scheduledTime = DateTime.now().add(const Duration(minutes: 10));
  bool _isInstant = true;

  final int _ratePerHour = 35000; // Rp 35.000 / jam

  final List<int> _durations = [30, 60, 90, 120];
  final List<String> _topics = [
    'Relationship Counseling & Masalah Pasangan',
    'Mendengarkan Curhat & Validasi Emosi',
    'Teman Cerita Santai & Bertukar Pikiran',
    'Dukungan Mental & Solusi Masalah',
  ];

  @override
  void dispose() {
    _waPhoneController.dispose();
    super.dispose();
  }

  int get _calculatedPrice {
    return ((_selectedDuration / 60) * _ratePerHour).round();
  }

  void _proceedToConfirmation() {
    final now = DateTime.now();
    final platformStr = _callPlatform == 'WA' ? 'WhatsApp Call' : 'In-App Encrypted Call';
    final waNote = (_callPlatform == 'WA' && _waPhoneController.text.trim().isNotEmpty)
        ? ' (No WA: ${_waPhoneController.text.trim()})'
        : '';
    final Map<String, dynamic> bookingDetails = {
      'serviceType': 'Relationship Counseling (Online by WA)',
      'service_category': 'VIRTUAL',
      'call_type': _callType,
      'call_platform': platformStr,
      'chat_topic': _selectedTopic,
      'call_duration_minutes': _selectedDuration,
      'duration': _selectedDuration,
      'is_instant': _isInstant,
      'scheduled_time': _scheduledTime.toIso8601String(),
      'serviceFee': _calculatedPrice,
      'insuranceFee': 0,
      'totalPayment': _calculatedPrice,
      'baseCost': _calculatedPrice,
      'dp': (_calculatedPrice * 0.5).round(),
      'remainingPayment': (_calculatedPrice * 0.5).round(),
      'note': 'Konseling Curhat via $platformStr$_selectedDuration Menit - Topik: $_selectedTopic$waNote',
      'pickup': 'Sesi $platformStr (${_selectedDuration} Menit)',
      'destination': 'Topik: $_selectedTopic',
      'date': 'Hari Ini, ${now.day}/${now.month}/${now.year}',
      'time': _isInstant ? 'Mulai Sekarang' : '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')} WIB',
      'estimatedTime': '$_selectedDuration',
      'vehicle': platformStr,
      'plateNumber': _callPlatform == 'WA' ? 'WA Call Direct' : 'Enkripsi P2P',
      'driverClass': 'Counselor Partner',
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
          "Konseling & Curhat Online",
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
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Relationship Counseling & Curhat",
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Sesi percakapan suara pribadi online via WhatsApp atau panggilan in-app.",
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.selectedPartner != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(
                          widget.selectedPartner!['avatar_url'] ??
                          widget.selectedPartner!['image'] ??
                          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.selectedPartner!['name'] ?? 'Mitra')}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Mitra Terpilih: ${widget.selectedPartner!['name'] ?? 'Mitra Temenin'}",
                              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              "⭐ ${widget.selectedPartner!['rating'] ?? '5.0'} • Siap Mendengarkan",
                              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Platform Panggilan Selection (WA vs In-App)
              Text(
                "Metode Hubung / Platform",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _callPlatform = 'WA'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _callPlatform == 'WA' ? const Color(0xFF10B981).withOpacity(0.15) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _callPlatform == 'WA' ? const Color(0xFF10B981) : AppTheme.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat_rounded, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "WhatsApp Call",
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _callPlatform == 'WA' ? const Color(0xFF10B981) : AppTheme.textHighContrast,
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
                      onTap: () => setState(() => _callPlatform = 'APP'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _callPlatform == 'APP' ? AppTheme.primaryPink.withOpacity(0.15) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _callPlatform == 'APP' ? AppTheme.primaryPink : AppTheme.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_rounded, color: _callPlatform == 'APP' ? AppTheme.primaryPink : AppTheme.textMediumContrast, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "In-App Enkripsi",
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _callPlatform == 'APP' ? AppTheme.primaryPink : AppTheme.textHighContrast,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (_callPlatform == 'WA') ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: TextField(
                    controller: _waPhoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Nomor WhatsApp Anda (Contoh: 08123456789)",
                      hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                      prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF10B981), size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Mode Panggilan Selection
              Text(
                "Tipe Panggilan",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _callType = 'VOICE'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _callType == 'VOICE' ? AppTheme.primaryPink.withOpacity(0.15) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _callType == 'VOICE' ? AppTheme.primaryPink : AppTheme.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic_rounded, color: _callType == 'VOICE' ? AppTheme.primaryPink : AppTheme.textMediumContrast),
                            const SizedBox(width: 8),
                            Text(
                              "Voice Call (Suara)",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _callType == 'VOICE' ? AppTheme.primaryPink : AppTheme.textHighContrast,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Opacity(
                      opacity: 0.6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.videocam_rounded, color: AppTheme.textMediumContrast),
                            const SizedBox(width: 6),
                            Text(
                              "Video Call",
                              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMediumContrast),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Soon",
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Duration Selection
              Text(
                "Pilih Durasi Panggilan",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _durations.map((duration) {
                  final isSelected = _selectedDuration == duration;
                  return ChoiceChip(
                    label: Text("$duration Menit"),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryPink,
                    backgroundColor: AppTheme.surface,
                    labelStyle: GoogleFonts.inter(
                      color: isSelected ? Colors.white : AppTheme.textHighContrast,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedDuration = duration);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Chat Topic Selection
              Text(
                "Topik Percakapan Utama",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
              ),
              const SizedBox(height: 10),
              Column(
                children: _topics.map((topic) {
                  final isSelected = _selectedTopic == topic;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedTopic = topic),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            ),
                            const SizedBox(width: 12),
                            Text(
                              topic,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: AppTheme.textHighContrast,
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

              // Time Preference
              Text(
                "Waktu Memulai Panggilan",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "Langsung Panggil (Instant)",
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textHighContrast),
                ),
                subtitle: Text(
                  "Partner akan langsung menghubungi Anda setelah bayar.",
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMediumContrast),
                ),
                value: _isInstant,
                activeColor: AppTheme.primaryPink,
                onChanged: (val) => setState(() => _isInstant = val),
              ),

              const SizedBox(height: 30),

              // Price Summary & Order Button
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
                          "Total Biaya Sesi",
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
