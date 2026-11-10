import 'package:flutter/material.dart';

/// Shared colors from the approved Harmonia Mobile Stitch designs.
class AppColors {
  AppColors._();

  // Brand colors.
  static const Color primary = Color(0xFFE40035);
  static const Color primaryDark = Color(0xFFB5002B);
  static const Color primaryLight = Color(0xFFF36B97);
  static const Color primarySoft = Color(0xFFFFEDF2);
  static const Color primaryContainer = primary;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFFDCE5);
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  // Liturgical Navy Palette (Alternative liturgical theme from Stitch)
  static const Color navyPrimary = Color(0xFF06334C);
  static const Color navyContainer = Color(0xFF244A64);
  static const Color onNavyPrimary = Color(0xFFFFFFFF);

  // Secondary & Accents
  static const Color secondary = Color(0xFF64748B);
  static const Color secondaryContainer = Color(0xFFF0F3F7);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF64646B);

  // Gold / Sacred Accents
  static const Color gold = Color(0xFFD3B166);
  static const Color goldSoft = Color(0x1AD3B166);
  static const Color tertiary = Color(0xFF3F2E00);

  // Neutral & Surfaces
  static const Color background = Color(0xFFF7F8FA);
  static const Color canvas = background;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF5F7FA);
  static const Color surfaceContainerHigh = Color(0xFFEEF0F4);
  static const Color onSurface = Color(0xFF20232A);
  static const Color onSurfaceVariant = Color(0xFF64748B);
  static const Color border = Color(0xFFECEDEF);
  static const Color outline = Color(0xFF94A3B8);
  static const Color outlineVariant = Color(0xFFD8DDE5);
  static const Color body = Color(0xFF475569);
  static const Color muted = Color(0xFF737783);
  static const Color disabled = Color(0xFFA1A1AA);

  // Status & Feedback Colors
  static const Color statusSuccess = Color(0xFF008A65);
  static const Color statusSuccessSoft = Color(0xFFEAFBF3);
  static const Color statusWarning = Color(0xFFB86A00);
  static const Color statusWarningSoft = Color(0xFFFFF7E6);
  static const Color statusDanger = Color(0xFFDC2626);
  static const Color statusDangerSoft = Color(0xFFFFF0F0);
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
