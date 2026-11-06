import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A tappable rounded surface with a subtle hover highlight, border glow,
/// and gentle lift (~150 ms, disabled when the platform asks to reduce motion).
class HoverSurface extends StatefulWidget {
  const HoverSurface({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.borderRadius,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  State<HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<HoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = widget.borderRadius ?? BorderRadius.circular(Radii.md);

    final bg = widget.selected
        ? scheme.primaryContainer.withValues(alpha: 0.35)
        : _hovered
        ? scheme.surfaceContainerHigh.withValues(alpha: 0.6)
        : Colors.transparent;

    final border = widget.selected
        ? Border.all(color: scheme.primary.withValues(alpha: 0.4), width: 1)
        : _hovered
        ? Border.all(color: scheme.outlineVariant, width: 1)
        : Border.all(color: Colors.transparent, width: 1);

    final duration = Motion.of(context, Motion.fast);

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          0,
          _hovered && !widget.selected ? -1.0 : 0.0,
          0,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: border,
          boxShadow: _hovered && !widget.selected
              ? [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : widget.selected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            child: widget.padding == null
                ? widget.child
                : Padding(padding: widget.padding!, child: widget.child),
          ),
        ),
      ),
    );
  }
}
