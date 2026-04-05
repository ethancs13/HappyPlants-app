import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:happy_plants/theme/app_theme.dart';

class PlantWidget extends StatefulWidget {
  final bool isHappy;

  /// Width of the bounding box. Height = width × 1.6 for drawn widget,
  /// or width × 1.0 (square) when using SVG assets (Figma frames are 500×500).
  final double size;

  /// If set (e.g. 'plant_01'), loads SVG assets from
  ///   assets/images/plants/PLANT_KEY_foliage.svg  (animated)
  ///   assets/images/plants/PLANT_KEY_pot.svg       (static)
  /// Otherwise falls back to the drawn widget.
  final String? plantKey;

  const PlantWidget({
    super.key,
    required this.isHappy,
    this.size = 120,
    this.plantKey,
  });

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
    if (widget.plantKey != null) {
      return _SvgPlant(
        plantKey: widget.plantKey!,
        isHappy: widget.isHappy,
        size: widget.size,
        sway: _sway,
      );
    }

    // Fallback: drawn widget (100×160 native, scaled to fit)
    final scale = widget.size / 100.0;
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.6,
      child: AnimatedBuilder(
        animation: _sway,
        builder: (_, child) => Transform.scale(
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: _DrawnPlantBody(
            isHappy: widget.isHappy,
            swayAngle: _sway.value,
          ),
        ),
      ),
    );
  }
}

// ── SVG-based plant ─────────────────────────────────────────────────────────

/// Stacks the pot SVG (static) under the foliage SVG (animated sway).
/// Both assets are 500×500 with transparent backgrounds so they align
/// automatically when placed at the same size.
class _SvgPlant extends StatelessWidget {
  final String plantKey;
  final bool isHappy;
  final double size;
  final Animation<double> sway;

  const _SvgPlant({
    required this.plantKey,
    required this.isHappy,
    required this.size,
    required this.sway,
  });

  @override
  Widget build(BuildContext context) {
    final foliagePath = 'assets/images/plants/${plantKey}_foliage.svg';
    final potPath = 'assets/images/plants/${plantKey}_pot.svg';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Foliage — behind the pot, sways around the bottom-center pivot
          AnimatedBuilder(
            animation: sway,
            builder: (_, child) => Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.rotationZ(sway.value),
              child: child,
            ),
            child: SvgPicture.asset(
              foliagePath,
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          ),
          // Pot — static, rendered on top so foliage appears to grow from it
          SvgPicture.asset(
            potPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

// ── Drawn fallback plant ─────────────────────────────────────────────────────

class _DrawnPlantBody extends StatelessWidget {
  final bool isHappy;
  final double swayAngle;

  const _DrawnPlantBody({required this.isHappy, required this.swayAngle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 160,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 18,
            top: 112,
            child: _trapezoidPot(),
          ),
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
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 54,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.rotationZ(swayAngle),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
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

  List<Widget> _happyLeaves(double sway) => [
        Positioned(
          left: 6,
          bottom: 30,
          child: Transform.rotate(
            angle: -pi / 3.8 + sway * 0.4,
            alignment: Alignment.bottomRight,
            child: _oval(40, 26, AppColors.forest),
          ),
        ),
        Positioned(
          left: 54,
          bottom: 38,
          child: Transform.rotate(
            angle: pi / 3.8 + sway * 0.4,
            alignment: Alignment.bottomLeft,
            child: _oval(36, 23, AppColors.olive),
          ),
        ),
        Positioned(
          left: 38,
          bottom: 54,
          child: Transform.rotate(
            angle: sway * 0.2,
            child: _oval(22, 16, AppColors.forest),
          ),
        ),
      ];

  List<Widget> _sadLeaves(double sway) => [
        Positioned(
          left: 8,
          bottom: 18,
          child: Transform.rotate(
            angle: -pi / 1.7 + sway,
            alignment: Alignment.bottomRight,
            child: _oval(36, 22, AppColors.plantLeafMuted),
          ),
        ),
        Positioned(
          left: 56,
          bottom: 18,
          child: Transform.rotate(
            angle: pi / 1.7 + sway,
            alignment: Alignment.bottomLeft,
            child: _oval(36, 22, AppColors.plantLeafMuted),
          ),
        ),
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
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(4),
    );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_TrapezoidPainter old) => old.color != color;
}
