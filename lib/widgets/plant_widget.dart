import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:happy_plants/models/plant_definition.dart';
import 'package:happy_plants/theme/app_theme.dart';

class PlantWidget extends StatefulWidget {
  final bool isHappy;

  /// Logical width. Height is determined by the plant's canvas aspect ratio
  /// (PlantDefinition) or defaults to width × 1.6 for the drawn fallback.
  final double size;

  /// Key into [kPlantDefinitions] (e.g. 'plant_02').
  /// Null → drawn fallback widget.
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.isHappy
          ? const Duration(milliseconds: 2000)
          : const Duration(milliseconds: 5000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final definition = widget.plantKey != null
        ? kPlantDefinitions[widget.plantKey]
        : null;

    if (definition != null) {
      final scale = widget.size / definition.canvasWidth;
      final height = definition.canvasHeight * scale;
      return SizedBox(
        width: widget.size,
        height: height,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: definition.canvasWidth,
            height: definition.canvasHeight,
            child: _DefinitionPlant(
              definition: definition,
              isHappy: widget.isHappy,
              controller: _controller,
            ),
          ),
        ),
      );
    }

    // Drawn fallback
    final scale = widget.size / 100.0;
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.6,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) {
          final maxAngle = widget.isHappy ? 0.24 : 0.07;
          final sway = sin(_controller.value * 2 * pi) * maxAngle;
          return Transform.scale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: _DrawnPlantBody(isHappy: widget.isHappy, swayAngle: sway),
          );
        },
      ),
    );
  }
}

// ── Definition-based plant ───────────────────────────────────────────────────

class _DefinitionPlant extends StatelessWidget {
  final PlantDefinition definition;
  final bool isHappy;
  final AnimationController controller;

  const _DefinitionPlant({
    required this.definition,
    required this.isHappy,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: definition.parts.map((part) {
            // Convert bottom-left origin to Flutter's top-left origin
            final top = definition.canvasHeight - part.bottom - part.height;

            if (part.happyAmplitude == 0) {
              // Static part (pot)
              return Positioned(
                left: part.left,
                top: top,
                child: SvgPicture.asset(
                  part.asset,
                  width: part.width,
                  height: part.height,
                  fit: BoxFit.fill,
                ),
              );
            }

            // Animated leaf — sways around its bottom center
            final amplitude =
                isHappy ? part.happyAmplitude : part.happyAmplitude * 0.3;
            final phase = part.phaseOffset * 2 * pi;
            final angle =
                sin(controller.value * 2 * pi + phase) * amplitude;

            return Positioned(
              left: part.left,
              top: top,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.rotationZ(angle),
                child: SvgPicture.asset(
                  part.asset,
                  width: part.width,
                  height: part.height,
                  fit: BoxFit.fill,
                ),
              ),
            );
          }).toList(),
        );
      },
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
