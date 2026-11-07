import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../data/app_settings.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../location/location_reminder_sync.dart';
import '../../../../notifications/reminder_scheduler.dart';
import '../../../../state/providers.dart';
import '../../../shared/location/location_permission.dart';
import '../location/location_picker_page.dart';
import '../../../shared/theme/tokens.dart';
import '../../../shared/tasks/labels.dart';

/// Relative presets offered by "Add reminder", in minutes before due.
const reminderPresets = [0, 5, 15, 30, 60, 24 * 60];

/// "15 minutes", "1 hour", "2 days".
String reminderDuration(AppLocalizations l10n, int minutes) =>
    minutes % (24 * 60) == 0
    ? l10n.durationDays(minutes ~/ (24 * 60))
    : minutes % 60 == 0
    ? l10n.durationHours(minutes ~/ 60)
    : l10n.durationMinutes(minutes);

/// "At due time", "15 minutes before", or "Oct 21, 9:00 AM".
String reminderLabel(
  AppLocalizations l10n,
  Reminder reminder,
  TimeFormat timeFormat,
) {
  if (reminder.minutesBeforeDue case final minutes?) {
    return minutes == 0
        ? l10n.reminderAtDueTime
        : l10n.reminderBefore(reminderDuration(l10n, minutes));
  }
  final at = reminder.absoluteAt!.toLocal();
  return '${DateFormat.MMMd(l10n.localeName).format(at)}, '
      '${l10n.clockTime(at.hour * 60 + at.minute, timeFormat)}';
}

/// The task's reminders as removable chips, plus an "Add reminder" menu.
class ReminderEditor extends ConsumerWidget {
  const ReminderEditor({super.key, required this.task});

  final Task task;

  Future<void> _added(WidgetRef ref) async {
    // Ask for notification permission the first time (iOS).
    if (ref.read(notificationPermissionProvider) == null) {
      await ref.read(reminderSchedulerProvider).requestPermission();
    }
  }

  Future<void> _addCustom(BuildContext context, WidgetRef ref) async {
    final today = ref.read(todayProvider);
    final start = task.dueDate ?? today;
    final date = await showDatePicker(
      context: context,
      initialDate: start.isBefore(today)
          ? today.atLocalTime()
          : start.atLocalTime(),
      firstDate: today.atLocalTime(),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final minutes = task.dueTimeMinutes ?? 9 * 60;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (time == null) return;
    await ref
        .read(reminderRepositoryProvider)
        .addAbsolute(
          task.id,
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
    await _added(ref);
  }

  /// Adds a location reminder, or changes [existing].
  Future<void> _pickLocation(
    BuildContext context,
    WidgetRef ref, {
    Reminder? existing,
  }) async {
    final picked = await pickReminderLocation(context, initial: existing);
    if (picked == null) return;
    var placeId = picked.placeId;
    if (picked.newPlaceName case final name?) {
      final place = await ref
          .read(placeRepositoryProvider)
          .createPlace(
            name: name,
            latitude: picked.latitude,
            longitude: picked.longitude,
            radiusMeters: picked.radiusMeters,
          );
      placeId = place.id;
    }
    final repo = ref.read(reminderRepositoryProvider);
    if (existing == null) {
      await repo.addLocation(
        task.id,
        placeId: placeId,
        latitude: picked.latitude,
        longitude: picked.longitude,
        label: picked.label,
        radiusMeters: picked.radiusMeters,
        trigger: picked.trigger,
      );
    } else {
      await repo.updateLocation(
        existing.id,
        placeId: placeId,
        latitude: picked.latitude,
        longitude: picked.longitude,
        label: picked.label,
        radiusMeters: picked.radiusMeters,
        trigger: picked.trigger,
      );
    }
    if (context.mounted) await ensureLocationPermission(context, ref);
    await _added(ref);
  }

  /// True when [r] is already in the past for this (one-off, open) task,
  /// so it won't fire: e.g. a time picked as AM instead of PM.
  bool _passed(Reminder r, int allDayMinutes, DateTime now) {
    if (task.done || task.recurrenceRule != null) return false;
    final fireAt = switch (r) {
      Reminder(absoluteAt: final at?) => at.toLocal(),
      Reminder(minutesBeforeDue: final m?) => switch (task.dueDate) {
        final date? =>
          date
              .atLocalTime(task.dueTimeMinutes ?? allDayMinutes)
              .subtract(Duration(minutes: m)),
        null => null,
      },
      _ => null,
    };
    return fireAt != null && fireAt.isBefore(now);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final timeFormat = ref.watch(appSettingsProvider).timeFormat;
    final reminders =
        ref.watch(taskRemindersProvider(task.id)).value ?? const <Reminder>[];
    final denied = ref.watch(notificationPermissionProvider) == false;
    final repo = ref.read(reminderRepositoryProvider);
    final hasDue = task.dueDate != null;
    final settings = ref.watch(appSettingsProvider);
    final now = ref.read(clockProvider)();
    final locations =
        ref.watch(taskLocationRemindersProvider(task.id)).value ??
        const <Reminder>[];
    final places = ref.watch(placesProvider).value ?? const <Place>[];
    final phone = ref.watch(locationPlatformProvider).supported;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final r in reminders)
              InputChip(
                avatar: Icon(
                  _passed(r, settings.allDayReminderMinutes, now)
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_outlined,
                  size: 18,
                ),
                label: Text(
                  _passed(r, settings.allDayReminderMinutes, now)
                      ? '${reminderLabel(l10n, r, timeFormat)} · '
                            '${l10n.reminderPassed}'
                      : reminderLabel(l10n, r, timeFormat),
                ),
                deleteButtonTooltipMessage: l10n.removeReminder,
                onDeleted: () => repo.delete(r.id),
              ),
            for (final r in locations)
              InputChip(
                avatar: Icon(
                  r.trigger == LocationTrigger.leave
                      ? Icons.logout
                      : Icons.place_outlined,
                  size: 18,
                ),
                label: Text(
                  locationReminderLabel(l10n, r, places),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                tooltip: phone ? null : l10n.locOnlyPhones,
                onPressed: () =>
                    unawaited(_pickLocation(context, ref, existing: r)),
                deleteButtonTooltipMessage: l10n.removeReminder,
                onDeleted: () => repo.delete(r.id),
              ),
            MenuAnchor(
              menuChildren: [
                for (final minutes in reminderPresets)
                  MenuItemButton(
                    onPressed: hasDue
                        ? () async {
                            await repo.addRelative(task.id, minutes);
                            await _added(ref);
                          }
                        : null,
                    child: Text(
                      minutes == 0
                          ? l10n.reminderAtDueTime
                          : l10n.reminderBefore(
                              reminderDuration(l10n, minutes),
                            ),
                    ),
                  ),
                const Divider(height: 1),
                MenuItemButton(
                  onPressed: () => unawaited(_addCustom(context, ref)),
                  child: Text(l10n.reminderCustom),
                ),
                const Divider(height: 1),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.place_outlined),
                  onPressed: () => unawaited(_pickLocation(context, ref)),
                  child: Text(l10n.reminderAtLocation),
                ),
              ],
              builder: (context, controller, _) => ActionChip(
                avatar: const Icon(Icons.add_alert_outlined, size: 18),
                label: Text(l10n.addReminder),
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
              ),
            ),
          ],
        ),
        if (locations.isNotEmpty && !phone)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xs),
            child: Text(
              l10n.locOnlyPhones,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (!hasDue)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xs),
            child: Text(
              l10n.reminderNeedsDueDate,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (denied)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xs),
            child: Text(
              l10n.notificationsDenied,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
