import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A tappable rounded surface with a subtle hover highlight and lift
/// (~150 ms, disabled when the platform asks to reduce motion).
class HoverSurface extends StatefulWidget {
  const HoverSurface({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;

  @override
  State<HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<HoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(Radii.md);
    final color = widget.selected
        ? scheme.secondaryContainer
        : _hovered
        ? scheme.surfaceContainerHigh
        : scheme.surface.withValues(alpha: 0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          boxShadow: _hovered && !widget.selected
              ? [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 6,
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
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
