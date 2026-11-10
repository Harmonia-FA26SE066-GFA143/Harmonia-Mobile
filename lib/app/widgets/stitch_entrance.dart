import 'package:flutter/material.dart';

/// Short entrance for panels that have motion in the Stitch reference.
class StitchEntrance extends StatelessWidget {
  const StitchEntrance({super.key, required this.child, this.distance = 8});

  final Widget child;
  final double distance;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, progress, child) => Opacity(
        opacity: 0.82 + 0.18 * progress,
        child: Transform.translate(
          offset: Offset(0, distance * (1 - progress)),
          child: child,
        ),
      ),
    );
  }
}
