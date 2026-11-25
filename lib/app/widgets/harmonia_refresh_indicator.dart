import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'harmonia_svg_art.dart';

class HarmoniaRefreshIndicator extends StatefulWidget {
  const HarmoniaRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color = AppColors.primary,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final Color color;

  @override
  State<HarmoniaRefreshIndicator> createState() =>
      _HarmoniaRefreshIndicatorState();
}

class _HarmoniaRefreshIndicatorState extends State<HarmoniaRefreshIndicator> {
  bool _visible = false;

  void _updateStatus(RefreshIndicatorStatus? status) {
    final visible = switch (status) {
      RefreshIndicatorStatus.armed ||
      RefreshIndicatorStatus.snap ||
      RefreshIndicatorStatus.refresh => true,
      _ => false,
    };
    if (_visible != visible) setState(() => _visible = visible);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      RefreshIndicator.noSpinner(
        onRefresh: widget.onRefresh,
        onStatusChange: _updateStatus,
        child: widget.child,
      ),
      if (_visible)
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                shape: const CircleBorder(),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: HarmoniaNeumeSpinner(
                    size: 24,
                    color: widget.color,
                    semanticsLabel: 'Đang tải lại',
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
