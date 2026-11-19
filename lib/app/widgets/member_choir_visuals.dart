import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MemberChoirStyle {
  MemberChoirStyle._();

  static const wine = AppColors.headerWine;
  static const accent = AppColors.primary;
  static const hover = AppColors.primaryHover;
  static const paper = Color(0xFFFBF8F5);
  static const border = Color(0xFFE6DED7);
  static const blush = Color(0xFFF7E9ED);
  static const soft = AppColors.primarySoft;
  static const gold = AppColors.gold;
  static const softGold = Color(0xFFFFF5DC);
  static const ink = Color(0xFF19233A);
  static const serviceCanvas = Color(0xFFF6F5FB);
  static const header = LinearGradient(colors: [wine, wine]);
  static const displayFont = 'Playfair Display';
  static const choiceIcon = Icon(Icons.keyboard_arrow_down_rounded, size: 26);
  static const buttonBorder = BorderSide(color: AppColors.muted, width: 1.2);
  static const panelBorder = Border.fromBorderSide(buttonBorder);
  static const dialogActionHeight = 52.0;
  static final cancelButtonStyle = OutlinedButton.styleFrom(
    minimumSize: const Size(0, dialogActionHeight),
    side: buttonBorder,
  );

  static Widget pairedActions({
    required Widget cancel,
    required Widget confirm,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Expanded(child: cancel),
          Expanded(child: confirm),
        ],
      ),
    );
  }

  static InputDecoration choiceDecoration(InputDecoration decoration) {
    final border = switch (decoration.border) {
      final OutlineInputBorder existing => existing,
      _ => OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    };
    return decoration.copyWith(
      border: border,
      enabledBorder: border.copyWith(borderSide: buttonBorder),
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: wine, width: 1.6),
      ),
      disabledBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
    );
  }

  static ThemeData theme(BuildContext context, {bool strengthenPanels = true}) {
    final base = Theme.of(context);
    final button = ElevatedButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        primaryContainer: blush,
        onPrimaryContainer: wine,
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: strengthenPanels
              ? buttonBorder
              : const BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: base.elevatedButtonTheme.style?.merge(button) ?? button,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? const BorderSide(color: AppColors.outlineVariant, width: 1.2)
                : buttonBorder,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: blush,
        checkmarkColor: wine,
        side: const BorderSide(color: border),
      ),
    );
  }
}

class MemberEmptyStateSliver extends StatelessWidget {
  const MemberEmptyStateSliver({super.key, required this.child, this.footer});

  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => SliverFillRemaining(
    hasScrollBody: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: Center(child: child)),
        ?footer,
      ],
    ),
  );
}

class MemberChoiceField<T> extends StatelessWidget {
  const MemberChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: ValueKey((label, value)),
    initialValue: items.any((item) => item.value == value) ? value : null,
    icon: MemberChoirStyle.choiceIcon,
    iconEnabledColor: MemberChoirStyle.wine,
    isExpanded: true,
    hint: hint == null ? null : Text(hint!),
    decoration: MemberChoirStyle.choiceDecoration(
      InputDecoration(labelText: label),
    ),
    items: items,
    onChanged: onChanged,
  );
}

enum MemberChoirArtwork {
  home('assets/images/choir_home.png'),
  service('assets/images/choir_service.png'),
  calendar('assets/images/choir_calendar.png'),
  practice('assets/images/choir_practice.png'),
  library('assets/images/choir_library.jpg'),
  song('assets/images/choir_song.jpg'),
  materials('assets/images/choir_materials.jpg');

  const MemberChoirArtwork(this.asset);
  final String asset;
}

class MemberChoirArt extends StatelessWidget {
  const MemberChoirArt({
    super.key,
    required this.artwork,
    required this.height,
    this.alignment = Alignment.center,
    this.radius = BorderRadius.zero,
    this.gradient,
    this.caption,
  });

  final MemberChoirArtwork artwork;
  final double height;
  final Alignment alignment;
  final BorderRadius radius;
  final Gradient? gradient;
  final Widget? caption;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: MemberChoirStyle.wine),
          ExcludeSemantics(
            child: Image.asset(
              artwork.asset,
              fit: BoxFit.cover,
              alignment: alignment,
            ),
          ),
          if (gradient != null)
            DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
          if (caption case final value?)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(padding: const EdgeInsets.all(12), child: value),
            ),
        ],
      ),
    ),
  );
}
