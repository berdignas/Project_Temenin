import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/booking_model.dart';
import '../../../providers/booking_provider.dart';
import 'active_booking_screen.dart';

class DriverNegotiationScreen extends StatefulWidget {
  final BookingModel bookingData;

  const DriverNegotiationScreen({super.key, required this.bookingData});

  @override
  State<DriverNegotiationScreen> createState() => _DriverNegotiationScreenState();
}

class _DriverNegotiationScreenState extends State<DriverNegotiationScreen> {
  // Negotiation states: 'initial_offer' -> 'waiting_client' -> 'client_accepted'
  String _negotiationState = 'initial_offer';
  
  final _chatController = TextEditingController();
  final _bidController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _chatMessages = [];
  
  double _currentOfferPrice = 0.0;
  Timer? _simulationTimer;

  @override
  void initState() {
    super.initState();
    _currentOfferPrice = widget.bookingData.totalPrice;
    
    // Seed initial messages
    _chatMessages.add({
      'sender': 'system',
      'text': 'Room Chat Negosiasi & Request Kustom Dibuat',
      'time': '13:50',
      'isBid': false,
    });
    _chatMessages.add({
      'sender': 'client',
      'text': 'Halo! Saya mengajukan request kustom kencan pendampingan.',
      'time': '13:51',
      'isBid': false,
    });
    _chatMessages.add({
      'sender': 'client',
      'text': 'Tawaran awal saya: Rp ${_formatPrice(_currentOfferPrice)}',
      'time': '13:51',
      'isBid': true,
      'price': _currentOfferPrice,
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _bidController.dispose();
    _scrollController.dispose();
    _simulationTimer?.cancel();
    super.dispose();
  }

  String _formatPrice(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add({
        'sender': 'driver',
        'text': text,
        'time': '13:52',
        'isBid': false,
      });
      _chatController.clear();
    });
    _scrollToBottom();
  }

  void _showBidDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Ajukan Tawaran (Bid)", style: GoogleFonts.poppins(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: _bidController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textHighContrast),
            decoration: InputDecoration(
              hintText: "Nominal harga (Rp)",
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppTheme.primaryPink),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppTheme.border),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppTheme.primaryPink),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal", style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final double? offer = double.tryParse(_bidController.text.replaceAll('.', ''));
                if (offer != null && offer > 0) {
                  Navigator.pop(context);
                  _sendBidOffer(offer);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Kirim Bid"),
            ),
          ],
        );
      },
    );
  }

  void _sendBidOffer(double offer) {
    setState(() {
      _currentOfferPrice = offer;
      _negotiationState = 'waiting_client';
      _chatMessages.add({
        'sender': 'driver',
        'text': 'Mengajukan penawaran baru: Rp ${_formatPrice(offer)}',
        'time': '13:52',
        'isBid': true,
        'price': offer,
      });
      _bidController.clear();
    });
    _scrollToBottom();
    FocusScope.of(context).unfocus();

    // Trigger simulation of client accepting after 3.5 seconds
    _simulationTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          _negotiationState = 'client_accepted';
          _chatMessages.add({
            'sender': 'client',
            'text': 'Sip, setuju dengan harga Rp ${_formatPrice(_currentOfferPrice)}!',
            'time': '13:53',
            'isBid': false,
          });
          _chatMessages.add({
            'sender': 'system',
            'text': 'Klien telah mengunci harga dan membayar DP. Negosiasi Selesai.',
            'time': '13:53',
            'isBid': false,
          });
        });
        _scrollToBottom();
      }
    });
  }

  void _acceptClientBid() {
    setState(() {
      _negotiationState = 'client_accepted';
      _chatMessages.add({
        'sender': 'driver',
        'text': 'Saya setuju dengan penawaran Rp ${_formatPrice(_currentOfferPrice)}.',
        'time': '13:52',
        'isBid': false,
      });
      _chatMessages.add({
        'sender': 'system',
        'text': 'Klien telah mengunci harga dan membayar DP. Negosiasi Selesai.',
        'time': '13:52',
        'isBid': false,
      });
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final clientName = widget.bookingData.client?.fullName ?? 'Client';
    final clientAvatar = widget.bookingData.client?.avatarUrl ?? '';
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textHighContrast),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(clientAvatar.isNotEmpty ? clientAvatar : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80'),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: GoogleFonts.poppins(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  "Negosiasi Kustom",
                  style: GoogleFonts.poppins(color: AppTheme.primaryPink, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.textMuted),
            onPressed: () {
              // Show details
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Chat area
              Expanded(
                child: _buildChatSection(),
              ),

              // Control panel (Chat input or Accept confirmation button)
              _buildControlPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatSection() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: _chatMessages.length,
      itemBuilder: (context, index) {
        final msg = _chatMessages[index];
        final sender = msg['sender'];
        final isMe = sender == 'driver';
        final isSystem = sender == 'system';
        final isBid = msg['isBid'] == true;

        if (isSystem) {
          return Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16, top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.cardDeep,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                msg['text'],
                style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 10),
              ),
            ),
          );
        }
        
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              gradient: isBid 
                ? (isMe ? const LinearGradient(colors: [Color(0xFFE11D74), Color(0xFFFF4081)]) : const LinearGradient(colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)]))
                : null,
              color: isBid ? null : (isMe ? AppTheme.primaryPink : AppTheme.surface),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 16),
              ),
              border: (isMe || isBid) ? null : Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                  color: isMe ? AppTheme.primaryPink.withOpacity(0.12) : Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isBid)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gavel_rounded, color: isMe ? Colors.white : AppTheme.primaryPink, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        "TAWARAN HARGA",
                        style: GoogleFonts.poppins(
                          color: isMe ? Colors.white70 : AppTheme.primaryPink,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                if (isBid) const SizedBox(height: 6),
                
                Text(
                  msg['text'],
                  style: GoogleFonts.poppins(
                    color: isMe ? Colors.white : AppTheme.textHighContrast,
                    fontSize: isBid ? 15 : 13,
                    fontWeight: isBid ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                
                if (isBid && !isMe && _negotiationState == 'initial_offer') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _acceptClientBid,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Setujui Harga Ini", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],

                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    msg['time'],
                    style: TextStyle(
                      color: isMe ? Colors.white70 : AppTheme.textMuted,
                      fontSize: 9,
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

  Widget _buildControlPanel() {
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    if (_negotiationState == 'waiting_client') {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink)),
              ),
              const SizedBox(height: 15),
              Text(
                "Menunggu tanggapan dari client...",
                style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    } else if (_negotiationState == 'client_accepted') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Tarif Negosiasi Deal:", style: GoogleFonts.poppins(color: AppTheme.textMuted, fontSize: 13)),
                Text(
                  "Rp ${_formatPrice(_currentOfferPrice)}",
                  style: GoogleFonts.poppins(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  final success = await bookingProvider.acceptBookingWithPrice(
                    widget.bookingData.id,
                    _currentOfferPrice,
                  );
                  if (success && mounted) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DriverActiveBookingScreen()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  "MULAI RIDE & PENJEMPUTAN",
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default chat input mode
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // BID Button
            GestureDetector(
              onTap: _showBidDialog,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                ),
                child: const Icon(Icons.monetization_on_rounded, color: AppTheme.primaryPink, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            // Text Field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardDeep,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: "Ketik pesan...",
                    hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Send Button
            GestureDetector(
              onTap: _sendChatMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryPink,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
