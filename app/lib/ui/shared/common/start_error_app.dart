import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Shown instead of Taskwise when the browser couldn't start it (for
/// example when the database files didn't load), so the page is never
/// blank. It needs no database or providers. [onReload] reloads the page.
class StartErrorApp extends StatelessWidget {
  const StartErrorApp({super.key, required this.onReload, this.locale});

  final VoidCallback onReload;

  /// Tests pick the language; otherwise the browser's language decides.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Like the app: Arabic browsers get Arabic, others English.
      localeListResolutionCallback: (locales, supported) =>
          (locales ?? const []).any((l) => l.languageCode == 'ar')
          ? const Locale('ar')
          : const Locale('en'),
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      onGenerateTitle: (context) =>
          AppLocalizations.of(context).startErrorTitle,
      home: _StartErrorPage(onReload: onReload),
    );
  }
}

class _StartErrorPage extends StatelessWidget {
  const _StartErrorPage({required this.onReload});

  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.startErrorTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.startErrorMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onReload,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.startErrorReload),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
