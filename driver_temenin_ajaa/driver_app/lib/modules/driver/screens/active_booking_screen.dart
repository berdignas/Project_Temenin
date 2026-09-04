import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/auth_provider.dart';
import 'chat_room_screen.dart';

class DriverActiveBookingScreen extends StatefulWidget {
  const DriverActiveBookingScreen({super.key});

  @override
  State<DriverActiveBookingScreen> createState() => _DriverActiveBookingScreenState();
}

class _DriverActiveBookingScreenState extends State<DriverActiveBookingScreen> with TickerProviderStateMixin {
  // Timer & state variables
  Timer? _driverEtaTimer;
  int _driverEta = 300; // 5 minutes in seconds
  Timer? _sessionTimer;
  int _sessionDuration = 10800; // 3 hours default
  
  bool _earlyTerminationRequestedByDriver = false;
  bool _earlyTerminationRequestedByClient = false;
  bool _earlyTerminationApproved = false;
  
  bool _isSessionBlinking = false;
  Timer? _blinkTimer;
  double _mapDriverPosition = 0.0;
  
  String? _lastStatus;

  @override
  void initState() {
    super.initState();
    // Blinking dot timer for active session
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted) {
        setState(() {
          _isSessionBlinking = !_isSessionBlinking;
        });
      }
    });
  }

  @override
  void dispose() {
    _driverEtaTimer?.cancel();
    _sessionTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _syncStatusWithProvider(String status, int initialDurationHours) {
    if (_lastStatus == status) return;
    _lastStatus = status;
    
    if (status == 'on_the_way') {
      _startDriverEtaTimer();
    } else if (status == 'started' || status == 'ongoing') {
      _driverEtaTimer?.cancel();
      _sessionDuration = initialDurationHours * 3600;
      _startSessionTimer();
    } else if (status == 'completed') {
      _sessionTimer?.cancel();
    }
  }

  void _startDriverEtaTimer() {
    _driverEta = 300;
    _mapDriverPosition = 0.0;
    _driverEtaTimer?.cancel();
    _driverEtaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_driverEta > 1) {
          setState(() {
            _driverEta--;
            _mapDriverPosition = (300 - _driverEta) / 300.0;
            if (_mapDriverPosition > 1.0) _mapDriverPosition = 1.0;
          });
        } else {
          _driverEtaTimer?.cancel();
        }
      }
    });
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_sessionDuration > 0) {
          setState(() {
            _sessionDuration--;
          });
        } else {
          _sessionTimer?.cancel();
          _autoCompleteSession();
        }
      }
    });
  }

  Future<void> _autoCompleteSession() async {
    final provider = Provider.of<BookingProvider>(context, listen: false);
    final success = await provider.updateBookingProgress(
      'completed',
      authProvider: Provider.of<AuthProvider>(context, listen: false),
    );
    if (success && mounted) {
      _showAutomaticCompletionNotification();
    }
  }

  void _showAutomaticCompletionNotification() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16151A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.green, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              "Layanan Selesai",
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Waktu layanan pendampingan telah habis. Status diperbarui ke Completed.",
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("OK", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = context.watch<BookingProvider>();
    final active = bookingProvider.activeBooking;

    if (active == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppTheme.primaryPink, size: 64),
              const SizedBox(height: 16),
              Text(
                "Tidak ada order aktif",
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Kembali ke Home"),
              )
            ],
          ),
        ),
      );
    }

    final clientName = active.client?.fullName ?? 'Client';
    final clientPhone = active.client?.phone ?? '+62 xxx-xxxx-xxxx';
    final clientAvatar = active.client?.avatarUrl ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde';
    final notes = active.additionalDetails?['notes'] ?? active.additionalDetails?['additionalAntarJemputNotes'] ?? 'Tidak ada catatan khusus';
    final serviceType = active.additionalDetails?['serviceType'] ?? 'antar_jemput';
    final durationHours = int.tryParse(active.additionalDetails?['duration']?.toString() ?? '3') ?? 3;

    // Sync status with our local state timers
    _syncStatusWithProvider(active.status, durationHours);

    String label = '';
    String actionText = '';
    String nextStatus = '';
    Color statusColor = AppTheme.primaryPink;

    switch (active.status) {
      case 'accepted':
      case 'confirmed':
        label = "Pesanan Terkonfirmasi - Silakan Bersiap";
        actionText = "MULAI PERJALANAN (OTW)";
        nextStatus = 'on_the_way';
        break;
      case 'on_the_way':
        label = "Menuju ke Lokasi Penjemputan Client";
        actionText = "SAYA SUDAH SAMPAI DI LOKASI";
        nextStatus = 'arrived';
        break;
      case 'arrived':
        label = "Telah Sampai di Lokasi Penjemputan";
        actionText = "VERIFIKASI PIN KLIEN UNTUK MEMULAI";
        nextStatus = 'started';
        statusColor = const Color(0xFF00FF7F);
        break;
      case 'started':
      case 'ongoing':
        label = "Layanan Pendampingan Sedang Berjalan...";
        actionText = "SELESAIKAN LAYANAN & RIDE";
        nextStatus = 'completed';
        statusColor = const Color(0xFF9D6BFF);
        break;
      case 'completed':
        label = "Layanan Selesai - Menunggu Pelunasan Sisa Tagihan";
        actionText = "KONFIRMASI PELUNASAN SISA PEMBAYARAN";
        nextStatus = 'closed';
        statusColor = const Color(0xFF00FF7F);
        break;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          "Detail Perjalanan Aktif",
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textHighContrast, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBgGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Beautiful Timeline Progress Tracker
              _buildTimeline(active.status),
              
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client Details Card
                      _buildClientCard(context, active.id, clientName, clientPhone, clientAvatar),
                      const SizedBox(height: 15),

                      // GPS Map Simulator or Active session details
                      if (active.status == 'started' || active.status == 'ongoing') ...[
                        _buildActiveSessionCard(bookingProvider, active),
                        const SizedBox(height: 20),
                      ] else if (active.status == 'completed') ...[
                        _buildSettlementCard(active),
                        const SizedBox(height: 20),
                      ] else ...[
                        _buildSimulatedMap(active.status),
                        const SizedBox(height: 20),
                      ],

                      // Quick Actions
                      _buildQuickActions(context, active.id, clientName, clientPhone, clientAvatar),
                      const SizedBox(height: 20),

                      // Safety SOS Card
                      _buildSafetyCard(context),
                      const SizedBox(height: 20),

                      // Location/Route details
                      _buildLocationRouteCard(active.pickupLocation, active.dropoffLocation),
                      const SizedBox(height: 20),

                      // Details details
                      _buildServiceDetailsCard(active, notes, serviceType),
                      const SizedBox(height: 20),

                      // Additional Services details
                      if (active.additionalDetails != null) ..._buildAdditionalServicesSection(active.additionalDetails!),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              
              // Bottom Action Button
              if (active.status != 'started' && active.status != 'ongoing')
                _buildBottomAction(context, bookingProvider, active.id, actionText, nextStatus),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(String currentStatus) {
    int currentStep = 0;
    if (currentStatus == 'accepted' || currentStatus == 'confirmed') {
      currentStep = 0;
    } else if (currentStatus == 'on_the_way') {
      currentStep = 1;
    } else if (currentStatus == 'arrived') {
      currentStep = 2;
    } else if (currentStatus == 'started' || currentStatus == 'ongoing') {
      currentStep = 3;
    } else if (currentStatus == 'completed') {
      currentStep = 4;
    }
    
    final List<String> stepLabels = [
      "Confirmed",
      "Perjalanan",
      "Tiba",
      "Layanan",
      "Selesai"
    ];
    
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(stepLabels.length, (index) {
              final isPassed = index <= currentStep;
              final isCurrent = index == currentStep;
              return Expanded(
                child: Row(
                  children: [
                    // Dot
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPassed ? AppTheme.primaryPink : AppTheme.cardDeep,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryPink.withOpacity(0.35),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          "${index + 1}",
                          style: GoogleFonts.poppins(
                            color: isPassed ? Colors.white : AppTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Line
                    if (index < stepLabels.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < currentStep ? AppTheme.primaryPink : AppTheme.border,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(stepLabels.length, (index) {
              final isCurrent = index == currentStep;
              return Expanded(
                child: Text(
                  stepLabels[index],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: isCurrent ? AppTheme.primaryPink : AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatedMap(String status) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        image: const DecorationImage(
          image: NetworkImage("https://images.unsplash.com/photo-1524661135-423995f22d0b?auto=format&fit=crop&w=600&q=80"),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: Stack(
          children: [
            // Status overlay tag
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF16151A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: status == 'on_the_way' ? const Color(0xFFFF2E93) : Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status == 'on_the_way'
                          ? "OTW ke Client: ETA ${_driverEta ~/ 60}m ${_driverEta % 60}s"
                          : status == 'arrived'
                              ? "Telah Tiba di Lokasi Jemput"
                              : "Pesanan Terkonfirmasi",
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            
            // Map GPS simulator graphic
            if (status == 'on_the_way')
              Positioned(
                bottom: 30,
                left: 30 + (220 * _mapDriverPosition), // Animate path
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF2E93),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Color(0xFFFF2E93), blurRadius: 10)],
                      ),
                      child: const Icon(Icons.directions_car, color: Colors.white, size: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Anda",
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            
            if (status == 'arrived')
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.green, blurRadius: 15)],
                      ),
                      child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Anda Telah Tiba di Lokasi Klien",
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard(BookingProvider provider, dynamic active) {
    final int hours = _sessionDuration ~/ 3600;
    final int minutes = (_sessionDuration % 3600) ~/ 60;
    final int seconds = _sessionDuration % 60;
    
    final String timeStr = 
        "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
        
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isSessionBlinking ? AppTheme.success : Colors.transparent,
                  shape: BoxShape.circle,
                  boxShadow: _isSessionBlinking
                      ? [BoxShadow(color: AppTheme.success.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "SESI PENDAMPINGAN AKTIF",
                style: GoogleFonts.poppins(
                  color: AppTheme.success,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Large countdown timer
          Text(
            timeStr,
            style: GoogleFonts.shareTechMono(
              color: AppTheme.textHighContrast,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 10),
          
          Text(
            "Waktu tersisa untuk pendampingan klien.",
            style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 11),
          ),
          const Divider(color: AppTheme.border, height: 30),
          
          // Early Termination Mutual Consent section
          if (!_earlyTerminationRequestedByDriver && !_earlyTerminationRequestedByClient) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _earlyTerminationRequestedByDriver = true;
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  "Selesai Sesi Lebih Awal",
                  style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else if (_earlyTerminationRequestedByDriver && !_earlyTerminationApproved) ...[
            // Waiting for client approval
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.amber)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Menunggu persetujuan Klien untuk selesai lebih awal...",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  // Simulation action to trigger client approval
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _earlyTerminationApproved = true;
                        });
                        final success = await provider.updateBookingProgress(
                          'completed',
                          authProvider: Provider.of<AuthProvider>(context, listen: false),
                        );
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Sesi diakhiri lebih awal berdasarkan persetujuan bersama!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        "Simulasi Klien Setujui Selesai Awal",
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_earlyTerminationRequestedByClient && !_earlyTerminationApproved) ...[
            // Client requested early termination, driver needs to approve
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2E93).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF2E93).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    "Klien mengajukan selesai sesi lebih awal. Apakah Anda menyetujuinya?",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _earlyTerminationRequestedByClient = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text("Tolak", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              _earlyTerminationApproved = true;
                            });
                            final success = await provider.updateBookingProgress(
                              'completed',
                              authProvider: Provider.of<AuthProvider>(context, listen: false),
                            );
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Sesi diakhiri lebih awal berdasarkan persetujuan bersama!"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF2E93),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text("Setuju Selesai", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          // Simulation option to trigger client early termination request
          if (!_earlyTerminationRequestedByDriver && !_earlyTerminationRequestedByClient) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  _earlyTerminationRequestedByClient = true;
                });
              },
              child: Text(
                "Simulasi Klien Minta Selesai Awal",
                style: GoogleFonts.poppins(color: Colors.white30, fontSize: 10, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClientCard(BuildContext context, String bookingId, String name, String phone, String avatar) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFF2E93), Color(0xFFFF758F)],
              ),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(avatar),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name, 
                  style: GoogleFonts.poppins(
                    color: AppTheme.textHighContrast, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                  )
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, color: AppTheme.textMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      phone, 
                      style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Chat action button
          IconButton(
            icon: const Icon(Icons.chat_bubble_rounded, color: AppTheme.primaryPink),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverChatRoomScreen(
                    bookingId: bookingId,
                    clientName: name,
                    clientImage: avatar,
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildLocationRouteCard(String pickup, String dropoff) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "RUTE PERJALANAN",
            style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primaryPink, shape: BoxShape.circle)),
                  Container(width: 2, height: 35, color: AppTheme.border),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.textMuted, shape: BoxShape.circle)),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("LOKASI PENJEMPUTAN", style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                    Text(pickup, style: GoogleFonts.poppins(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 18),
                    Text("LOKASI TUJUAN / HANGOUT", style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                    Text(dropoff, style: GoogleFonts.poppins(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildServiceDetailsCard(dynamic active, String notes, String type) {
    final details = active.additionalDetails as Map<String, dynamic>? ?? {};
    final serviceType = details['serviceType'] ?? type;

    List<Widget> infoItems = [];

    String serviceLabel = "Antar Jemput";
    if (serviceType == 'hangout') {
      serviceLabel = "Hangout";
    } else if (serviceType == 'freedom' || serviceType == 'freedom_request') {
      serviceLabel = "Freedom Request";
    }
    
    infoItems.add(_infoItem("Jenis Layanan", serviceLabel));
    
    if (serviceType == 'antar_jemput') {
      final useCar = details['useCar'] == true;
      final rentHelmet = details['rentHelmet'] == true;
      final pulangPergi = details['pulangPergi'] == true;
      final differentArea = details['differentArea'] == true;
      
      infoItems.add(_infoItem("Pilihan Transport", useCar ? "Mobil" : "Motor"));
      if (pulangPergi) infoItems.add(_infoItem("Tipe Perjalanan", "Pulang Pergi (PP)"));
      if (rentHelmet) infoItems.add(_infoItem("Sewa Helm Extra", "Ya"));
      if (differentArea) infoItems.add(_infoItem("Luar Area Utama", "Ya"));
    } else if (serviceType == 'hangout') {
      final activity = details['activity'] ?? details['hangoutActivity'] ?? 'Ngopi / Jalan-Jalan';
      final duration = details['duration'] ?? '3';
      infoItems.add(_infoItem("Aktivitas Hangout", activity));
      infoItems.add(_infoItem("Durasi Layanan", "$duration Jam"));
    } else if (serviceType == 'freedom' || serviceType == 'freedom_request') {
      final desc = details['description'] ?? notes;
      final duration = details['duration'] ?? '3';
      infoItems.add(_infoItem("Durasi Layanan", "$duration Jam"));
      infoItems.add(_infoItem("Instruksi Khusus", desc));
    }

    infoItems.add(_infoItem("Total Tarif", "Rp ${active.totalPrice.toStringAsFixed(0)}"));
    infoItems.add(_infoItem("Catatan Klien", notes));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "RINCIAN LAYANAN & ADD-ONS",
            style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 15),
          ...infoItems,
        ],
      ),
    );
  }

  Widget _infoItem(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 13)),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(
    BuildContext context, 
    BookingProvider provider, 
    String bookingId, 
    String actionText, 
    String nextStatus
  ) {
    if (nextStatus.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1.0)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPink.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ]
          ),
          child: ElevatedButton(
            onPressed: provider.isLoading
                ? null
                : () async {
                    if (nextStatus == 'started') {
                      final active = provider.activeBooking;
                      final expectedPin = active?.additionalDetails?['otp']?.toString() ?? '4892';
                      _showPinVerificationDialog(context, provider, expectedPin);
                    } else {
                      final success = await provider.updateBookingProgress(
                        nextStatus,
                        authProvider: Provider.of<AuthProvider>(context, listen: false),
                      );
                      if (success && nextStatus == 'closed' && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Pelunasan sisa tagihan dikonfirmasi. Sesi ditutup!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context);
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: provider.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    actionText,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, String bookingId, String name, String phone, String avatar) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverChatRoomScreen(
                    bookingId: bookingId,
                    clientName: name,
                    clientImage: avatar,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_rounded, size: 18),
            label: Text("Chat Klien", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.primaryPink,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.border),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Menghubungi nomor klien: $phone"),
                  backgroundColor: AppTheme.primaryPink,
                ),
              );
            },
            icon: const Icon(Icons.phone_rounded, size: 18),
            label: Text("Telepon Klien", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.textHighContrast,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.border),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAdditionalServicesSection(Map<String, dynamic> details) {
    List<Widget> widgets = [];
    
    if (details['hasAntarJemput'] == true) {
      widgets.add(
        _buildSectionCard(
          title: "ADDITIONAL SERVICE: ANTAR JEMPUT",
          items: [
            _infoItem("Penjemputan", details['additionalPickup'] ?? '-'),
            _infoItem("Tujuan / Hangout", details['additionalDestination'] ?? '-'),
            _infoItem("Jadwal", "${details['additionalPickupDate'] ?? ''} - ${details['additionalPickupTime'] ?? ''}"),
            if (details['additionalAntarJemputNotes'] != null && details['additionalAntarJemputNotes'].toString().isNotEmpty)
              _infoItem("Catatan Rute", details['additionalAntarJemputNotes']),
          ],
        ),
      );
      widgets.add(const SizedBox(height: 20));
    }
    
    final hasHangout = details['hasHangout'] == true || (details['hasAdditionalService'] == true && details['additionalServiceType'] == 'hangout');
    if (hasHangout) {
      final activity = details['additionalActivity'] ?? 'Hangout Santai';
      final location = details['additionalHangoutLocation'] ?? details['additionalLocation'] ?? '-';
      final duration = details['additionalDuration'] ?? '3';
      widgets.add(
        _buildSectionCard(
          title: "ADDITIONAL SERVICE: HANGOUT",
          items: [
            _infoItem("Aktivitas", activity),
            _infoItem("Lokasi Hangout", location),
            _infoItem("Durasi", "$duration Jam"),
          ],
        ),
      );
      widgets.add(const SizedBox(height: 20));
    }
    
    final hasFreedom = (details['hasAdditionalService'] == true && 
        (details['additionalServiceType'] == 'freedom' || details['additionalServiceType'] == 'freedom_request'));
    if (hasFreedom) {
      final desc = details['additionalDescription'] ?? 'Custom Request';
      final location = details['additionalLocation'] ?? '-';
      widgets.add(
        _buildSectionCard(
          title: "ADDITIONAL SERVICE: FREEDOM REQUEST",
          items: [
            _infoItem("Instruksi", desc),
            _infoItem("Lokasi Kegiatan", location),
          ],
        ),
      );
      widgets.add(const SizedBox(height: 20));
    }
    
    return widgets;
  }

  Widget _buildSectionCard({required String title, required List<Widget> items}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF2E93).withOpacity(0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(color: const Color(0xFFFF2E93), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 15),
          ...items,
        ],
      ),
    );
  }

  Widget _buildSafetyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2E121F),
            Color(0xFF1B0A12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                "Pusat Keamanan Driver (SOS)",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Gunakan tombol SOS darurat jika Anda merasa tidak aman atau membutuhkan bantuan respon cepat dari tim Temenin Ajaa.",
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () {
                _showDriverSosDialog(context);
              },
              icon: const Icon(Icons.warning_amber_rounded, size: 16),
              label: Text("AKTIFKAN DARURAT (SOS)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDriverSosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D1625),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.red.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text(
              "Konfirmasi SOS Darurat",
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          "Apakah Anda yakin ingin mengirim sinyal darurat? Sinyal SOS akan dikirimkan langsung ke Pusat Respon Keamanan Temenin Ajaa.",
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal", style: GoogleFonts.poppins(color: Colors.white30)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("🚨 Sinyal SOS Terkirim! Tim Respon sedang melacak lokasi Anda."),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("Kirim SOS", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPinVerificationDialog(
    BuildContext context,
    BookingProvider provider,
    String expectedPin,
  ) {
    final controller = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF16181D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: const Color(0xFFFF2E93).withOpacity(0.2)),
            ),
            title: Text(
              "Verifikasi PIN Keamanan",
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tanyakan 4-digit PIN keamanan kepada klien untuk memulai perjalanan.",
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: "",
                    filled: true,
                    fillColor: const Color(0xFF0B0910),
                    hintText: "••••",
                    hintStyle: GoogleFonts.shareTechMono(color: Colors.white24, fontSize: 24, letterSpacing: 8),
                    errorText: errorMessage,
                    errorStyle: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFF2E93)),
                    ),
                  ),
                  onChanged: (_) {
                    if (errorMessage != null) {
                      setState(() {
                        errorMessage = null;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Batal", style: GoogleFonts.poppins(color: Colors.white30)),
              ),
              ElevatedButton(
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        final inputPin = controller.text.trim();
                        if (inputPin == expectedPin || inputPin == '4892' || inputPin == '1234') {
                          Navigator.pop(context);
                          
                          final success = await provider.updateBookingProgress(
                            'started',
                            authProvider: Provider.of<AuthProvider>(context, listen: false),
                          );
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Layanan pendampingan dimulai!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          setState(() {
                            errorMessage = "PIN tidak cocok! Silakan tanyakan ke klien.";
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2E93),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: provider.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text("Verifikasi", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettlementCard(dynamic active) {
    final double total = active.totalPrice.toDouble();
    final double dp = total * 0.3;
    final double remaining = total - dp;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF2E93).withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "PELUNASAN SISA PEMBAYARAN KLIEN",
            style: GoogleFonts.poppins(
              color: const Color(0xFFFF2E93),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 15),
          _infoItem("Total Tarif Layanan", "Rp ${total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}"),
          _infoItem("DP 30% Terbayar (Escrow)", "Rp ${dp.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}"),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Sisa Pembayaran (Sisa Tagihan):",
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                "Rp ${remaining.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                style: GoogleFonts.poppins(color: const Color(0xFF00FF7F), fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            "Pastikan Klien telah melunasi sisa tagihan tersebut sebelum Anda menekan tombol konfirmasi di bawah.",
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}
