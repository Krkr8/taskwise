import 'package:flutter/material.dart';

import '../theme/brutal.dart';
import '../theme/tokens.dart';

/// A static block: flat fill, ink outline and a hard offset shadow.
///
/// The shadow is painted outside the box (down and toward the end side), so
/// leave [depth] of room after and below it.
class BrutalBox extends StatelessWidget {
  const BrutalBox({
    super.key,
    required this.child,
    this.color,
    this.depth = BrutalTheme.depth,
    this.radius = Radii.md,
    this.padding = EdgeInsets.zero,
    this.lineColor,
  });

  final Widget child;
  final Color? color;
  final double depth;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? lineColor;

  @override
  Widget build(BuildContext context) {
    final b = BrutalTheme.of(context);
    final fill = color ?? b.card;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: b.border(
          depth: depth,
          radius: radius,
          color: lineColor ?? b.lineFor(fill),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A raised, tappable block that sinks into its shadow on hover (halfway)
/// and press (all the way), with the content moving along with its face.
///
/// When [selected] it rests pressed in. When [flat] it shows no outline or
/// shadow until hovered, which keeps quiet controls quiet.
class BrutalPressable extends StatefulWidget {
  const BrutalPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.color,
    this.hoverColor,
    this.depth = BrutalTheme.depthSmall,
    this.radius = Radii.md,
    this.padding = EdgeInsets.zero,
    this.tooltip,
    this.semanticLabel,
    this.selected = false,
    this.flat = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Color? hoverColor;
  final double depth;
  final double radius;
  final EdgeInsetsGeometry padding;
  final String? tooltip;
  final String? semanticLabel;
  final bool selected;
  final bool flat;

  @override
  State<BrutalPressable> createState() => _BrutalPressableState();
}

class _BrutalPressableState extends State<BrutalPressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final b = BrutalTheme.of(context);
    final enabled = widget.onTap != null;
    final active = enabled && (_hovered || _focused);
    final showFrame = !widget.flat || active || widget.selected;
    final depth = showFrame ? widget.depth : 0.0;
    final shift = !enabled
        ? 0.0
        : _pressed
        ? depth
        : active
        ? depth / 2
        : 0.0;
    final color = active && widget.hoverColor != null
        ? widget.hoverColor!
        : widget.color ?? b.card;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    Widget box = TweenAnimationBuilder<double>(
      tween: Tween(end: shift),
      duration: Motion.of(context, Motion.fast),
      curve: Curves.easeOut,
      builder: (context, s, child) => DecoratedBox(
        decoration: ShapeDecoration(
          color: showFrame || widget.selected
              ? color
              : color.withValues(alpha: 0),
          shape: b.border(
            depth: depth,
            radius: widget.radius,
            shift: s,
            color: showFrame ? b.lineFor(color) : b.ink.withValues(alpha: 0),
          ),
        ),
        // The face moved by s; move the content with it.
        position: DecorationPosition.background,
        child: Transform.translate(
          offset: Offset(rtl ? -s : s, s),
          child: child,
        ),
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    box = FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: box,
      ),
    );

    box = Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel ?? widget.tooltip,
      child: box,
    );
    if (widget.tooltip != null) {
      box = Tooltip(message: widget.tooltip, child: box);
    }
    return box;
  }
}

/// A square icon button that stands up from the page.
class BrutalIconButton extends StatelessWidget {
  const BrutalIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.iconColor,
    this.size = 40,
    this.flat = false,
    this.selected = false,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? iconColor;
  final double size;
  final bool flat;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final b = BrutalTheme.of(context);
    return BrutalPressable(
      tooltip: tooltip,
      onTap: onPressed,
      color: color,
      hoverColor: flat ? b.yellow : null,
      flat: flat,
      selected: selected,
      child: SizedBox.square(
        dimension: size,
        child: IconTheme.merge(
          data: IconThemeData(
            size: 20,
            color:
                iconColor ??
                (onPressed == null ? b.ink.withValues(alpha: 0.35) : b.ink),
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }
}

/// A small flat label block, like a sticker: "TODAY 3".
class Sticker extends StatelessWidget {
  const Sticker({
    super.key,
    required this.label,
    this.color,
    this.foreground,
    this.leading,
    this.depth = 0,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final Color? foreground;
  final Widget? leading;
  final double depth;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final b = BrutalTheme.of(context);
    final fg = foreground ?? (color == null ? b.ink : b.onAccent);
    final style =
        (dense
                ? Theme.of(context).textTheme.labelSmall
                : Theme.of(context).textTheme.labelMedium)
            ?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              height: 1.1,
            );
    return BrutalBox(
      color: color ?? b.card,
      depth: depth,
      radius: Radii.sm,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 5 : Spacing.sm,
        vertical: dense ? 2 : 4,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: fg, size: dense ? 12 : 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 4)],
            Text(label, style: style),
          ],
        ),
      ),
    );
  }
}

/// A small square colour swatch with an ink outline (categories).
class Swatch extends StatelessWidget {
  const Swatch({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: BrutalTheme.of(context).ink, width: 1.5),
    ),
  );
}

/// The section title used across the app: a bold uppercase label.
class BrutalLabel extends StatelessWidget {
  const BrutalLabel(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding ?? const EdgeInsets.only(bottom: Spacing.sm),
    child: Text(
      // Arabic has no capitals; toUpperCase leaves it unchanged.
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: BrutalTheme.of(context).ink,
      ),
    ),
  );
}

/// Paints only a hard shadow behind [child], for widgets that draw their
/// own outline (text fields).
class ShadowBehind extends StatelessWidget {
  const ShadowBehind({
    super.key,
    required this.child,
    this.depth = BrutalTheme.depth,
    this.radius = Radii.md,
  });

  final Widget child;
  final double depth;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      shape: BrutalBorder(
        side: BorderSide.none,
        radius: radius,
        depth: depth,
        shadowColor: BrutalTheme.of(context).shadow,
      ),
    ),
    child: child,
  );
}

/// One slice of a card that is split across list items, so long lists stay
/// lazy: the first slice draws the top edge, the last the bottom edge and
/// the bottom shadow, and every slice its part of the sides and side shadow.
class CardSlice extends StatelessWidget {
  const CardSlice({
    super.key,
    required this.child,
    required this.first,
    required this.last,
    this.color,
    this.depth = BrutalTheme.depth,
  });

  final Widget child;
  final bool first;
  final bool last;
  final Color? color;
  final double depth;

  @override
  Widget build(BuildContext context) {
    final b = BrutalTheme.of(context);
    return CustomPaint(
      painter: _SlicePainter(
        first: first,
        last: last,
        fill: color ?? b.card,
        line: b.ink,
        shadow: b.shadow,
        depth: depth,
        rtl: Directionality.of(context) == TextDirection.rtl,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          BrutalTheme.line,
          first ? BrutalTheme.line : 0,
          BrutalTheme.line,
          last ? BrutalTheme.line : 0,
        ),
        child: child,
      ),
    );
  }
}

class _SlicePainter extends CustomPainter {
  _SlicePainter({
    required this.first,
    required this.last,
    required this.fill,
    required this.line,
    required this.shadow,
    required this.depth,
    required this.rtl,
  });

  final bool first;
  final bool last;
  final Color fill;
  final Color line;
  final Color shadow;
  final double depth;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    const big = 10000.0;
    final card = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        0,
        first ? 0 : -big,
        size.width,
        last ? size.height : size.height + big,
      ),
      const Radius.circular(Radii.md),
    );
    canvas
      ..save()
      ..clipRect(
        Rect.fromLTRB(
          -depth - 1,
          0,
          size.width + depth + 1,
          size.height + (last ? depth + 1 : 0),
        ),
      )
      ..drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRRect(card.shift(Offset(rtl ? -depth : depth, depth))),
          Path()..addRRect(card),
        ),
        Paint()..color = shadow,
      )
      ..drawRRect(card, Paint()..color = fill)
      ..drawRRect(
        card.deflate(BrutalTheme.line / 2),
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = BrutalTheme.line,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_SlicePainter old) =>
      old.first != first ||
      old.last != last ||
      old.fill != fill ||
      old.line != line ||
      old.shadow != shadow ||
      old.depth != depth ||
      old.rtl != rtl;
}

/// A keyboard key cap, for shortcut hints: "Ctrl", "N".
class KeyCap extends StatelessWidget {
  const KeyCap(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final b = BrutalTheme.of(context);
    return BrutalBox(
      depth: 2,
      radius: Radii.sm,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(fontWeight: FontWeight.w700, color: b.ink),
      ),
    );
  }
}
