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

/// Corner radii.
abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}

/// Animation durations. Use [Motion.of] so "reduce motion" is respected.
abstract final class Motion {
  /// Hover and press feedback (SPEC.md section 3.6: ~150 ms).
  static const Duration fast = Duration(milliseconds: 150);

  /// Check animation, panel slide/fade.
  static const Duration medium = Duration(milliseconds: 250);

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

  /// Width of the side detail panel.
  static const double detailPanelWidth = 420;
}

/// Colour for a priority marker, or null for [Priority.none].
Color? priorityColor(Priority priority, ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  return switch (priority) {
    Priority.none => null,
    Priority.low => dark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0),
    Priority.medium => dark ? const Color(0xFFFFCC80) : const Color(0xFFB45309),
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
