import 'package:flutter/material.dart' hide MaterialType;

import '../../../app/theme/app_colors.dart';
import '../data/music_dto.dart';

class MusicTileIcon extends StatelessWidget {
  const MusicTileIcon({super.key, required this.materialType, this.size = 44});

  final MaterialType materialType;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (materialType) {
      MaterialType.sampleAudio => (
        Icons.music_note_rounded,
        AppColors.primary,
        AppColors.primarySoft,
      ),
      MaterialType.lyrics => (
        Icons.article_outlined,
        AppColors.statusWarning,
        AppColors.statusWarningSoft,
      ),
      MaterialType.interactiveScore => (
        Icons.piano_outlined,
        AppColors.navyPrimary,
        AppColors.surfaceContainerLow,
      ),
      _ => (
        Icons.description_outlined,
        AppColors.primary,
        AppColors.primarySoft,
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
