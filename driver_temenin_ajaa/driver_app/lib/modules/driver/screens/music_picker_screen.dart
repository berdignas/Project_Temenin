import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme/app_theme.dart';

class MusicPickerScreen extends StatefulWidget {
  const MusicPickerScreen({super.key});

  @override
  State<MusicPickerScreen> createState() => _MusicPickerScreenState();
}

class _MusicPickerScreenState extends State<MusicPickerScreen> {
  final TextEditingController _searchController = TextEditingController(text: "Indonesia");
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<dynamic> _tracks = [];
  bool _isLoading = false;
  String? _playingUrl;

  @override
  void initState() {
    super.initState();
    _searchMusic("Indonesia Trending");
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchMusic(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&media=music&limit=15');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _tracks = data['results'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Music search error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePlayPreview(String previewUrl) async {
    if (_playingUrl == previewUrl) {
      await _audioPlayer.stop();
      setState(() => _playingUrl = null);
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(previewUrl));
      setState(() => _playingUrl = previewUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0910),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14101E),
        title: Text(
          "Cari Musik & Lagu (iTunes API)",
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
          // 1. SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppTheme.primaryPink, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      onSubmitted: _searchMusic,
                      decoration: const InputDecoration(
                        hintText: "Cari judul lagu atau nama penyanyi...",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppTheme.primaryPink, size: 18),
                    onPressed: () => _searchMusic(_searchController.text),
                  )
                ],
              ),
            ),
          ),

          // 2. TRACK LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPink))
                : _tracks.isEmpty
                    ? Center(
                        child: Text("Lagu tidak ditemukan.", style: GoogleFonts.inter(color: Colors.white38)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _tracks.length,
                        separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
                        itemBuilder: (context, index) {
                          final track = _tracks[index];
                          final trackName = track['trackName'] ?? 'Unknown Track';
                          final artistName = track['artistName'] ?? 'Unknown Artist';
                          final artworkUrl = track['artworkUrl100'] ?? '';
                          final previewUrl = track['previewUrl'] ?? '';
                          final isPlaying = _playingUrl == previewUrl;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: artworkUrl.isNotEmpty
                                  ? Image.network(artworkUrl, width: 48, height: 48, fit: BoxFit.cover)
                                  : Container(width: 48, height: 48, color: Colors.white10, child: const Icon(Icons.music_note, color: Colors.white)),
                            ),
                            title: Text(
                              trackName,
                              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              artistName,
                              style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (previewUrl.isNotEmpty)
                                  IconButton(
                                    icon: Icon(
                                      isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                      color: AppTheme.primaryPink,
                                      size: 32,
                                    ),
                                    onPressed: () => _togglePlayPreview(previewUrl),
                                  ),
                                const SizedBox(width: 4),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context, {
                                      'trackName': trackName,
                                      'artistName': artistName,
                                      'previewUrl': previewUrl,
                                      'artworkUrl': artworkUrl,
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryPink,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                  child: Text("Pilih", style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    ),
  );
}
}
