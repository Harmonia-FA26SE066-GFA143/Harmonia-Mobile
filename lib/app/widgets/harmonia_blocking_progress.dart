import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'harmonia_svg_art.dart';

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
              const HarmoniaNeumeSpinner(size: 48),
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
