import 'package:flutter/material.dart';

class CalendarPeriodButton extends StatelessWidget {
  const CalendarPeriodButton({
    super.key,
    required this.isPrevious,
    required this.tooltip,
    required this.onPressed,
  });

  final bool isPrevious;
  final String tooltip;
  final VoidCallback? onPressed;

  static final _style = IconButton.styleFrom(
    foregroundColor: const Color(0xFF05102B),
    hoverColor: const Color(0xFFE7EEFF),
    highlightColor: const Color(0xFFDEE8FF),
    minimumSize: const Size(38, 38),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: _style,
    icon: isPrevious
        ? const Icon(Icons.chevron_left_rounded, size: 20)
        : const Text(
            'Sau',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
  );
}
