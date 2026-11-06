import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Text that wraps between words, never inside one: if its longest word is
/// wider than the space, the text is shrunk a little (down to [minScale]),
/// and a word that still doesn't fit is cut short with "…". Used where
/// columns are narrow, like the phone's week view, where "electricity"
/// used to become "electric / ity".
class WholeWordsText extends StatelessWidget {
  const WholeWordsText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.minScale = 0.85,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final double minScale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final scaler = MediaQuery.textScalerOf(context);
        var shown = text;
        var used = scaler;
        if (box.maxWidth.isFinite) {
          (shown, used) = _fit(context, box.maxWidth, scaler);
        }
        return Text(
          shown,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textScaler: used,
        );
      },
    );
  }

  (String, TextScaler) _fit(
    BuildContext context,
    double width,
    TextScaler scaler,
  ) {
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      maxLines: 1,
    );
    final textStyle = DefaultTextStyle.of(context).style.merge(style);
    double measure(String s, TextScaler textScaler) {
      painter
        ..textScaler = textScaler
        ..text = TextSpan(text: s, style: textStyle)
        ..layout();
      return painter.width;
    }

    try {
      final parts = text.split(RegExp(r'(?=\s)|(?<=\s)'));
      var widest = 0.0;
      for (final part in parts) {
        if (part.trim().isNotEmpty) {
          widest = math.max(widest, measure(part, scaler));
        }
      }
      if (widest <= width) return (text, scaler);
      final scaled = _Scaled(scaler, math.max(minScale, width / widest));
      final out = StringBuffer();
      for (final part in parts) {
        if (part.trim().isEmpty || measure(part, scaled) <= width) {
          out.write(part);
          continue;
        }
        // Too long even when smaller: keep what fits, then "…".
        final chars = part.characters.toList();
        var keep = chars.length - 1;
        while (keep > 1 &&
            measure('${chars.take(keep).join()}…', scaled) > width) {
          keep--;
        }
        out.write('${chars.take(keep).join()}…');
      }
      return (out.toString(), scaled);
    } finally {
      painter.dispose();
    }
  }
}

/// [base], made [factor] times smaller.
final class _Scaled extends TextScaler {
  const _Scaled(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.scale(1) * factor;

  @override
  bool operator ==(Object other) =>
      other is _Scaled && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
