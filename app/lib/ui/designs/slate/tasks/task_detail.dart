import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../data/repositories/task_repository.dart';
import '../../../../state/providers.dart';
import '../theme/tokens.dart';
import '../../../shared/tasks/device_targets_editor.dart';
import '../../../shared/tasks/labels.dart';
import '../../classic/tasks/reminder_editor.dart';
import '../../../shared/tasks/repeat_editor.dart';
import '../../../shared/tasks/subtask_list.dart';
import '../../../shared/tasks/task_actions.dart';

/// Full-screen task details (phone / narrow windows).
class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: TaskDetailView(
        taskId: taskId,
        onClose: () => Navigator.of(context).maybePop(),
      ),
    ),
  );
}

/// Task details and editor, used in the side panel and the full-screen page.
class TaskDetailView extends ConsumerWidget {
  const TaskDetailView({
    super.key,
    required this.taskId,
    required this.onClose,
  });

  final String taskId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final task = ref.watch(taskProvider(taskId));
    return task.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l10n.loadError)),
      data: (task) => task == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.taskNotFound),
                  const SizedBox(height: Spacing.sm),
                  TextButton(onPressed: onClose, child: Text(l10n.close)),
                ],
              ),
            )
          : _TaskEditor(task: task, onClose: onClose),
    );
  }
}

class _TaskEditor extends ConsumerStatefulWidget {
  const _TaskEditor({required this.task, required this.onClose});

  final Task task;
  final VoidCallback onClose;

  @override
  ConsumerState<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<_TaskEditor> {
  static const _typingDelay = Duration(milliseconds: 400);

  late final TaskRepository _repo = ref.read(taskRepositoryProvider);
  late final _title = TextEditingController(text: widget.task.title);
  late final _notes = TextEditingController(text: widget.task.notes);
  final _titleFocus = FocusNode();
  Timer? _typing;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(() {
      // Never leave a blank title behind: restore the saved one on blur.
      if (!_titleFocus.hasFocus && _title.text.trim().isEmpty) {
        _title.text = widget.task.title;
      }
    });
  }

  @override
  void dispose() {
    if (_typing?.isActive ?? false) unawaited(_save(_latestWithText()));
    _typing?.cancel();
    _title.dispose();
    _notes.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  /// The latest saved task with the text fields' current contents applied.
  Task _latestWithText([Task? base]) {
    final task = base ?? widget.task;
    final title = _title.text.trim();
    return task.copyWith(
      title: title.isEmpty ? null : title,
      notes: _notes.text,
    );
  }

  void _onTextChanged() {
    _typing?.cancel();
    _typing = Timer(_typingDelay, () {
      final next = _latestWithText();
      if (next.title != widget.task.title || next.notes != widget.task.notes) {
        unawaited(_save(next));
      }
    });
  }

  /// Applies [change] to the latest task (plus pending text) and saves.
  Future<void> _update(Task Function(Task) change) {
    _typing?.cancel();
    return _save(change(_latestWithText()));
  }

  Future<void> _save(Task task) => _repo.saveTask(task);

  Future<void> _pickDate() async {
    final today = ref.read(todayProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: (widget.task.dueDate ?? today).atLocalTime(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final date = LocalDate.fromDateTime(picked);
    // A repeat follows the new date: "yearly" and "every 2 weeks" count
    // from it.
    await _update(
      (t) => t.copyWith(
        dueDate: () => date,
        recurrenceRule: () =>
            RecurrenceRule.tryParse(t.recurrenceRule)
                ?.withStart(date)
                .toString() ??
            t.recurrenceRule,
      ),
    );
  }

  Future<void> _pickRepeat() async {
    final LocalDate anchor = widget.task.dueDate ?? ref.read(todayProvider);
    final choice = await showRepeatPicker(
      context,
      anchor: anchor,
      current: widget.task.recurrenceRule,
      weekStart: ref.read(appSettingsProvider).weekStart,
    );
    if (choice == null) return;
    // A repeating task needs a date to repeat from.
    await _update(
      (t) => t.copyWith(
        recurrenceRule: () => choice.rule,
        dueDate: () => t.dueDate ?? anchor,
      ),
    );
  }

  Future<void> _pickTime() async {
    final minutes = widget.task.dueTimeMinutes ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    final hadTime = widget.task.dueTimeMinutes != null;
    await _update(
      (t) => t.copyWith(dueTimeMinutes: () => picked.hour * 60 + picked.minute),
    );
    // The first time a task gets a time, add the default reminder (if one
    // is set and the task has no reminders yet).
    final before = ref.read(appSettingsProvider).defaultReminder.minutesBefore;
    final reminders = ref.read(reminderRepositoryProvider);
    if (!hadTime &&
        before != null &&
        !await reminders.hasReminders(widget.task.id)) {
      await reminders.addRelative(widget.task.id, before);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final timeFormat = ref.watch(appSettingsProvider).timeFormat;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final rule = RecurrenceRule.tryParse(task.recurrenceRule);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.xs,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.close,
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
              const Spacer(),
              IconButton(
                tooltip: task.done ? l10n.markTaskNotDone : l10n.markTaskDone,
                onPressed: () =>
                    setTaskDone(context, ref, task, done: !task.done),
                icon: Icon(
                  task.done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: task.done ? scheme.primary : scheme.outline,
                ),
              ),
              IconButton(
                tooltip: l10n.deleteTask,
                onPressed: () async {
                  final deleting = deleteTaskWithUndo(context, ref, task.id);
                  widget.onClose();
                  await deleting;
                },
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              Spacing.xxl,
            ),
            children: [
              TextField(
                controller: _title,
                focusNode: _titleFocus,
                onChanged: (_) => _onTextChanged(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: task.done ? scheme.onSurfaceVariant : scheme.onSurface,
                  decoration: task.done ? TextDecoration.lineThrough : null,
                ),
                maxLines: null,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.titleLabel,
                  hintText: l10n.newTaskHint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: Spacing.md),

              // Schedule Section Card
              _DetailCard(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.event_outlined,
                      color: task.dueDate != null
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    title: Text(
                      task.dueDate == null
                          ? l10n.noDueDate
                          : l10n.relativeDate(task.dueDate!, today),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: task.dueDate != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(l10n.dueDate),
                    onTap: _pickDate,
                    trailing: task.dueDate == null
                        ? null
                        : IconButton(
                            tooltip: l10n.clearDueDate,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => _update(
                              (t) => t.copyWith(
                                dueDate: () => null,
                                dueTimeMinutes: () => null,
                                recurrenceRule: () => null,
                              ),
                            ),
                          ),
                  ),
                  if (task.dueDate != null) ...[
                    const Divider(height: Spacing.sm),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.schedule_rounded,
                        color: task.dueTimeMinutes != null
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      title: Text(
                        task.dueTimeMinutes == null
                            ? l10n.allDay
                            : l10n.clockTime(task.dueTimeMinutes!, timeFormat),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: task.dueTimeMinutes != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      subtitle: Text(
                        task.dueTimeMinutes == null
                            ? l10n.addTime
                            : l10n.dueTime,
                      ),
                      onTap: _pickTime,
                      trailing: task.dueTimeMinutes == null
                          ? null
                          : IconButton(
                              tooltip: l10n.clearDueTime,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => _update(
                                (t) => t.copyWith(dueTimeMinutes: () => null),
                              ),
                            ),
                    ),
                  ],
                  const Divider(height: Spacing.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.repeat_rounded,
                      color: rule != null
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    title: Text(
                      rule == null ? l10n.repeatNone : l10n.repeatSummary(rule),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: rule != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(l10n.repeat),
                    onTap: _pickRepeat,
                    trailing: task.recurrenceRule == null
                        ? null
                        : IconButton(
                            tooltip: l10n.repeatNone,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => _update(
                              (t) => t.copyWith(recurrenceRule: () => null),
                            ),
                          ),
                  ),
                  const Divider(height: Spacing.lg),
                  _Label(l10n.reminders),
                  ReminderEditor(task: task),
                  const SizedBox(height: Spacing.sm),
                  DeviceTargetsEditor(task: task),
                ],
              ),

              const SizedBox(height: Spacing.md),

              // Priority & Organization Card
              _DetailCard(
                children: [
                  _Label(l10n.priority),
                  Wrap(
                    spacing: Spacing.sm,
                    runSpacing: Spacing.sm,
                    children: [
                      for (final p in Priority.values)
                        ChoiceChip(
                          showCheckmark: false,
                          avatar: p == Priority.none
                              ? null
                              : Icon(
                                  Icons.flag_rounded,
                                  size: 16,
                                  color: priorityColor(p, theme.colorScheme),
                                ),
                          label: Text(l10n.priorityName(p)),
                          selected: task.priority == p,
                          onSelected: (_) =>
                              _update((t) => t.copyWith(priority: p)),
                        ),
                    ],
                  ),
                  const Divider(height: Spacing.xl),
                  _Label(l10n.category),
                  InputDecorator(
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsetsDirectional.symmetric(
                        horizontal: Spacing.md,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: categories.any((c) => c.id == task.categoryId)
                            ? task.categoryId
                            : null,
                        onChanged: (id) =>
                            _update((t) => t.copyWith(categoryId: () => id)),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(l10n.noCategory),
                          ),
                          for (final c in categories)
                            DropdownMenuItem(
                              value: c.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Color(c.colorValue),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.sm),
                                  Flexible(child: Text(c.name)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: Spacing.xl),
                  _Label(l10n.tags),
                  _TagEditor(taskId: task.id),
                ],
              ),

              const SizedBox(height: Spacing.md),

              // Subtasks Card
              _DetailCard(
                children: [
                  _Label(l10n.subtasks),
                  SubtaskList(taskId: task.id),
                ],
              ),

              const SizedBox(height: Spacing.md),

              // Notes Card
              _DetailCard(
                children: [
                  TextField(
                    controller: _notes,
                    onChanged: (_) => _onTextChanged(),
                    minLines: 3,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      labelText: l10n.notesLabel,
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Spacing.sm),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.1),
    ),
  );
}

/// Chips for a task's tags, plus a way to add existing or new tags.
class _TagEditor extends ConsumerWidget {
  const _TagEditor({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final repo = ref.read(taskRepositoryProvider);
    final allTags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final tagIds = ref.watch(taskTagIdsProvider(taskId)).value ?? const {};
    final onTask = [
      for (final t in allTags)
        if (tagIds.contains(t.id)) t,
    ];

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final tag in onTask)
          InputChip(
            label: Text('#${tag.name}'),
            deleteButtonTooltipMessage: l10n.removeTag(tag.name),
            onDeleted: () =>
                repo.setTaskTags(taskId, {...tagIds}..remove(tag.id)),
          ),
        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 16),
          label: Text(l10n.addTag),
          onPressed: () async {
            final available = [
              for (final t in allTags)
                if (!tagIds.contains(t.id)) t,
            ];
            final name = await _showAddTagDialog(context, available);
            if (name == null) return;
            final tag = await repo.findOrCreateTag(name);
            await repo.setTaskTags(taskId, {...tagIds, tag.id});
          },
        ),
      ],
    );
  }
}

/// Lets the user type a new tag name or tap an existing tag.
Future<String?> _showAddTagDialog(BuildContext context, List<Tag> existing) {
  final controller = TextEditingController();
  final l10n = context.l10n;
  return showDialog<String>(
    context: context,
    builder: (context) {
      void submit(String value) {
        final trimmed = value.trim();
        Navigator.of(context).pop(trimmed.isEmpty ? null : trimmed);
      }

      return AlertDialog(
        title: Text(l10n.addTag),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.tagName),
              onSubmitted: submit,
            ),
            if (existing.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: [
                  for (final tag in existing)
                    ActionChip(
                      label: Text('#${tag.name}'),
                      onPressed: () => submit(tag.name),
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => submit(controller.text),
            child: Text(l10n.add),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}
