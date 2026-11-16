import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'harmonia_svg_art.dart';

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
    this.titleSpacing = 20,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
    this.showEmptyAccent = false,
    this.showChantMotif = false,
    this.chantRightPadding = 12,
    this.accentTitleText,
  });

  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool large;
  final bool roundedBottom;
  final Gradient gradient;
  final String? titleFontFamily;
  final double titleSpacing;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final bool showEmptyAccent;
  final bool showChantMotif;
  final double chantRightPadding;
  final String? accentTitleText;

  @override
  Size get preferredSize =>
      Size.fromHeight((large ? 96 : 72) + (bottom?.preferredSize.height ?? 0));

  bool _canFitEmptyAccent(
    BuildContext context,
    double maxWidth,
    TextStyle titleStyle,
  ) {
    if (actions != null && actions!.isNotEmpty) return false;
    final text =
        accentTitleText ?? (title is Text ? (title as Text).data : null);
    if (text == null || text.trim().isEmpty) return false;

    final painter = TextPainter(
      text: TextSpan(text: text, style: titleStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();

    final hasLeading =
        leading != null ||
        (automaticallyImplyLeading &&
            (ModalRoute.of(context)?.canPop ?? false));
    final leadingReserve = hasLeading ? 56.0 : 20.0;
    final rightFree = centerTitle
        ? (maxWidth - painter.width) / 2 - 12.0
        : maxWidth - leadingReserve - painter.width - 16.0;
    return !painter.didExceedMaxLines && rightFree >= 84.0;
  }

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.vertical(
      bottom: Radius.circular(large || roundedBottom ? 28 : 0),
    );
    final titleStyle =
        (large ? AppTypography.headlineMedium : AppTypography.headlineSmall)
            .copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w700,
              fontFamily: titleFontFamily,
            );
    final hasBackdropMotif =
        showChantMotif ||
        (showEmptyAccent && (actions == null || actions!.isEmpty));

    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      bottom: bottom,
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: centerTitle,
      toolbarHeight: large ? 96 : 72,
      backgroundColor: AppColors.headerWine,
      foregroundColor: AppColors.onPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: titleSpacing,
      titleTextStyle: titleStyle,
      iconTheme: const IconThemeData(color: AppColors.onPrimary),
      actionsIconTheme: const IconThemeData(color: AppColors.onPrimary),
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: shape),
      clipBehavior: Clip.antiAlias,
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient, borderRadius: shape),
        child: !hasBackdropMotif
            ? const SizedBox.expand()
            : ClipRRect(
                borderRadius: shape,
                child: SafeArea(
                  bottom: false,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (showChantMotif) {
                            final motifWidth = (constraints.maxWidth * 0.44)
                                .clamp(112.0, 176.0);
                            return Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: chantRightPadding,
                                  bottom: 8,
                                ),
                                child: Opacity(
                                  opacity: 0.22,
                                  child: HarmoniaSvgGraphic(
                                    assetPath: HarmoniaSvgAsset.chantIncipit,
                                    width: motifWidth,
                                    height: motifWidth * (29 / 196),
                                    colorOverride: const Color(0xFFF7E6B5),
                                    fit: BoxFit.contain,
                                    alignment: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (!_canFitEmptyAccent(
                            context,
                            constraints.maxWidth,
                            titleStyle,
                          )) {
                            return const SizedBox.shrink();
                          }
                          final accentHeight = large ? 56.0 : 48.0;
                          return Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Opacity(
                                opacity: 0.22,
                                child: HarmoniaSvgGraphic(
                                  assetPath: HarmoniaSvgAsset.noResults,
                                  height: accentHeight,
                                  width: accentHeight * 1.5,
                                  colorOverride: AppColors.onPrimaryContainer,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.centerRight,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
