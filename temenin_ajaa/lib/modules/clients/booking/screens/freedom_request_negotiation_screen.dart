import 'package:temenin_ajaa/core/theme/app_theme.dart';
// lib/modules/clients/booking/screens/freedom_request_negotiation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'booking_confirmation_screen.dart';

class FreedomRequestNegotiationScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const FreedomRequestNegotiationScreen({super.key, required this.bookingData});

  @override
  State<FreedomRequestNegotiationScreen> createState() => _FreedomRequestNegotiationScreenState();
}

class _FreedomRequestNegotiationScreenState extends State<FreedomRequestNegotiationScreen> {
  // States: 'checking' -> 'first_offer' -> 'waiting_counter' -> 'counter_response' -> 'agreement_pending' -> 'accepted'
  String _negotiationState = 'checking';
  bool _clientApproved = false;
  
  late int _originalServiceFee;
  late int _currentDriverOffer;
  int _counterOffer = 0;
  
  // Simulated conversation messages
  final List<Map<String, dynamic>> _messages = [];
  final _counterController = TextEditingController();
  
  // Timer for simulations
  Timer? _simulationTimer;
  int _checkingStep = 0;
  final List<String> _checkingStepsText = [
    "Mengirim rincian request ke partner...",
    "Partner sedang meninjau deskripsi & rute...",
    "Partner sedang menghitung penawaran harga...",
  ];

  late int _userInitialOffer;

  @override
  void initState() {
    super.initState();
    _originalServiceFee = widget.bookingData['serviceFee'] ?? 70000;
    _userInitialOffer = widget.bookingData['userInitialPrice'] ?? _originalServiceFee;
    _currentDriverOffer = _originalServiceFee + 35000;
    _transitionToFirstOffer();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _counterController.dispose();
    super.dispose();
  }

  void _startCheckingSimulation() {
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          if (_checkingStep < 2) {
            _checkingStep++;
          } else {
            timer.cancel();
            _transitionToFirstOffer();
          }
        });
      }
    });
  }

  void _transitionToFirstOffer() {
    setState(() {
      // 1. Add User's initial offer message
      _messages.add({
        'sender': 'user',
        'text': "Halo, saya mengajukan penawaran harga awal sebesar Rp ${_formatNumber(_userInitialOffer)} untuk layanan utama ini.",
        'time': _getCurrentTime(),
      });

      // 2. Driver decision logic on initial offer
      if (_userInitialOffer >= (_originalServiceFee * 0.9)) {
        _currentDriverOffer = _userInitialOffer;
        _negotiationState = 'agreement_pending';
        _messages.add({
          'sender': 'driver',
          'text': "Tawaran Anda sebesar Rp ${_formatNumber(_currentDriverOffer)} cukup wajar. Saya setuju! Silakan konfirmasi persetujuan tarif di bawah agar kita bisa mulai.",
          'time': _getCurrentTime(),
        });
      } else {
        _negotiationState = 'first_offer';
        _messages.add({
          'sender': 'driver',
          'text': "Terima kasih atas penawaran awal Anda sebesar Rp ${_formatNumber(_userInitialOffer)}. Namun, deskripsi request Anda cukup detail dan memerlukan waktu khusus. Bagaimana jika Rp ${_formatNumber(_currentDriverOffer)}? Semoga cocok.",
          'time': _getCurrentTime(),
        });
      }
    });
  }

  void _submitCounterOffer() {
    final inputVal = int.tryParse(_counterController.text.replaceAll('.', ''));
    if (inputVal == null || inputVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Masukkan penawaran harga yang valid")),
      );
      return;
    }

    setState(() {
      _counterOffer = inputVal;
      _negotiationState = 'waiting_counter';
      _messages.add({
        'sender': 'user',
        'text': "Apakah bisa Rp ${_formatNumber(_counterOffer)}?",
        'time': _getCurrentTime(),
      });
    });

    FocusScope.of(context).unfocus();

    // Simulate driver thinking for 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;

      setState(() {
        // Driver simulation decision logic:
        // 1. If user counter-offer is close to original base or higher: Driver accepts
        // 2. If user counter-offer is extremely low (e.g. < originalBase * 0.8): Driver rejects/proposes slightly lower than current offer
        // 3. Otherwise: Driver counter-proposes a middle-ground
        
        int difference = _currentDriverOffer - _counterOffer;
        if (difference <= 15000) {
          // Accept counter offer
          _currentDriverOffer = _counterOffer;
          _negotiationState = 'agreement_pending';
          _messages.add({
            'sender': 'driver',
            'text': "Baiklah, saya setuju dengan harga Rp ${_formatNumber(_currentDriverOffer)}! Silakan konfirmasi persetujuan tarif di bawah agar kita bisa mulai.",
            'time': _getCurrentTime(),
          });
        } else if (_counterOffer < (_originalServiceFee * 0.85)) {
          // Reject and propose a counter closer to original/current
          int counterProp = _currentDriverOffer - 15000;
          if (counterProp < _originalServiceFee) counterProp = _originalServiceFee;
          _currentDriverOffer = counterProp;
          _negotiationState = 'counter_response';
          _messages.add({
            'sender': 'driver',
            'text': "Waduh, kalau segitu kejauhan kak. Bagaimana kalau Rp ${_formatNumber(_currentDriverOffer)}? Ini harga pas terbaik saya untuk membantu Anda.",
            'time': _getCurrentTime(),
          });
        } else {
          // Propose a middle-ground price
          int middleGround = ((_currentDriverOffer + _counterOffer) / 2).round();
          // Round to nearest thousand
          middleGround = (middleGround / 1000).round() * 1000;
          _currentDriverOffer = middleGround;
          _negotiationState = 'counter_response';
          _messages.add({
            'sender': 'driver',
            'text': "Bagaimana kalau tengah-tengahnya kak, Rp ${_formatNumber(_currentDriverOffer)}? Semoga cocok.",
            'time': _getCurrentTime(),
          });
        }
      });
    });
  }

  void _acceptOffer() {
    setState(() {
      _negotiationState = 'agreement_pending';
      _messages.add({
        'sender': 'driver',
        'text': "Mantap! Saya konfirmasi kesepakatan harga Rp ${_formatNumber(_currentDriverOffer)}. Silakan lakukan konfirmasi akhir persetujuan tarif di bawah.",
        'time': _getCurrentTime(),
      });
    });
  }

  void _clientConfirmAgreement() {
    setState(() {
      _clientApproved = true;
      _negotiationState = 'accepted';
      _messages.add({
        'sender': 'user',
        'text': "Saya menyetujui kesepakatan harga Rp ${_formatNumber(_currentDriverOffer)}! Mari kita lanjut ke konfirmasi booking.",
        'time': _getCurrentTime(),
      });
    });
    _navigateToConfirmation();
  }

  void _navigateToConfirmation() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      // Update pricing details in booking data based on negotiated fee
      final negotiatedServiceFee = _currentDriverOffer;
      final service2Fee = widget.bookingData['additionalServiceFee'] ?? 0;
      
      final carAddon = widget.bookingData['useCar'] == true ? 50000 : 0;
      final helmetAddon = widget.bookingData['rentHelmet'] == true ? 10000 : 0;
      final areaAddon = widget.bookingData['differentArea'] == true ? 20000 : 0;
      
      final baseSubtotal = negotiatedServiceFee + service2Fee;
      final subtotal = baseSubtotal + carAddon + helmetAddon + areaAddon;
      
      final bool isWeekend = widget.bookingData['weekendFee'] != null && widget.bookingData['weekendFee'] > 0;
      final weekendFee = isWeekend ? (subtotal * 0.25).toInt() : 0;
      
      final totalEstimasi = subtotal + weekendFee;
      final dp = (totalEstimasi * 0.5).toInt();
      final remainingPayment = totalEstimasi - dp;

      // Update Map
      final updatedBookingData = Map<String, dynamic>.from(widget.bookingData);
      updatedBookingData['serviceFee'] = negotiatedServiceFee;
      updatedBookingData['weekendFee'] = weekendFee;
      updatedBookingData['totalPayment'] = totalEstimasi + 10000; // including 10k insurance
      updatedBookingData['dp'] = dp + 5000; // DP includes 50% insurance
      updatedBookingData['remainingPayment'] = remainingPayment + 5000;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BookingConfirmationScreen(bookingData: updatedBookingData),
        ),
      );
    });
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  String _formatNumber(int val) {
    return val.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    final driverName = widget.bookingData['driverName'] ?? "User";
    final driverImage = widget.bookingData['driverImage'] ?? '';
    final vehicle = widget.bookingData['vehicle'] ?? "Kendaraan";
    final rating = widget.bookingData['driverRating'] ?? "4.9";
    final trips = widget.bookingData['driverTrips'] ?? "450";

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.primaryPink),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          "Negosiasi Harga F.R.",
          style: GoogleFonts.inter(
            color: AppTheme.primaryPink,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBgGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Partner Mini Profile Header Card
              _buildPartnerHeader(driverName, driverImage, vehicle, rating, trips),
              
              // Chat/Negotiation Interface
              Expanded(
                child: _negotiationState == 'checking'
                    ? _buildCheckingLoader()
                    : _buildNegotiationChatArea(),
              ),

              // Bottom control panels depending on state
              if (_negotiationState != 'checking') _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerHeader(String name, String image, String vehicle, String rating, String trips) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(image),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white12)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "$vehicle • ⭐ $rating ($trips Order)",
                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryPink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryPink.withOpacity(0.2)),
            ),
            child: Text(
              "Negosiasi",
              style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCheckingLoader() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              "Menghubungkan ke Partner",
              style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _checkingStepsText[_checkingStep],
                key: ValueKey<int>(_checkingStep),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 13),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _checkingStepIndicator("Request dikirim", _checkingStep >= 0),
                  const SizedBox(height: 10),
                  _checkingStepIndicator("Partner meninjau rincian", _checkingStep >= 1),
                  const SizedBox(height: 10),
                  _checkingStepIndicator("Menghitung tarif penawaran", _checkingStep >= 2),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _checkingStepIndicator(String text, bool completed) {
    return Row(
      children: [
        Icon(
          completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: completed ? AppTheme.primaryPink : Colors.white24,
          size: 18,
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.inter(
            color: completed ? Colors.white70 : Colors.white24,
            fontSize: 13,
            fontWeight: completed ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildNegotiationChatArea() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isDriver = msg['sender'] == 'driver';

        return Align(
          alignment: isDriver ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isDriver ? const Color(0xFF1C1B21) : AppTheme.primaryPink,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isDriver ? Radius.zero : const Radius.circular(16),
                bottomRight: isDriver ? const Radius.circular(16) : Radius.zero,
              ),
              border: isDriver ? Border.all(color: Colors.white.withOpacity(0.03)) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg['text'],
                  style: GoogleFonts.inter(
                    color: isDriver ? Colors.white : AppTheme.card,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    msg['time'],
                    style: TextStyle(
                      color: isDriver ? Colors.white38 : AppTheme.card.withOpacity(0.5),
                      fontSize: 9,
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    if (_negotiationState == 'waiting_counter') {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 15),
            Text(
              "Menunggu keputusan driver...",
              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_negotiationState == 'agreement_pending') {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Konfirmasi Kesepakatan Tarif",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1B21),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          "Driver",
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 11),
                        ),
                        Text(
                          "Persetujuan: SIAP",
                          style: GoogleFonts.inter(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1B21),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.pending_actions_rounded, color: AppTheme.primaryPink, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          "Anda",
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 11),
                        ),
                        Text(
                          "Menunggu Konfirmasi",
                          style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tarif Disepakati",
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Rp ${_formatNumber(_currentDriverOffer)}",
                      style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppTheme.primaryPink,
                        Color(0xFFFF6B9D),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPink.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _clientConfirmAgreement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: Text(
                      "Setujui & Konfirmasi Tarif",
                      style: GoogleFonts.inter(color: AppTheme.card, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_negotiationState == 'accepted') {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryPink, size: 24),
            const SizedBox(width: 12),
            Text(
              "Harga Disepakati! Mengalihkan...",
              style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // Otherwise show Offer Action Box: Setuju or Tawar (Tidak Setuju)
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Penawaran Tarif Layanan",
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Rp ${_formatNumber(_currentDriverOffer)}",
                    style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "*belum termasuk add-on & asuransi",
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Estimasi Awal",
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Rp ${_formatNumber(_originalServiceFee)}",
                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 14, decoration: TextDecoration.lineThrough),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _showCounterOfferDialog,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryPink),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      "Tidak Setuju / Tawar",
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppTheme.primaryPink,
                        Color(0xFFFF6B9D),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    onPressed: _acceptOffer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      "Setuju & Lanjut",
                      style: GoogleFonts.inter(color: AppTheme.card, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _showCounterOfferDialog() {
    _counterController.text = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B21),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Tawar Tarif Layanan",
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Masukkan tawaran harga Anda untuk layanan dasar dasar (tanpa add-on).",
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _counterController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.background,
                labelText: "Tawaran Anda (Rp)",
                labelStyle: const TextStyle(color: AppTheme.primaryPink),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                prefixText: "Rp ",
                prefixStyle: const TextStyle(color: AppTheme.primaryPink),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal", style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitCounterOffer();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              foregroundColor: Colors.black,
            ),
            child: const Text("Tawar"),
          ),
        ],
      ),
    );
  }
}
