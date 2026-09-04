import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/modules/clients/matching/screens/matching_radar_screen.dart';

class MatchingColors {
  static const Color deepVoid = AppTheme.background;
  static const Color obsidian = AppTheme.surface;
  static const Color elevatedDark = AppTheme.cardDeep;
  static const Color electricPink = AppTheme.primaryPink;
  static const Color roseGold = Color(0xFFD9A86C);
  static const Color textMuted = AppTheme.textMuted;
  static const Color textMain = AppTheme.textHighContrast;
}

class SmartMatchScreen extends StatefulWidget {
  const SmartMatchScreen({super.key});

  @override
  State<SmartMatchScreen> createState() => _SmartMatchScreenState();
}

class _SmartMatchScreenState extends State<SmartMatchScreen> {
  String _selectedActivity = '';
  String _selectedVibe = '';
  String _selectedTopic = '';

  final List<Map<String, dynamic>> _activities = [
    {'label': '☕ Coffee Date', 'value': 'coffee'},
    {'label': '🛵 Night Ride', 'value': 'ride'},
    {'label': '🎬 Movie Buddy', 'value': 'movie'},
    {'label': '🎸 Concert Partner', 'value': 'concert'},
    {'label': '✨ Dinner Date', 'value': 'dinner'},
    {'label': '🥂 Party/Kondangan', 'value': 'party'},
  ];

  final List<Map<String, dynamic>> _vibes = [
    {'label': '💬 Good Listener', 'value': 'listener'},
    {'label': '⚡ Extrovert (Asik & Rame)', 'value': 'extrovert'},
    {'label': '🍃 Introvert (Calm & Chill)', 'value': 'introvert'},
    {'label': '🗣️ Talkative (Nyambung Terus)', 'value': 'talkative'},
  ];

  final List<Map<String, dynamic>> _topics = [
    {'label': '🌌 Deep Talk (Kehidupan)', 'value': 'deeptalk'},
    {'label': '🎙️ Pop Culture / Gosip', 'value': 'popculture'},
    {'label': '🎮 Gaming / Anime', 'value': 'gaming'},
    {'label': '💼 Karir & Bisnis', 'value': 'career'},
    {'label': '🤣 Receh / Komedi', 'value': 'comedy'},
  ];

  void _startMatching() {
    if (_selectedActivity.isEmpty || _selectedVibe.isEmpty || _selectedTopic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap pilih semua opsi kriteria kencan terlebih dahulu!'),
          backgroundColor: AppTheme.primaryPink,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchingRadarScreen(
          activity: _selectedActivity,
          vibe: _selectedVibe,
          topic: _selectedTopic,
        ),
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Smart Matching',
          style: GoogleFonts.inter(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.fuchsiaLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.auto_awesome, color: AppTheme.primaryPink, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI Companion Radar',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textHighContrast,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Algoritma kecerdasan buatan mencari partner terdekat dengan frekuensi & vibe yang cocok.',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textMuted,
                                    fontSize: 11.5,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 24),

                    // Section 1: Aktivitas
                    _buildSectionHeader('1. Aktivitas Pilihan', 'Pilih agenda seru yang ingin Anda jalani'),
                    const SizedBox(height: 12),
                    _buildChipGroup(
                      items: _activities,
                      selectedValue: _selectedActivity,
                      onSelected: (val) => setState(() => _selectedActivity = val),
                    ),

                    const SizedBox(height: 24),

                    // Section 2: Vibe Kepribadian
                    _buildSectionHeader('2. Vibe Kepribadian', 'Karakter partner yang paling Anda butuhkan hari ini'),
                    const SizedBox(height: 12),
                    _buildCardSelectionGroup(
                      items: _vibes,
                      selectedValue: _selectedVibe,
                      onSelected: (val) => setState(() => _selectedVibe = val),
                    ),

                    const SizedBox(height: 24),

                    // Section 3: Topik Obrolan
                    _buildSectionHeader('3. Topik Obrolan', 'Bahan diskusi yang ingin dibahas saat bertemu'),
                    const SizedBox(height: 12),
                    _buildChipGroup(
                      items: _topics,
                      selectedValue: _selectedTopic,
                      onSelected: (val) => setState(() => _selectedTopic = val),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // Bottom Action Button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _startMatching,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.radar_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Pindai Radar Partner',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: AppTheme.textHighContrast,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: AppTheme.textMuted,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }

  Widget _buildChipGroup({
    required List<Map<String, dynamic>> items,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = selectedValue == item['value'];
        return GestureDetector(
          onTap: () => onSelected(item['value']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryPink : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.primaryPink : AppTheme.border,
              ),
            ),
            child: Text(
              item['label'],
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : AppTheme.textHighContrast,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCardSelectionGroup({
    required List<Map<String, dynamic>> items,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      children: items.map((item) {
        final isSelected = selectedValue == item['value'];
        return GestureDetector(
          onTap: () => onSelected(item['value']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.fuchsiaLight : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.primaryPink : AppTheme.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item['label'],
                    style: GoogleFonts.inter(
                      color: AppTheme.textHighContrast,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryPink : AppTheme.border,
                      width: 2,
                    ),
                    color: isSelected ? AppTheme.primaryPink : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 12)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
