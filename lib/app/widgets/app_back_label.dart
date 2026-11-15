import 'package:flutter/material.dart';

class AppBackLabel extends StatelessWidget {
  const AppBackLabel({super.key});

  @override
  Widget build(BuildContext context) => Text(
    'Về',
    maxLines: 1,
    style: TextStyle(
      color: IconTheme.of(context).color,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
}
