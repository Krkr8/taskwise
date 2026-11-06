import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds the custom modern light and dark themes for Taskwise.
///
/// Crafted with an exquisite Slate & Royal Indigo palette, purposeful
/// typography hierarchy, subtle micro-borders, and tactile interaction states.
abstract final class AppTheme {
  static const Color primarySeed = Color(0xFF4F46E5); // Royal Indigo

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ColorScheme _colorScheme(Brightness brightness) {
    if (brightness == Brightness.light) {
      return const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF4F46E5),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFEEF2FF),
        onPrimaryContainer: Color(0xFF312E81),
        secondary: Color(0xFF0284C7),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFE0F2FE),
        onSecondaryContainer: Color(0xFF0369A1),
        tertiary: Color(0xFF0D9488),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFCCFBF1),
        onTertiaryContainer: Color(0xFF115E59),
        error: Color(0xFFDC2626),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFEE2E2),
        onErrorContainer: Color(0xFF991B1B),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF0F172A),
        onSurfaceVariant: Color(0xFF64748B),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFF8FAFC),
        surfaceContainer: Color(0xFFF1F5F9),
        surfaceContainerHigh: Color(0xFFE2E8F0),
        surfaceContainerHighest: Color(0xFFCBD5E1),
        outline: Color(0xFF94A3B8),
        outlineVariant: Color(0xFFE2E8F0),
        shadow: Color(0x140F172A),
      );
    } else {
      return const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF818CF8),
        onPrimary: Color(0xFF0F172A),
        primaryContainer: Color(0xFF312E81),
        onPrimaryContainer: Color(0xFFE0E7FF),
        secondary: Color(0xFF38BDF8),
        onSecondary: Color(0xFF082F49),
        secondaryContainer: Color(0xFF0369A1),
        onSecondaryContainer: Color(0xFFE0F2FE),
        tertiary: Color(0xFF2DD4BF),
        onTertiary: Color(0xFF042F2E),
        tertiaryContainer: Color(0xFF115E59),
        onTertiaryContainer: Color(0xFFCCFBF1),
        error: Color(0xFFF87171),
        onError: Color(0xFF450A0A),
        errorContainer: Color(0xFF7F1D1D),
        onErrorContainer: Color(0xFFFEE2E2),
        surface: Color(0xFF111827),
        onSurface: Color(0xFFF8FAFC),
        onSurfaceVariant: Color(0xFF94A3B8),
        surfaceContainerLowest: Color(0xFF080C14),
        surfaceContainerLow: Color(0xFF0E1524),
        surfaceContainer: Color(0xFF162032),
        surfaceContainerHigh: Color(0xFF1E293B),
        surfaceContainerHighest: Color(0xFF283548),
        outline: Color(0xFF64748B),
        outlineVariant: Color(0xFF1E293B),
        shadow: Color(0x40000000),
      );
    }
  }

  static ThemeData _build(Brightness brightness) {
    final scheme = _colorScheme(brightness);
    final isDark = brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? const Color(0xFF0A0E17)
        : const Color(0xFFF8FAFC);

    final roundedMd = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
    );
    final roundedLg = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
    );

    const baseTextTheme = TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.35,
      ),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    );

    return ThemeData(
      colorScheme: scheme,
      fontFamily: 'NotoSans',
      fontFamilyFallback: const ['NotoSansArabic'],
      textTheme: baseTextTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        shape: roundedMd,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xs,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: roundedMd,
        backgroundColor: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
        dragHandleColor: scheme.outlineVariant,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: roundedLg,
        elevation: 2,
        focusElevation: 4,
        hoverElevation: 4,
      ),
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
          side: WidgetStateProperty.all(
            BorderSide(color: scheme.outlineVariant, width: 1),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md),
            ),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        backgroundColor: scheme.surfaceContainerLow,
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : null,
        ),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
