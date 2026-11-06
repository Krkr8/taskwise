import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The Taskwise mark: a lapis tile with a check, and a saffron sun for
/// "today". Same drawing as the app icon.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: const BrandPainter()),
  );
}

class BrandPainter extends CustomPainter {
  const BrandPainter({this.tile = Palette.lapis, this.sun = Palette.saffron});

  final Color tile;
  final Color sun;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size.square(s);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(s * 0.28)),
      Paint()..color = tile,
    );
    canvas.drawCircle(
      Offset(s * 0.72, s * 0.29),
      s * 0.115,
      Paint()..color = sun,
    );
    final check = Path()
      ..moveTo(s * 0.25, s * 0.53)
      ..lineTo(s * 0.43, s * 0.70)
      ..lineTo(s * 0.62, s * 0.45);
    canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, s * 0.095)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(BrandPainter oldDelegate) =>
      oldDelegate.tile != tile || oldDelegate.sun != sun;
}
