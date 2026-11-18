import 'package:flutter/material.dart';

import '../../../shared/tasks/subtask_tree.dart';
import '../theme/tokens.dart';
import 'task_tile.dart';

/// How Lapis draws subtasks: a soft lapis line with square branches and
/// small check rings, hanging under the parent's check ring.
///
/// [lineInset] is the distance from the start edge to the line (the centre
/// of the parent's check ring); the branches end 18 px further in. [compact]
/// is the version for the narrow week columns.
SubtaskTreeStyle lapisSubtaskTreeStyle(
  BuildContext context, {
  double lineInset = 24,
  bool compact = false,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  final text =
      (compact ? theme.textTheme.labelSmall : theme.textTheme.bodyMedium)!
          .copyWith(color: scheme.onSurface, height: 1.25);
  final ring = compact ? 12.0 : 16.0;
  return SubtaskTreeStyle(
    line: dark ? Palette.lapisDeep : Palette.lapisSoft,
    lineWidth: 2,
    lineInset: lineInset,
    indent: lineInset + (compact ? 10 : 18),
    text: text,
    doneText: text.copyWith(
      color: scheme.onSurfaceVariant,
      decoration: TextDecoration.lineThrough,
    ),
    checkbox: (context, subtask, onToggle) => CheckRing(
      done: subtask.done,
      color: scheme.outline,
      fill: scheme.primary,
      onFill: scheme.onPrimary,
      size: ring,
    ),
    rowPadding: EdgeInsetsDirectional.fromSTEB(
      compact ? 3 : Spacing.xs,
      compact ? 3 : Spacing.sm,
      compact ? 3 : Spacing.xs,
      compact ? 3 : Spacing.sm,
    ),
    rowGap: 0,
    bottomGap: compact ? 2 : Spacing.xs,
  );
}
