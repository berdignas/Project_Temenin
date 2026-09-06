import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';

class DriverStoryViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;

  const DriverStoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<DriverStoryViewerScreen> createState() => _DriverStoryViewerScreenState();
}

class _DriverStoryViewerScreenState extends State<DriverStoryViewerScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex < widget.stories.length ? widget.initialIndex : 0;
    _pageController = PageController(initialPage: _currentIndex);
    _animController = AnimationController(vsync: this);

    _loadStory(index: _currentIndex, animateToPage: false);

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onStoryTimeout();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _loadStory({required int index, bool animateToPage = true}) async {
    _animController.stop();
    _animController.reset();

    // Clean up previous video controller if present
    final oldVideo = _videoController;
    if (oldVideo != null) {
      _videoController = null;
      scheduleMicrotask(() => oldVideo.dispose());
    }

    if (mounted) {
      setState(() {
        _isVideoInitialized = false;
      });
    }

    if (animateToPage && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }

    final story = widget.stories[index];
    final videoUrl = story['videoUrl'] as String?;
    final localFilePath = story['localFilePath'] as String?;

    final isVideo = (videoUrl != null && videoUrl.isNotEmpty) ||
        (localFilePath != null && (localFilePath.endsWith('.mp4') || localFilePath.endsWith('.mov')));

    if (isVideo) {
      VideoPlayerController controller;
      if (!kIsWeb && localFilePath != null && File(localFilePath).existsSync()) {
        controller = VideoPlayerController.file(File(localFilePath));
      } else if (videoUrl != null && videoUrl.isNotEmpty) {
        controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      } else {
        _startPhotoTimer();
        return;
      }

      _videoController = controller;
      try {
        await controller.initialize();
        if (mounted && _videoController == controller) {
          setState(() {
            _isVideoInitialized = true;
          });
          controller.play();

          // Duration: cap video story to max 60s as per requirement
          final durationSec = controller.value.duration.inSeconds.clamp(3, 60);
          _animController.duration = Duration(seconds: durationSec);
          _animController.forward();
        }
      } catch (e) {
        debugPrint("Error initializing story video: $e");
        _startPhotoTimer();
      }
    } else {
      // Photo story: minimum duration 5 seconds
      _startPhotoTimer();
    }
  }

  void _startPhotoTimer() {
    if (!mounted) return;
    _animController.duration = const Duration(seconds: 5);
    _animController.forward();
  }

  void _onStoryTimeout() {
    _animController.stop();
    _animController.reset();

    if (_currentIndex + 1 < widget.stories.length) {
      setState(() {
        _currentIndex++;
      });
      _loadStory(index: _currentIndex);
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadStory(index: _currentIndex);
    } else {
      _animController.reset();
      _animController.forward();
    }
  }

  void _nextStory() {
    if (_currentIndex + 1 < widget.stories.length) {
      setState(() {
        _currentIndex++;
      });
      _loadStory(index: _currentIndex);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    if (dx < screenWidth * 0.3) {
      _previousStory();
    } else {
      _nextStory();
    }
  }

  void _pauseStory() {
    _animController.stop();
    _videoController?.pause();
  }

  void _resumeStory() {
    if (!_animController.isCompleted) {
      _animController.forward();
      _videoController?.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    if (widget.stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "Tidak ada story tersedia",
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
        ),
      );
    }

    final story = widget.stories[_currentIndex];
    final String name = story['name'] ?? story['author'] ?? 'Driver Temenin Ajaa';
    final String avatar = story['avatar'] ?? story['authorAvatar'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80';
    final String title = story['title'] ?? story['caption'] ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. FULLSCREEN STORY CONTENT (Image or Video)
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.stories.length,
                  itemBuilder: (context, idx) {
                    final curStory = widget.stories[idx];
                    final curLocalPath = curStory['localFilePath'];
                    final curImg = curStory['image'] ?? curStory['avatar'] ?? '';
                    final curHasLocal = !kIsWeb && curLocalPath != null && curLocalPath.isNotEmpty && File(curLocalPath).existsSync();

                    if (_isVideoInitialized && _videoController != null && idx == _currentIndex) {
                      return SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _videoController!.value.size.width > 0 ? _videoController!.value.size.width : 1080,
                            height: _videoController!.value.size.height > 0 ? _videoController!.value.size.height : 1920,
                            child: VideoPlayer(_videoController!),
                          ),
                        ),
                      );
                    }

                    if (curHasLocal) {
                      return Image.file(
                        File(curLocalPath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        alignment: Alignment.center,
                      );
                    }

                    return Image.network(
                      curImg.isNotEmpty ? curImg : 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=800',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1B1429),
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Top Gradient Shadow Vignette
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black87, Colors.transparent, Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.25, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // 2. TOP ANIMATED PROGRESS BARS & AUTHOR HEADER
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Segmented Progress Bar Header
                        Row(
                      children: widget.stories.asMap().entries.map((entry) {
                        final idx = entry.key;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: AnimatedBuilder(
                              animation: _animController,
                              builder: (context, child) {
                                double progress = 0.0;
                                if (idx < _currentIndex) {
                                  progress = 1.0;
                                } else if (idx == _currentIndex) {
                                  progress = _animController.value;
                                } else {
                                  progress = 0.0;
                                }
                                return LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white30,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  minHeight: 2.5,
                                );
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Author Header Row (Avatar, Name, Time, Close Button)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primaryPink,
                          backgroundImage: NetworkImage(avatar),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 14),
                                ],
                              ),
                              Text(
                                "Story 24 Jam • Driver Temenin Ajaa",
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        // Close / Back Button
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 3. BOTTOM CAPTION & STICKERS OVERLAY
        Positioned(
          bottom: 24 + MediaQuery.of(context).padding.bottom,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xCC14101E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
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
