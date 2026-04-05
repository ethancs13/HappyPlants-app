import 'dart:math';
import 'package:flutter/material.dart';
import 'package:happy_plants/theme/app_theme.dart';

class PlantWidget extends StatefulWidget {
  final bool isHappy;

  /// Width/height of the bounding box. The plant is drawn at 100×160
  /// native size and scaled to fit.
  final double size;

  const PlantWidget({super.key, required this.isHappy, this.size = 120});

  @override
  State<PlantWidget> createState() => _PlantWidgetState();
}

class _PlantWidgetState extends State<PlantWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sway;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.isHappy
          ? const Duration(milliseconds: 2000)
          : const Duration(milliseconds: 6000),
    )..repeat(reverse: true);

    final maxAngle = widget.isHappy ? 0.18 : 0.05; // radians
    _sway = Tween<double>(begin: -maxAngle, end: maxAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.size / 100.0;
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.6,
      child: AnimatedBuilder(
        animation: _sway,
        builder: (_, child) => Transform.scale(
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: _PlantBody(
            isHappy: widget.isHappy,
            swayAngle: _sway.value,
          ),
        ),
      ),
    );
  }
}

/// Static plant body at native 100×160 size.
/// The stem and leaves rotate around the base of the stem.
class _PlantBody extends StatelessWidget {
  final bool isHappy;
  final double swayAngle;

  const _PlantBody({required this.isHappy, required this.swayAngle});

  @override
  Widget build(BuildContext context) {
    final leafColor = isHappy ? AppColors.forest : AppColors.plantLeafMuted;
    final leafColorAlt = isHappy ? AppColors.olive : AppColors.plantLeafMuted;
    final stemColor = isHappy ? AppColors.plantStem : const Color(0xFF6B7A50);

    return SizedBox(
      width: 100,
      height: 160,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Pot base (static) ────────────────────────────────
          Positioned(
            left: 20,
            top: 110,
            child: Container(
              width: 60,
              height: 50,
              decoration: ShapeDecoration(
                color: AppColors.potBody,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          // Pot rim (static)
          Positioned(
            left: 16,
            top: 104,
            child: Container(
              width: 68,
              height: 12,
              decoration: ShapeDecoration(
                color: AppColors.potRim,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          // ── Animated stem + leaves ────────────────────────────
          // Pivot point is the base of the stem (center-bottom of stem).
          // We rotate everything above the pot around that point.
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            bottom: 56, // bottom of stem aligns with top of pot rim
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.rotationZ(swayAngle),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Stem
                  Positioned(
                    left: 46,
                    bottom: 0,
                    child: Container(
                      width: 7,
                      height: isHappy ? 55 : 45,
                      decoration: ShapeDecoration(
                        color: stemColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  if (isHappy) ...[
                    // Left leaf
                    Positioned(
                      left: 14,
                      bottom: 42,
                      child: Transform.rotate(
                        angle: -pi / 6 + swayAngle * 0.5,
                        child: _leaf(36, 22, leafColor),
                      ),
                    ),
                    // Right leaf
                    Positioned(
                      left: 50,
                      bottom: 46,
                      child: Transform.rotate(
                        angle: pi / 6 + swayAngle * 0.5,
                        child: _leaf(36, 22, leafColorAlt),
                      ),
                    ),
                    // Top leaf
                    Positioned(
                      left: 35,
                      bottom: 60,
                      child: Transform.rotate(
                        angle: swayAngle * 0.3,
                        child: _leaf(28, 34, leafColor),
                      ),
                    ),
                  ] else ...[
                    // Sad: drooping leaves
                    Positioned(
                      left: 16,
                      bottom: 28,
                      child: Transform.rotate(
                        angle: -pi / 2.2 + swayAngle,
                        child: _leaf(32, 18, leafColor),
                      ),
                    ),
                    Positioned(
                      left: 52,
                      bottom: 28,
                      child: Transform.rotate(
                        angle: pi / 2.2 + swayAngle,
                        child: _leaf(32, 18, leafColor),
                      ),
                    ),
                    // Wilted top
                    Positioned(
                      left: 38,
                      bottom: 48,
                      child: Transform.rotate(
                        angle: 0.25 + swayAngle * 0.3,
                        child: _leaf(22, 28, leafColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaf(double w, double h, Color color) => Container(
        width: w,
        height: h,
        decoration: ShapeDecoration(
          color: color,
          shape: const OvalBorder(),
        ),
      );
}
