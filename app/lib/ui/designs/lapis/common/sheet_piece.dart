import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One row of a rounded sheet that is split over several list items, so
/// long lists stay lazy: the [first] piece draws the top corners, the
/// [last] one the bottom corners, and every piece after the first starts
/// with a hairline.
class SheetPiece extends StatelessWidget {
  const SheetPiece({
    super.key,
    required this.first,
    required this.last,
    required this.child,
    this.horizontalPadding = Spacing.xs,
    this.endPadding = Spacing.xs,
    this.dividerIndent,
  });

  final bool first;
  final bool last;
  final Widget child;
  final double horizontalPadding;

  /// Room above the first row and below the last.
  final double endPadding;

  /// Where the hairline starts; null draws no hairline.
  final double? dividerIndent;

  @override
  Widget build(BuildContext context) {
    final lapis = LapisColors.of(context);
    final side = BorderSide(color: lapis.line);
    const corner = Radius.circular(Radii.lg);
    final radius = BorderRadius.vertical(
      top: first ? corner : Radius.zero,
      bottom: last ? corner : Radius.zero,
    );
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border(
          left: side,
          right: side,
          top: first ? side : BorderSide.none,
          bottom: last ? side : BorderSide.none,
        ),
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            first ? endPadding : 0,
            horizontalPadding,
            last ? endPadding : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!first && dividerIndent != null)
                Divider(
                  height: 1,
                  indent: dividerIndent,
                  endIndent: Spacing.md,
                  color: lapis.line,
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
