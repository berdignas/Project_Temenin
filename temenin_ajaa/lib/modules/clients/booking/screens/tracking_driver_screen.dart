// lib/modules/booking/screens/tracking_driver_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/providers/auth_provider.dart';
import 'package:temenin_ajaa/providers/driver_provider.dart';
import 'package:temenin_ajaa/modules/clients/chat/screens/chat_room_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'payment_method_screen.dart';
import '../../screens/home_loggedin_screen.dart';
import '../../../../providers/client_booking_provider.dart';

class TrackingDriverScreen extends StatefulWidget {
  final Map<String, dynamic>? bookingData;
  final String? paymentMethod;
  final String? bookingId;
  final String? initialStatus;
  
  const TrackingDriverScreen({
    super.key, 
    this.bookingData, 
    this.paymentMethod, 
    this.bookingId,
    this.initialStatus,
  });

  @override
  State<TrackingDriverScreen> createState() => _TrackingDriverScreenState();
}

class _TrackingDriverScreenState extends State<TrackingDriverScreen> {
  // Booking Lifecycle States: 
  // 'on_the_way' -> 'arrived' -> 'started' -> 'completed' -> 'final_payment' -> 'paid' -> 'review'
  String _simulationState = 'on_the_way';
  Map<String, dynamic>? _bookingDetails;
  
  int _remainingSeconds = 240; // 4 minutes
  String _estimatedTime = "Arriving in 4 mins";
  String _countdownTimer = "00:04:00";
  
  // Overtime detail
  int _overtimeHours = 1;
  int _overtimeCost = 0;
  int _finalDueAmount = 0;

  // Rating & Review state
  double _userRating = 5.0;
  final _reviewController = TextEditingController();
  
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _driversSubscription;
  List<Map<String, dynamic>> _detectedDrivers = [];
  bool _isWaitingForDriverApproval = false;
  String? _currentBookingId;
  Timer? _pollingTimer;
  bool _isCompletionModalShowing = false;
  bool _isPelunasanModalShowing = false;

  @override
  void initState() {
    super.initState();
    _currentBookingId = widget.bookingId;
    _bookingDetails = widget.bookingData;

    final initDetails = widget.bookingData;
    final addDetails = initDetails?['additional_details'] is Map
        ? initDetails!['additional_details'] as Map
        : (initDetails?['additionalDetails'] is Map ? initDetails!['additionalDetails'] as Map : null);
    final subStatus = addDetails?['sub_status']?.toString() ?? initDetails?['sub_status']?.toString();
    final isDpPaid = addDetails?['dp_paid'] == true || initDetails?['dp_paid'] == true || subStatus == 'dp_paid';
    String initialStatus = widget.initialStatus ?? subStatus ?? initDetails?['status'] ?? 'pending';
    if (isDpPaid && (initialStatus == 'accepted' || initialStatus == 'ongoing')) {
      if (subStatus == null || subStatus.isEmpty || subStatus == 'accepted') {
        initialStatus = 'dp_paid';
      }
    }
    _simulationState = initialStatus;

    _startTimer();
    _subscribeToBookingChanges();
    _listenToActiveDrivers();
    _ensureRealOtpExists();
    
    // Calculate overtime cost based on driver class
    final driverClass = widget.bookingData?['driverClass'] ?? 'Gold';
    switch (driverClass) {
      case 'Bronze':
      case 'Silver':
        _overtimeCost = 35000;
        break;
      case 'Gold':
      case 'Platinum':
        _overtimeCost = 50000;
        break;
      case 'Diamond':
      case 'VVIP':
        _overtimeCost = 75000;
        break;
      default:
        _overtimeCost = 50000;
    }
  }

  void _listenToActiveDrivers() {
    try {
      _driversSubscription = Supabase.instance.client
          .from('drivers')
          .stream(primaryKey: ['id'])
          .listen((List<Map<String, dynamic>> data) {
            if (mounted) {
              final active = data.where((d) => d['is_available'] == true).toList();
              setState(() {
                _detectedDrivers = active;
              });
            }
          });
    } catch (e) {
      debugPrint("Error streaming active drivers: $e");
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _driversSubscription?.cancel();
    _pollingTimer?.cancel();
    _reviewController.dispose();
    super.dispose();
  }

  void _handleBookingStatusUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    if (_simulationState == 'review') {
      _bookingDetails = data;
      return;
    }
    final dbStatus = data['status'] as String? ?? 'pending';
    Map<String, dynamic>? addDetails;
    if (data['additional_details'] is Map) {
      addDetails = Map<String, dynamic>.from(data['additional_details'] as Map);
    } else if (data['additionalDetails'] is Map) {
      addDetails = Map<String, dynamic>.from(data['additionalDetails'] as Map);
    } else if (data['additional_details'] is String) {
      try {
        final decoded = jsonDecode(data['additional_details'] as String);
        if (decoded is Map) addDetails = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    final subStatus = addDetails?['sub_status']?.toString();
    final isDpPaid = addDetails?['dp_paid'] == true || subStatus == 'dp_paid' || data['dp_paid'] == true;

    String status = subStatus ?? dbStatus;
    if (status == 'accepted' && isDpPaid) {
      status = 'dp_paid';
    }
    debugPrint('⚡ Supabase Booking status update: $status (db: $dbStatus, sub: $subStatus, isDpPaid: $isDpPaid)');
    
    setState(() {
      _bookingDetails = data;
      _simulationState = status;
      if (status == 'pending') {
        _estimatedTime = "Menunggu Driver...";
      } else if (status == 'accepted') {
        _isWaitingForDriverApproval = false;
      } else if (status == 'dp_paid') {
        _estimatedTime = "Driver Sedang Bersiap...";
      } else if (status == 'on_the_way') {
        _estimatedTime = "Menuju Lokasi Anda";
        _countdownTimer = "00:03:45";
      } else if (status == 'arrived') {
        _estimatedTime = "Driver Telah Tiba!";
      } else if (status == 'started' || status == 'ongoing') {
        final durationHours = int.tryParse(addDetails?['duration']?.toString() ?? widget.bookingData?['duration']?.toString() ?? '3') ?? 3;
        if (_remainingSeconds <= 240) {
          _remainingSeconds = durationHours * 3600;
        }
        int hours = _remainingSeconds ~/ 3600;
        int minutes = (_remainingSeconds % 3600) ~/ 60;
        int seconds = _remainingSeconds % 60;
        _countdownTimer = "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
        _estimatedTime = "Sesi Berjalan: $_countdownTimer";
        _startTimer();
      } else if (status == 'completion_requested') {
        _estimatedTime = "Menunggu Konfirmasi Anda...";
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showClientCompletionConfirmationDialog();
        });
      } else if (status == 'completed') {
        _estimatedTime = "Layanan Selesai";
        final totalEstimasi = widget.bookingData?['totalPayment'] ?? (data['total_price'] as num?)?.toInt() ?? 130000;
        final dpPaid = widget.bookingData?['dp'] ?? (totalEstimasi * 0.5).toInt();
        _finalDueAmount = (totalEstimasi - dpPaid) + (_overtimeHours * _overtimeCost);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPelunasanModal();
        });
      } else if (status == 'paid') {
        _simulationState = 'paid';
        _pollingTimer?.cancel();
      } else if (status == 'cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Order pendampingan Anda dibatalkan oleh driver."),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/client-home', (route) => false);
      }
    });
  }

  String _formatCurrency(int amount) {
    return "Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  void _showPelunasanModal() {
    if (_isPelunasanModalShowing || !mounted) return;
    _isPelunasanModalShowing = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF7F).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF7F), size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                "Sesi Pendampingan Selesai!",
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Mitra pengemudi telah menyelesaikan sesi layanan. Silakan lakukan pembayaran pelunasan untuk menyelesaikan transaksi.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _isPelunasanModalShowing = false;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentMethodScreen(
                          bookingData: _bookingDetails,
                          bookingId: _currentBookingId ?? widget.bookingId,
                          isPelunasan: true,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    "BAYAR PELUNASAN SEKARANG (${_formatCurrency(_finalDueAmount)})",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _isPelunasanModalShowing = false;
    });
  }

  void _showClientCompletionConfirmationDialog() {
    if (_isCompletionModalShowing) return;
    _isCompletionModalShowing = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.task_alt_rounded, color: AppTheme.primaryPink, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                "Konfirmasi Penyelesaian Sesi",
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Driver meminta konfirmasi bahwa pendampingan telah selesai. Apakah sesi Anda sudah berakhir?",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        _isCompletionModalShowing = false;
                        await _updateClientBookingStatus('ongoing');
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("Belum Selesai", style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        _isCompletionModalShowing = false;
                        await _updateClientBookingStatus('completed');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("Ya, Selesaikan", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateClientBookingStatus(String status) async {
    final bookingId = _currentBookingId ?? widget.bookingId;
    if (bookingId == null) return;

    final updatedDetails = Map<String, dynamic>.from(_bookingDetails?['additional_details'] ?? widget.bookingData ?? {});
    updatedDetails['sub_status'] = status;

    final payload = <String, dynamic>{
      'status': status == 'completed' ? 'completed' : 'ongoing',
      'additional_details': updatedDetails,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final dynamic queryId = int.tryParse(bookingId) ?? bookingId;
      await Supabase.instance.client.from('bookings').update(payload).eq('id', queryId);
    } catch (e) {
      debugPrint("Error client update booking status: $e");
    }
  }

  String? _extractOtp(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      final direct = data['otp']?.toString().trim();
      if (direct != null && direct.isNotEmpty && direct != 'null') {
        return direct;
      }
      if (data['additional_details'] is Map) {
        final sub = _extractOtp(data['additional_details']);
        if (sub != null) return sub;
      }
      if (data['additionalDetails'] is Map) {
        final sub = _extractOtp(data['additionalDetails']);
        if (sub != null) return sub;
      }
    }
    return null;
  }

  String? _extractCompletionOtp(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      final direct = data['completion_otp']?.toString().trim() ?? data['end_otp']?.toString().trim();
      if (direct != null && direct.isNotEmpty && direct != 'null') {
        return direct;
      }
      if (data['additional_details'] is Map) {
        final sub = _extractCompletionOtp(data['additional_details']);
        if (sub != null) return sub;
      }
      if (data['additionalDetails'] is Map) {
        final sub = _extractCompletionOtp(data['additionalDetails']);
        if (sub != null) return sub;
      }
    }
    return null;
  }

  Future<void> _ensureRealOtpExists() async {
    final details = _bookingDetails ?? widget.bookingData;
    String? existingStartOtp = _extractOtp(_bookingDetails) ?? _extractOtp(widget.bookingData);
    String? existingCompOtp = _extractCompletionOtp(_bookingDetails) ?? _extractCompletionOtp(widget.bookingData);
    final bookingId = _currentBookingId ?? widget.bookingId;

    if (bookingId != null && !bookingId.startsWith('mock')) {
      final random = Random();
      bool needsUpdate = false;

      String startOtp = existingStartOtp ?? '';
      if (startOtp.isEmpty) {
        startOtp = (random.nextInt(9000) + 1000).toString();
        needsUpdate = true;
      }

      String compOtp = existingCompOtp ?? '';
      if (compOtp.isEmpty || compOtp == startOtp) {
        do {
          compOtp = (random.nextInt(9000) + 1000).toString();
        } while (compOtp == startOtp);
        needsUpdate = true;
      }

      if (needsUpdate) {
        try {
          final dynamic queryId = int.tryParse(bookingId) ?? bookingId;
          final currentRec = await Supabase.instance.client
              .from('bookings')
              .select('additional_details')
              .eq('id', queryId)
              .maybeSingle();

          final updatedDetails = currentRec != null && currentRec['additional_details'] is Map
              ? Map<String, dynamic>.from(currentRec['additional_details'] as Map)
              : Map<String, dynamic>.from(details ?? {});

          updatedDetails['otp'] = startOtp;
          updatedDetails['completion_otp'] = compOtp;

          await Supabase.instance.client
              .from('bookings')
              .update({'additional_details': updatedDetails})
              .eq('id', queryId);

          if (mounted) {
            setState(() {
              if (_bookingDetails != null) {
                _bookingDetails!['additional_details'] = updatedDetails;
                _bookingDetails!['otp'] = startOtp;
                _bookingDetails!['completion_otp'] = compOtp;
              }
            });
          }
          debugPrint("✅ Saved Start PIN $startOtp & Completion PIN $compOtp for booking $bookingId to Supabase");
        } catch (e) {
          debugPrint("Error saving generated OTPs to DB: $e");
        }
      }
    }
  }

  void _subscribeToBookingChanges() {
    final bookingId = _currentBookingId ?? widget.bookingId;
    if (bookingId == null || bookingId.startsWith('mock')) {
      debugPrint('ℹ️ Booking ID is mock or null.');
      return;
    }

    final dynamic queryId = int.tryParse(bookingId) ?? bookingId;

    debugPrint('📡 Subscribing to Supabase Realtime for Booking ID: $queryId');
    _realtimeSubscription?.cancel();
    try {
      _realtimeSubscription = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', queryId)
          .listen((List<Map<String, dynamic>> data) {
            if (data.isNotEmpty) {
              _handleBookingStatusUpdate(data.first);
            }
          });
    } catch (e) {
      debugPrint('❌ Supabase subscription error: $e');
    }

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      try {
        final data = await Supabase.instance.client
            .from('bookings')
            .select()
            .eq('id', queryId)
            .maybeSingle();
        if (data != null && mounted) {
          _handleBookingStatusUpdate(data);
        }
      } catch (e) {
        debugPrint("Polling error: $e");
      }
    });
  }
  
  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_remainingSeconds > 0 && _simulationState == 'on_the_way') {
        setState(() {
          _remainingSeconds--;
          
          if (_remainingSeconds > 60) {
            int minutes = _remainingSeconds ~/ 60;
            _estimatedTime = "Tiba dalam $minutes mnt";
          } else if (_remainingSeconds > 0) {
            _estimatedTime = "Tiba dalam $_remainingSeconds dtk";
          } else {
            _estimatedTime = "Segera Tiba";
          }
          
          int hours = _remainingSeconds ~/ 3600;
          int minutes = (_remainingSeconds % 3600) ~/ 60;
          int seconds = _remainingSeconds % 60;
          _countdownTimer = "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
          
          _startTimer();
        });
      } else if (_simulationState == 'started' || _simulationState == 'ongoing') {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          }
          int hours = _remainingSeconds ~/ 3600;
          int minutes = (_remainingSeconds % 3600) ~/ 60;
          int seconds = _remainingSeconds % 60;
          _countdownTimer = "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
          _estimatedTime = "Sesi Berjalan: $_countdownTimer";
          
          _startTimer();
        });
      }
    });
  }

  void _showDriverProfile(BuildContext context, Map<String, dynamic> driver) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryPink.withOpacity(0.2),
                    backgroundImage: (driver['profile_image'] != null && driver['profile_image'].toString().isNotEmpty)
                        ? NetworkImage(driver['profile_image'].toString())
                        : null,
                    child: (driver['profile_image'] == null || driver['profile_image'].toString().isEmpty)
                        ? const Icon(Icons.person, color: AppTheme.primaryPink, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver['name'] ?? 'Driver Partner',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textHighContrast,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "${driver['rating'] ?? '5.0'}",
                              style: GoogleFonts.inter(
                                color: AppTheme.textHighContrast,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 16),
              _buildProfileDetailRow(Icons.directions_car_rounded, "Kendaraan", driver['vehicle_name'] ?? '-'),
              const SizedBox(height: 12),
              _buildProfileDetailRow(Icons.badge_rounded, "Plat Nomor", driver['plate_number'] ?? '-'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    "Tutup",
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryPink, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
            ),
            Text(
              value,
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> details = (_bookingDetails != null && _bookingDetails!.containsKey('additional_details'))
        ? (_bookingDetails!['additional_details'] as Map<String, dynamic>? ?? widget.bookingData ?? {})
        : (_bookingDetails ?? widget.bookingData ?? {});

    final driverProv = Provider.of<DriverProvider>(context);
    final dId = _bookingDetails?['driver_id']?.toString() ?? details['driver_id']?.toString();
    Map<String, dynamic>? currentDriver;
    if (dId != null) {
      try {
        currentDriver = driverProv.drivers.firstWhere((d) => d['id'] == dId || d['driverId'] == dId);
      } catch (_) {}
    }

    final driverName = currentDriver?['name'] ?? details['driverName'] ?? "Mitra Driver";
    final driverImage = currentDriver?['image'] ?? details['driverImage'] ?? '';
    final driverRating = currentDriver?['rating'] ?? details['driverRating'] ?? "-";
    final vehicle = currentDriver?['vehicle'] ?? details['vehicle'] ?? "-";
    final plateNumber = details['plateNumber'] ?? "-";
    final pickupLocation = details['pickup'] ?? "-";
    final destinationLocation = details['destination'] ?? "-";
    final totalPayment = details['totalPayment'] ?? 130000;
    final dp = details['dp'] ?? 65000;
    final remainingPayment = details['remainingPayment'] ?? 65000;
    final paymentMethod = widget.paymentMethod ?? "BCA Virtual Account";
    final serviceType = details['serviceType'] ?? 'antar_jemput';
    final rawOtp = _extractOtp(_bookingDetails) ?? _extractOtp(widget.bookingData) ?? _extractOtp(details);
    final rawCompOtp = _extractCompletionOtp(_bookingDetails) ?? _extractCompletionOtp(widget.bookingData) ?? _extractCompletionOtp(details);

    final startPin = (rawOtp != null && rawOtp.isNotEmpty) ? rawOtp : "1234";
    final compPin = (rawCompOtp != null && rawCompOtp.isNotEmpty) ? rawCompOtp : "5678";

    final isOngoingSession = _simulationState == 'started' || _simulationState == 'ongoing';
    final otpPin = isOngoingSession ? compPin : startPin;

    String formatCurrency(int amount) {
      return "Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }

    if (_simulationState == 'review') {
      return _buildReviewScreen(driverName, driverImage);
    }



    if (_simulationState == 'accepted') {
      final totalEst = (details['totalPayment'] ?? details['total_price'] ?? 130000) as num;
      final dpAmount = (totalEst * 0.5).toInt();

      return Scaffold(
        backgroundColor: const Color(0xFF0D0C11),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
                ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                const SizedBox(height: 24),
                Text(
                  "Driver Menyetujui Orderan! 🎉",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textHighContrast,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Driver $driverName telah menyetujui permintaan Anda. Silakan lanjutkan ke pembayaran DP untuk mengonfirmasi pesanan.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
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
                          Text("Total Estimasi", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
                          Text(formatCurrency(totalEst.toInt()), style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const Divider(color: AppTheme.border, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("DP Wajib (50%)", style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(formatCurrency(dpAmount), style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentMethodScreen(
                            bookingData: details,
                            bookingId: widget.bookingId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      "BAYAR DP SEKARANG (${formatCurrency(dpAmount)})",
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0C11),
      body: Stack(
        children: [
          _buildMapBackground(),
          if (_alarmTriggered)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.withOpacity(0.5), width: 8),
                  color: Colors.red.withOpacity(0.04),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        
                        const SizedBox(height: 10),
                        
                        if (_simulationState == 'pending') ...[
                          _buildWaitingForDriverCard(),
                          const SizedBox(height: 15),
                        ],

                        _buildArrivingCard(
                          driverName: driverName,
                          driverImage: driverImage,
                          driverRating: driverRating,
                          vehicle: vehicle,
                          plateNumber: plateNumber,
                          estimatedTime: _estimatedTime,
                          countdownTimer: _countdownTimer,
                          serviceType: serviceType,
                          otpPin: otpPin,
                        ),
                        const SizedBox(height: 15),

                        // Prominent PIN Security Card
                        if (_simulationState == 'accepted' || 
                            _simulationState == 'dp_paid' || 
                            _simulationState == 'on_the_way' || 
                            _simulationState == 'arrived' ||
                            _simulationState == 'started' ||
                            _simulationState == 'ongoing') ...[
                          _buildSecurityPinCard(otpPin, isCompletion: isOngoingSession),
                          const SizedBox(height: 15),
                        ],
                        
                        _buildBookingStatusCard(),
                        const SizedBox(height: 15),
                        
                        _buildLocationCard(pickupLocation, destinationLocation),
                        const SizedBox(height: 15),
                        
                        if (_simulationState == 'completed' || _simulationState == 'paid')
                          _buildFinalInvoiceCard(totalPayment, dp, formatCurrency)
                        else
                          _buildPaymentSummaryCard(
                            totalPayment: totalPayment,
                            remainingPayment: remainingPayment,
                            paymentMethod: paymentMethod,
                            formatCurrency: formatCurrency,
                          ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return Positioned.fill(
      child: SimulatedMapWidget(status: _simulationState),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(context, '/client-home', (route) => false);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast, size: 20),
            ),
          ),
          Text(
            "Temenin Ajaa",
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryPink,
            ),
          ),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.cardDeep,
            child: Icon(Icons.person, size: 20, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForDriverCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Menghubungkan ke Driver...",
                  style: GoogleFonts.inter(
                    color: AppTheme.textHighContrast,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Pesanan Anda sedang menunggu konfirmasi dari partner driver.",
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrivingCard({
    required String driverName,
    required String driverImage,
    required String driverRating,
    required String vehicle,
    required String plateNumber,
    required String estimatedTime,
    required String countdownTimer,
    required String serviceType,
    String? otpPin,
  }) {
    String statusLabel = 'ON THE WAY';
    if (_simulationState == 'pending') statusLabel = 'MENUNGGU DRIVER';
    if (_simulationState == 'accepted') statusLabel = 'DRIVER ACCEPTED';
    if (_simulationState == 'dp_paid') statusLabel = 'DP TERBAYAR - MENUNGGU OTW';
    if (_simulationState == 'on_the_way') statusLabel = 'DRIVER ON THE WAY';
    if (_simulationState == 'arrived') statusLabel = 'DRIVER ARRIVED';
    if (_simulationState == 'started' || _simulationState == 'ongoing') statusLabel = 'SERVICE ONGOING';
    if (_simulationState == 'completed') statusLabel = 'SERVICE COMPLETED';
    if (_simulationState == 'paid') statusLabel = 'PAID';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.fuchsiaLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.access_time_rounded, color: AppTheme.primaryPink, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _simulationState == 'pending'
                ? "Menunggu Konfirmasi Driver"
                : (_simulationState == 'accepted'
                    ? "Driver Telah Menyetujui"
                    : (_simulationState == 'dp_paid'
                        ? "DP Terverifikasi, Menunggu Driver OTW"
                        : (_simulationState == 'on_the_way'
                            ? estimatedTime
                            : (_simulationState == 'arrived'
                                ? "Driver Telah Tiba!"
                                : (_simulationState == 'completed'
                                    ? "Layanan Selesai"
                                    : "Selamat Menikmati Perjalanan"))))),
            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (_simulationState == 'on_the_way' || _simulationState == 'started' || _simulationState == 'ongoing') ...[
            const SizedBox(height: 10),
            _buildDurationBadge(countdownTimer),
          ],
          if (_simulationState == 'arrived' || _simulationState == 'on_the_way' || _simulationState == 'dp_paid') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.fuchsiaLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pin_rounded, color: AppTheme.primaryPink, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PIN VERIFIKASI KEAMANAN",
                          style: GoogleFonts.inter(
                            color: AppTheme.primaryPink,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Berikan PIN ini ke driver Anda untuk memulai layanan:",
                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPink,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      otpPin ?? "1234",
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildDriverInfo(
            driverName: driverName,
            driverImage: driverImage,
            driverRating: driverRating,
            vehicle: vehicle,
            plateNumber: plateNumber,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: "Chat Driver",
                  color: AppTheme.primaryPink,
                  textColor: Colors.white,
                  onPressed: () {
                    _openDriverChat(driverName, driverImage);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.emergency_share_outlined,
                  label: "Safety (SOS)",
                  color: AppTheme.cardDeep,
                  textColor: AppTheme.primaryPink,
                  isOutline: true,
                  onPressed: () {
                    _showEmergencyDialog();
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _openDriverChat(String driverName, String driverImage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          bookingId: _currentBookingId ?? widget.bookingId,
          recipientName: driverName,
          recipientImage: driverImage,
          status: "Online Now",
          tag: "Driver",
        ),
      ),
    );
  }

  Widget _buildDurationBadge(String timer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.fuchsiaLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: AppTheme.primaryPink, size: 14),
          const SizedBox(width: 8),
          Text(
            timer,
            style: GoogleFonts.shareTechMono(color: AppTheme.primaryPink, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfo({
    required String driverName,
    required String driverImage,
    required String driverRating,
    required String vehicle,
    required String plateNumber,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundImage: NetworkImage(driverImage),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.border)),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(driverName, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 15)),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                        const SizedBox(width: 4),
                        Text(driverRating, style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                Text("$vehicle • $plateNumber", style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    bool isOutline = false,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: isOutline ? Border.all(color: AppTheme.primaryPink.withOpacity(0.3)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityPinCard(String otpPin, {bool isCompletion = false}) {
    final digits = otpPin.padLeft(4, '0').split('');
    final titleText = isCompletion ? "PIN VERIFIKASI SELESAI LAYANAN" : "PIN KEAMANAN PENJEMPUTAN";
    final subtitleText = isCompletion ? "Berikan ke Driver untuk Menyelesaikan Sesi" : "Berikan ke Driver untuk Memulai Sesi";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCompletion ? Icons.check_circle_outline_rounded : Icons.security_rounded,
                        color: AppTheme.primaryPink,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryPink,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleText,
                            style: GoogleFonts.inter(
                              color: AppTheme.textHighContrast,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: otpPin));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("PIN berhasil disalin!"),
                      duration: Duration(seconds: 1),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDeep,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "Salin",
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          
          // 4 individual digit boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: digits.map((digit) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 50,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF131118),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryPink.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPink.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    digit,
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardDeep,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Driver harus memasukkan 4 digit angka di atas pada aplikasi driver untuk memverifikasi dan memulai layanan.",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingStatusCard() {
    final isAccepted = _simulationState != 'pending';
    final isDpPaid = _simulationState == 'dp_paid' ||
                     _simulationState == 'on_the_way' ||
                     _simulationState == 'arrived' ||
                     _simulationState == 'started' ||
                     _simulationState == 'ongoing' ||
                     _simulationState == 'completed' ||
                     _simulationState == 'paid';
    final isOtw = _simulationState == 'on_the_way' ||
                  _simulationState == 'arrived' ||
                  _simulationState == 'started' ||
                  _simulationState == 'ongoing' ||
                  _simulationState == 'completed' ||
                  _simulationState == 'paid';
    final isArrived = _simulationState == 'arrived' ||
                      _simulationState == 'started' ||
                      _simulationState == 'ongoing' ||
                      _simulationState == 'completed' ||
                      _simulationState == 'paid';
    final isStarted = _simulationState == 'started' ||
                      _simulationState == 'ongoing' ||
                      _simulationState == 'completed' ||
                      _simulationState == 'paid';
    final isCompleted = _simulationState == 'completed' || _simulationState == 'paid';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("BOOKING STATUS TIMELINE", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 20),
          _buildTimelineItem("Driver Accepted", "Driver telah menyetujui jadwal", isAccepted, true, isActive: _simulationState == 'pending'),
          _buildTimelineItem("DP Paid", "DP 50% berhasil diverifikasi", isDpPaid, true, isActive: _simulationState == 'accepted' && !isDpPaid),
          _buildTimelineItem("Driver OTW", "Driver sedang berkendara ke arah Anda", isOtw, true, isActive: _simulationState == 'on_the_way' || _simulationState == 'dp_paid'),
          _buildTimelineItem("Driver Arrived", "Driver telah sampai di lokasi penjemputan", isArrived, true, isActive: _simulationState == 'arrived'),
          _buildTimelineItem("Service Started", "Jadwal pendampingan sedang berjalan", isStarted, true, isActive: _simulationState == 'started' || _simulationState == 'ongoing'),
          _buildTimelineItem("Service Completed", "Layanan selesai, invoice pelunasan diterbitkan", isCompleted, false, isActive: _simulationState == 'completed', isLast: true),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, String subtitle, bool isDone, bool hasLine, {bool isActive = false, bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? AppTheme.primaryPink : Colors.transparent,
                border: Border.all(color: AppTheme.primaryPink, width: 2),
              ),
              child: isDone 
                ? const Icon(Icons.check, size: 14, color: Colors.white) 
                : (isActive ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primaryPink, shape: BoxShape.circle))) : null),
            ),
            if (!isLast) Container(width: 2, height: 40, color: isDone ? AppTheme.primaryPink : AppTheme.border),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(color: isDone || isActive ? AppTheme.textHighContrast : AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 14)),
              if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard(String pickup, String destination) {
    final hasAntarJemput = widget.bookingData?['hasAntarJemput'] == true;
    final hasHangout = widget.bookingData?['hasHangout'] == true;
    
    final addDest = widget.bookingData?['additionalDestination'] ?? '';
    final addPickupDate = widget.bookingData?['additionalPickupDate'] ?? '';
    final addPickupTime = widget.bookingData?['additionalPickupTime'] ?? '';
    final ajNotes = widget.bookingData?['additionalAntarJemputNotes'] ?? '';

    final activity = widget.bookingData?['additionalActivity'] ?? '';
    final duration = widget.bookingData?['additionalDuration'] ?? '3';
    final hangoutLoc = widget.bookingData?['additionalHangoutLocation'] ?? '';
    final hangoutDate = widget.bookingData?['additionalHangoutDate'] ?? '';
    final hangoutTime = widget.bookingData?['additionalHangoutTime'] ?? '';
    final hgNotes = widget.bookingData?['additionalHangoutNotes'] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _locationRow(AppTheme.primaryPink, "JEMPUT", pickup),
          const SizedBox(height: 15),
          _locationRow(AppTheme.textMuted, "TUJUAN", destination),
          
          if (hasAntarJemput && addDest.isNotEmpty) ...[
            const Divider(color: AppTheme.border, height: 25),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppTheme.fuchsiaLight, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.two_wheeler_rounded, color: AppTheme.primaryPink, size: 14),
                ),
                const SizedBox(width: 8),
                Text("LAYANAN TAMBAHAN: ANTAR JEMPUT", style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 10),
            _locationRow(AppTheme.textMuted, "ANTAR TAMBAHAN", addDest),
            if (addPickupDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: AppTheme.textMuted, size: 14),
                    const SizedBox(width: 6),
                    Text("$addPickupDate, pukul $addPickupTime", style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            if (ajNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("Catatan: \"$ajNotes\"", style: const TextStyle(color: AppTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 11)),
              ),
          ],

          if (hasHangout && activity.isNotEmpty) ...[
            const Divider(color: AppTheme.border, height: 25),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppTheme.fuchsiaLight, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.coffee_rounded, color: AppTheme.primaryPink, size: 14),
                ),
                const SizedBox(width: 8),
                Text("LAYANAN TAMBAHAN: TEMAN HANGOUT ($duration Jam)", style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 10),
            Text("Aktivitas: $activity", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600)),
            if (hangoutLoc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("Lokasi: $hangoutLoc", style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ),
            if (hangoutDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: AppTheme.textMuted, size: 14),
                    const SizedBox(width: 6),
                    Text("$hangoutDate, pukul $hangoutTime", style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            if (hgNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("Catatan: \"$hgNotes\"", style: const TextStyle(color: AppTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 11)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _locationRow(Color dotColor, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              Text(
                address, 
                style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildPaymentSummaryCard({
    required int totalPayment,
    required int remainingPayment,
    required String paymentMethod,
    required String Function(int) formatCurrency,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.fuchsiaLight, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryPink),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Total Estimasi", style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    Text(formatCurrency(totalPayment), style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text("Sisa Bayar", style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    Text(formatCurrency(remainingPayment), style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Metode DP", style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    Text(paymentMethod.length > 15 ? paymentMethod.substring(0, 15) : paymentMethod, textAlign: TextAlign.right, style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalInvoiceCard(int totalPayment, int dpPaid, String Function(int) formatCurrency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryPink, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TAGIHAN SISA AKHIR",
            style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const Divider(color: AppTheme.border, height: 20),
          _invoiceRow("Total Estimasi", formatCurrency(totalPayment)),
          _invoiceRow("DP Dibayar (50%)", "- ${formatCurrency(dpPaid)}"),
          _invoiceRow("Overtime (${_overtimeHours} Jam)", formatCurrency(_overtimeHours * _overtimeCost)),
          const Divider(color: AppTheme.border, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "SISA PELUNASAN WAJIB",
                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                formatCurrency(_finalDueAmount),
                style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          if (_simulationState == 'completed') ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentMethodScreen(
                        bookingData: _bookingDetails,
                        bookingId: _currentBookingId ?? widget.bookingId,
                        isPelunasan: true,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  "BAYAR PELUNASAN SEKARANG (${formatCurrency(_finalDueAmount)})",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ] else if (_simulationState == 'paid') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _simulationState = 'review';
                  });
                },
                icon: const Icon(Icons.star_rounded, color: Colors.black, size: 20),
                label: Text(
                  "BERI ULASAN DRIVER",
                  style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF7F),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _invoiceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5)),
          Text(value, style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _navigateToDashboard() {
    _pollingTimer?.cancel();
    _realtimeSubscription?.cancel();
    _driversSubscription?.cancel();
    try {
      final clientBookingProv = Provider.of<ClientBookingProvider>(context, listen: false);
      clientBookingProv.clearBooking();
      clientBookingProv.unsubscribeFromBookings();
    } catch (e) {
      debugPrint("ClientBookingProvider unsubscribe notice: $e");
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeLoggedInScreen()),
      (route) => false,
    );
  }

  Widget _buildReviewScreen(String name, String image) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: _navigateToDashboard,
            icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.textMuted, size: 18),
            label: Text(
              "Lewati",
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                const Icon(Icons.check_circle_outline_rounded, color: AppTheme.primaryPink, size: 72),
                const SizedBox(height: 16),
                Text(
                  "Layanan Selesai!",
                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  "Berikan ulasan Anda untuk meningkatkan kualitas layanan.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 36,
                  backgroundImage: NetworkImage(image),
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starVal = index + 1;
                    final isSelected = starVal <= _userRating;
                    return IconButton(
                      icon: Icon(
                        isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFF59E0B),
                        size: 36,
                      ),
                      onPressed: () => setState(() => _userRating = starVal.toDouble()),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: TextField(
                    controller: _reviewController,
                    maxLines: 3,
                    style: const TextStyle(color: AppTheme.textHighContrast),
                    decoration: const InputDecoration(
                      hintText: "Tulis ulasan Anda di sini (rapi, sopan, dll)...",
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final bookingId = _currentBookingId ?? widget.bookingId ?? widget.bookingData?['id']?.toString() ?? _bookingDetails?['id']?.toString() ?? '';
                      final authProv = Provider.of<AuthProvider>(context, listen: false);
                      final user = Supabase.instance.client.auth.currentUser;
                      final userId = user?.id ?? authProv.user?.id;
                      final userName = authProv.user?.fullName ?? user?.userMetadata?['full_name']?.toString() ?? 'Pelanggan';
                      final userAvatar = authProv.user?.avatarUrl ?? user?.userMetadata?['avatar_url']?.toString() ?? '';

                      final Map<String, dynamic> mergedDetails = Map<String, dynamic>.from(
                        (_bookingDetails != null && _bookingDetails!.containsKey('additional_details') && _bookingDetails!['additional_details'] is Map)
                            ? (_bookingDetails!['additional_details'] as Map)
                            : (_bookingDetails ?? widget.bookingData ?? {})
                      );

                      final rawDriverId = _bookingDetails?['driver_id']?.toString() ?? 
                                       widget.bookingData?['driver_id']?.toString() ?? 
                                       mergedDetails['driverId']?.toString() ?? 
                                       mergedDetails['partnerId']?.toString() ??
                                       mergedDetails['driver_id']?.toString();

                      final reviewText = _reviewController.text.trim();

                      // Resolve driver mapping (table id & user_id)
                      String? targetDriverTableId = rawDriverId;
                      String? targetDriverUserId;
                      if (rawDriverId != null && rawDriverId.isNotEmpty && !rawDriverId.startsWith('mock')) {
                        try {
                          final drvRow = await Supabase.instance.client
                              .from('drivers')
                              .select('id, user_id')
                              .or('id.eq.$rawDriverId,user_id.eq.$rawDriverId')
                              .maybeSingle();
                          if (drvRow != null) {
                            targetDriverTableId = drvRow['id']?.toString() ?? rawDriverId;
                            targetDriverUserId = drvRow['user_id']?.toString();
                          }
                        } catch (e) {
                          debugPrint('Notice resolving driver ids: $e');
                        }
                      }

                      // 1. Save to Supabase 'reviews' table
                      if (bookingId.isNotEmpty && targetDriverTableId != null && targetDriverTableId.isNotEmpty && userId != null) {
                        try {
                          try {
                            await Supabase.instance.client.from('reviews').insert({
                              'booking_id': bookingId,
                              'user_id': userId,
                              'driver_id': targetDriverTableId,
                              'rating': _userRating,
                              'comment': reviewText,
                            });
                          } catch (e) {
                            debugPrint('First review insert attempt failed, trying customer_id: $e');
                            try {
                              await Supabase.instance.client.from('reviews').insert({
                                'booking_id': bookingId,
                                'customer_id': userId,
                                'driver_id': targetDriverTableId,
                                'rating': _userRating,
                                'comment': reviewText,
                              });
                            } catch (e2) {
                              debugPrint('Second review insert attempt failed: $e2');
                            }
                          }

                          if (targetDriverUserId != null && targetDriverUserId != targetDriverTableId) {
                            try {
                              await Supabase.instance.client.from('reviews').insert({
                                'booking_id': bookingId,
                                'user_id': userId,
                                'driver_id': targetDriverUserId,
                                'rating': _userRating,
                                'comment': reviewText,
                              });
                            } catch (_) {}
                          }

                          // Recalculate average rating for the driver
                          final allReviews = await Supabase.instance.client
                              .from('reviews')
                              .select('rating')
                              .or('driver_id.eq.$targetDriverTableId${targetDriverUserId != null ? ",driver_id.eq.$targetDriverUserId" : ""}');

                          if (allReviews.isNotEmpty) {
                            final sum = allReviews.fold<double>(
                                0.0, (acc, r) => acc + (double.tryParse(r['rating']?.toString() ?? '5') ?? 5.0));
                            final avg = (sum / allReviews.length).clamp(1.0, 5.0);
                            await Supabase.instance.client
                                .from('drivers')
                                .update({'rating': double.parse(avg.toStringAsFixed(1))})
                                .eq('id', targetDriverTableId);
                          }
                        } catch (e) {
                          debugPrint('Notice on review submission: $e');
                        }
                      }

                      // 2. Persist review & completed payment directly into 'bookings' table
                      if (bookingId.isNotEmpty && !bookingId.startsWith('mock')) {
                        try {
                          mergedDetails['has_reviewed'] = true;
                          mergedDetails['rating'] = _userRating;
                          mergedDetails['comment'] = reviewText;
                          mergedDetails['client_name'] = userName;
                          mergedDetails['client_avatar'] = userAvatar;
                          mergedDetails['user_name'] = userName;
                          mergedDetails['user_avatar'] = userAvatar;
                          mergedDetails['pelunasan_paid'] = true;
                          mergedDetails['final_paid'] = true;
                          mergedDetails['sub_status'] = 'paid';
                          mergedDetails['payment_status'] = 'LUNAS';

                          final updatePayload = <String, dynamic>{
                            'status': 'completed',
                            'additional_details': mergedDetails,
                          };
                          if (targetDriverTableId != null) {
                            updatePayload['driver_id'] = targetDriverTableId;
                          }
                          await Supabase.instance.client
                              .from('bookings')
                              .update(updatePayload)
                              .eq('id', bookingId);
                        } catch (e) {
                          debugPrint('Error updating booking status to completed: $e');
                        }
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Terima kasih atas ulasan Anda! Pembayaran lunas dan sesi telah selesai."),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                        _navigateToDashboard();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      "KIRIM ULASAN & SELESAI",
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _navigateToDashboard,
                  child: Text(
                    "Kembali ke Dashboard",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _emergencyContact = '+62 811-9999-110';
  bool _alarmTriggered = false;

  void _showEmergencyDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.safetyGradient,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFFFF4DA6), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top notch
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFFFF4DA6), size: 28),
                  const SizedBox(width: 12),
                  Text(
                    "Safety & Security Hub",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Perjalanan Anda dipantau oleh admin secara real-time demi keamanan Anda. Pilih opsi darurat di bawah jika terjadi kendala.",
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              
              // Alarm Trigger Row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _alarmTriggered ? const Color(0xFFFF4DA6) : Colors.white10,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _alarmTriggered ? Icons.alarm_on : Icons.alarm_off,
                      color: _alarmTriggered ? const Color(0xFFFF4DA6) : Colors.white30,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Bunyikan Sirine Lokal",
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            "Simulasikan alarm suara keras untuk menarik perhatian sekitar.",
                            style: GoogleFonts.poppins(color: Colors.white30, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _alarmTriggered,
                      activeColor: const Color(0xFFFF4DA6),
                      onChanged: (val) {
                        setModalState(() {
                          _alarmTriggered = val;
                        });
                        setState(() {
                          _alarmTriggered = val;
                        });
                        if (_alarmTriggered) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("🚨 Sirine Darurat Terpicu! (Simulasi alarm suara keras)"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // SOS Action Cards
              Row(
                children: [
                  Expanded(
                    child: _safetyActionCard(
                      icon: Icons.phone_in_talk_rounded,
                      label: "Panggil SOS",
                      color: const Color(0xFFFF4DA6),
                      textColor: Colors.black,
                      onPressed: () {
                        Navigator.pop(context);
                        _triggerSOSCall();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _safetyActionCard(
                      icon: Icons.share_location_rounded,
                      label: "Bagikan Rute",
                      color: Colors.white.withOpacity(0.08),
                      textColor: Colors.white,
                      onPressed: () {
                        Navigator.pop(context);
                        _shareTripLocation();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _safetyActionCard(
                icon: Icons.contact_phone_rounded,
                label: "Kontak Darurat saat ini: $_emergencyContact",
                color: Colors.white.withOpacity(0.04),
                textColor: Colors.white70,
                onPressed: () {
                  Navigator.pop(context);
                  _configureEmergencyContact();
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Tutup",
                    style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _safetyActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerSOSCall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D1625),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Panggilan Darurat",
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Menghubungi Tim Respons Keamanan Temenin Ajaa...\n\n(Telepon simulasi berhasil dilakukan ke nomor darurat).",
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF3D1625),
            ),
            child: const Text("Selesai"),
          ),
        ],
      ),
    );
  }

  void _shareTripLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Tautan pelacakan perjalanan langsung Anda dibagikan ke kontak darurat!"),
        backgroundColor: Color(0xFF8E2B5F),
      ),
    );
  }

  void _configureEmergencyContact() {
    final controller = TextEditingController(text: _emergencyContact);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1A24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Kontak Darurat",
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF131218),
            labelText: "Nomor Telepon",
            labelStyle: const TextStyle(color: Color(0xFFFF9DCC)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            prefixIcon: const Icon(Icons.phone, color: Color(0xFFFF9DCC)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal", style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _emergencyContact = controller.text;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Kontak Darurat diperbarui: $_emergencyContact'),
                  backgroundColor: const Color(0xFF8E2B5F),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9DCC),
              foregroundColor: Colors.black,
            ),
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }
}

// Interactive Sub-Screen for mock chat room
class _MockChatScreen extends StatefulWidget {
  final String name;
  final String image;
  final String? bookingId;
  
  const _MockChatScreen({required this.name, required this.image, this.bookingId});

  @override
  State<_MockChatScreen> createState() => _MockChatScreenState();
}

class _MockChatScreenState extends State<_MockChatScreen> {
  List<Map<String, dynamic>> _messages = [];
  final _msgController = TextEditingController();
  
  Map<String, dynamic>? _bookingData;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    if (widget.bookingId != null && widget.bookingId!.isNotEmpty) {
      _isConnecting = true;
      _subscribeToChat();
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _msgController.dispose();
    super.dispose();
  }

  void _subscribeToChat() {
    try {
      _streamSubscription = Supabase.instance.client
          .from('booking_messages')
          .stream(primaryKey: ['id'])
          .eq('booking_id', widget.bookingId!)
          .order('created_at', ascending: true)
          .listen((List<Map<String, dynamic>> data) {
            if (mounted) {
              final formatted = data.map((m) {
                final sender = m['sender_role'] ?? m['sender'] ?? 'user';
                String time = '';
                if (m['created_at'] != null) {
                  final dt = DateTime.tryParse(m['created_at'].toString())?.toLocal() ?? DateTime.now();
                  time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                }
                return {
                  'id': m['id'],
                  'sender': (sender == 'client' || sender == 'user') ? 'user' : 'driver',
                  'text': m['message'] ?? m['text'] ?? '',
                  'time': time.isNotEmpty ? time : "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                  'timestamp': m['created_at'],
                };
              }).toList();

              setState(() {
                _messages = formatted;
                _isConnecting = false;
              });
            }
          }, onError: (err) {
            debugPrint('Chat stream error: $err');
            if (mounted) {
              setState(() {
                _isConnecting = false;
              });
            }
          });
    } catch (e) {
      debugPrint('Supabase stream setup error: $e');
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    
    final newMsg = {
      'sender': 'user',
      'text': text,
      'time': timeStr,
      'timestamp': now.toIso8601String(),
    };

    final updatedMessages = List<Map<String, dynamic>>.from(_messages)..add(newMsg);
    setState(() {
      _messages = updatedMessages;
      _msgController.clear();
    });

    if (widget.bookingId != null && widget.bookingId!.isNotEmpty) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        await Supabase.instance.client.from('booking_messages').insert({
          'booking_id': widget.bookingId!,
          'sender_id': user?.id ?? '00000000-0000-0000-0000-000000000000',
          'sender_role': 'client',
          'message': text,
        });
      } catch (e) {
        debugPrint('Error sending message from client: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0C11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16151A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(radius: 16, backgroundImage: NetworkImage(widget.image)),
            const SizedBox(width: 10),
            Text(widget.name, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isConnecting
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF9DCC))))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender'] == 'user';
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFFFF9DCC) : const Color(0xFF1C1B21),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            msg['text'] ?? '',
                            style: GoogleFonts.poppins(
                              color: isMe ? const Color(0xFF4A1031) : Colors.white,
                              fontSize: 13,
                              fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            color: const Color(0xFF16151A),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: const Color(0xFF1C1B21), borderRadius: BorderRadius.circular(25)),
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Kirim pesan...",
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Color(0xFFFF9DCC), shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Color(0xFF4A1031), size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SimulatedMapWidget extends StatefulWidget {
  final String status;
  const SimulatedMapWidget({super.key, required this.status});

  @override
  State<SimulatedMapWidget> createState() => _SimulatedMapWidgetState();
}

class _SimulatedMapWidgetState extends State<SimulatedMapWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    if (widget.status == 'on_the_way') {
      _controller.repeat();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(SimulatedMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == 'on_the_way') {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: MapSimulationPainter(
            progress: _controller.value,
            status: widget.status,
          ),
        );
      },
    );
  }
}

class MapSimulationPainter extends CustomPainter {
  final double progress;
  final String status;

  MapSimulationPainter({required this.progress, required this.status});

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = const Color(0xFFFF9DCC).withOpacity(0.04)
      ..strokeWidth = 1.0;

    // Draw grid lines
    const gridSpacing = 40.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGrid);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    // Define points for the path
    final startPoint = Offset(size.width * 0.15, size.height * 0.75);
    final controlPoint1 = Offset(size.width * 0.5, size.height * 0.85);
    final controlPoint2 = Offset(size.width * 0.8, size.height * 0.45);
    final endPoint = Offset(size.width * 0.5, size.height * 0.35);

    final path = Path()
      ..moveTo(startPoint.dx, startPoint.dy)
      ..cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        endPoint.dx, endPoint.dy,
      );

    // Draw route path (glowing line)
    final routePaint = Paint()
      ..color = const Color(0xFFFF9DCC).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, routePaint);

    final routeActivePaint = Paint()
      ..color = const Color(0xFFFF9DCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // Extract path metrics to get the position along the path
    final pathMetrics = path.computeMetrics();
    Offset driverPosition = startPoint;
    double currentProgress = (status == 'on_the_way') ? progress : 1.0;

    for (final metric in pathMetrics) {
      final length = metric.length;
      final currentLength = length * currentProgress;
      
      // Draw active path
      final extractPath = metric.extractPath(0.0, currentLength);
      canvas.drawPath(extractPath, routeActivePaint);

      final tangent = metric.getTangentForOffset(currentLength);
      if (tangent != null) {
        driverPosition = tangent.position;
      }
    }

    // Draw client destination pin (glowing target)
    final pinPaint = Paint()
      ..color = const Color(0xFFFF9DCC)
      ..style = PaintingStyle.fill;
    
    // Outer glow for client pin
    canvas.drawCircle(endPoint, 12.0, Paint()..color = const Color(0xFFFF9DCC).withOpacity(0.3));
    canvas.drawCircle(endPoint, 6.0, pinPaint);
    
    // Draw target client text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Penjemputan',
        style: TextStyle(
          color: const Color(0xFFFF9DCC),
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          backgroundColor: const Color(0xFF0D0C11).withOpacity(0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(endPoint.dx - textPainter.width / 2, endPoint.dy - 22));

    // Draw driver marker
    final driverPaint = Paint()
      ..color = const Color(0xFF9D6BFF)
      ..style = PaintingStyle.fill;

    // Pulse animation around driver marker
    if (status == 'on_the_way') {
      final pulseRadius = 8.0 + (progress * 12.0) % 12.0;
      final pulsePaint = Paint()
        ..color = const Color(0xFF9D6BFF).withOpacity(1.0 - (pulseRadius - 8.0) / 12.0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(driverPosition, pulseRadius, pulsePaint);
    }

    canvas.drawCircle(driverPosition, 10.0, Paint()..color = const Color(0xFF9D6BFF).withOpacity(0.3));
    canvas.drawCircle(driverPosition, 5.0, driverPaint);

    // Draw driver tag text
    final driverTextPainter = TextPainter(
      text: TextSpan(
        text: 'Driver',
        style: TextStyle(
          color: const Color(0xFF9D6BFF),
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          backgroundColor: const Color(0xFF0D0C11).withOpacity(0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    driverTextPainter.layout();
    driverTextPainter.paint(
      canvas,
      Offset(driverPosition.dx - driverTextPainter.width / 2, driverPosition.dy + 10),
    );
  }

  @override
  bool shouldRepaint(covariant MapSimulationPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.status != status;
  }
}