import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_settings.dart';
import '../../state/providers.dart';
import 'brutal/shell/adaptive_shell.dart' as brutal;
import 'brutal/theme/app_theme.dart' as brutal;
import 'classic/shell/adaptive_shell.dart' as classic;
import 'classic/theme/app_theme.dart' as classic;
import 'lapis/shell/adaptive_shell.dart' as lapis;
import 'lapis/theme/app_theme.dart' as lapis;
import 'slate/shell/adaptive_shell.dart' as slate;
import 'slate/theme/app_theme.dart' as slate;

/// The design in use: the device's setting. Tests override it to pin one.
final appDesignProvider = Provider<AppDesign>(
  (ref) => ref.watch(appSettingsProvider).design,
);

/// Everything the app root needs from a design.
final class DesignSpec {
  const DesignSpec({
    required this.light,
    required this.dark,
    required this.shell,
  });

  final ThemeData Function() light;
  final ThemeData Function() dark;

  /// The top-level screen: navigation plus the Tasks/Calendar/Settings
  /// pages of this design.
  final Widget Function() shell;
}

DesignSpec designSpec(AppDesign design) => switch (design) {
  AppDesign.classic => DesignSpec(
    light: classic.AppTheme.light,
    dark: classic.AppTheme.dark,
    shell: () => const classic.AdaptiveShell(),
  ),
  AppDesign.lapis => DesignSpec(
    light: lapis.AppTheme.light,
    dark: lapis.AppTheme.dark,
    shell: () => const lapis.AdaptiveShell(),
  ),
  AppDesign.slate => DesignSpec(
    light: slate.AppTheme.light,
    dark: slate.AppTheme.dark,
    shell: () => const slate.AdaptiveShell(),
  ),
  AppDesign.brutal => DesignSpec(
    light: brutal.AppTheme.light,
    dark: brutal.AppTheme.dark,
    shell: () => const brutal.AdaptiveShell(),
  ),
};
