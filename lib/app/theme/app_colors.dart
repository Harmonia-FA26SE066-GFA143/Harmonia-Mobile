import 'package:flutter/material.dart';

/// Centralized design tokens and color palette extracted directly from Stitch UI
class AppColors {
  AppColors._();

  // Liturgical Burgundy Palette (Default Stitch Mobile Theme)
  static const Color primary = Color(0xFF8E3B4B);
  static const Color primaryDark = Color(0xFF6F2B39);
  static const Color primaryLight = Color(0xFFBA5D6F);
  static const Color primaryContainer = Color(0xFF8E3B4B);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFFBAC3);

  // Liturgical Navy Palette (Alternative liturgical theme from Stitch)
  static const Color navyPrimary = Color(0xFF06334C);
  static const Color navyContainer = Color(0xFF244A64);
  static const Color onNavyPrimary = Color(0xFFFFFFFF);

  // Secondary & Accents
  static const Color secondary = Color(0xFF3E6562);
  static const Color secondaryContainer = Color(0xFFE3E1EA);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF64646B);

  // Gold / Sacred Accents
  static const Color gold = Color(0xFFD3B166);
  static const Color goldSoft = Color(0x1AD3B166);
  static const Color tertiary = Color(0xFF3F2E00);

  // Neutral & Surfaces
  static const Color background = Color(0xFFF7F7F8);
  static const Color canvas = Color(0xFFF7F7F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF6F2F7);
  static const Color surfaceContainerHigh = Color(0xFFEAE7EB);
  static const Color onSurface = Color(0xFF18181B);
  static const Color onSurfaceVariant = Color(0xFF544244);
  static const Color border = Color(0xFFE4E4E7);
  static const Color outline = Color(0xFF877274);
  static const Color outlineVariant = Color(0xFFC2C7CD);
  static const Color body = Color(0xFF3F3F46);
  static const Color muted = Color(0xFF71717A);
  static const Color disabled = Color(0xFFA1A1AA);

  // Status & Feedback Colors
  static const Color statusSuccess = Color(0xFF15803D);
  static const Color statusSuccessSoft = Color(0x1A15803D);
  static const Color statusWarning = Color(0xFFB45309);
  static const Color statusWarningSoft = Color(0x1AB45309);
  static const Color statusDanger = Color(0xFFB91C1C);
  static const Color statusDangerSoft = Color(0x1AB91C1C);
  static const Color statusInfo = Color(0xFF1D4ED8);
  static const Color statusInfoSoft = Color(0x1A1D4ED8);

  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Liturgical Seasons Colors
  static const Color seasonOrdinary = Color(
    0xFF15803D,
  ); // Xanh lá - Mùa Thường Niên
  static const Color seasonAdventLent = Color(
    0xFF6B21A8,
  ); // Tím - Mùa Vọng / Mùa Chay
  static const Color seasonEasterChristmas = Color(
    0xFFD97706,
  ); // Trắng / Vàng - Mùa Phục Sinh & Giáng Sinh
  static const Color seasonPentecostMartyrs = Color(
    0xFFB91C1C,
  ); // Đỏ - Thánh Linh & Tử Đạo
}
