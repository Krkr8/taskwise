import 'package:flutter/material.dart';

import '../../../shared/tasks/subtask_tree.dart';
import '../theme/tokens.dart';

/// Slate's subtask tree: a 2px indigo line from the parent's round check,
/// a branch to each subtask card and a 17px circular check on every one.
///
/// [compact] is for the narrow week columns of the calendar.
SubtaskTreeStyle slateSubtaskTreeStyle(
  BuildContext context, {
  bool compact = false,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final dark = scheme.brightness == Brightness.dark;
  final text = theme.textTheme.bodySmall!.copyWith(
    color: scheme.onSurface,
    fontSize: compact ? 11.5 : 13,
  );
  final size = compact ? 14.0 : 17.0;
  // Where the parent's round check sits: the tile's border and padding plus
  // half of the check's tap target.
  final target = theme.materialTapTargetSize == MaterialTapTargetSize.padded
      ? 48.0
      : 40.0;
  final lineInset = compact ? 6.0 : 1 + Spacing.sm + target / 2;
  return SubtaskTreeStyle(
    line: dark ? const Color(0xFF39446D) : const Color(0xFFC7D2FE),
    lineWidth: 2,
    lineInset: lineInset,
    indent: lineInset + (compact ? 10 : 18),
    text: text,
    doneText: text.copyWith(
      color: scheme.onSurfaceVariant,
      decoration: TextDecoration.lineThrough,
    ),
    checkbox: (context, subtask, onToggle) => InkResponse(
      onTap: onToggle,
      radius: size,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: subtask.done ? scheme.primary : scheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: subtask.done ? scheme.primary : scheme.outline,
            width: 1.6,
          ),
        ),
        child: subtask.done
            ? Icon(Icons.check_rounded, size: size - 6, color: scheme.onPrimary)
            : null,
      ),
    ),
    rowDecoration: (done) => BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(Radii.sm),
      border: Border.all(color: scheme.outlineVariant),
    ),
    rowPadding: EdgeInsetsDirectional.fromSTEB(
      compact ? 5 : 8,
      compact ? 3 : 5,
      compact ? 4 : 8,
      compact ? 3 : 5,
    ),
    rowGap: compact ? 3 : 4,
    topGap: 2,
    bottomGap: compact ? 4 : 6,
    branchRadius: 0,
  );
}
