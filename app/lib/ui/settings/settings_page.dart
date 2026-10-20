import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../data/app_settings.dart';
import '../../state/providers.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';
import 'categories_page.dart';

/// Settings destination (M1: appearance, date & time, categories).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(appSettingsProvider);
    final repo = ref.read(settingsRepositoryProvider);
    // The Settings tab shows the effective language even before one is saved.
    final language =
        settings.language ??
        (Localizations.localeOf(context).languageCode == 'ar'
            ? AppLanguage.ar
            : AppLanguage.en);

    return SafeArea(
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              Text(
                l10n.navSettings,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              _Section(l10n.settingsAppearance),
              _Setting(
                label: l10n.theme,
                child: SegmentedButton<ThemePreference>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ThemePreference.system,
                      label: Text(l10n.themeSystem),
                      icon: const Icon(Icons.brightness_auto_outlined),
                    ),
                    ButtonSegment(
                      value: ThemePreference.light,
                      label: Text(l10n.themeLight),
                      icon: const Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemePreference.dark,
                      label: Text(l10n.themeDark),
                      icon: const Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {settings.theme},
                  onSelectionChanged: (s) => repo.setTheme(s.single),
                ),
              ),
              _Setting(
                label: l10n.language,
                child: SegmentedButton<AppLanguage>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: AppLanguage.en,
                      label: Text(l10n.languageEnglish),
                    ),
                    ButtonSegment(
                      value: AppLanguage.ar,
                      label: Text(l10n.languageArabic),
                    ),
                  ],
                  selected: {language},
                  onSelectionChanged: (s) => repo.setLanguage(s.single),
                ),
              ),
              _Section(l10n.settingsDateTime),
              _Setting(
                label: l10n.weekStartsOn,
                child: SegmentedButton<WeekStart>(
                  showSelectedIcon: false,
                  segments: [
                    for (final w in WeekStart.values)
                      ButtonSegment(
                        value: w,
                        label: Text(l10n.weekStartName(w)),
                      ),
                  ],
                  selected: {settings.weekStart},
                  onSelectionChanged: (s) => repo.setWeekStart(s.single),
                ),
              ),
              _Setting(
                label: l10n.timeFormat,
                child: SegmentedButton<TimeFormat>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: TimeFormat.h12,
                      label: Text(l10n.timeFormat12),
                    ),
                    ButtonSegment(
                      value: TimeFormat.h24,
                      label: Text(l10n.timeFormat24),
                    ),
                  ],
                  selected: {settings.timeFormat},
                  onSelectionChanged: (s) => repo.setTimeFormat(s.single),
                ),
              ),
              _Section(l10n.settingsOrganize),
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(l10n.categories),
                subtitle: Text(l10n.manageCategoriesSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CategoriesPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Spacing.xl, bottom: Spacing.sm),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// A label above a control, wrapping nicely on narrow screens.
class _Setting extends StatelessWidget {
  const _Setting({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: Spacing.sm),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: child),
      ],
    ),
  );
}
