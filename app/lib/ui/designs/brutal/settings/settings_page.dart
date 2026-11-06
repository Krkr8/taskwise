import '../../../shared/settings/design_picker.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../data/app_settings.dart';
import '../../../../location/location_reminder_sync.dart';
import '../../../../notifications/reminder_scheduler.dart';
import '../../../../state/providers.dart';
import '../../../shared/location/location_permission.dart';
import '../../../shared/tasks/labels.dart';
import '../common/brutal_widgets.dart';
import '../theme/brutal.dart';
import '../../../shared/theme/tokens.dart' show centeredPadding;
import '../theme/tokens.dart';
import '../../../shared/settings/categories_page.dart';
import '../../../shared/settings/location_debug_page.dart';
import 'places_page.dart';
import '../../../shared/settings/sync_section.dart';

/// Settings destination: appearance, date & time, notifications,
/// background (desktop) and categories.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(appSettingsProvider);
    final repo = ref.read(settingsRepositoryProvider);
    final isDesktop = Platform.isLinux || Platform.isWindows;
    final b = BrutalTheme.of(context);
    // The Settings tab shows the effective language even before one is saved.
    final language =
        settings.language ??
        (Localizations.localeOf(context).languageCode == 'ar'
            ? AppLanguage.ar
            : AppLanguage.en);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => ListView(
          // Rows are built only once on screen (no build-ahead).
          scrollCacheExtent: const ScrollCacheExtent.pixels(0),
          padding: centeredPadding(
            box.maxWidth,
            EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < Breakpoints.compact
                  ? Spacing.lg
                  : Spacing.xl,
              vertical: Spacing.xl,
            ),
          ),
          children: [
            Text(
              l10n.navSettings,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            ..._section(
              l10n.settingsSync,
              color: b.lilac,
              children: [const SyncSection()],
            ),
            ..._section(
              l10n.settingsAppearance,
              color: b.yellow,
              children: [
                _Setting(
                  label: l10n.settingsDesign,
                  child: const DesignPicker(),
                ),
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
              ],
            ),
            ..._section(
              l10n.settingsDateTime,
              color: b.mint,
              children: [
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
              ],
            ),
            ..._section(
              l10n.settingsNotifications,
              color: b.tomato,
              children: [
                _Setting(
                  label: l10n.defaultReminder,
                  child: SegmentedButton<DefaultReminder>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: DefaultReminder.none,
                        label: Text(l10n.defaultReminderNone),
                      ),
                      ButtonSegment(
                        value: DefaultReminder.atDueTime,
                        label: Text(l10n.defaultReminderAtDue),
                      ),
                      ButtonSegment(
                        value: DefaultReminder.min15,
                        label: Text(l10n.defaultReminderMin15),
                      ),
                    ],
                    selected: {settings.defaultReminder},
                    onSelectionChanged: (s) =>
                        repo.setDefaultReminder(s.single),
                  ),
                ),
                _Setting(
                  label: l10n.snoozeOptions,
                  child: Wrap(
                    spacing: Spacing.sm,
                    children: [
                      for (final m in AppSettings.snoozeChoices)
                        FilterChip(
                          showCheckmark: false,
                          label: Text(l10n.minutesShort(m)),
                          selected: settings.snoozeMinutes.contains(m),
                          // Keep 1 to 3 selected.
                          onSelected: (on) {
                            final current = settings.snoozeMinutes;
                            if (on && current.length < 3) {
                              repo.setSnoozeMinutes([...current, m]);
                            } else if (!on && current.length > 1) {
                              repo.setSnoozeMinutes([...current]..remove(m));
                            }
                          },
                        ),
                    ],
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(l10n.allDayReminderTime),
                  trailing: Text(
                    l10n.clockTime(
                      settings.allDayReminderMinutes,
                      settings.timeFormat,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () async {
                    final minutes = settings.allDayReminderMinutes;
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: minutes ~/ 60,
                        minute: minutes % 60,
                      ),
                    );
                    if (picked != null) {
                      await repo.setAllDayReminderMinutes(
                        picked.hour * 60 + picked.minute,
                      );
                    }
                  },
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(l10n.notifTestButton),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final sent = await ref
                          .read(reminderSchedulerProvider)
                          .sendTest();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            sent ? l10n.notifTestSent : l10n.notifTestDenied,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            ..._section(
              l10n.settingsLocation,
              color: b.cobalt,
              children: [
                // One list item, so the radius chips are built with it.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(l10n.placesTitle),
                      subtitle: Text(l10n.placesSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PlacesPage(),
                        ),
                      ),
                    ),
                    _Setting(
                      label: l10n.defaultLocationRadius,
                      child: Wrap(
                        spacing: Spacing.sm,
                        children: [
                          for (final m in const [30, 50, 100, 200])
                            ChoiceChip(
                              showCheckmark: false,
                              label: Text(l10n.meters(m)),
                              selected: settings.defaultLocationRadius == m,
                              onSelected: (_) =>
                                  repo.setDefaultLocationRadius(m),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (ref.watch(locationPlatformProvider).supported) ...[
                  // A gap before the rows about this iPhone.
                  const SizedBox(height: Spacing.xl),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.my_location),
                    title: Text(l10n.locPermissionStatus),
                    subtitle: Text(
                      locationPermissionLabel(
                        context,
                        ref.watch(locationPermissionProvider),
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: ref
                          .read(locationPlatformProvider)
                          .openSettings,
                      child: Text(l10n.openSettings),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bug_report_outlined),
                    title: Text(l10n.locDebugTitle),
                    subtitle: Text(l10n.locDebugSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LocationDebugPage(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (isDesktop) ...[
              ..._section(
                l10n.settingsBackground,
                color: b.card,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.keepRunning),
                    subtitle: Text(l10n.keepRunningHint),
                    value: settings.keepRunningInBackground,
                    onChanged: repo.setKeepRunningInBackground,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.startOnLogin),
                    value: settings.startOnLogin,
                    onChanged: repo.setStartOnLogin,
                  ),
                  if (Platform.isLinux)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Text(
                        l10n.linuxTrayHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            ..._section(
              l10n.settingsOrganize,
              color: b.lilac,
              children: [
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
          ],
        ),
      ),
    );
  }
}

/// A settings section's title row and its controls, as separate list items.
List<Widget> _section(
  String title, {
  required Color color,
  required List<Widget> children,
}) => [_SectionHeader(title, color: color), ...children];

/// A settings section title: a sticker on an ink rule.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final b = BrutalTheme.of(context);
    final light =
        color == b.cobalt && Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xxl, bottom: Spacing.md),
      child: Row(
        children: [
          Sticker(
            label: title.toUpperCase(),
            color: color == b.card ? null : color,
            foreground: light ? Colors.white : null,
            depth: 2,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Container(height: BrutalTheme.line, color: b.ink),
          ),
        ],
      ),
    );
  }
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
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Spacing.sm),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: child),
      ],
    ),
  );
}
