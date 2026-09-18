import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'booking_confirmation_screen.dart';

class GamingBuddyBookingScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedPartner;

  const GamingBuddyBookingScreen({super.key, this.selectedPartner});

  @override
  State<GamingBuddyBookingScreen> createState() => _GamingBuddyBookingScreenState();
}

class _GamingBuddyBookingScreenState extends State<GamingBuddyBookingScreen> {
  String _selectedGame = 'Mobile Legends';
  String _selectedPlayMode = 'Per Jam'; // 'Per Jam' or 'Per Match'
  int _selectedQuantity = 2; // 2 Jam or 2 Match
  String _selectedGoal = 'Push Rank Santai';
  bool _useVoiceChat = true;
  final TextEditingController _inGameIdController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<Map<String, dynamic>> _gameList = [
    {'name': 'Mobile Legends', 'icon': Icons.sports_esports_rounded, 'genre': 'MOBA 5v5'},
    {'name': 'PUBG Mobile', 'icon': Icons.track_changes_rounded, 'genre': 'Battle Royale'},
    {'name': 'Valorant (PC)', 'icon': Icons.gps_fixed_rounded, 'genre': 'FPS Tactical'},
    {'name': 'Free Fire', 'icon': Icons.local_fire_department_rounded, 'genre': 'Battle Royale'},
    {'name': 'Honor of Kings', 'icon': Icons.shield_rounded, 'genre': 'MOBA 5v5'},
    {'name': 'Genshin Impact', 'icon': Icons.auto_awesome_rounded, 'genre': 'Action RPG / Co-op'},
    {'name': 'Roblox', 'icon': Icons.grid_view_rounded, 'genre': 'Casual Party'},
  ];

  final List<String> _gamingGoals = [
    'Push Rank Santai',
    'Main Seru & Senang-senang (Casual)',
    'Gendong / Carry Match (Kompetitif)',
    'Belajar Hero / Gameplay Tips',
  ];

  final int _ratePerHour = 30000;  // Rp 30.000 / jam
  final int _ratePerMatch = 15000; // Rp 15.000 / match

  int get _calculatedPrice {
    if (_selectedPlayMode == 'Per Jam') {
      return _selectedQuantity * _ratePerHour;
    } else {
      return _selectedQuantity * _ratePerMatch;
    }
  }

  @override
  void dispose() {
    _inGameIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _proceedToConfirmation() {
    final now = DateTime.now();
    final durationMinutes = _selectedPlayMode == 'Per Jam' ? _selectedQuantity * 60 : _selectedQuantity * 20;

    final Map<String, dynamic> bookingDetails = {
      'serviceType': 'Gaming Buddy (Mabar)',
      'service_category': 'VIRTUAL',
      'call_type': 'GAMING',
      'game_name': _selectedGame,
      'play_mode': _selectedPlayMode,
      'quantity': _selectedQuantity,
      'call_duration_minutes': durationMinutes,
      'duration': durationMinutes,
      'gaming_goal': _selectedGoal,
      'use_voice_chat': _useVoiceChat,
      'in_game_id': _inGameIdController.text.trim(),
      'serviceFee': _calculatedPrice,
      'insuranceFee': 0,
      'totalPayment': _calculatedPrice,
      'baseCost': _calculatedPrice,
      'dp': (_calculatedPrice * 0.5).round(),
      'remainingPayment': (_calculatedPrice * 0.5).round(),
      'note': 'Mabar $_selectedGame ($_selectedQuantity $_selectedPlayMode). Goal: $_selectedGoal. VC: ${_useVoiceChat ? 'On' : 'Off'}. ${_notesController.text.trim()}',
      'pickup': 'Sesi Mabar $_selectedGame',
      'destination': 'Target: $_selectedGoal ($_selectedQuantity $_selectedPlayMode)',
      'date': 'Hari Ini, ${now.day}/${now.month}/${now.year}',
      'time': 'Mulai Segera Setelah Bayar',
      'estimatedTime': '$durationMinutes',
      'vehicle': _useVoiceChat ? 'Discord VC' : 'No Voice Chat',
      'plateNumber': _selectedGame,
      'driverClass': 'Gamer Companion',
    };

    if (widget.selectedPartner != null) {
      bookingDetails['driver'] = widget.selectedPartner;
      bookingDetails['selectedPartner'] = widget.selectedPartner;
      bookingDetails['driver_id'] = widget.selectedPartner!['id'] ?? widget.selectedPartner!['driverId'];
      bookingDetails['driverName'] = widget.selectedPartner!['full_name'] ?? widget.selectedPartner!['name'] ?? 'Mitra Temenin';
      bookingDetails['driverRating'] = widget.selectedPartner!['rating']?.toString() ?? '5.0';
      bookingDetails['driverImage'] = widget.selectedPartner!['avatar_url'] ?? widget.selectedPartner!['image'] ?? '';
      bookingDetails['isOpenOffer'] = false;
      bookingDetails['is_open_offer'] = false;
    } else {
      bookingDetails['isOpenOffer'] = true;
      bookingDetails['is_open_offer'] = true;
      bookingDetails['driverName'] = 'Mitra Radar Temenin';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(bookingData: bookingDetails),
      ),
    );
  }

  Widget _buildSelectedPartnerHeader() {
    final partner = widget.selectedPartner!;
    final name = partner['full_name'] ?? partner['name'] ?? 'Mitra Temenin';
    final avatar = partner['avatar_url'] ?? partner['image'] ?? '';
    final rating = partner['rating']?.toString() ?? '5.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: avatar.isNotEmpty
                ? Image.network(
                    avatar,
                    width: 55,
                    height: 55,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 55,
                      height: 55,
                      color: const Color(0xFF6366F1).withOpacity(0.15),
                      child: const Icon(Icons.person, color: Color(0xFF6366F1), size: 30),
                    ),
                  )
                : Container(
                    width: 55,
                    height: 55,
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    child: const Icon(Icons.person, color: Color(0xFF6366F1), size: 30),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "MITRA GAMER TERPILIH",
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "⭐ $rating",
                      style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: AppTheme.textHighContrast,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "Pesanan langsung via Profil Mitra",
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Teman Mabar Seru & Asyik",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Bebas main solo! Sewa teman mabar ramah untuk push rank atau have fun.",
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
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
          "Gaming Buddy (Mabar)",
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
              // Header: Selected Partner or Hero Banner
              widget.selectedPartner != null
                  ? _buildSelectedPartnerHeader()
                  : _buildHeroBanner(),

              const SizedBox(height: 24),

              // Pilih Game
              Text(
                "Pilih Game yang Dimainkan",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _gameList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final game = _gameList[index];
                    final isSelected = _selectedGame == game['name'];
                    return InkWell(
                      onTap: () => setState(() => _selectedGame = game['name']),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 130,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.15) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF6366F1) : AppTheme.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(game['icon'] as IconData, color: isSelected ? const Color(0xFF6366F1) : AppTheme.textMediumContrast, size: 22),
                            const SizedBox(height: 6),
                            Text(
                              game['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: AppTheme.textHighContrast,
                              ),
                            ),
                            Text(
                              game['genre'] as String,
                              style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Mode Pemesanan: Per Jam vs Per Match
              Text(
                "Tipe Hitungan Mabar",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedPlayMode = 'Per Jam';
                        _selectedQuantity = 2;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedPlayMode == 'Per Jam' ? const Color(0xFF6366F1).withValues(alpha: 0.15) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedPlayMode == 'Per Jam' ? const Color(0xFF6366F1) : AppTheme.border,
                            width: _selectedPlayMode == 'Per Jam' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Hitungan Jam",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedPlayMode == 'Per Jam' ? const Color(0xFF6366F1) : AppTheme.textHighContrast,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text("Rp 30.000 / Jam", style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedPlayMode = 'Per Match';
                        _selectedQuantity = 3;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedPlayMode == 'Per Match' ? const Color(0xFF6366F1).withValues(alpha: 0.15) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedPlayMode == 'Per Match' ? const Color(0xFF6366F1) : AppTheme.border,
                            width: _selectedPlayMode == 'Per Match' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Hitungan Match",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedPlayMode == 'Per Match' ? const Color(0xFF6366F1) : AppTheme.textHighContrast,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text("Rp 15.000 / Match", style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Jumlah Jam / Match
              Text(
                _selectedPlayMode == 'Per Jam' ? "Pilih Durasi Waktu" : "Pilih Jumlah Pertandingan",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: (_selectedPlayMode == 'Per Jam' ? [1, 2, 3, 4] : [1, 2, 3, 5]).map((val) {
                  final isSelected = _selectedQuantity == val;
                  return ChoiceChip(
                    label: Text("$val ${_selectedPlayMode == 'Per Jam' ? 'Jam' : 'Match'}"),
                    selected: isSelected,
                    selectedColor: const Color(0xFF6366F1),
                    backgroundColor: AppTheme.surface,
                    labelStyle: GoogleFonts.inter(
                      color: isSelected ? Colors.white : AppTheme.textHighContrast,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedQuantity = val);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Tujuan Mabar
              Text(
                "Tujuan / Mode Permainan",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
              ),
              const SizedBox(height: 10),
              Column(
                children: _gamingGoals.map((goal) {
                  final isSelected = _selectedGoal == goal;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedGoal = goal),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.1) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF6366F1) : AppTheme.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? const Color(0xFF6366F1) : AppTheme.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                goal,
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

              const SizedBox(height: 20),

              // Voice Chat Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "Gunakan Voice Chat (Discord / Mic In-Game)",
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textHighContrast),
                ),
                subtitle: Text(
                  "Partner akan bergabung ke voice call saat bermain game.",
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMediumContrast),
                ),
                value: _useVoiceChat,
                activeColor: const Color(0xFF6366F1),
                onChanged: (val) => setState(() => _useVoiceChat = val),
              ),

              const SizedBox(height: 16),

              // In-game ID field
              TextField(
                controller: _inGameIdController,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textHighContrast),
                decoration: InputDecoration(
                  labelText: "ID Game / Nickname Anda (Opsional)",
                  labelStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                  hintText: "Contoh: GamerPro#1234 atau Server ID",
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                ),
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
                          "Total Biaya Mabar",
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMediumContrast),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Rp ${_calculatedPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _proceedToConfirmation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
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
