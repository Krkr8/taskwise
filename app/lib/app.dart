import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/app_settings.dart';
import 'l10n/app_localizations.dart';
import 'state/providers.dart';
import 'ui/shell/adaptive_shell.dart';
import 'ui/theme/app_theme.dart';

/// Root widget: theme, language/RTL and time format come from settings.
class TaskwiseApp extends ConsumerWidget {
  const TaskwiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
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
        child: child!,
      ),
      home: const AdaptiveShell(),
    );
  }
}
