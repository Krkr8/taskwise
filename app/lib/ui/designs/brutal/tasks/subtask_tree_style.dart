import 'package:flutter/material.dart';

import '../../../shared/tasks/subtask_tree.dart';
import '../theme/brutal.dart';

/// How Brutal draws the subtasks under a task: a 2 px cobalt line (light
/// periwinkle in dark) through the parent's check box, a short branch to
/// each subtask, and each subtask in a small quiet box. A done subtask has
/// a mint check box and a muted strike.
///
/// [compact] is for narrow week columns: tighter, with a smaller check box.
SubtaskTreeStyle brutalSubtaskTreeStyle(
  BuildContext context, {
  bool compact = false,
}) {
  final b = BrutalTheme.of(context);
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  final text = (compact
      ? theme.textTheme.labelSmall
      : theme.textTheme.bodySmall)!;
  final boxSize = compact ? 13.0 : 15.0;
  return SubtaskTreeStyle(
    line: dark ? const Color(0xFF98ACFF) : b.cobalt,
    lineWidth: 2,
    // The parent's check box is a 48 px button: its centre is 24 px in.
    lineInset: compact ? 5 : 24,
    indent: compact ? 12 : 42,
    text: text,
    doneText: text.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      decoration: TextDecoration.lineThrough,
    ),
    checkbox: (context, subtask, onToggle) => Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: subtask.done ? b.mint : b.card,
        border: Border.all(color: b.ink, width: 1.5),
      ),
      child: subtask.done
          ? Icon(Icons.check, size: boxSize - 3, color: b.onAccent, weight: 700)
          : null,
    ),
    rowDecoration: (done) => BoxDecoration(
      color: done
          ? b.hairline.withValues(alpha: dark ? 0.12 : 0.35)
          : dark
          ? Color.alphaBlend(b.yellow.withValues(alpha: 0.04), b.card)
          : b.card,
      border: Border.all(color: b.hairline),
    ),
    rowPadding: compact
        ? const EdgeInsetsDirectional.fromSTEB(3, 2, 3, 2)
        : const EdgeInsetsDirectional.fromSTEB(6, 5, 6, 5),
    rowGap: compact ? 2 : 4,
    topGap: compact ? 2 : 0,
    bottomGap: compact ? 2 : 4,
  );
}
