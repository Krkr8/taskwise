import 'package:flutter/material.dart';

import 'brutal.dart';
import 'tokens.dart';

/// Neo-brutalist light and dark themes: flat colour blocks, 2 px outlines,
/// hard offset shadows, square corners and a chunky grotesk.
///
/// Most of the look comes from [BrutalBorder], used as the shape of cards,
/// buttons, chips, menus and dialogs, so stock Material widgets pick it up.
abstract final class AppTheme {
  static ThemeData light() => _build(_light);
  static ThemeData dark() => _build(_dark);

  static final _light = _Look(
    brightness: Brightness.light,
    b: BrutalTheme.light,
    primary: BrutalTheme.light.cobalt,
    onPrimary: Colors.white,
    error: const Color(0xFFD63A1A),
    onError: Colors.white,
    tertiary: const Color(0xFF0E8A5A),
    muted: const Color(0xFF55504A),
    surfaceDim: const Color(0xFFEDE4D1),
    surfaceHigh: const Color(0xFFF1E8D6),
    surfaceHighest: const Color(0xFFEADFC9),
    barrier: BrutalTheme.light.ink,
  );

  static final _dark = _Look(
    brightness: Brightness.dark,
    b: BrutalTheme.dark,
    // A lighter cobalt, so it also reads as text on the charcoal cards.
    primary: const Color(0xFF98ACFF),
    onPrimary: BrutalTheme.dark.onAccent,
    error: const Color(0xFFFF9A80),
    onError: BrutalTheme.dark.onAccent,
    tertiary: BrutalTheme.dark.mint,
    muted: const Color(0xFFCDC2AF),
    surfaceDim: const Color(0xFF322C27),
    surfaceHigh: const Color(0xFF514841),
    surfaceHighest: const Color(0xFF5C534A),
    barrier: Colors.black,
  );

  static ColorScheme _scheme(_Look look) {
    final b = look.b;
    return ColorScheme(
      brightness: look.brightness,
      primary: look.primary,
      onPrimary: look.onPrimary,
      primaryContainer: b.lilac,
      onPrimaryContainer: b.onAccent,
      secondary: b.ink,
      onSecondary: b.paper,
      secondaryContainer: b.yellow,
      onSecondaryContainer: b.onAccent,
      tertiary: look.tertiary,
      onTertiary: b.onAccent,
      tertiaryContainer: b.mint,
      onTertiaryContainer: b.onAccent,
      error: look.error,
      onError: look.onError,
      errorContainer: b.tomato,
      onErrorContainer: b.onAccent,
      surface: b.paper,
      onSurface: b.ink,
      onSurfaceVariant: look.muted,
      surfaceDim: look.surfaceDim,
      surfaceBright: b.card,
      surfaceContainerLowest: b.card,
      surfaceContainerLow: b.card,
      surfaceContainer: b.card,
      surfaceContainerHigh: look.surfaceHigh,
      surfaceContainerHighest: look.surfaceHighest,
      outline: b.ink,
      outlineVariant: b.hairline,
      shadow: b.shadow,
      scrim: Colors.black,
      inverseSurface: b.ink,
      onInverseSurface: b.paper,
      inversePrimary: b.yellow,
      surfaceTint: Colors.transparent,
    );
  }

  static TextTheme _text(Color ink, Color muted) {
    const w4 = FontWeight.w400;
    const w5 = FontWeight.w500;
    const w7 = FontWeight.w700;
    TextStyle s(
      double size,
      FontWeight weight, {
      double? height,
      double ls = 0,
    }) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: ls,
      color: ink,
    );
    return TextTheme(
      displayLarge: s(56, w7, height: 1.05, ls: -1.5),
      displayMedium: s(44, w7, height: 1.05, ls: -1),
      displaySmall: s(36, w7, height: 1.1, ls: -1),
      headlineLarge: s(32, w7, height: 1.15, ls: -0.8),
      headlineMedium: s(28, w7, height: 1.15, ls: -0.6),
      headlineSmall: s(24, w7, height: 1.2, ls: -0.4),
      titleLarge: s(20, w7, height: 1.25, ls: -0.2),
      titleMedium: s(16, w7, height: 1.3),
      titleSmall: s(14, w7, height: 1.3, ls: 0.2),
      bodyLarge: s(16, w4, height: 1.35),
      bodyMedium: s(14, w4, height: 1.4),
      bodySmall: s(12.5, w4, height: 1.35).copyWith(color: muted),
      labelLarge: s(14, w7, ls: 0.2),
      labelMedium: s(12.5, w5, ls: 0.2),
      labelSmall: s(11, w5, ls: 0.2),
    );
  }

  static ThemeData _build(_Look look) {
    final b = look.b;
    final brightness = look.brightness;
    final scheme = _scheme(look);
    final text = _text(b.ink, scheme.onSurfaceVariant);
    final inkSide = BorderSide(color: b.ink, width: BrutalTheme.line);
    final square = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
    );

    /// Raised buttons sink into their shadow on hover and press.
    WidgetStateProperty<OutlinedBorder> pressable(double depth, Color line) =>
        WidgetStateProperty.resolveWith(
          (states) => b.border(
            depth: depth,
            shift: states.contains(WidgetState.disabled)
                ? depth
                : states.contains(WidgetState.pressed)
                ? depth
                : states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)
                ? depth / 2
                : 0,
            color: states.contains(WidgetState.disabled)
                ? b.ink.withValues(alpha: 0.35)
                : line,
          ),
        );

    ButtonStyle raised({
      required Color background,
      required Color foreground,
      required Color line,
    }) => ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? b.card : background,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? b.ink.withValues(alpha: 0.4)
            : foreground,
      ),
      iconColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? b.ink.withValues(alpha: 0.4)
            : foreground,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shape: pressable(BrutalTheme.depthSmall, line),
      side: const WidgetStatePropertyAll(BorderSide.none),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(64, 42)),
      animationDuration: Motion.fast,
      splashFactory: NoSplash.splashFactory,
    );

    final filled = raised(
      background: scheme.primary,
      foreground: scheme.onPrimary,
      line: b.accentLine,
    );
    final outlined = raised(background: b.card, foreground: b.ink, line: b.ink);

    return ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      extensions: [b],
      // Latin text uses Space Grotesk; Arabic glyphs fall back to
      // Alexandria, a geometric Arabic face of the same weight and spirit.
      fontFamily: 'SpaceGrotesk',
      fontFamilyFallback: const ['Alexandria'],
      textTheme: text,
      primaryTextTheme: text,
      scaffoldBackgroundColor: b.paper,
      canvasColor: b.paper,
      dividerColor: b.hairline,
      splashFactory: NoSplash.splashFactory,
      hoverColor: b.yellow.withValues(alpha: 0.18),
      highlightColor: b.yellow.withValues(alpha: 0.3),
      focusColor: b.yellow.withValues(alpha: 0.35),
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: b.paper,
        foregroundColor: b.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge,
        shape: Border(
          bottom: BorderSide(color: b.ink, width: BrutalTheme.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: b.hairline, thickness: 1),
      iconTheme: IconThemeData(color: b.ink, size: 22),
      cardTheme: CardThemeData(
        color: b.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: b.border(),
      ),
      listTileTheme: ListTileThemeData(
        shape: square,
        iconColor: b.ink,
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: text.bodySmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: b.card,
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        prefixIconColor: b.ink,
        suffixIconColor: b.ink,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: inkSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: inkSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.primary, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filled),
      elevatedButtonTheme: ElevatedButtonThemeData(style: outlined),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlined),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? b.ink.withValues(alpha: 0.4)
                : b.ink,
          ),
          textStyle: WidgetStatePropertyAll(
            text.labelLarge?.copyWith(
              decoration: TextDecoration.underline,
              decorationThickness: 2,
            ),
          ),
          overlayColor: WidgetStatePropertyAll(
            b.yellow.withValues(alpha: 0.35),
          ),
          shape: WidgetStatePropertyAll(square),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? b.ink.withValues(alpha: 0.35)
                : b.ink,
          ),
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? b.yellow.withValues(alpha: 0.6)
                : states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)
                ? b.yellow.withValues(alpha: 0.35)
                : null,
          ),
          shape: WidgetStatePropertyAll(square),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: b.yellow,
        foregroundColor: b.onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        shape: b.border(depth: BrutalTheme.depth, color: b.accentLine),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: b.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: b.paper),
        actionTextColor: b.yellow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: b.yellow, width: BrutalTheme.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: b.card,
        elevation: 0,
        shape: b.border(depth: 6, width: 2.5),
        titleTextStyle: text.titleLarge,
        barrierColor: look.barrier.withValues(alpha: 0.45),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: b.card,
        elevation: 0,
        shape: b.border(depth: 6, width: 2.5),
        headerBackgroundColor: b.yellow,
        headerForegroundColor: b.onAccent,
        todayBorder: BorderSide(color: b.ink, width: 2),
        dayShape: WidgetStatePropertyAll(square),
        dividerColor: b.ink,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: b.card,
        elevation: 0,
        shape: b.border(depth: 6, width: 2.5),
        hourMinuteShape: square.copyWith(side: inkSide),
        dayPeriodShape: square,
        dayPeriodBorderSide: inkSide,
        dialBackgroundColor: b.paper,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: b.card,
        modalBackgroundColor: b.card,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: b.ink,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.lg),
          ),
          side: BorderSide(color: b.ink, width: 2.5),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: b.card,
        elevation: 0,
        shape: b.border(),
        textStyle: text.bodyMedium,
        labelTextStyle: WidgetStatePropertyAll(
          text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(b.card),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(b.border()),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: Spacing.xs),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(200, 44)),
          overlayColor: WidgetStatePropertyAll(
            b.yellow.withValues(alpha: 0.45),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(b.card),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(b.border()),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: b.ink,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        textStyle: text.labelMedium?.copyWith(color: b.paper),
        waitDuration: const Duration(milliseconds: 400),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: b.tomato,
        textColor: b.onAccent,
        textStyle: text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        side: BorderSide(color: b.ink, width: BrutalTheme.line),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? b.mint : b.card,
        ),
        checkColor: WidgetStatePropertyAll(b.onAccent),
        overlayColor: WidgetStatePropertyAll(b.yellow.withValues(alpha: 0.3)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? b.onAccent : b.ink,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? b.mint : b.card,
        ),
        trackOutlineColor: WidgetStatePropertyAll(b.ink),
        trackOutlineWidth: const WidgetStatePropertyAll(BrutalTheme.line),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: b.ink,
        inactiveTrackColor: b.hairline,
        thumbColor: b.yellow,
        overlayColor: b.yellow.withValues(alpha: 0.3),
        trackHeight: 6,
        valueIndicatorColor: b.ink,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: b.ink,
        linearTrackColor: b.hairline,
      ),
      // Selected segments use the accent colour (the owner found the old
      // pale default hard to tell apart).
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
          side: WidgetStatePropertyAll(inkSide),
          shape: WidgetStatePropertyAll(square),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          overlayColor: WidgetStatePropertyAll(b.yellow.withValues(alpha: 0.3)),
        ),
      ),
      // Chips stand up from the page; a selected chip is pressed flat and
      // turns yellow.
      chipTheme: ChipThemeData(
        backgroundColor: b.card,
        selectedColor: b.yellow,
        disabledColor: b.card,
        checkmarkColor: b.onAccent,
        labelStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: WidgetStateColor.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? b.onAccent : b.ink,
          ),
        ),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: b.onAccent),
        iconTheme: IconThemeData(color: b.ink, size: 18),
        deleteIconColor: WidgetStateColor.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? b.onAccent : b.ink,
        ),
        elevation: 0,
        pressElevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xs,
          vertical: 6,
        ),
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? b.yellow : b.card,
        ),
        side: inkSide,
        shape: WidgetStateOutlinedBorder.resolveWith(
          (states) => b.border(
            color: states.contains(WidgetState.selected) ? b.accentLine : null,
            depth: 2,
            radius: Radii.sm,
            shift:
                states.contains(WidgetState.selected) ||
                    states.contains(WidgetState.pressed)
                ? 2
                : states.contains(WidgetState.hovered)
                ? 1
                : 0,
          ),
        ),
      ),
    );
  }
}

/// Everything a theme needs beyond the [BrutalTheme] palette.
class _Look {
  const _Look({
    required this.brightness,
    required this.b,
    required this.primary,
    required this.onPrimary,
    required this.error,
    required this.onError,
    required this.tertiary,
    required this.muted,
    required this.surfaceDim,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.barrier,
  });

  final Brightness brightness;
  final BrutalTheme b;
  final Color primary;
  final Color onPrimary;
  final Color error;
  final Color onError;
  final Color tertiary;

  /// Secondary text (onSurfaceVariant).
  final Color muted;
  final Color surfaceDim;
  final Color surfaceHigh;
  final Color surfaceHighest;

  /// Dialog barrier colour, before its 45% alpha.
  final Color barrier;
}
