import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class HarmoniaRoseWindowSpinner extends StatefulWidget {
  const HarmoniaRoseWindowSpinner({super.key});

  @override
  State<HarmoniaRoseWindowSpinner> createState() =>
      _HarmoniaRoseWindowSpinnerState();
}

class _HarmoniaRoseWindowSpinnerState extends State<HarmoniaRoseWindowSpinner>
    with SingleTickerProviderStateMixin {
  static const _frames = [
    AssetImage('assets/illustrations/rose_window/0.png'),
    AssetImage('assets/illustrations/rose_window/1.png'),
    AssetImage('assets/illustrations/rose_window/2.png'),
    AssetImage('assets/illustrations/rose_window/3.png'),
  ];

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.reset();
    } else if (!_controller.isAnimating) {
      for (final frame in _frames) {
        precacheImage(frame, context);
      }
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final index =
          (_controller.value * _frames.length).floor() % _frames.length;
      return Image(
        image: _frames[index],
        width: 64,
        height: 64,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      );
    },
  );
}

class HarmoniaBlockingProgress extends StatelessWidget {
  const HarmoniaBlockingProgress({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background,
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              const HarmoniaRoseWindowSpinner(),
              Semantics(
                liveRegion: true,
                child: Text(
                  label,
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Covers a page while keeping its form, scroll position and draft state mounted.
class HarmoniaBlockingOverlay extends StatelessWidget {
  const HarmoniaBlockingOverlay({
    super.key,
    required this.label,
    required this.child,
  });

  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: label == null,
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        ExcludeFocus(excluding: label != null, child: child),
        if (label case final message?)
          Positioned.fill(
            child: BlockSemantics(
              child: AbsorbPointer(
                child: HarmoniaBlockingProgress(label: message),
              ),
            ),
          ),
      ],
    ),
  );
}
