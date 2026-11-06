import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../state/providers.dart';
import '../../../shared/theme/tokens.dart';
import '../../../shared/tasks/labels.dart';

/// Search box, filter button and sort menu shown above the task list.
class TaskToolbar extends ConsumerStatefulWidget {
  const TaskToolbar({super.key});

  @override
  ConsumerState<TaskToolbar> createState() => _TaskToolbarState();
}

class _TaskToolbarState extends ConsumerState<TaskToolbar> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(taskFilterProvider).text,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filter = ref.watch(taskFilterProvider);
    final sort = ref.watch(taskSortProvider);
    final active = filter.activeFacetCount;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: ref.read(taskFilterProvider.notifier).setText,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: ListenableBuilder(
                listenable: _search,
                builder: (context, _) => _search.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .deleteButtonTooltip,
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          ref.read(taskFilterProvider.notifier).setText('');
                        },
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        IconButton(
          tooltip: active == 0 ? l10n.filter : l10n.filterWithCount(active),
          isSelected: active > 0,
          onPressed: () => showTaskFilterSheet(context),
          icon: Badge(
            isLabelVisible: active > 0,
            label: Text('$active'),
            child: const Icon(Icons.filter_list),
          ),
        ),
        PopupMenuButton<TaskSort>(
          tooltip: l10n.sortBy,
          icon: const Icon(Icons.sort),
          initialValue: sort,
          onSelected: ref.read(taskSortProvider.notifier).set,
          itemBuilder: (context) => [
            for (final option in TaskSort.values)
              CheckedPopupMenuItem(
                value: option,
                checked: option == sort,
                child: Text(l10n.sortName(option)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Opens the category / priority / tag filter sheet.
Future<void> showTaskFilterSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _FilterSheet(),
    );

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(taskFilterProvider);
    final notifier = ref.read(taskFilterProvider.notifier);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final tags = ref.watch(tagsProvider).value ?? const [];
    final scheme = Theme.of(context).colorScheme;

    Widget section(String title, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Spacing.sm),
          Wrap(spacing: Spacing.sm, runSpacing: Spacing.sm, children: chips),
        ],
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xl,
          0,
          Spacing.xl,
          Spacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            section(l10n.priority, [
              for (final p in Priority.values.reversed)
                if (p != Priority.none)
                  FilterChip(
                    avatar: Icon(Icons.flag, color: priorityColor(p, scheme)),
                    label: Text(l10n.priorityName(p)),
                    selected: filter.priorities.contains(p),
                    onSelected: (_) => notifier.togglePriority(p),
                  ),
              FilterChip(
                label: Text(l10n.priorityNone),
                selected: filter.priorities.contains(Priority.none),
                onSelected: (_) => notifier.togglePriority(Priority.none),
              ),
            ]),
            if (categories.isNotEmpty)
              section(l10n.category, [
                for (final c in categories)
                  FilterChip(
                    avatar: CircleAvatar(
                      radius: 6,
                      backgroundColor: Color(c.colorValue),
                    ),
                    label: Text(c.name),
                    selected: filter.categoryIds.contains(c.id),
                    onSelected: (_) => notifier.toggleCategory(c.id),
                  ),
              ]),
            if (tags.isNotEmpty)
              section(l10n.tags, [
                for (final t in tags)
                  FilterChip(
                    label: Text('#${t.name}'),
                    selected: filter.tagIds.contains(t.id),
                    onSelected: (_) => notifier.toggleTag(t.id),
                  ),
              ]),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: filter.activeFacetCount == 0
                    ? null
                    : notifier.clearFacets,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: Text(l10n.clearFilters),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
