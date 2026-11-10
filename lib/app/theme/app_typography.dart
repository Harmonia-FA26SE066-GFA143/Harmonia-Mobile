import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography from the approved Be Vietnam Pro Stitch design
class AppTypography {
  AppTypography._();

  static TextStyle get headlineLarge => TextStyle(
    fontFamily: 'Be Vietnam Pro',
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.onSurface,
  );

  static TextStyle get headlineMedium => TextStyle(
    fontFamily: 'Be Vietnam Pro',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.onSurface,
  );

  static TextStyle get headlineSmall => TextStyle(
    fontFamily: 'Be Vietnam Pro',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: AppColors.onSurface,
  );

  static TextStyle get titleLarge => TextStyle(
    fontFamily: 'Be Vietnam Pro',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.onSurface,
  );

  static TextStyle get titleMedium => TextStyle(
    fontFamily: 'Be Vietnam Pro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.onSurface,
  );

  static TextStyle get bodyLarge => TextStyle(
    fontFamily: 'Be Vietnam Pro',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.body,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontFamily: 'Be Vietnam Pro',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.body,
  );

  static TextStyle get bodySmall => TextStyle(
    fontFamily: 'Be Vietnam Pro',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.muted,
  );

  static TextStyle get labelLarge => TextStyle(
    fontFamily: 'Be Vietnam Pro',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.onSurface,
  );

  static TextStyle get labelMedium => TextStyle(
    fontFamily: 'Be Vietnam Pro',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.muted,
  );

  static TextStyle get labelSmall => TextStyle(
    fontFamily: 'Be Vietnam Pro',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.muted,
  );

  /// Tabular numbers for countdowns, timers, and quantitative metrics (Prevents layout jitter - Rule N1)
  static TextStyle get tabularCounter => TextStyle(
    fontFamily: 'Be Vietnam Pro',
    fontSize: 38,
    fontWeight: FontWeight.w800,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: AppColors.onSurface,
  );

  static TextStyle get tabularBody => TextStyle(
    fontFamily: 'Be Vietnam Pro',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: AppColors.onSurface,
  );
}
