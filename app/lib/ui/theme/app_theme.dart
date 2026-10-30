import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds the Material 3 light and dark themes from a single accent colour.
abstract final class AppTheme {
  static const Color seed = Color(0xFF00897B);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
    );
    return ThemeData(
      colorScheme: scheme,
      // Latin text uses Noto Sans; Arabic glyphs fall back to Noto Sans
      // Arabic, so mixed-language titles render correctly in both locales.
      fontFamily: 'NotoSans',
      fontFamilyFallback: const ['NotoSansArabic'],
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(shape: rounded, margin: EdgeInsets.zero),
      listTileTheme: ListTileThemeData(shape: rounded),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      // The default selected segment (secondaryContainer) is a pale tint that
      // is hard to tell apart from unselected ones, so use the accent colour.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? scheme.primary : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurface,
          ),
        ),
      ),
      // Selected chips (priority, weekdays) get a stronger fill and an
      // accent outline, for the same reason as the segmented buttons.
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : null,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
