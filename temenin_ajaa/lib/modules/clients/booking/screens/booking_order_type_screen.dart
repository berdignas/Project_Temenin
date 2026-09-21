import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/core/utils/booking_date_helper.dart';
import 'antar_jemput_booking_screen.dart';
import 'hangout_booking_screen.dart';
import 'freedom_request_booking_screen.dart';
import 'sleep_call_booking_screen.dart';
import 'virtual_call_booking_screen.dart';
import 'gaming_buddy_booking_screen.dart';

class BookingOrderTypeScreen extends StatefulWidget {
  final Map<String, dynamic> partnerData;
  final String serviceType;

  const BookingOrderTypeScreen({
    super.key,
    required this.partnerData,
    this.serviceType = 'hangout',
  });

  @override
  State<BookingOrderTypeScreen> createState() => _BookingOrderTypeScreenState();
}

class _BookingOrderTypeScreenState extends State<BookingOrderTypeScreen> {
  String _bookingMode = 'now'; // 'now' or 'scheduled'
  DateTime _currentDisplayMonth = DateTime.now();
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 13, minute: 30);

  List<Map<String, dynamic>> _driverBookings = [];
  bool _isLoadingBookings = true;

  final List<String> _monthsIndo = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  final List<String> _daysIndo = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Ming'];

  String _getDayName(int weekday) {
    const names = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return names[(weekday - 1) % 7];
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _fetchDriverBookings();
  }

  Future<void> _fetchDriverBookings() async {
    setState(() => _isLoadingBookings = true);
    try {
      final supabase = Supabase.instance.client;
      final driverId = widget.partnerData['id'] ?? widget.partnerData['driverId'];
      final userId = widget.partnerData['userId'] ?? widget.partnerData['user_id'];

      String? targetDriverId = driverId?.toString();
      String? targetUserId = userId?.toString();

      if (targetDriverId != null || targetUserId != null) {
        try {
          var dQuery = supabase.from('drivers').select('id, user_id');
          if (targetDriverId != null) {
            dQuery = dQuery.or('id.eq.$targetDriverId,user_id.eq.$targetDriverId');
          } else if (targetUserId != null) {
            dQuery = dQuery.eq('user_id', targetUserId);
          }
          final dRes = await dQuery.maybeSingle();
          if (dRes != null) {
            targetDriverId = dRes['id']?.toString() ?? targetDriverId;
            targetUserId = dRes['user_id']?.toString() ?? targetUserId;
          }
        } catch (_) {}

        final List<String> orClauses = [];
        if (targetDriverId != null && targetDriverId.isNotEmpty) {
          orClauses.add('driver_id.eq.$targetDriverId');
        }
        if (targetUserId != null && targetUserId.isNotEmpty && targetUserId != targetDriverId) {
          orClauses.add('driver_id.eq.$targetUserId');
        }
        if (targetDriverId != null && targetDriverId.isNotEmpty) {
          orClauses.add('user_id.eq.$targetDriverId');
        }

        if (orClauses.isNotEmpty) {
          final List<dynamic> rows = await supabase
              .from('bookings')
              .select('*')
              .or(orClauses.join(','))
              .order('created_at', ascending: false);

          _driverBookings = List<Map<String, dynamic>>.from(rows);
        }
      }
    } catch (e) {
      debugPrint("Error fetching driver bookings in BookingOrderTypeScreen: $e");
    }

    if (mounted) {
      setState(() => _isLoadingBookings = false);
    }
  }

  int _extractBookingDurationHours(Map<String, dynamic> b) {
    final add = b['additional_details'] is Map ? b['additional_details'] as Map : null;
    final rawDur = b['duration'] ?? add?['duration'] ?? add?['duration_hours'] ?? add?['hangoutDurationHours'] ?? add?['totalHours'] ?? add?['hours'];
    if (rawDur != null) {
      final n = int.tryParse(rawDur.toString().replaceAll(RegExp(r'[^0-9]'), ''));
      if (n != null && n > 0) {
        if (n >= 30 && n % 30 == 0 && n > 24) {
          return (n / 60).ceil();
        }
        return n;
      }
    }
    return 2; // Default 2 jam
  }

  DateTime? _extractBookingDateTime(Map<String, dynamic> b) {
    final dt = BookingDateHelper.extractScheduledDateTime(b);
    if (dt != null) return dt;
    final rawCreatedAt = b['created_at']?.toString();
    if (rawCreatedAt != null && rawCreatedAt.isNotEmpty) {
      return DateTime.tryParse(rawCreatedAt);
    }
    return null;
  }

  bool _isBookingActive(String status) {
    final s = status.toLowerCase();
    return s != 'cancelled' && s != 'rejected' && s != 'declined';
  }

  bool _isBookingWaitingOrActive(String status) {
    final s = status.toLowerCase();
    return s == 'waiting_dp' ||
        s == 'dp_paid' ||
        s == 'pending' ||
        s == 'accepted' ||
        s == 'waiting_client' ||
        s == 'arrived' ||
        s == 'in_trip' ||
        s == 'ongoing' ||
        s == 'confirmed' ||
        s == 'waiting_final_payment';
  }

  List<Map<String, dynamic>> _getBookingsForDate(DateTime date) {
    return _driverBookings.where((b) {
      final status = (b['status'] ?? '').toString();
      if (!_isBookingActive(status)) return false;

      final dt = _extractBookingDateTime(b);
      if (dt == null) return false;

      return dt.year == date.year && dt.month == date.month && dt.day == date.day;
    }).toList();
  }

  List<Map<String, dynamic>> _computeHourlySlots(DateTime date, List<Map<String, dynamic>> dayBookings) {
    final List<Map<String, dynamic>> slots = [];
    for (int h = 8; h < 22; h++) {
      final slotStart = DateTime(date.year, date.month, date.day, h, 0);
      final slotEnd = DateTime(date.year, date.month, date.day, h + 1, 0);
      final slotLabel = "${h.toString().padLeft(2, '0')}:00 - ${(h + 1).toString().padLeft(2, '0')}:00";

      Map<String, dynamic>? overlappingBooking;
      DateTime? bStart;
      DateTime? bEnd;
      int bDur = 2;

      for (final b in dayBookings) {
        final start = _extractBookingDateTime(b);
        if (start == null) continue;
        final dur = _extractBookingDurationHours(b);
        final end = start.add(Duration(hours: dur));

        if (slotStart.isBefore(end) && slotEnd.isAfter(start)) {
          overlappingBooking = b;
          bStart = start;
          bEnd = end;
          bDur = dur;
          break;
        }
      }

      if (overlappingBooking != null && bStart != null && bEnd != null) {
        final add = overlappingBooking['additional_details'] is Map ? overlappingBooking['additional_details'] as Map : null;
        final serviceName = overlappingBooking['service_type']?.toString() ??
            add?['service_name']?.toString() ??
            add?['service_type']?.toString() ??
            'Layanan Pendamping';
        final status = overlappingBooking['status']?.toString() ?? 'pending';
        final isWaitingOrActive = _isBookingWaitingOrActive(status);
        final timeRangeStr = "${bStart.hour.toString().padLeft(2, '0')}:${bStart.minute.toString().padLeft(2, '0')} - ${bEnd.hour.toString().padLeft(2, '0')}:${bEnd.minute.toString().padLeft(2, '0')} WIB";

        slots.add({
          'hour': h,
          'label': slotLabel,
          'isLocked': true,
          'booking': overlappingBooking,
          'serviceName': serviceName,
          'timeRangeString': timeRangeStr,
          'durationHours': bDur,
          'status': status,
          'isWaitingOrActive': isWaitingOrActive,
        });
      } else {
        slots.add({
          'hour': h,
          'label': slotLabel,
          'isLocked': false,
          'booking': null,
          'serviceName': null,
          'timeRangeString': null,
          'durationHours': 0,
          'status': 'available',
          'isWaitingOrActive': false,
        });
      }
    }
    return slots;
  }

  Map<String, dynamic>? _getConflictingBooking(DateTime date, TimeOfDay time) {
    final selectedStart = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final selectedEnd = selectedStart.add(const Duration(hours: 1));

    final dayBookings = _getBookingsForDate(date);
    for (final b in dayBookings) {
      final status = (b['status'] ?? '').toString();
      if (!_isBookingWaitingOrActive(status)) continue;

      final start = _extractBookingDateTime(b);
      if (start == null) continue;
      final dur = _extractBookingDurationHours(b);
      final end = start.add(Duration(hours: dur));

      if (selectedStart.isBefore(end) && selectedEnd.isAfter(start)) {
        final add = b['additional_details'] is Map ? b['additional_details'] as Map : null;
        final serviceName = b['service_type']?.toString() ??
            add?['service_name']?.toString() ??
            add?['service_type']?.toString() ??
            'Layanan Pendamping';
        final timeRangeStr = "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')} WIB";

        return {
          'booking': b,
          'start': start,
          'end': end,
          'duration': dur,
          'serviceName': serviceName,
          'timeRangeString': timeRangeStr,
        };
      }
    }
    return null;
  }


  Color _getIndicatorColor(List<Map<String, dynamic>> dayBookings) {
    if (dayBookings.isEmpty) return const Color(0xFF10B981); // Hijau: Kosong
    final hasActive = dayBookings.any((b) => _isBookingWaitingOrActive((b['status'] ?? '').toString()));
    if (hasActive) return const Color(0xFFF59E0B); // Amber: Ada Order
    if (dayBookings.length >= 3) return const Color(0xFFEF4444); // Merah: Padat
    return const Color(0xFF3B82F6); // Biru: Selesai
  }

  String _getIndicatorText(List<Map<String, dynamic>> dayBookings) {
    if (dayBookings.isEmpty) return "Kosong / Bebas";
    final activeBookings = dayBookings.where((b) => _isBookingWaitingOrActive((b['status'] ?? '').toString())).toList();
    if (activeBookings.isNotEmpty) return "⚠️ Ada Order (${activeBookings.length})";
    return "Selesai (${dayBookings.length})";
  }

  void _nextMonth() {
    setState(() {
      _currentDisplayMonth = DateTime(_currentDisplayMonth.year, _currentDisplayMonth.month + 1, 1);
    });
  }

  void _prevMonth() {
    final now = DateTime.now();
    if (_currentDisplayMonth.year > now.year || (_currentDisplayMonth.year == now.year && _currentDisplayMonth.month > now.month)) {
      setState(() {
        _currentDisplayMonth = DateTime(_currentDisplayMonth.year, _currentDisplayMonth.month - 1, 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final partnerName = widget.partnerData['name'] ?? 'Driver Partner';
    final partnerRating = widget.partnerData['rating']?.toString() ?? '5.0';
    final partnerVehicle = widget.partnerData['vehicle'] ?? 'Kendaraan Driver';
    final partnerImage = widget.partnerData['image'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(partnerName)}&background=D64573&color=fff&bold=true';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        debugPrint("PopScope triggered on BookingOrderTypeScreen");
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textHighContrast),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Pilih Mode & Jadwal Booking",
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textHighContrast,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // DRIVER INFO BANNER
                _buildDriverCard(partnerName, partnerRating, partnerVehicle, partnerImage),
                const SizedBox(height: 20),

                // MODE SELECTION: PESAN SEKARANG VS BOOKING JADWAL
                Text(
                  "Pilih Mode Waktu Pemesanan",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textHighContrast,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _buildModeSelector(),
                const SizedBox(height: 24),

                if (_bookingMode == 'now') ...[
                  _buildPesanSekarangCard(),
                ] else ...[
                  // MONTH & YEAR NAVIGATION HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${_monthsIndo[_currentDisplayMonth.month - 1]} ${_currentDisplayMonth.year}",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textHighContrast,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textHighContrast),
                            onPressed: _prevMonth,
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textHighContrast),
                            onPressed: _nextMonth,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // LEGEND BADGES (HIJAU, ORANGE, MERAH)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildLegendBadge(const Color(0xFF10B981), "🟢 Hijau: Bebas"),
                      _buildLegendBadge(const Color(0xFFF59E0B), "🟠 Orange: Ada Order"),
                      _buildLegendBadge(const Color(0xFFEF4444), "🔴 Merah: Padat"),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_isLoadingBookings) ...[
                    const ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      child: LinearProgressIndicator(color: AppTheme.primaryPink, minHeight: 2),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // MONTHLY CALENDAR GRID
                  _buildMonthlyCalendarGrid(),
                  const SizedBox(height: 20),

                  // SELECTED DATE DETAILS CARD
                  _buildSelectedDateDetailCard(),
                  const SizedBox(height: 16),

                  // TIME PICKER FIELD
                  _buildTimePickerCard(),
                ],

                const SizedBox(height: 30),

                // SUBMIT BUTTON: LANJUT KE FORM
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_bookingMode == 'scheduled') {
                        final conflict = _getConflictingBooking(_selectedDate, _selectedTime);
                        if (conflict != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFEF4444),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              content: Row(
                                children: [
                                  const Icon(Icons.cancel_rounded, color: Colors.white),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Jadwal ${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')} WIB bentrok dengan order lain (${conflict['timeRangeString']}). Driver sedang tidak tersedia di jam tersebut. Silakan pilih jam lain!",
                                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          return;
                        }
                      }

                      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
                      final formattedDateStr = "${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}";
                      final formattedTimeStr = "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')} WIB";

                      final partnerInfo = Map<String, dynamic>.from(widget.partnerData);
                      partnerInfo['selectedDate'] = formattedDateStr;
                      partnerInfo['selectedTime'] = formattedTimeStr;
                      partnerInfo['bookingMode'] = _bookingMode;

                      Widget targetScreen;
                      final sType = widget.serviceType.toLowerCase();
                      if (sType == 'sleep' || sType == 'sleep_call') {
                        targetScreen = SleepCallBookingScreen(
                          selectedPartner: partnerInfo,
                        );
                      } else if (sType == 'telepon' || sType == 'virtual' || sType == 'counseling' || sType == 'curhat') {
                        targetScreen = VirtualCallBookingScreen(
                          serviceType: sType,
                          selectedPartner: partnerInfo,
                        );
                      } else if (sType == 'gaming' || sType == 'game' || sType == 'mabar') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF6366F1),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            content: Row(
                              children: [
                                const Icon(Icons.engineering_rounded, color: Colors.white),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Fitur Gaming Buddy (Mabar) sedang dalam tahap pengembangan!",
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        return;
                      } else if (sType == 'regular' || sType == 'antar_jemput' || sType == 'ride' || sType == 'sporty' || sType == 'sporty_ride') {
                        targetScreen = AntarJemputBookingScreen(
                          selectedPartner: partnerInfo,
                          serviceType: widget.serviceType,
                        );
                      } else if (sType == 'freedom' || sType == 'freedom_request' || sType == 'assistant' || sType == 'detektif' || sType == 'detective') {
                        targetScreen = FreedomRequestBookingScreen(
                          selectedPartner: partnerInfo,
                          serviceType: sType,
                        );
                      } else {
                        targetScreen = HangoutBookingScreen(
                          selectedPartner: partnerInfo,
                          serviceType: widget.serviceType,
                        );
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => targetScreen,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      "Lanjut ke Form Pemesanan ➔",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverCard(String name, String rating, String vehicle, String image) {
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
            radius: 28,
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
                        "MITRA DRIVER",
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text("⭐ $rating", style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text("Kendaraan: $vehicle", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _bookingMode = 'now'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _bookingMode == 'now' ? AppTheme.primaryPink : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt_rounded, size: 16, color: _bookingMode == 'now' ? Colors.white : AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "Pesan Sekarang",
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: _bookingMode == 'now' ? Colors.white : AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _bookingMode = 'scheduled'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _bookingMode == 'scheduled' ? AppTheme.primaryPink : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 16, color: _bookingMode == 'scheduled' ? Colors.white : AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "Booking Jadwal",
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: _bookingMode == 'scheduled' ? Colors.white : AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPesanSekarangCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.success.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on_rounded, color: AppTheme.success, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Penjemputan Langsung (OTW)",
                      style: GoogleFonts.plusJakartaSans(color: AppTheme.success, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Driver langsung bersiap menuju lokasi penjemputan Anda (~15-30 menit).",
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendBadge(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMonthlyCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(_currentDisplayMonth.year, _currentDisplayMonth.month);
    final firstDayOffset = DateTime(_currentDisplayMonth.year, _currentDisplayMonth.month, 1).weekday - 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // Weekday Labels Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _daysIndo.map((d) => SizedBox(
              width: 36,
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            )).toList(),
          ),
          const SizedBox(height: 10),

          // Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daysInMonth + firstDayOffset,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              if (index < firstDayOffset) {
                return const SizedBox();
              }
              final dayNumber = index - firstDayOffset + 1;
              final date = DateTime(_currentDisplayMonth.year, _currentDisplayMonth.month, dayNumber);
              final isSelected = DateUtils.isSameDay(_selectedDate, date);
              final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

              final dayBookings = _getBookingsForDate(date);
              final hasActive = dayBookings.any((b) => _isBookingWaitingOrActive((b['status'] ?? '').toString()));
              final indicatorColor = _getIndicatorColor(dayBookings);

              return GestureDetector(
                onTap: isPast ? null : () => setState(() => _selectedDate = date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryPink
                        : (isPast ? AppTheme.cardDeep : (hasActive ? indicatorColor.withOpacity(0.18) : indicatorColor.withOpacity(0.08))),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryPink
                          : (isPast ? AppTheme.border : indicatorColor.withOpacity(hasActive ? 0.8 : 0.4)),
                      width: isSelected ? 2 : (hasActive ? 1.5 : 1),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "$dayNumber",
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? Colors.white
                              : (isPast ? AppTheme.textMuted : AppTheme.textHighContrast),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      if (!isPast) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: hasActive ? 6 : 5,
                          height: hasActive ? 6 : 5,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : indicatorColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ]
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

  Widget _buildSelectedDateDetailCard() {
    final dayBookings = _getBookingsForDate(_selectedDate);
    final count = dayBookings.length;
    final hasActive = dayBookings.any((b) => _isBookingWaitingOrActive((b['status'] ?? '').toString()));
    final color = _getIndicatorColor(dayBookings);
    final statusText = _getIndicatorText(dayBookings);

    final slots = _computeHourlySlots(_selectedDate, dayBookings);
    final lockedCount = slots.where((s) => s['isLocked'] == true).length;
    final freeCount = 14 - lockedCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasActive ? color.withOpacity(0.6) : AppTheme.border,
          width: hasActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Status ${_getDayName(_selectedDate.weekday)}, ${_selectedDate.day} ${_monthsIndo[_selectedDate.month - 1]} ${_selectedDate.year}",
                      style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? "Driver siap melayani sepanjang hari ini."
                          : "Terdapat $count kegiatan terdaftar di hari ini.",
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (hasActive) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Driver memiliki $lockedCount Jam Terkunci pada hari ini. Anda hanya dapat memesan di slot jam yang berstatus FREE (tersedia).",
                      style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11.5, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Hours chips
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_rounded, color: Color(0xFFEF4444), size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "$lockedCount Jam Terkunci",
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "$freeCount Jam Free",
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _showDayScheduleBottomSheet(
                  context,
                  _selectedDate,
                  statusText,
                  color,
                  count,
                  dayBookings,
                  slots,
                );
              },
              icon: const Icon(Icons.schedule_rounded, size: 16),
              label: const Text("LIHAT DETAIL JAM TERKUNCI & FREE"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryPink,
                side: const BorderSide(color: AppTheme.primaryPink),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerCard() {
    final conflict = _bookingMode == 'scheduled' ? _getConflictingBooking(_selectedDate, _selectedTime) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: _selectedTime,
            );
            if (time != null) {
              setState(() => _selectedTime = time);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: conflict != null ? const Color(0xFFEF4444) : AppTheme.border,
                width: conflict != null ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        conflict != null ? Icons.lock_clock_rounded : Icons.access_time_rounded,
                        color: conflict != null ? const Color(0xFFEF4444) : AppTheme.primaryPink,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "JAM PENJEMPUTAN TERENCANA",
                              style: GoogleFonts.inter(
                                color: conflict != null ? const Color(0xFFEF4444) : AppTheme.textMuted,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                Text(
                                  "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')} WIB",
                                  style: GoogleFonts.inter(
                                    color: conflict != null ? const Color(0xFFEF4444) : AppTheme.textHighContrast,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (conflict != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "TERKUNCI",
                                      style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 9.5, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
              ],
            ),
          ),
        ),
        if (conflict != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "⛔ WAKTU TERKUNCI: Jam ${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')} WIB bentrok dengan pesanan lain (${conflict['timeRangeString']}). Driver sedang sibuk pada jam tersebut. Silakan pilih jam lainnya yang berstatus FREE.",
                    style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showDayScheduleBottomSheet(
    BuildContext context,
    DateTime date,
    String statusLabel,
    Color badgeColor,
    int bookingCount,
    List<Map<String, dynamic>> dayBookings,
    List<Map<String, dynamic>> slots,
  ) {
    final lockedHours = slots.where((s) => s['isLocked'] == true).length;
    final freeHours = 14 - lockedHours;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          bottom: true,
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${_getDayName(date.weekday)}, ${date.day} ${_monthsIndo[date.month - 1]} ${date.year}",
                            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$bookingCount Aktivitas Terjadwal ($lockedHours Jam Terkunci)",
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeColor),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Summary chips
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDeep,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("Total Order: $bookingCount", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      Container(height: 16, width: 1, color: AppTheme.border),
                      Text("Terkunci: $lockedHours Jam", style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 11.5, fontWeight: FontWeight.bold)),
                      Container(height: 16, width: 1, color: AppTheme.border),
                      Text("Free: $freeHours Jam", style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 8),

                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Ketersediaan Jam (08:00 - 22:00 WIB)",
                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Ketuk slot jam berstatus FREE untuk memilih jam tersebut sebagai jam penjemputan.",
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 10),

                        // Timeline slots
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: slots.length,
                          itemBuilder: (ctx, sIdx) {
                            final slot = slots[sIdx];
                            final isLocked = slot['isLocked'] == true;

                            return GestureDetector(
                              onTap: isLocked
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedTime = TimeOfDay(hour: slot['hour'] as int, minute: 0);
                                      });
                                      Navigator.pop(context);
                                    },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isLocked ? const Color(0xFFEF4444).withOpacity(0.08) : AppTheme.cardDeep,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isLocked ? const Color(0xFFEF4444).withOpacity(0.4) : AppTheme.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isLocked ? Icons.lock_rounded : Icons.check_circle_outline_rounded,
                                      color: isLocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            slot['label'] as String,
                                            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isLocked
                                                ? "Terkunci (${slot['timeRangeString']})"
                                                : "Driver Bebas / Siap Menerima Pesanan (Ketuk untuk pilih)",
                                            style: GoogleFonts.inter(color: isLocked ? const Color(0xFFEF4444) : AppTheme.textMuted, fontSize: 10.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isLocked ? const Color(0xFFEF4444).withOpacity(0.15) : const Color(0xFF10B981).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isLocked ? "TERKUNCI" : "PILIH JAM",
                                        style: GoogleFonts.inter(
                                          color: isLocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        Text(
                          "Daftar Booking Terdaftar Pada Tanggal Ini",
                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),

                        if (dayBookings.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDeep,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Center(
                              child: Text(
                                "Belum ada pesanan terdaftar di hari ini.",
                                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dayBookings.length,
                            itemBuilder: (ctx, bIdx) {
                              final b = dayBookings[bIdx];
                              final add = b['additional_details'] is Map ? b['additional_details'] as Map : null;
                              final serviceName = b['service_type']?.toString() ??
                                  add?['service_name']?.toString() ??
                                  add?['service_type']?.toString() ??
                                  'Layanan Pendamping';
                              final status = (b['status'] ?? 'pending').toString();
                              final isWaitingOrActive = _isBookingWaitingOrActive(status);
                              final dur = _extractBookingDurationHours(b);
                              final start = _extractBookingDateTime(b);
                              final startStr = start != null
                                  ? "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}"
                                  : "--:--";

                              String displayStatus;
                              Color statusBadgeColor;
                              switch (status.toLowerCase()) {
                                case 'waiting_dp':
                                  displayStatus = "Menunggu DP";
                                  statusBadgeColor = const Color(0xFFF59E0B);
                                  break;
                                case 'dp_paid':
                                  displayStatus = "DP Terbayar";
                                  statusBadgeColor = const Color(0xFF10B981);
                                  break;
                                case 'accepted':
                                  displayStatus = "Diterima Driver";
                                  statusBadgeColor = const Color(0xFF3B82F6);
                                  break;
                                case 'ongoing':
                                case 'in_trip':
                                  displayStatus = "Sedang Berjalan";
                                  statusBadgeColor = AppTheme.primaryPink;
                                  break;
                                case 'completed':
                                  displayStatus = "Selesai";
                                  statusBadgeColor = const Color(0xFF10B981);
                                  break;
                                default:
                                  displayStatus = status;
                                  statusBadgeColor = AppTheme.textMuted;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardDeep,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isWaitingOrActive ? const Color(0xFFF59E0B).withOpacity(0.4) : AppTheme.border,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          serviceName,
                                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusBadgeColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            displayStatus,
                                            style: GoogleFonts.inter(color: statusBadgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 13, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Mulai: $startStr WIB • Durasi: $dur Jam",
                                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
