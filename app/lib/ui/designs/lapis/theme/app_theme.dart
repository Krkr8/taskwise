import 'package:flutter/material.dart';

import 'tokens.dart';

/// The "Lapis" light and dark themes: ink blue on cool paper, saffron for
/// today, IBM Plex Sans Arabic for both scripts.
abstract final class AppTheme {
  static const String fontFamily = 'IBMPlexSansArabic';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ColorScheme scheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: Palette.lapis,
      brightness: brightness,
    );
    return dark
        ? base.copyWith(
            primary: Palette.lapisLight,
            onPrimary: Palette.night,
            primaryContainer: Palette.lapisDeep,
            onPrimaryContainer: const Color(0xFFDDE3FF),
            secondaryContainer: Palette.lapisDeep,
            onSecondaryContainer: const Color(0xFFDDE3FF),
            tertiary: Palette.saffronLight,
            onTertiary: Palette.night,
            error: Palette.vermilionLight,
            onError: Palette.night,
            surface: Palette.night,
            onSurface: Palette.moon,
            onSurfaceVariant: Palette.moonMuted,
            surfaceContainerLowest: const Color(0xFF0B0E1C),
            surfaceContainerLow: Palette.nightSheet,
            surfaceContainer: Palette.nightSheet,
            surfaceContainerHigh: Palette.nightRaised,
            surfaceContainerHighest: const Color(0xFF242B46),
            outline: const Color(0xFF59607E),
            outlineVariant: Palette.nightLine,
            inverseSurface: Palette.moon,
            onInverseSurface: Palette.night,
            inversePrimary: Palette.lapis,
          )
        : base.copyWith(
            primary: Palette.lapis,
            onPrimary: Colors.white,
            primaryContainer: Palette.lapisSoft,
            onPrimaryContainer: const Color(0xFF14246B),
            secondaryContainer: Palette.lapisSoft,
            onSecondaryContainer: const Color(0xFF14246B),
            tertiary: Palette.saffron,
            onTertiary: Palette.ink,
            error: Palette.vermilion,
            onError: Colors.white,
            surface: Palette.paper,
            onSurface: Palette.ink,
            onSurfaceVariant: Palette.inkMuted,
            surfaceContainerLowest: Palette.sheet,
            surfaceContainerLow: Palette.sheet,
            surfaceContainer: const Color(0xFFEEF0F6),
            surfaceContainerHigh: const Color(0xFFE8EBF3),
            surfaceContainerHighest: const Color(0xFFE1E4EE),
            outline: const Color(0xFF9096AE),
            outlineVariant: Palette.line,
            inverseSurface: Palette.ink,
            onInverseSurface: Palette.paper,
            inversePrimary: Palette.lapisLight,
          );
  }

  static TextTheme _text(TextTheme base, ColorScheme scheme) {
    TextStyle? s(TextStyle? t, {double? size, FontWeight? w, double? h}) =>
        t?.copyWith(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: w,
          height: h,
          letterSpacing: 0,
        );
    return base
        .copyWith(
          displaySmall: s(base.displaySmall, size: 34, w: FontWeight.w600),
          headlineLarge: s(base.headlineLarge, size: 30, w: FontWeight.w600),
          headlineMedium: s(base.headlineMedium, size: 26, w: FontWeight.w600),
          headlineSmall: s(base.headlineSmall, size: 22, w: FontWeight.w600),
          titleLarge: s(base.titleLarge, size: 19, w: FontWeight.w600),
          titleMedium: s(base.titleMedium, size: 15, w: FontWeight.w600),
          titleSmall: s(base.titleSmall, size: 13.5, w: FontWeight.w600),
          bodyLarge: s(base.bodyLarge, size: 15, h: 1.4),
          bodyMedium: s(base.bodyMedium, size: 14, h: 1.4),
          bodySmall: s(base.bodySmall, size: 12.5, h: 1.35),
          labelLarge: s(base.labelLarge, size: 14, w: FontWeight.w500),
          labelMedium: s(base.labelMedium, size: 12.5, w: FontWeight.w500),
          labelSmall: s(base.labelSmall, size: 11.5, w: FontWeight.w500),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }

  static ThemeData _build(Brightness brightness) {
    final scheme = AppTheme.scheme(brightness);
    final dark = brightness == Brightness.dark;
    final lapis = dark ? LapisColors.dark : LapisColors.light;
    final sheet = scheme.surfaceContainerLow;
    final base = ThemeData(
      colorScheme: scheme,
      fontFamily: fontFamily,
      brightness: brightness,
    );
    final text = _text(base.textTheme, scheme);
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
    );
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: text,
      extensions: [lapis],
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      hoverColor: scheme.primary.withValues(alpha: dark ? 0.08 : 0.05),
      dividerTheme: DividerThemeData(color: lapis.line, space: 1),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: lapis.line),
        ),
        color: sheet,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        shape: rounded,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: sheet,
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: border(lapis.line),
        enabledBorder: border(lapis.line),
        focusedBorder: border(scheme.primary, 1.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: rounded,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: rounded,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
          foregroundColor: scheme.onSurface,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: rounded,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm + 2),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: sheet,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        height: 66,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: sheet,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: lapis.line),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(sheet),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md),
              side: BorderSide(color: lapis.line),
            ),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheet,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: scheme.outline.withValues(alpha: 0.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: sheet,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg + 4),
        ),
        titleTextStyle: text.titleLarge,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: sheet,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.primary,
        headerForegroundColor: scheme.onPrimary,
        todayBorder: BorderSide(color: lapis.today, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg + 4),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: sheet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg + 4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: dark ? Palette.lapis : Palette.lapisLight,
        shape: rounded,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: text.labelMedium?.copyWith(color: scheme.onInverseSurface),
        waitDuration: const Duration(milliseconds: 400),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(4),
        thickness: const WidgetStatePropertyAll(6),
        thumbColor: WidgetStatePropertyAll(
          scheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline.withValues(alpha: 0.6),
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
      ),
      // Selected segments use the full accent so the choice is obvious.
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
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
          ),
          shape: WidgetStatePropertyAll(rounded),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      // Selected chips get a tinted fill and an accent outline.
      chipTheme: ChipThemeData(
        backgroundColor: sheet,
        labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm + 2),
        ),
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : sheet,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: lapis.line,
        circularTrackColor: lapis.line,
      ),
    );
  }
}
