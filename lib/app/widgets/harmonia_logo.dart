import 'package:flutter/widgets.dart';

class HarmoniaLogo extends StatelessWidget {
  const HarmoniaLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/harmonia_logo.png',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}
