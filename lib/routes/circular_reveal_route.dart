import 'dart:math';
import 'package:flutter/material.dart';

/// Page route that reveals the new page with an expanding circle originating
/// from [center] (absolute screen coordinates of the tapped element).
class CircularRevealRoute<T> extends PageRoute<T> {
  final Widget page;
  final Offset center;

  CircularRevealRoute({required this.page, required this.center});

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 550);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 380);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      page;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (_, _) => ClipPath(
        clipper: _CircleClipper(fraction: curved.value, center: center),
        child: child,
      ),
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset center;

  const _CircleClipper({required this.fraction, required this.center});

  @override
  Path getClip(Size size) {
    // Radius must reach the farthest corner of the screen
    final maxRadius = sqrt(
      max(
        pow(center.dx, 2) + pow(center.dy, 2),
        max(
          pow(size.width - center.dx, 2) + pow(center.dy, 2),
          max(
            pow(center.dx, 2) + pow(size.height - center.dy, 2),
            pow(size.width - center.dx, 2) +
                pow(size.height - center.dy, 2),
          ),
        ),
      ),
    );
    return Path()
      ..addOval(
        Rect.fromCircle(center: center, radius: maxRadius * fraction),
      );
  }

  @override
  bool shouldReclip(_CircleClipper old) =>
      old.fraction != fraction || old.center != center;
}
