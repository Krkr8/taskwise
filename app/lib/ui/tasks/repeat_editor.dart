import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../theme/tokens.dart';
import 'labels.dart';

/// What the repeat picker returned: the new rule text, or null for
/// "does not repeat". The picker itself returns null when cancelled.
typedef RepeatChoice = ({String? rule});

/// Lets the user pick a repeat preset or build a custom rule.
///
/// [anchor] is the task's due date: presets repeat from it ("Weekly on
/// Tuesday", "Monthly on day 20"). A bottom sheet on phones, a dialog on
/// wider screens.
Future<RepeatChoice?> showRepeatPicker(
  BuildContext context, {
  required LocalDate anchor,
  required String? current,
  required WeekStart weekStart,
}) async {
  final l10n = context.l10n;
  final currentRule = RecurrenceRule.tryParse(current);
  final presets = repeatPresets(anchor);
  final presetIndex = currentRule == null
      ? -1
      : presets.indexWhere((p) => p.rule == currentRule.withStart(anchor));
  final isCustom = currentRule != null && presetIndex == -1;

  String presetLabel(RepeatPreset preset) => switch (preset.kind) {
    RepeatPresetKind.daily => l10n.repeatDaily,
    RepeatPresetKind.weekdays => l10n.repeatWeekdays,
    RepeatPresetKind.weekly => l10n.repeatWeeklyOn(
      l10n.weekdayName(anchor.weekday),
    ),
    RepeatPresetKind.monthlyDay => l10n.repeatMonthlyOnDay(anchor.day),
    RepeatPresetKind.monthlyNth => l10n.repeatMonthlyOnNth(
      l10n.ordinal(preset.rule.nthWeekday!.n),
      l10n.weekdayName(anchor.weekday),
    ),
    RepeatPresetKind.yearly => l10n.repeatYearlyOn(
      DateFormat.MMMd(l10n.localeName).format(anchor.atLocalTime()),
    ),
  };

  Widget option(
    BuildContext context,
    String label, {
    required bool isSelected,
    required Object? result,
    String? subtitle,
  }) => ListTile(
    title: Text(label),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: isSelected
        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
        : null,
    selected: isSelected,
    onTap: () => Navigator.of(context).pop(result),
  );

  const custom = Object();
  Widget list(BuildContext context) => ListView(
    shrinkWrap: true,
    children: [
      option(
        context,
        l10n.repeatNone,
        isSelected: current == null,
        result: const (rule: null),
      ),
      for (final (index, preset) in presets.indexed)
        option(
          context,
          presetLabel(preset),
          isSelected: presetIndex == index,
          result: (rule: preset.rule.toString()),
        ),
      option(
        context,
        l10n.repeatCustom,
        // A rule that isn't one of the presets is shown here.
        isSelected: isCustom,
        subtitle: isCustom ? l10n.repeatSummary(currentRule) : null,
        result: custom,
      ),
    ],
  );

  final compact = MediaQuery.sizeOf(context).width < Breakpoints.compact;
  final picked = compact
      ? await showModalBottomSheet<Object>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => SafeArea(child: list(context)),
        )
      : await showDialog<Object>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.repeat),
            contentPadding: const EdgeInsets.symmetric(vertical: Spacing.lg),
            content: SizedBox(width: 360, child: list(context)),
          ),
        );
  if (picked is RepeatChoice) return picked;
  if (!identical(picked, custom) || !context.mounted) return null;
  final rule = await showDialog<RecurrenceRule>(
    context: context,
    builder: (context) => CustomRepeatDialog(
      anchor: anchor,
      initial: currentRule?.withStart(anchor),
      weekStart: weekStart,
    ),
  );
  return rule == null ? null : (rule: rule.toString());
}

enum RepeatPresetKind {
  daily,
  weekdays,
  weekly,
  monthlyDay,
  monthlyNth,
  yearly,
}

typedef RepeatPreset = ({RepeatPresetKind kind, RecurrenceRule rule});

/// The quick choices offered for a task due on [anchor].
List<RepeatPreset> repeatPresets(LocalDate anchor) => [
  (
    kind: RepeatPresetKind.daily,
    rule: RecurrenceRule(frequency: Frequency.daily, start: anchor),
  ),
  (
    kind: RepeatPresetKind.weekdays,
    rule: RecurrenceRule(
      frequency: Frequency.weekly,
      weekdays: const {1, 2, 3, 4, 5},
      start: anchor,
    ),
  ),
  (
    kind: RepeatPresetKind.weekly,
    rule: RecurrenceRule(
      frequency: Frequency.weekly,
      weekdays: {anchor.weekday},
      start: anchor,
    ),
  ),
  (
    kind: RepeatPresetKind.monthlyDay,
    rule: RecurrenceRule(
      frequency: Frequency.monthly,
      monthDay: anchor.day,
      start: anchor,
    ),
  ),
  (
    kind: RepeatPresetKind.monthlyNth,
    rule: RecurrenceRule(
      frequency: Frequency.monthly,
      nthWeekday: nthWeekdayOf(anchor),
      start: anchor,
    ),
  ),
  (
    kind: RepeatPresetKind.yearly,
    rule: RecurrenceRule(frequency: Frequency.yearly, start: anchor),
  ),
];

/// Which "nth weekday" [date] is; a 5th one counts as the last.
NthWeekday nthWeekdayOf(LocalDate date) {
  final n = (date.day - 1) ~/ 7 + 1;
  return NthWeekday(n > 4 ? -1 : n, date.weekday);
}

enum _Ends { never, onDate, afterCount }

/// Builds a rule: every N units, weekdays or monthly mode, and an end.
class CustomRepeatDialog extends StatefulWidget {
  const CustomRepeatDialog({
    super.key,
    required this.anchor,
    required this.weekStart,
    this.initial,
  });

  final LocalDate anchor;
  final WeekStart weekStart;
  final RecurrenceRule? initial;

  @override
  State<CustomRepeatDialog> createState() => _CustomRepeatDialogState();
}

class _CustomRepeatDialogState extends State<CustomRepeatDialog> {
  late Frequency _frequency = widget.initial?.frequency ?? Frequency.weekly;
  late final _interval = TextEditingController(
    text: '${widget.initial?.interval ?? 1}',
  );
  late Set<int> _weekdays = {
    ...?widget.initial?.weekdays,
    if (widget.initial?.weekdays.isEmpty ?? true) widget.anchor.weekday,
  };
  late bool _byNth = widget.initial?.nthWeekday != null;
  late _Ends _ends = widget.initial?.until != null
      ? _Ends.onDate
      : widget.initial?.count != null
      ? _Ends.afterCount
      : _Ends.never;
  late LocalDate _until = widget.initial?.until ?? widget.anchor.addDays(30);
  late final _count = TextEditingController(
    text: '${widget.initial?.count ?? 10}',
  );

  @override
  void dispose() {
    _interval.dispose();
    _count.dispose();
    super.dispose();
  }

  int get _intervalValue => (int.tryParse(_interval.text) ?? 1).clamp(1, 999);

  RecurrenceRule _build() => RecurrenceRule(
    frequency: _frequency,
    start: widget.anchor,
    interval: _intervalValue,
    weekdays: _frequency == Frequency.weekly ? _weekdays : const {},
    monthDay: _frequency == Frequency.monthly && !_byNth
        ? widget.anchor.day
        : null,
    nthWeekday: _frequency == Frequency.monthly && _byNth
        ? nthWeekdayOf(widget.anchor)
        : null,
    until: _ends == _Ends.onDate ? _until : null,
    count: _ends == _Ends.afterCount
        ? (int.tryParse(_count.text) ?? 1).clamp(1, 999)
        : null,
  );

  Future<void> _pickUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _until.atLocalTime(),
      firstDate: widget.anchor.atLocalTime(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _until = LocalDate.fromDateTime(picked);
        _ends = _Ends.onDate;
      });
    }
  }

  String _unitName(Frequency f, int count) {
    final l10n = context.l10n;
    return switch (f) {
      Frequency.daily => l10n.unitDays(count),
      Frequency.weekly => l10n.unitWeeks(count),
      Frequency.monthly => l10n.unitMonths(count),
      Frequency.yearly => l10n.unitYears(count),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final nth = nthWeekdayOf(widget.anchor);
    final order = [
      for (var i = 0; i < 7; i++) (widget.weekStart.weekday - 1 + i) % 7 + 1,
    ];
    final numberField = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.sm,
      ),
    );

    return AlertDialog(
      title: Text(l10n.repeatCustomTitle),
      scrollable: true,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l10n.repeatEvery),
                const SizedBox(width: Spacing.sm),
                SizedBox(
                  width: 64,
                  child: TextField(
                    key: const Key('repeat-interval'),
                    controller: _interval,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: numberField,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                DropdownButton<Frequency>(
                  value: _frequency,
                  onChanged: (f) => setState(() => _frequency = f!),
                  items: [
                    for (final f in Frequency.values)
                      DropdownMenuItem(
                        value: f,
                        child: Text(_unitName(f, _intervalValue)),
                      ),
                  ],
                ),
              ],
            ),
            if (_frequency == Frequency.weekly) ...[
              const SizedBox(height: Spacing.lg),
              Text(l10n.repeatOn, style: theme.textTheme.labelLarge),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: [
                  for (final w in order)
                    FilterChip(
                      showCheckmark: false,
                      label: Text(l10n.weekdayName(w, short: true)),
                      selected: _weekdays.contains(w),
                      onSelected: (on) => setState(() {
                        // Keep at least one day selected.
                        if (on) {
                          _weekdays = {..._weekdays, w};
                        } else if (_weekdays.length > 1) {
                          _weekdays = {..._weekdays}..remove(w);
                        }
                      }),
                    ),
                ],
              ),
            ],
            if (_frequency == Frequency.monthly) ...[
              const SizedBox(height: Spacing.sm),
              RadioGroup<bool>(
                groupValue: _byNth,
                onChanged: (v) => setState(() => _byNth = v!),
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: false,
                      title: Text(l10n.monthlyByDay(widget.anchor.day)),
                    ),
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: true,
                      title: Text(
                        l10n.monthlyByNth(
                          l10n.ordinal(nth.n),
                          l10n.weekdayName(nth.weekday),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            Text(l10n.repeatEnds, style: theme.textTheme.labelLarge),
            RadioGroup<_Ends>(
              groupValue: _ends,
              onChanged: (v) => setState(() => _ends = v!),
              child: Column(
                children: [
                  RadioListTile<_Ends>(
                    contentPadding: EdgeInsets.zero,
                    value: _Ends.never,
                    title: Text(l10n.endsNever),
                  ),
                  RadioListTile<_Ends>(
                    contentPadding: EdgeInsets.zero,
                    value: _Ends.onDate,
                    title: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: _pickUntil,
                        child: Text(
                          l10n.endsOnDate(
                            DateFormat.yMMMd(l10n.localeName)
                                .format(_until.atLocalTime()),
                          ),
                        ),
                      ),
                    ),
                  ),
                  RadioListTile<_Ends>(
                    contentPadding: EdgeInsets.zero,
                    value: _Ends.afterCount,
                    title: Row(
                      children: [
                        Text(l10n.endsAfter),
                        const SizedBox(width: Spacing.sm),
                        SizedBox(
                          width: 64,
                          child: TextField(
                            controller: _count,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: numberField,
                            onTap: () =>
                                setState(() => _ends = _Ends.afterCount),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Text(l10n.endsTimes(int.tryParse(_count.text) ?? 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              l10n.repeatSummary(_build()),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_build()),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
