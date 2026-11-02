import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../data/repositories/task_repository.dart';
import '../../state/providers.dart';
import '../theme/tokens.dart';
import 'device_targets_editor.dart';
import 'labels.dart';
import 'reminder_editor.dart';
import 'repeat_editor.dart';
import 'subtask_list.dart';
import 'task_actions.dart';

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
    final today = ref.watch(todayProvider);
    final timeFormat = ref.watch(appSettingsProvider).timeFormat;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final rule = RecurrenceRule.tryParse(task.recurrenceRule);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(Spacing.sm),
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
                  task.done ? Icons.check_circle : Icons.check_circle_outline,
                  color: task.done ? theme.colorScheme.primary : null,
                ),
              ),
              IconButton(
                tooltip: l10n.deleteTask,
                onPressed: () async {
                  // Starts the delete (capturing context) before closing.
                  final deleting = deleteTaskWithUndo(context, ref, task.id);
                  widget.onClose();
                  await deleting;
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              0,
              Spacing.lg,
              Spacing.xxl,
            ),
            children: [
              TextField(
                controller: _title,
                focusNode: _titleFocus,
                onChanged: (_) => _onTextChanged(),
                style: theme.textTheme.titleLarge,
                maxLines: null,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.titleLabel,
                  filled: false,
                  border: InputBorder.none,
                ),
              ),
              const Divider(height: Spacing.xl),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  task.dueDate == null
                      ? l10n.noDueDate
                      : l10n.relativeDate(task.dueDate!, today),
                ),
                subtitle: Text(l10n.dueDate),
                onTap: _pickDate,
                trailing: task.dueDate == null
                    ? null
                    : IconButton(
                        tooltip: l10n.clearDueDate,
                        icon: const Icon(Icons.close),
                        onPressed: () => _update(
                          (t) => t.copyWith(
                            dueDate: () => null,
                            dueTimeMinutes: () => null,
                            recurrenceRule: () => null,
                          ),
                        ),
                      ),
              ),
              if (task.dueDate != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(
                    task.dueTimeMinutes == null
                        ? l10n.allDay
                        : l10n.clockTime(task.dueTimeMinutes!, timeFormat),
                  ),
                  subtitle: Text(
                    task.dueTimeMinutes == null ? l10n.addTime : l10n.dueTime,
                  ),
                  onTap: _pickTime,
                  trailing: task.dueTimeMinutes == null
                      ? null
                      : IconButton(
                          tooltip: l10n.clearDueTime,
                          icon: const Icon(Icons.close),
                          onPressed: () => _update(
                            (t) => t.copyWith(dueTimeMinutes: () => null),
                          ),
                        ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.repeat),
                title: Text(
                  rule == null ? l10n.repeatNone : l10n.repeatSummary(rule),
                ),
                subtitle: Text(l10n.repeat),
                onTap: _pickRepeat,
                trailing: task.recurrenceRule == null
                    ? null
                    : IconButton(
                        tooltip: l10n.repeatNone,
                        icon: const Icon(Icons.close),
                        onPressed: () => _update(
                          (t) => t.copyWith(recurrenceRule: () => null),
                        ),
                      ),
              ),
              const SizedBox(height: Spacing.md),
              _Label(l10n.reminders),
              ReminderEditor(task: task),
              const SizedBox(height: Spacing.sm),
              DeviceTargetsEditor(task: task),
              const SizedBox(height: Spacing.lg),
              _Label(l10n.priority),
              // Chips size to their labels and wrap as whole chips, so longer
              // Arabic words never break across lines in the narrow panel.
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
                              Icons.flag,
                              color: priorityColor(p, theme.colorScheme),
                            ),
                      label: Text(l10n.priorityName(p)),
                      selected: task.priority == p,
                      onSelected: (_) =>
                          _update((t) => t.copyWith(priority: p)),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.lg),
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
                              CircleAvatar(
                                radius: 6,
                                backgroundColor: Color(c.colorValue),
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
              const SizedBox(height: Spacing.lg),
              _Label(l10n.tags),
              _TagEditor(taskId: task.id),
              const SizedBox(height: Spacing.lg),
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
              const SizedBox(height: Spacing.xl),
              _Label(l10n.subtasks),
              SubtaskList(taskId: task.id),
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Spacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
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
          avatar: const Icon(Icons.add, size: 18),
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
