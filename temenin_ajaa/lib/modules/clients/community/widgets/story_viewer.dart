import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

class StoryViewer extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int startIndex;
  final Function(String name, double rating) onBookingTap;

  const StoryViewer({
    super.key,
    required this.stories,
    required this.startIndex,
    required this.onBookingTap,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _animController = AnimationController(vsync: this);

    _loadStory(index: _currentIndex, animateToPage: false);

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animController.stop();
        _animController.reset();
        if (mounted) {
          setState(() {
            if (_currentIndex + 1 < widget.stories.length) {
              _currentIndex++;
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              Navigator.of(context).pop();
            }
          });
        }
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
    
    // Dispose the old video controller if it exists
    final oldController = _videoController;
    if (oldController != null) {
      _videoController = null;
      // Do it asynchronously
      scheduleMicrotask(() => oldController.dispose());
    }

    if (mounted) {
      setState(() {
        _isVideoInitialized = false;
      });
    }

    final story = widget.stories[index];
    final videoUrl = story['videoUrl'] as String?;

    if (videoUrl != null && videoUrl.isNotEmpty && videoUrl != 'mock') {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoController = controller;
      try {
        await controller.initialize();
        if (mounted && _videoController == controller) {
          setState(() {
            _isVideoInitialized = true;
          });
          controller.play();
          _animController.duration = controller.value.duration;
          _animController.forward();
        }
      } catch (e) {
        debugPrint("Error loading story video: $e");
        if (mounted && _videoController == controller) {
          _fallbackToImage();
        }
      }
    } else {
      _fallbackToImage();
    }

    if (animateToPage) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _fallbackToImage() {
    if (mounted) {
      setState(() {
        _isVideoInitialized = false;
      });
    }
    _animController.duration = const Duration(seconds: 5);
    _animController.forward();
  }

  void _onTapDown(TapDownDetails details) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double dx = details.globalPosition.dx;

    if (dx < screenWidth / 3) {
      // Tap Left -> Previous Story
      setState(() {
        if (_currentIndex - 1 >= 0) {
          _currentIndex--;
          _loadStory(index: _currentIndex);
        }
      });
    } else {
      // Tap Right -> Next Story
      setState(() {
        if (_currentIndex + 1 < widget.stories.length) {
          _currentIndex++;
          _loadStory(index: _currentIndex);
        } else {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final storyImg = (story['storyImage'] ?? story['image'] ?? '').toString();
    final avatarImg = (story['avatar'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb').toString();
    final authorName = (story['name'] ?? 'Mitra Driver').toString();
    final captionText = (story['caption'] ?? '').toString();
    final ratingVal = (story['rating'] as num?)?.toDouble() ?? 4.9;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        child: Stack(
          children: [
            // Story Background (Video or Image)
            Positioned.fill(
              child: _isVideoInitialized && _videoController != null
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : Image.network(
                      storyImg,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.black,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.white24, size: 40),
                          ),
                        );
                      },
                    ),
            ),

            // Gradient Overlay (for text readability)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Top Progress Bar
            Positioned(
              top: 50,
              left: 10,
              right: 10,
              child: Row(
                children: widget.stories.asMap().entries.map((entry) {
                  int idx = entry.key;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          double value = 0.0;
                          if (idx < _currentIndex) {
                            value = 1.0;
                          } else if (idx == _currentIndex) {
                            value = _animController.value;
                          }
                          return LinearProgressIndicator(
                            value: value,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 3,
                          );
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Top Profile Bar
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(avatarImg),
                    onBackgroundImageError: (_, __) {},
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            authorName,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Colors.green, size: 14),
                        ],
                      ),
                      Text(
                        story['time'] ?? '12 jam yang lalu',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Bottom Caption & Call to Action (Booking)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (captionText.isNotEmpty)
                    Text(
                      captionText,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4FA3), Color(0xFFD9A86C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4FA3).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          _animController.stop();
                          Navigator.pop(context);
                          widget.onBookingTap(authorName, ratingVal);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: Text(
                            'Temani Sekarang',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
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
}
