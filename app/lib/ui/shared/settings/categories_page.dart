import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../state/providers.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';

/// Add, rename, recolour and delete categories.
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final repo = ref.read(categoryRepositoryProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];

    Future<void> add() async {
      final result = await _showCategoryDialog(
        context,
        title: l10n.addCategory,
      );
      if (result != null) await repo.createCategory(result.$1, result.$2);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categories)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: add,
        icon: const Icon(Icons.add),
        label: Text(l10n.addCategory),
      ),
      body: categories.isEmpty
          ? Center(child: Text(l10n.noCategoriesYet))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Spacing.sm,
                Spacing.sm,
                Spacing.sm,
                96,
              ),
              children: [
                for (final c in categories)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 10,
                      backgroundColor: Color(c.colorValue),
                    ),
                    title: Text(c.name),
                    onTap: () async {
                      final result = await _showCategoryDialog(
                        context,
                        title: l10n.editCategory,
                        initial: c,
                      );
                      if (result != null) {
                        await repo.updateCategory(
                          c.id,
                          name: result.$1,
                          colorValue: result.$2,
                        );
                      }
                    },
                    trailing: IconButton(
                      tooltip: l10n.delete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (await _confirmDelete(context, c)) {
                          await repo.deleteCategory(c.id);
                        }
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, Category category) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteCategoryTitle(category.name)),
      content: Text(l10n.deleteCategoryBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Returns (name, colour) or null if cancelled.
Future<(String, int)?> _showCategoryDialog(
  BuildContext context, {
  required String title,
  Category? initial,
}) => showDialog<(String, int)>(
  context: context,
  builder: (context) => _CategoryDialog(title: title, initial: initial),
);

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.title, this.initial});

  final String title;
  final Category? initial;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late int _color = widget.initial?.colorValue ?? categoryPalette.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name, _color));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.categoryName),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Spacing.lg),
          Text(l10n.color, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final (index, color) in categoryPalette.indexed)
                Semantics(
                  label: l10n.colorOption(index + 1),
                  selected: color == _color,
                  button: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = color),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(color),
                      child: color == _color
                          ? Icon(Icons.check, color: scheme.surface, size: 18)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
