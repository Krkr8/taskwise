import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/app_settings.dart';
import 'desktop/desktop_shell.dart';
import 'l10n/app_localizations.dart';
import 'location/location_reminder_sync.dart';
import 'notifications/reminder_scheduler.dart';
import 'state/providers.dart';
import 'sync/sync_controller.dart';
import 'ui/shell/adaptive_shell.dart';
import 'ui/theme/app_theme.dart';

/// Root widget: theme, language/RTL and time format come from settings.
class TaskwiseApp extends ConsumerWidget {
  const TaskwiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    // Starts the reminder scheduler, location reminders and sync (kept alive by these watches).
    ref
      ..watch(reminderSchedulerProvider)
      ..watch(locationReminderSyncProvider)
      ..watch(syncControllerProvider);
    ref.listen(
      appSettingsProvider,
      (_, next) => DesktopShell.instance?.apply(next),
    );
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (settings.theme) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
      locale: switch (settings.language) {
        AppLanguage.en => const Locale('en'),
        AppLanguage.ar => const Locale('ar'),
        null => null,
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Until a language is chosen: Arabic systems get Arabic, others English.
      localeListResolutionCallback: (locales, supported) =>
          (locales ?? const []).any((l) => l.languageCode == 'ar')
          ? const Locale('ar')
          : const Locale('en'),
      // The time-format setting also drives the time picker's clock style.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          alwaysUse24HourFormat: settings.timeFormat == TimeFormat.h24,
        ),
        // Tapping outside a text field closes the keyboard. Flutter only does
        // this for mouse clicks on iOS/Android, so the keyboard would
        // otherwise cover the bottom bar until a field is submitted.
        child: Actions(
          actions: {
            EditableTextTapOutsideIntent:
                CallbackAction<EditableTextTapOutsideIntent>(
                  onInvoke: (intent) => intent.focusNode.unfocus(),
                ),
          },
          child: child!,
        ),
      ),
      home: const AdaptiveShell(),
    );
  }
}

/// Desktop scrolling: besides the wheel and the touchpad, lists can be
/// dragged with the mouse, and their scrollbars stay visible so they can be
/// grabbed (Flutter's desktop default allows neither).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final desktop = switch (getPlatform(context)) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };
    if (!desktop || details.direction != AxisDirection.down) {
      return super.buildScrollbar(context, child, details);
    }
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      interactive: true,
      child: child,
    );
  }
}
