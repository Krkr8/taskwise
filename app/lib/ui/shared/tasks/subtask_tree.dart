import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../state/providers.dart';
import 'labels.dart';

/// How a design draws [SubtaskTree]: the tree line, the subtask rows and
/// their check boxes. Each design builds one from its own theme.
@immutable
class SubtaskTreeStyle {
  const SubtaskTreeStyle({
    required this.line,
    this.lineWidth = 2,
    required this.lineInset,
    required this.indent,
    required this.text,
    required this.doneText,
    required this.checkbox,
    this.rowDecoration,
    this.rowPadding = const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 6),
    this.rowGap = 4,
    this.branchRadius = 0,
    this.topGap = 0,
    this.bottomGap = 8,
  });

  /// Colour and width of the tree line and its branches.
  final Color line;
  final double lineWidth;

  /// Distance from the start edge to the vertical line (usually the centre
  /// of the parent row's check box).
  final double lineInset;

  /// Distance from the start edge to where subtask rows begin; the branches
  /// run from the line to here.
  final double indent;

  final TextStyle text;
  final TextStyle doneText;

  /// The check box of one subtask; call [onToggle] to tick or untick it.
  final Widget Function(
    BuildContext context,
    Subtask subtask,
    VoidCallback onToggle,
  )
  checkbox;

  /// The box around one subtask row (null for none).
  final BoxDecoration Function(bool done)? rowDecoration;
  final EdgeInsetsGeometry rowPadding;

  /// Space between subtask rows.
  final double rowGap;

  /// Rounds the corner where a branch leaves the line (0 for a sharp one).
  final double branchRadius;

  /// Space above the first row and below the last.
  final double topGap;
  final double bottomGap;
}

/// A task's subtasks hanging under its row on a tree line: a vertical line
/// down the start side with a branch to each subtask. Each subtask can be
/// ticked in place. Mirrors itself in right-to-left languages.
class SubtaskTree extends ConsumerWidget {
  const SubtaskTree({super.key, required this.taskId, required this.style});

  final String taskId;
  final SubtaskTreeStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtasks = ref.watch(subtasksProvider(taskId)).value;
    if (subtasks == null || subtasks.isEmpty) return const SizedBox.shrink();
    final repo = ref.read(taskRepositoryProvider);
    return Padding(
      padding: EdgeInsets.only(top: style.topGap, bottom: style.bottomGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, s) in subtasks.indexed)
            _Branch(
              style: style,
              last: i == subtasks.length - 1,
              gap: i == 0 ? 0 : style.rowGap,
              child: _SubtaskRow(
                subtask: s,
                style: style,
                onToggle: () => repo.setSubtaskDone(s.id, done: !s.done),
              ),
            ),
        ],
      ),
    );
  }
}

/// One subtask with the piece of tree line to its start side.
class _Branch extends StatelessWidget {
  const _Branch({
    required this.style,
    required this.last,
    required this.gap,
    required this.child,
  });

  final SubtaskTreeStyle style;
  final bool last;
  final double gap;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TreePainter(
      style: style,
      last: last,
      gap: gap,
      rtl: Directionality.of(context) == TextDirection.rtl,
    ),
    child: Padding(
      padding: EdgeInsetsDirectional.only(start: style.indent, top: gap),
      child: child,
    ),
  );
}

class _TreePainter extends CustomPainter {
  _TreePainter({
    required this.style,
    required this.last,
    required this.gap,
    required this.rtl,
  });

  final SubtaskTreeStyle style;
  final bool last;
  final double gap;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = style.line
      ..strokeWidth = style.lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    double x(double fromStart) => rtl ? size.width - fromStart : fromStart;
    final lineX = x(style.lineInset);
    final branchY = gap + (size.height - gap) / 2;
    final endX = x(style.indent);
    final r = style.branchRadius.clamp(0, (endX - lineX).abs()).toDouble();
    final dir = rtl ? -1.0 : 1.0;
    final path = Path()..moveTo(lineX, 0);
    if (r == 0) {
      path
        ..lineTo(lineX, branchY)
        ..lineTo(endX, branchY);
    } else {
      path
        ..lineTo(lineX, branchY - r)
        ..quadraticBezierTo(lineX, branchY, lineX + dir * r, branchY)
        ..lineTo(endX, branchY);
    }
    if (!last) {
      path
        ..moveTo(lineX, branchY - r)
        ..lineTo(lineX, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TreePainter old) =>
      old.style != style ||
      old.last != last ||
      old.gap != gap ||
      old.rtl != rtl;
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    required this.subtask,
    required this.style,
    required this.onToggle,
  });

  final Subtask subtask;
  final SubtaskTreeStyle style;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final row = Padding(
      padding: style.rowPadding,
      child: Row(
        children: [
          style.checkbox(context, subtask, onToggle),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtask.title,
              style: subtask.done ? style.doneText : style.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      checked: subtask.done,
      label: subtask.done
          ? l10n.markNotDone(subtask.title)
          : l10n.markDone(subtask.title),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onToggle,
          child: switch (style.rowDecoration) {
            final decorate? => DecoratedBox(
              decoration: decorate(subtask.done),
              child: row,
            ),
            null => row,
          },
        ),
      ),
    );
  }
}
