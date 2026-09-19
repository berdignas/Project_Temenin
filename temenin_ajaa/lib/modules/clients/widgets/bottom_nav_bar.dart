// lib/modules/clients/widgets/bottom_nav_bar.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';

/// Data class representing an item in the [FluidCurvedNavBar].
class FluidCurvedNavBarItem {
  final IconData icon;
  final String label;
  final IconData? selectedIcon;
  final bool showBadge;
  final Color? badgeColor;

  const FluidCurvedNavBarItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.showBadge = false,
    this.badgeColor,
  });
}

/// A modern, high-end Fluid Curved Navigation Bar inspired by Pinterest & Dribbble UX motion design.
///
/// Features:
/// - Smooth organic cubic Bézier notch that glides fluidly across tabs when switching.
/// - Floating circular action bubble with multi-layer ambient glow and spring physics.
/// - Vertical dip & rise micro-bounce as the indicator travels.
/// - Crisp typography and icons with seamless opacity transitions.
/// - Built-in haptic feedback on tab selection.
class FluidCurvedNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<FluidCurvedNavBarItem> items;
  final Color backgroundColor;
  final Color activeColor;
  final Color inactiveColor;
  final Color borderColor;
  final Color shadowColor;
  final double barHeight;

  const FluidCurvedNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
    this.backgroundColor = Colors.white,
    this.activeColor = const Color(0xFFDB2777), // Rose Gold / Fuchsia
    this.inactiveColor = const Color(0xFF64748B), // Slate Muted
    this.borderColor = const Color(0xFFE5C8DC), // Rose Accent Border
    this.shadowColor = const Color(0xFFDB2777),
    this.barHeight = 68.0,
  });

  @override
  State<FluidCurvedNavBar> createState() => _FluidCurvedNavBarState();
}

class _FluidCurvedNavBarState extends State<FluidCurvedNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideCurve;

  int _currentIndex = 0;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _previousIndex = widget.selectedIndex;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _slideCurve = CurvedAnimation(
      parent: _animController,
      curve: Curves.fastOutSlowIn,
    );

    _animController.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant FluidCurvedNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _previousIndex = _currentIndex;
      _currentIndex = widget.selectedIndex;
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final totalNavHeight = widget.barHeight + 20.0; // Space for floating button

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomPadding > 0 ? bottomPadding : 14,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final itemCount = widget.items.length;
          final itemWidth = totalWidth / itemCount;

          return AnimatedBuilder(
            animation: _slideCurve,
            builder: (context, child) {
              final progress = _slideCurve.value;

              final startCenterX = (_previousIndex + 0.5) * itemWidth;
              final targetCenterX = (_currentIndex + 0.5) * itemWidth;
              final currentActiveX = lerpDouble(startCenterX, targetCenterX, progress)!;

              // Vertical bounce during transit: dips down slightly then springs back up
              final bounceFactor = math.sin(progress * math.pi);
              final verticalDip = bounceFactor * 4.5;
              final scaleFactor = 1.0 - (bounceFactor * 0.12);

              return SizedBox(
                height: totalNavHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Background Fluid Curved Notch Dock
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: widget.barHeight,
                      child: CustomPaint(
                        size: Size(totalWidth, widget.barHeight),
                        painter: _FluidNavPainter(
                          activeX: currentActiveX,
                          backgroundColor: widget.backgroundColor,
                          borderColor: widget.borderColor,
                          shadowColor: widget.shadowColor,
                          notchRadius: 27.0,
                          notchDepth: 25.0,
                          smoothness: 14.0,
                          cornerRadius: 24.0,
                        ),
                      ),
                    ),

                    // 2. Tab Items Row (Inactive Icons & Labels, Active Label)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: widget.barHeight,
                      child: Row(
                        children: List.generate(itemCount, (index) {
                          final item = widget.items[index];
                          final isSelected = _currentIndex == index;

                          // Distance from current animated bubble to this item
                          final itemCenter = (index + 0.5) * itemWidth;
                          final dist = (currentActiveX - itemCenter).abs();
                          final normDist = (dist / itemWidth).clamp(0.0, 1.0);

                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (_currentIndex != index) {
                                  HapticFeedback.lightImpact();
                                  widget.onItemSelected(index);
                                }
                              },
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                height: widget.barHeight,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Inactive Icon + Label (Fades out when bubble is near)
                                    Opacity(
                                      opacity: normDist,
                                      child: Transform.scale(
                                        scale: 0.85 + (normDist * 0.15),
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 10),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Icon(
                                                    item.icon,
                                                    color: widget.inactiveColor,
                                                    size: 22,
                                                  ),
                                                  if (item.showBadge)
                                                    Positioned(
                                                      top: -2,
                                                      right: -4,
                                                      child: Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration: BoxDecoration(
                                                          color: item.badgeColor ??
                                                              AppTheme.danger,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                item.label,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  color: widget.inactiveColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Active Label shown directly under the notch when settled
                                    if (isSelected)
                                      Positioned(
                                        bottom: 7,
                                        child: Opacity(
                                          opacity: progress.clamp(0.0, 1.0),
                                          child: Text(
                                            item.label,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              color: widget.activeColor,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // 3. Floating Circular Bubble Indicator (Tracks currentActiveX)
                    Positioned(
                      left: currentActiveX - 25.0,
                      top: 4.0 + verticalDip,
                      child: Transform.scale(
                        scale: scaleFactor,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onItemSelected(_currentIndex);
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: widget.activeColor,
                                width: 2.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.activeColor.withValues(alpha: 0.38),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, anim) => ScaleTransition(
                                  scale: anim,
                                  child: child,
                                ),
                                child: Icon(
                                  widget.items[_currentIndex].selectedIcon ??
                                      widget.items[_currentIndex].icon,
                                  key: ValueKey<int>(_currentIndex),
                                  color: widget.activeColor,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Custom painter that draws the smooth cubic Bézier curved notch navigation bar.
class _FluidNavPainter extends CustomPainter {
  final double activeX;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final double notchRadius;
  final double notchDepth;
  final double smoothness;
  final double cornerRadius;

  _FluidNavPainter({
    required this.activeX,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
    required this.notchRadius,
    required this.notchDepth,
    required this.smoothness,
    required this.cornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cr = cornerRadius;
    final R = notchRadius;
    final d = notchDepth;
    final s = smoothness;

    final path = Path();

    // Start at bottom-left corner
    path.moveTo(0, h - cr);
    path.quadraticBezierTo(0, h, cr, h);

    // Bottom edge to bottom-right corner
    path.lineTo(w - cr, h);
    path.quadraticBezierTo(w, h, w, h - cr);

    // Up right side
    path.lineTo(w, cr);

    // Top-right corner
    final endX = activeX + R + s;
    if (endX < w - cr) {
      path.quadraticBezierTo(w, 0, w - cr, 0);
      path.lineTo(endX, 0);
    } else {
      path.lineTo(w, 0);
      path.lineTo(math.min(w, endX), 0);
    }

    // Bézier notch (drawn from right to left as we trace counter-clockwise)
    // 1. Right curve from top edge down into notch
    path.cubicTo(
      activeX + R, 0,
      activeX + R * 0.95, d * 0.55,
      activeX + R * 0.65, d * 0.88,
    );

    // 2. Bottom scoop of the notch
    path.cubicTo(
      activeX + R * 0.35, d,
      activeX - R * 0.35, d,
      activeX - R * 0.65, d * 0.88,
    );

    // 3. Left curve from bottom scoop up to top edge
    final startX = activeX - R - s;
    path.cubicTo(
      activeX - R * 0.95, d * 0.55,
      activeX - R, 0,
      startX, 0,
    );

    // Top-left corner
    if (startX > cr) {
      path.lineTo(cr, 0);
      path.quadraticBezierTo(0, 0, 0, cr);
    } else {
      path.lineTo(math.max(0, startX), 0);
      path.lineTo(0, cr);
    }

    path.close();

    // 1. Multi-layer ambient drop shadow
    canvas.drawShadow(path, shadowColor.withValues(alpha: 0.18), 16.0, false);
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.05), 8.0, false);

    // 2. Solid Background fill
    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(path, fillPaint);

    // 3. Crisp Outline Border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _FluidNavPainter oldDelegate) {
    return oldDelegate.activeX != activeX ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor;
  }
}