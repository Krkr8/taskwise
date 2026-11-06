import 'package:flutter/material.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

/// Spacing scale (logical pixels).
abstract final class Spacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 40;
  static const double massive = 48;
}

/// Corner radii for cards, inputs, buttons and sheets.
abstract final class Radii {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double full = 999;
}

/// Animation durations. Use [Motion.of] so "reduce motion" is respected.
abstract final class Motion {
  /// Hover and press feedback (SPEC.md section 3.6: ~150 ms).
  static const Duration fast = Duration(milliseconds: 150);

  /// Check animation, panel slide/fade, sheet entry.
  static const Duration medium = Duration(milliseconds: 250);

  /// Layout reorganizations, page switches.
  static const Duration slow = Duration(milliseconds: 350);

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
  static const double detailPanelWidth = 430;
}

/// Colour for a priority marker, or null for [Priority.none].
Color? priorityColor(Priority priority, ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  return switch (priority) {
    Priority.none => null,
    Priority.low => dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    Priority.medium => dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
    Priority.high => dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
  };
}

/// Background tint for priority tags and badges.
Color? priorityBackgroundColor(Priority priority, ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  return switch (priority) {
    Priority.none => null,
    Priority.low =>
      dark
          ? const Color(0xFF1E3A5F).withValues(alpha: 0.6)
          : const Color(0xFFEFF6FF),
    Priority.medium =>
      dark
          ? const Color(0xFF452B0E).withValues(alpha: 0.6)
          : const Color(0xFFFFFBEB),
    Priority.high =>
      dark
          ? const Color(0xFF4C1D1D).withValues(alpha: 0.6)
          : const Color(0xFFFEF2F2),
  };
}

/// Colours offered for categories (ARGB). Mid-tones that read on both themes.
const List<int> categoryPalette = [
  0xFFE11D48, // Rose
  0xFFDB2777, // Pink
  0xFF9333EA, // Purple
  0xFF4F46E5, // Indigo
  0xFF2563EB, // Blue
  0xFF0D9488, // Teal
  0xFF16A34A, // Green
  0xFFEA580C, // Deep Orange
  0xFFD97706, // Amber
  0xFF854D0E, // Warm Bronze
  0xFF475569, // Slate
];
