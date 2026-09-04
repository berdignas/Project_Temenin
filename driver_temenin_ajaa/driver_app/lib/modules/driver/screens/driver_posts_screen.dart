import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/community_provider.dart';
import 'map_picker_screen.dart';

class DriverPostsScreen extends StatefulWidget {
  const DriverPostsScreen({super.key});

  @override
  State<DriverPostsScreen> createState() => _DriverPostsScreenState();
}

class _DriverPostsScreenState extends State<DriverPostsScreen> {
  final _captionController = TextEditingController();
  final _locationController = TextEditingController(text: 'Monas, Jakarta Pusat (Peta Asli)');
  
  String _mediaType = 'image'; // 'image' or 'video'
  List<String> _selectedLocalPaths = [];
  int _currentPreviewIndex = 0;
  final PageController _pageController = PageController();

  final ImagePicker _picker = ImagePicker();

  // Daftar Driver untuk Mention (@)
  final List<String> _driverSuggestions = [
    '@BudiSantoso',
    '@RudiSetiawan',
    '@SitiAminah',
    '@DriverVVIP_Jkt',
    '@EkoPrasetyo',
  ];

  // Tagar yang sedang trending
  final List<String> _quickHashtags = [
    '#OjekOnlineViral',
    '#Trending',
    '#DriverVVIP',
    '#JakartaHits',
    '#JalanJalan',
    '#TemeninAjaa',
  ];

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _cropCurrentPhoto() async {
    if (_selectedLocalPaths.isEmpty || _mediaType != 'image') return;
    final currentPath = _selectedLocalPaths[_currentPreviewIndex];

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: currentPath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong & Edit Foto',
            toolbarColor: const Color(0xFF14101E),
            toolbarWidgetColor: Colors.white,
            statusBarColor: Colors.black,
            activeControlsWidgetColor: const Color(0xFFFF007A),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Potong & Edit Foto',
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        ],
      );
      if (cropped != null) {
        setState(() {
          _selectedLocalPaths[_currentPreviewIndex] = cropped.path;
        });
      }
    } catch (e) {
      debugPrint("Crop error: $e");
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 85);
      if (images.isNotEmpty) {
        setState(() {
          _selectedLocalPaths = images.map((img) => img.path).toList();
          _mediaType = 'image';
          _currentPreviewIndex = 0;
        });
      }
    } catch (e) {
      debugPrint('Gallery picker error: $e');
    }
  }

  Future<void> _takePhotoWithCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (photo != null) {
        setState(() {
          _selectedLocalPaths = [photo.path];
          _mediaType = 'image';
          _currentPreviewIndex = 0;
        });
      }
    } catch (e) {
      debugPrint('Camera picker error: $e');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
      if (video != null) {
        setState(() {
          _selectedLocalPaths = [video.path];
          _mediaType = 'video';
          _currentPreviewIndex = 0;
        });
      }
    } catch (e) {
      debugPrint('Video picker error: $e');
    }
  }

  void _addHashtagToCaption(String tag) {
    setState(() {
      if (!_captionController.text.contains(tag)) {
        _captionController.text = "${_captionController.text.trim()} $tag ";
      }
    });
  }

  void _addMentionToCaption(String mention) {
    setState(() {
      if (!_captionController.text.contains(mention)) {
        _captionController.text = "${_captionController.text.trim()} $mention ";
      }
    });
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const MapPickerScreen()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _locationController.text = result;
      });
    }
  }

  void _uploadContent() {
    final caption = _captionController.text.trim();
    if (_selectedLocalPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tolong pilih satu atau beberapa foto/video terlebih dahulu.")),
      );
      return;
    }
    if (caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tolong isi deskripsi atau caption postingan Anda.")),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final userAvatar = (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
        ? user.avatarUrl!
        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80';
    final userName = user?.fullName ?? 'Driver Temenin Ajaa';
    final location = _locationController.text.trim().isEmpty ? 'Jakarta' : _locationController.text.trim();

    // Simpan postingan (mendukung banyak foto sekaligus)
    context.read<CommunityProvider>().addPost(
      partnerName: userName,
      avatar: userAvatar,
      image: '',
      mediaType: _mediaType,
      localFilePath: _selectedLocalPaths.first,
      localFilePaths: _selectedLocalPaths,
      caption: caption,
      location: location,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "📸 Unggahan ${_mediaType == 'video' ? 'Video Reels' : '${_selectedLocalPaths.length} Foto'} berhasil dipublikasikan!",
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textHighContrast),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Postingan Baru Instagram",
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _uploadContent,
            child: Text(
              "Bagikan",
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primaryPink,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkBgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. MEDIA PREVIEW BOX (Support Multi-Photo Carousel)
                Container(
                  width: double.infinity,
                  height: 290,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: SizedBox.expand(
                          child: _selectedLocalPaths.isNotEmpty
                              ? PageView.builder(
                                  controller: _pageController,
                                  itemCount: _selectedLocalPaths.length,
                                  onPageChanged: (index) {
                                    setState(() => _currentPreviewIndex = index);
                                  },
                                  itemBuilder: (context, index) {
                                    return Image.file(
                                      File(_selectedLocalPaths[index]),
                                      fit: BoxFit.cover,
                                    );
                                  },
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.textMuted, size: 60),
                                    const SizedBox(height: 12),
                                    Text("Pilih Satu atau Beberapa Foto / Video", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text("Bisa pilih banyak foto dari galeri", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                                  ],
                                ),
                        ),
                      ),

                      if (_mediaType == 'video' && _selectedLocalPaths.isNotEmpty)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black38,
                            child: const Center(
                              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64),
                            ),
                          ),
                        ),

                      // Top Right Badge (Video / Multi-Photo Counter)
                      if (_selectedLocalPaths.isNotEmpty)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _mediaType == 'video' ? Icons.videocam_rounded : Icons.photo_library_rounded,
                                  color: AppTheme.primaryPink,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _mediaType == 'video'
                                      ? 'VIDEO REELS'
                                      : (_selectedLocalPaths.length > 1
                                          ? '${_currentPreviewIndex + 1}/${_selectedLocalPaths.length} FOTO'
                                          : '1 FOTO HD'),
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Bottom Floating Crop & Delete Buttons (When Media Selected)
                      if (_selectedLocalPaths.isNotEmpty && _mediaType == 'image')
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _cropCurrentPhoto,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.surface,
                                  foregroundColor: AppTheme.textHighContrast,
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(color: AppTheme.border),
                                  ),
                                ),
                                icon: const Icon(Icons.crop_rounded, color: AppTheme.primaryPink, size: 14),
                                label: Text("Crop Foto Ini", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: AppTheme.surface,
                                ),
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _selectedLocalPaths.removeAt(_currentPreviewIndex);
                                    if (_currentPreviewIndex >= _selectedLocalPaths.length && _selectedLocalPaths.isNotEmpty) {
                                      _currentPreviewIndex = _selectedLocalPaths.length - 1;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. MEDIA PICKER BUTTONS (Kamera, Galeri Multi-Foto, Video)
                Row(
                  children: [
                    Expanded(
                      child: _buildMediaPickButton(
                        icon: Icons.camera_alt_rounded,
                        label: "Kamera",
                        onTap: _takePhotoWithCamera,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMediaPickButton(
                        icon: Icons.photo_library_rounded,
                        label: "Galeri Foto",
                        onTap: _pickImageFromGallery,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMediaPickButton(
                        icon: Icons.video_collection_rounded,
                        label: "Video Reels",
                        onTap: _pickVideoFromGallery,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. CAPTION & HASHTAGS
                Text("Tulis Caption & Deskripsi:", style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    controller: _captionController,
                    maxLines: 4,
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, height: 1.4),
                    decoration: const InputDecoration(
                      hintText: "Ceritakan perjalanan atau momen pelayanan terbaik Anda hari ini...",
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick Hashtag Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _quickHashtags.map((tag) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          backgroundColor: AppTheme.cardDeep,
                          side: const BorderSide(color: AppTheme.border),
                          label: Text(tag, style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.w600)),
                          onPressed: () => _addHashtagToCaption(tag),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick Mention Chips (@)
                Text("Sebut Teman Driver (@Mention):", style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _driverSuggestions.map((driver) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          backgroundColor: AppTheme.cardDeep,
                          side: const BorderSide(color: AppTheme.border),
                          avatar: const Icon(Icons.alternate_email_rounded, color: AppTheme.primaryPink, size: 12),
                          label: Text(driver, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11, fontWeight: FontWeight.w600)),
                          onPressed: () => _addMentionToCaption(driver),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // 4. LOKASI OPERASI (MAPS ASLI OPENSTREETMAP)
                Text("Lokasi Operasi / Peta Asli:", style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _openMapPicker,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.map_rounded, color: AppTheme.primaryPink, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Klik untuk pilih titik di Peta Interaktif",
                                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _locationController.text,
                                style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 22),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // 5. SUBMIT BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _uploadContent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    label: Text(
                      "BAGIKAN KE KOMUNITAS & PROFIL",
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPickButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryPink, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
