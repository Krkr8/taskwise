import 'package:flutter/material.dart';

import '../../../shared/tasks/subtask_tree.dart';

/// The subtask tree in Classic's look: a teal-tinted line from the parent's
/// check button with a rounded branch to each subtask.
///
/// [lineInset] and [indent] default to a task row in the list (the line
/// under the centre of the 48 px check button). The calendar passes its own,
/// and [compact] shrinks text and spacing for the narrow week columns.
SubtaskTreeStyle classicSubtaskTreeStyle(
  BuildContext context, {
  double lineInset = 24,
  double indent = 44,
  bool compact = false,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  final line = Color.alphaBlend(
    scheme.primary.withValues(alpha: dark ? .32 : .18),
    scheme.outlineVariant,
  );
  final text = compact
      ? theme.textTheme.labelSmall!
      : theme.textTheme.bodySmall!;
  return SubtaskTreeStyle(
    line: line,
    lineWidth: 2,
    lineInset: lineInset,
    indent: indent,
    branchRadius: compact ? 4 : 7,
    rowPadding: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
    rowGap: compact ? 2 : 8,
    bottomGap: compact ? 2 : 8,
    text: text.copyWith(color: scheme.onSurface),
    doneText: text.copyWith(
      color: scheme.onSurfaceVariant,
      decoration: TextDecoration.lineThrough,
    ),
    checkbox: (context, subtask, onToggle) => Icon(
      subtask.done ? Icons.check_circle : Icons.radio_button_unchecked,
      size: compact ? 12 : 18,
      color: subtask.done ? scheme.primary : scheme.outline,
    ),
  );
}
