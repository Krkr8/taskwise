import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../theme/tokens.dart';
import 'labels.dart';

/// Reorderable checklist of a task's subtasks, with an "add" field.
class SubtaskList extends ConsumerStatefulWidget {
  const SubtaskList({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<SubtaskList> createState() => _SubtaskListState();
}

class _SubtaskListState extends ConsumerState<SubtaskList> {
  final _add = TextEditingController();
  final _addFocus = FocusNode();

  /// Order shown right after a drag, until the database catches up.
  List<Subtask>? _optimistic;

  @override
  void dispose() {
    _add.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _addSubtask(String title) async {
    if (title.trim().isEmpty) return;
    _add.clear();
    _addFocus.requestFocus();
    await ref.read(taskRepositoryProvider).addSubtask(widget.taskId, title);
  }

  void _reorder(List<Subtask> current, int from, int to) {
    // onReorderItem already adjusts [to] for the removed item.
    final list = [...current];
    list.insert(to, list.removeAt(from));
    setState(() => _optimistic = list);
    ref.read(taskRepositoryProvider).reorderSubtasks([
      for (final s in list) s.id,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final repo = ref.read(taskRepositoryProvider);
    ref.listen(subtasksProvider(widget.taskId), (_, _) {
      if (_optimistic != null) setState(() => _optimistic = null);
    });
    final subtasks =
        _optimistic ??
        ref.watch(subtasksProvider(widget.taskId)).value ??
        const <Subtask>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: subtasks.length,
          onReorderItem: (from, to) => _reorder(subtasks, from, to),
          itemBuilder: (context, index) {
            final s = subtasks[index];
            return Row(
              key: ValueKey(s.id),
              children: [
                Checkbox(
                  value: s.done,
                  semanticLabel: s.done
                      ? l10n.markNotDone(s.title)
                      : l10n.markDone(s.title),
                  onChanged: (v) => repo.setSubtaskDone(s.id, done: v ?? false),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.sm),
                    onTap: () async {
                      final title = await showTextInputDialog(
                        context,
                        title: l10n.renameSubtask,
                        label: l10n.titleLabel,
                        initialValue: s.title,
                      );
                      if (title != null) await repo.renameSubtask(s.id, title);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                      child: Text(
                        s.title,
                        style: s.done
                            ? TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.deleteSubtask,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => repo.deleteSubtask(s.id),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: l10n.reorderSubtask,
                    child: const Padding(
                      padding: EdgeInsets.all(Spacing.sm),
                      child: Icon(Icons.drag_indicator),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: Spacing.sm),
        TextField(
          controller: _add,
          focusNode: _addFocus,
          onSubmitted: _addSubtask,
          decoration: InputDecoration(
            hintText: l10n.addSubtaskHint,
            prefixIcon: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
