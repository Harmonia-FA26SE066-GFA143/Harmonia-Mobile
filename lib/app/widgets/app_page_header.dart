import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A shared gradient header for the approved mobile screens.
class AppPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.large = false,
    this.roundedBottom = false,
    this.gradient = AppColors.brandGradient,
    this.titleFontFamily,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
  });

  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool large;
  final bool roundedBottom;
  final Gradient gradient;
  final String? titleFontFamily;
  final bool centerTitle;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize =>
      Size.fromHeight((large ? 96 : 72) + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.vertical(
      bottom: Radius.circular(large || roundedBottom ? 28 : 0),
    );
    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      bottom: bottom,
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: centerTitle,
      toolbarHeight: large ? 96 : 72,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 20,
      titleTextStyle:
          (large ? AppTypography.headlineMedium : AppTypography.headlineSmall)
              .copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
                fontFamily: titleFontFamily,
              ),
      iconTheme: const IconThemeData(color: AppColors.onPrimary),
      actionsIconTheme: const IconThemeData(color: AppColors.onPrimary),
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: shape),
      clipBehavior: Clip.antiAlias,
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient, borderRadius: shape),
      ),
    );
  }
}
