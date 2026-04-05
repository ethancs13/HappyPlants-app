import 'dart:math';
import 'package:flutter/material.dart';
import 'package:happy_plants/theme/app_theme.dart';

class PlantWidget extends StatefulWidget {
  final bool isHappy;

  /// Width of the bounding box. Height is 1.6× width.
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
          : const Duration(milliseconds: 5000),
    )..repeat(reverse: true);

    // Happy: lively ±14°, Sad: barely-moving ±4°
    final maxAngle = widget.isHappy ? 0.24 : 0.07;
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

/// Static plant body drawn at native 100×160.
/// Stem + leaves pivot around the base of the stem (bottom-center).
class _PlantBody extends StatelessWidget {
  final bool isHappy;
  final double swayAngle;

  const _PlantBody({required this.isHappy, required this.swayAngle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 160,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Pot body ────────────────────────────────────────────
          Positioned(
            left: 18,
            top: 112,
            child: _trapezoidPot(),
          ),
          // Pot rim
          Positioned(
            left: 14,
            top: 106,
            child: Container(
              width: 72,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.potRim,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // ── Animated stem + leaves ───────────────────────────────
          // Pivot = base of stem, which sits at (50, 106) in the 100×160 space.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 54, // 160 - 106 = 54 px from bottom
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
                      width: 8,
                      height: isHappy ? 58 : 44,
                      decoration: BoxDecoration(
                        color: isHappy
                            ? AppColors.plantStem
                            : const Color(0xFF5E6E42),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),

                  if (isHappy) ..._happyLeaves(swayAngle)
                  else ..._sadLeaves(swayAngle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Happy: two big oval leaves like the Figma design ────────────
  List<Widget> _happyLeaves(double sway) => [
        // Left leaf — dark forest green, angled up-left
        Positioned(
          left: 6,
          bottom: 30,
          child: Transform.rotate(
            angle: -pi / 3.8 + sway * 0.4,
            alignment: Alignment.bottomRight,
            child: _oval(40, 26, AppColors.forest),
          ),
        ),
        // Right leaf — olive, angled up-right, slightly higher
        Positioned(
          left: 54,
          bottom: 38,
          child: Transform.rotate(
            angle: pi / 3.8 + sway * 0.4,
            alignment: Alignment.bottomLeft,
            child: _oval(36, 23, AppColors.olive),
          ),
        ),
        // Small top bud
        Positioned(
          left: 38,
          bottom: 54,
          child: Transform.rotate(
            angle: sway * 0.2,
            child: _oval(22, 16, AppColors.forest),
          ),
        ),
      ];

  // ── Sad: drooping leaves ─────────────────────────────────────────
  List<Widget> _sadLeaves(double sway) => [
        // Left — muted, drooping outward-down
        Positioned(
          left: 8,
          bottom: 18,
          child: Transform.rotate(
            angle: -pi / 1.7 + sway,
            alignment: Alignment.bottomRight,
            child: _oval(36, 22, AppColors.plantLeafMuted),
          ),
        ),
        // Right — muted, drooping outward-down
        Positioned(
          left: 56,
          bottom: 18,
          child: Transform.rotate(
            angle: pi / 1.7 + sway,
            alignment: Alignment.bottomLeft,
            child: _oval(36, 22, AppColors.plantLeafMuted),
          ),
        ),
        // Top — slightly wilted, leaning
        Positioned(
          left: 34,
          bottom: 38,
          child: Transform.rotate(
            angle: 0.3 + sway * 0.3,
            child: _oval(20, 14, AppColors.plantLeafMuted),
          ),
        ),
      ];

  Widget _oval(double w, double h, Color color) => Container(
        width: w,
        height: h,
        decoration: ShapeDecoration(
          color: color,
          shape: const OvalBorder(),
        ),
      );

  /// Simple trapezoid pot shape via CustomPaint.
  Widget _trapezoidPot() => CustomPaint(
        size: const Size(64, 44),
        painter: _TrapezoidPainter(AppColors.potBody),
      );
}

class _TrapezoidPainter extends CustomPainter {
  final Color color;
  _TrapezoidPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(4, 0) // top-left (inset slightly for rim overlap)
      ..lineTo(size.width - 4, 0) // top-right
      ..lineTo(size.width - 2, size.height) // bottom-right (slightly wider)
      ..lineTo(2, size.height) // bottom-left
      ..close();
    canvas.drawPath(path, paint);
    // Rounded corners
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(4),
    );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_TrapezoidPainter old) => old.color != color;
}
