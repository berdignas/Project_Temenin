import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverMatchingPrefsScreen extends StatefulWidget {
  const DriverMatchingPrefsScreen({super.key});

  @override
  State<DriverMatchingPrefsScreen> createState() => _DriverMatchingPrefsScreenState();
}

class _DriverMatchingPrefsScreenState extends State<DriverMatchingPrefsScreen> {
  final List<String> _activities = ['coffee', 'ride', 'movie', 'concert', 'dinner', 'party'];
  final List<String> _vibes = ['listener', 'extrovert', 'introvert', 'talkative'];
  final List<String> _topics = ['deeptalk', 'popculture', 'gaming', 'career', 'comedy'];

  final Set<String> _selectedActivities = {'coffee', 'ride'};
  final Set<String> _selectedVibes = {'listener', 'introvert'};
  final Set<String> _selectedTopics = {'deeptalk', 'gaming'};

  final Map<String, String> _activityLabels = {
    'coffee': '☕ Coffee Date',
    'ride': '🛵 Night Ride',
    'movie': '🎬 Movie Buddy',
    'concert': '🎸 Concert Partner',
    'dinner': '✨ Dinner Date',
    'party': '🥂 Party/Kondangan',
  };

  final Map<String, String> _vibeLabels = {
    'listener': '💬 Good Listener',
    'extrovert': '⚡ Extrovert (Asik & Rame)',
    'introvert': '🍃 Introvert (Calm & Chill)',
    'talkative': '🗣️ Talkative (Nyambung Terus)',
  };

  final Map<String, String> _topicLabels = {
    'deeptalk': '🌌 Deep Talk (Kehidupan)',
    'popculture': '🎙️ Pop Culture / Gosip',
    'gaming': '🎮 Gaming / Anime',
    'career': '💼 Karir & Bisnis',
    'comedy': '🤣 Receh / Komedi',
  };

  void _savePreferences() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Preferensi Smart Matching berhasil diperbarui!",
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF00FF7F),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Preferensi Smart Matching",
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FA),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "PENGATURAN MATCHING RADAR",
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Pilih kecocokan kencan yang bersedia Anda dampingi agar radar pencarian Client dapat menemukan Anda.",
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFF334155), fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 25),

                      // Section 1: Activities
                      _buildHeaderSection("Aktivitas yang didukung", Icons.local_activity_rounded),
                      const SizedBox(height: 12),
                      _buildWrapSelector(_activities, _activityLabels, _selectedActivities),
                      const SizedBox(height: 25),

                      // Section 2: Vibes
                      _buildHeaderSection("Kepribadian Anda", Icons.psychology_rounded),
                      const SizedBox(height: 12),
                      _buildWrapSelector(_vibes, _vibeLabels, _selectedVibes),
                      const SizedBox(height: 25),

                      // Section 3: Topics
                      _buildHeaderSection("Topik Obrolan Favorit", Icons.forum_rounded),
                      const SizedBox(height: 12),
                      _buildWrapSelector(_topics, _topicLabels, _selectedTopics),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _savePreferences,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D74),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    child: Text(
                      "SIMPAN PREFERENSI",
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE11D74), size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildWrapSelector(List<String> items, Map<String, String> labels, Set<String> targetSet) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((val) {
        final isSelected = targetSet.contains(val);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                targetSet.remove(val);
              } else {
                targetSet.add(val);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE11D74).withOpacity(0.12) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFFE11D74) : const Color(0xFFE2E8F0),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? const Color(0xFFE11D74).withOpacity(0.08) : Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              labels[val] ?? val,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected ? const Color(0xFFE11D74) : const Color(0xFF0F172A),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
