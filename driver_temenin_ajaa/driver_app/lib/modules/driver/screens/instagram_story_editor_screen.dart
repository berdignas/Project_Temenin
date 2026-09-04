import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/community_provider.dart';
import 'map_picker_screen.dart';
import 'music_picker_screen.dart';

class DoodleLine {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DoodleLine({required this.points, required this.color, this.strokeWidth = 4.0});
}

class DoodlePainter extends CustomPainter {
  final List<DoodleLine> lines;

  DoodlePainter({required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = line.strokeWidth;

      for (int i = 0; i < line.points.length - 1; i++) {
        if (line.points[i] != Offset.zero && line.points[i + 1] != Offset.zero) {
          canvas.drawLine(line.points[i], line.points[i + 1], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant DoodlePainter oldDelegate) => true;
}

class InstagramStoryEditorScreen extends StatefulWidget {
  final XFile? initialMediaFile;

  const InstagramStoryEditorScreen({super.key, this.initialMediaFile});

  @override
  State<InstagramStoryEditorScreen> createState() => _InstagramStoryEditorScreenState();
}

class _InstagramStoryEditorScreenState extends State<InstagramStoryEditorScreen> {
  XFile? _selectedMedia;
  final ImagePicker _picker = ImagePicker();

  // Story Canvas Overlay State
  bool _isDoodleMode = false;
  bool _showTextInput = false;
  final _captionTextController = TextEditingController();
  
  String _locationSticker = '';
  String _musicSticker = '';

  // Filter effect state
  int _activeFilterIndex = 0;
  final List<Map<String, dynamic>> _colorFilters = [
    {"name": "Normal", "matrix": null},
    {
      "name": "Vintage Warm",
      "matrix": <double>[
        1.1, 0, 0, 0, 10,
        0, 1.0, 0, 0, 10,
        0, 0, 0.9, 0, -10,
        0, 0, 0, 1, 0,
      ],
    },
    {
      "name": "Cyber Glow",
      "matrix": <double>[
        1.2, 0, 0, 0, 20,
        0, 0.9, 0, 0, 0,
        0, 0, 1.2, 0, 25,
        0, 0, 0, 1, 0,
      ],
    },
    {
      "name": "B&W Mono",
      "matrix": <double>[
        0.33, 0.33, 0.33, 0, 0,
        0.33, 0.33, 0.33, 0, 0,
        0.33, 0.33, 0.33, 0, 0,
        0, 0, 0, 1, 0,
      ],
    },
  ];

  // Doodle state
  Color _selectedDoodleColor = const Color(0xFFFF007A); // Neon Pink
  final List<DoodleLine> _doodleLines = [];
  List<Offset> _currentLinePoints = [];

  final List<Color> _doodleColors = [
    const Color(0xFFFF007A), // Neon Pink
    const Color(0xFF00E5FF), // Cyan
    const Color(0xFFFFD700), // Gold
    const Color(0xFF00FF7F), // Neon Green
    Colors.white,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _selectedMedia = widget.initialMediaFile;
    if (_selectedMedia == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMediaSourcePicker();
      });
    }
  }

  @override
  void dispose() {
    _captionTextController.dispose();
    super.dispose();
  }

  void _showMediaSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16141D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Pilih Media untuk Story 24 Jam",
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryPink),
                title: Text("Ambil Foto dari Kamera", style: GoogleFonts.plusJakartaSans(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                  if (file != null) {
                    setState(() => _selectedMedia = file);
                  } else if (_selectedMedia == null && mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF00E5FF)),
                title: Text("Pilih Foto dari Galeri", style: GoogleFonts.plusJakartaSans(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                  if (file != null) {
                    setState(() => _selectedMedia = file);
                  } else if (_selectedMedia == null && mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_rounded, color: Color(0xFFFFD700)),
                title: Text("Pilih Video Pendek (Maks. 1 Menit)", style: GoogleFonts.plusJakartaSans(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await _picker.pickVideo(
                    source: ImageSource.gallery,
                    maxDuration: const Duration(seconds: 60),
                  );
                  if (file != null) {
                    setState(() => _selectedMedia = file);
                  } else if (_selectedMedia == null && mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cropStoryPhoto() async {
    if (_selectedMedia == null) return;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _selectedMedia!.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Sesuaikan & Potong Story',
            toolbarColor: const Color(0xFF14101E),
            toolbarWidgetColor: Colors.white,
            statusBarColor: Colors.black,
            activeControlsWidgetColor: const Color(0xFFFF007A),
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Sesuaikan Story',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        ],
      );
      if (cropped != null) {
        setState(() {
          _selectedMedia = XFile(cropped.path);
        });
      }
    } catch (e) {
      debugPrint("Crop story error: $e");
    }
  }

  void _cycleColorFilter() {
    setState(() {
      _activeFilterIndex = (_activeFilterIndex + 1) % _colorFilters.length;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 900),
        content: Text(
          "Filter: ${_colorFilters[_activeFilterIndex]['name']}",
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF14101E),
      ),
    );
  }

  void _publishStory() {
    if (_selectedMedia == null) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final userAvatar = (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
        ? user.avatarUrl!
        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80';
    final userName = user?.fullName ?? 'Driver Temenin Ajaa';
    final caption = _captionTextController.text.trim();

    context.read<CommunityProvider>().addStory(
      name: userName,
      avatar: userAvatar,
      image: 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=500',
      localFilePath: _selectedMedia!.path,
      title: caption.isNotEmpty ? caption : 'Story Driver',
      caption: caption,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "⚡ Story 24 Jam berhasil dipublikasikan ke Komunitas!",
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF00FF7F),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    final filterMatrix = _colorFilters[_activeFilterIndex]['matrix'] as List<double>?;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _selectedMedia == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPink))
          : SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. STORY TRUE FULLSCREEN MEDIA (Edge-to-Edge like Instagram)
                Positioned.fill(
                  child: filterMatrix != null
                      ? ColorFiltered(
                          colorFilter: ColorFilter.matrix(filterMatrix),
                          child: Image.file(
                            File(_selectedMedia!.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            alignment: Alignment.center,
                          ),
                        )
                      : Image.file(
                          File(_selectedMedia!.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          alignment: Alignment.center,
                        ),
                ),

                // Top & Bottom Vignette Overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black54,
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black54,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.15, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. DOODLE DRAWING CANVAS (Touch to Draw)
                if (_isDoodleMode)
                  Positioned.fill(
                    child: GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _currentLinePoints = [details.localPosition];
                          _doodleLines.add(DoodleLine(points: _currentLinePoints, color: _selectedDoodleColor));
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          _currentLinePoints.add(details.localPosition);
                        });
                      },
                      onPanEnd: (details) {
                        setState(() {
                          _currentLinePoints.add(Offset.zero);
                        });
                      },
                      child: CustomPaint(
                        painter: DoodlePainter(lines: _doodleLines),
                        size: Size.infinite,
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DoodlePainter(lines: _doodleLines),
                      size: Size.infinite,
                    ),
                  ),

                // 3. LOCATION STICKER (If Attached)
                if (_locationSticker.isNotEmpty)
                  Positioned(
                    top: 140,
                    left: 30,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xE614101E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryPink, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, color: AppTheme.primaryPink, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            _locationSticker,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _locationSticker = ''),
                            child: const Icon(Icons.close, color: Colors.white54, size: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 4. MUSIC STICKER (If Attached)
                if (_musicSticker.isNotEmpty)
                  Positioned(
                    top: 195,
                    left: 30,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xE614101E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_note_rounded, color: Color(0xFF00E5FF), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            _musicSticker,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _musicSticker = ''),
                            child: const Icon(Icons.close, color: Colors.white54, size: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 5. FLOATING STORY TEXT OVERLAY
                if (_captionTextController.text.isNotEmpty && !_showTextInput)
                  Positioned(
                    top: 260,
                    left: 24,
                    right: 24,
                    child: GestureDetector(
                      onTap: () => setState(() => _showTextInput = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xB3000000),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryPink),
                        ),
                        child: Text(
                          _captionTextController.text,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 6. TOP INSTAGRAM ACTION BAR (Close, Aa, Doodle ✏️, Sticker 📍, Music 🎵, Filter 🎨, Crop ✂️)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: true,
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Close Button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                        const SizedBox(width: 10),

                        // Action Icons Row wrapped in ScrollView to prevent overflow
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            reverse: true,
                            child: Row(
                              children: [
                                // Text Aa Button
                                _buildStoryActionButton(
                                  icon: Icons.title_rounded,
                                  label: "Aa",
                                  isActive: _showTextInput,
                                  onTap: () {
                                    setState(() {
                                      _showTextInput = !_showTextInput;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),

                                // Doodle Pen ✏️ Button
                                _buildStoryActionButton(
                                  icon: Icons.edit_rounded,
                                  label: "✏️",
                                  isActive: _isDoodleMode,
                                  onTap: () {
                                    setState(() {
                                      _isDoodleMode = !_isDoodleMode;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),

                                // Location Sticker 📍 Button
                                _buildStoryActionButton(
                                  icon: Icons.location_on_rounded,
                                  label: "📍",
                                  isActive: _locationSticker.isNotEmpty,
                                  onTap: () async {
                                    final loc = await Navigator.push<String>(
                                      context,
                                      MaterialPageRoute(builder: (context) => const MapPickerScreen()),
                                    );
                                    if (loc != null && loc.isNotEmpty) {
                                      setState(() => _locationSticker = loc);
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),

                                // Music Sticker 🎵 Button
                                _buildStoryActionButton(
                                  icon: Icons.music_note_rounded,
                                  label: "🎵",
                                  isActive: _musicSticker.isNotEmpty,
                                  onTap: () async {
                                    final music = await Navigator.push<Map<String, String>>(
                                      context,
                                      MaterialPageRoute(builder: (context) => const MusicPickerScreen()),
                                    );
                                    if (music != null) {
                                      setState(() {
                                        _musicSticker = "${music['trackName']} • ${music['artistName']}";
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),

                                // Color Filter 🎨 Button
                                _buildStoryActionButton(
                                  icon: Icons.auto_awesome_rounded,
                                  label: "🎨",
                                  isActive: _activeFilterIndex != 0,
                                  onTap: _cycleColorFilter,
                                ),
                                const SizedBox(width: 8),

                                // Crop / Rotate ✂️ Button
                                _buildStoryActionButton(
                                  icon: Icons.crop_rounded,
                                  label: "✂️",
                                  isActive: false,
                                  onTap: _cropStoryPhoto,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

                // 7. DOODLE COLOR PALETTE BAR (When Doodle Mode is Active)
                if (_isDoodleMode)
                  Positioned(
                    top: 100,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: _doodleColors.map((color) {
                              final isSelected = _selectedDoodleColor == color;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedDoodleColor = color),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: isSelected ? 28 : 22,
                                  height: isSelected ? 28 : 22,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isSelected ? Colors.white : Colors.white24, width: 2),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          if (_doodleLines.isNotEmpty)
                            GestureDetector(
                              onTap: () => setState(() => _doodleLines.clear()),
                              child: Text(
                                "Hapus Coretan",
                                style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // 8. TEXT INPUT BOX OVERLAY (When Aa Text Mode is Active)
                if (_showTextInput)
                  Positioned(
                    top: 160,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xE616141D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryPink),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _captionTextController,
                            autofocus: true,
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              hintText: "Tuliskan caption story Anda di sini...",
                              hintStyle: TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => setState(() => _showTextInput = false),
                              child: Text("Selesai", style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 9. BOTTOM PUBLISH STORY BUTTON BAR
                Positioned(
                  bottom: 16 + MediaQuery.of(context).padding.bottom,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      // Retake / Change Media Button
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xCC14101E),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.change_circle_outlined, color: Colors.white, size: 24),
                        onPressed: _showMediaSourcePicker,
                      ),
                      const SizedBox(width: 10),
                      // Publish Story Button
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _publishStory,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPink,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                              elevation: 8,
                            ),
                            icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                            label: Text(
                              "⚡ BAGIKAN KE STORY 24 JAM",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildStoryActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryPink : Colors.black54,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? Colors.white : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
