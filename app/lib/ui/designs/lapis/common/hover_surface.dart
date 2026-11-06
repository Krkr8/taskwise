import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A tappable rounded surface with a subtle hover tint (~150 ms, none when
/// the platform asks to reduce motion). Selected: tinted, with a start bar.
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
        ? scheme.primaryContainer
        : _hovered
        ? scheme.primary.withValues(alpha: 0.05)
        : scheme.primary.withValues(alpha: 0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        curve: Curves.easeOut,
        decoration: BoxDecoration(color: color, borderRadius: radius),
        child: Stack(
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radius,
                onTap: widget.onTap,
                child: widget.child,
              ),
            ),
            // A lapis bar on the start edge marks the open task.
            PositionedDirectional(
              start: 0,
              top: Spacing.md,
              bottom: Spacing.md,
              child: AnimatedOpacity(
                opacity: widget.selected ? 1 : 0,
                duration: Motion.of(context, Motion.fast),
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
