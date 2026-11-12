import 'package:flutter/material.dart' hide MaterialType;

import '../../../app/widgets/member_choir_visuals.dart';
import '../data/music_dto.dart';

class MusicTileIcon extends StatelessWidget {
  const MusicTileIcon({super.key, required this.materialType, this.size = 44});

  final MaterialType materialType;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (materialType) {
      MaterialType.sampleAudio => (
        Icons.headphones_rounded,
        const Color(0xFF775A00),
        const Color(0xFFFFFBEB),
      ),
      MaterialType.lyrics => (
        Icons.article_outlined,
        const Color(0xFF15803D),
        const Color(0xFFECFDF5),
      ),
      MaterialType.interactiveScore => (
        Icons.piano_outlined,
        const Color(0xFF1B2541),
        const Color(0xFFF0F3FF),
      ),
      MaterialType.rehearsalMaterial => (
        Icons.record_voice_over_outlined,
        const Color(0xFF15803D),
        const Color(0xFFECFDF5),
      ),
      _ => (
        Icons.picture_as_pdf_outlined,
        MemberChoirStyle.wine,
        MemberChoirStyle.blush,
      ),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }
}
