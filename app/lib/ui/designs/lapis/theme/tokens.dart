import 'package:flutter/material.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

/// Spacing scale (logical pixels).
abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii. Small things are tighter, containers rounder.
abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
}

/// Animation durations. Use [Motion.of] so "reduce motion" is respected.
abstract final class Motion {
  /// Hover and press feedback (SPEC.md section 3.6: ~150 ms).
  static const Duration fast = Duration(milliseconds: 150);

  /// Check animation, panel slide/fade.
  static const Duration medium = Duration(milliseconds: 250);

  /// The today ring filling up.
  static const Duration slow = Duration(milliseconds: 600);

  /// [duration], or zero when the platform asks to reduce motion.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Layout breakpoints, by available width.
abstract final class Breakpoints {
  /// Below this the app uses phone layout (bottom navigation).
  static const double compact = 600;

  /// From this width the task list shows a side detail panel.
  static const double listDetail = 880;

  /// From this window width the side bar shows labels, not just icons.
  static const double sidebar = 1100;

  /// Width of the side detail panel.
  static const double detailPanelWidth = 420;

  /// Width of the labelled side bar and of the icon-only rail.
  static const double sidebarWidth = 220;
  static const double railWidth = 76;
}

/// The "Lapis" palette: ink blue on cool paper, with saffron kept for
/// anything that means "today".
abstract final class Palette {
  // Light.
  static const paper = Color(0xFFF4F5F9);
  static const sheet = Color(0xFFFFFFFF);
  static const ink = Color(0xFF171B33);
  static const inkMuted = Color(0xFF5C6280);
  static const line = Color(0xFFE2E5EE);
  static const lapis = Color(0xFF2B48C4);
  static const lapisSoft = Color(0xFFE5E9FB);
  static const saffron = Color(0xFFE39B2D);
  static const saffronSoft = Color(0xFFFCEFD9);
  static const vermilion = Color(0xFFC33F2A);

  // Dark.
  static const night = Color(0xFF0F1324);
  static const nightSheet = Color(0xFF161B30);
  static const nightRaised = Color(0xFF1D233B);
  static const moon = Color(0xFFE6E8F2);
  static const moonMuted = Color(0xFF9CA2BF);
  static const nightLine = Color(0xFF283050);
  static const lapisLight = Color(0xFF94A7FF);
  static const lapisDeep = Color(0xFF243068);
  static const saffronLight = Color(0xFFF3B85E);
  static const saffronDeep = Color(0xFF3A2C14);
  static const vermilionLight = Color(0xFFFF8F7A);
}

/// Colours the Material scheme has no slot for.
@immutable
class LapisColors extends ThemeExtension<LapisColors> {
  const LapisColors({
    required this.today,
    required this.onToday,
    required this.todaySoft,
    required this.sidebar,
    required this.line,
  });

  /// Marks today: the date ring, today's column and section.
  final Color today;
  final Color onToday;
  final Color todaySoft;

  /// Background of the side bar (desktop).
  final Color sidebar;

  /// Hairlines between areas.
  final Color line;

  static const light = LapisColors(
    today: Palette.saffron,
    onToday: Palette.ink,
    todaySoft: Palette.saffronSoft,
    sidebar: Color(0xFFEBEDF4),
    line: Palette.line,
  );

  static const dark = LapisColors(
    today: Palette.saffronLight,
    onToday: Palette.night,
    todaySoft: Palette.saffronDeep,
    sidebar: Color(0xFF0B0E1C),
    line: Palette.nightLine,
  );

  static LapisColors of(BuildContext context) =>
      Theme.of(context).extension<LapisColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  LapisColors copyWith({
    Color? today,
    Color? onToday,
    Color? todaySoft,
    Color? sidebar,
    Color? line,
  }) => LapisColors(
    today: today ?? this.today,
    onToday: onToday ?? this.onToday,
    todaySoft: todaySoft ?? this.todaySoft,
    sidebar: sidebar ?? this.sidebar,
    line: line ?? this.line,
  );

  @override
  LapisColors lerp(LapisColors? other, double t) {
    if (other == null) return this;
    return LapisColors(
      today: Color.lerp(today, other.today, t)!,
      onToday: Color.lerp(onToday, other.onToday, t)!,
      todaySoft: Color.lerp(todaySoft, other.todaySoft, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}

/// Colour for a priority marker, or null for [Priority.none].
Color? priorityColor(Priority priority, ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  return switch (priority) {
    Priority.none => null,
    Priority.low => dark ? const Color(0xFFA3B3D6) : const Color(0xFF5E739C),
    Priority.medium => dark ? const Color(0xFFFFA36B) : const Color(0xFFC25E14),
    Priority.high => scheme.error,
  };
}

/// Colours offered for categories (ARGB). Mid-tones that read on both themes.
const List<int> categoryPalette = [
  0xFFE53935, // red
  0xFFD81B60, // pink
  0xFF8E24AA, // purple
  0xFF3949AB, // indigo
  0xFF1E88E5, // blue
  0xFF00897B, // teal
  0xFF43A047, // green
  0xFFF4511E, // deep orange
  0xFFFFB300, // amber
  0xFF6D4C41, // brown
  0xFF546E7A, // blue grey
];
