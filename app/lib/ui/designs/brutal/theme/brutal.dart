import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The neo-brutalist palette and line weights, read with [BrutalTheme.of].
///
/// Light mode is ink on paper; dark mode flips it to paper-coloured lines
/// on a dark ground. The five flat colours are the same family in both.
@immutable
class BrutalTheme extends ThemeExtension<BrutalTheme> {
  const BrutalTheme({
    required this.ink,
    required this.shadow,
    required this.paper,
    required this.card,
    required this.yellow,
    required this.cobalt,
    required this.tomato,
    required this.mint,
    required this.lilac,
    required this.onAccent,
    required this.hairline,
    Color? accentLine,
  }) : accentLine = accentLine ?? ink;

  /// Outlines and strong text.
  final Color ink;

  /// The hard offset shadow.
  final Color shadow;

  /// The page ground.
  final Color paper;

  /// Raised blocks: cards, inputs, buttons.
  final Color card;

  final Color yellow;
  final Color cobalt;
  final Color tomato;
  final Color mint;
  final Color lilac;

  /// Text and icons on the five accent colours (always dark).
  final Color onAccent;

  /// Quiet dividers between rows inside a block.
  final Color hairline;

  /// Outline of blocks filled with one of the five accent colours. Same as
  /// [ink] unless a dark palette wants dark lines around its colour blocks.
  final Color accentLine;

  /// Outline width of blocks, buttons and inputs.
  static const double line = 2;

  /// Shadow offset of big blocks (cards, dialogs).
  static const double depth = 4;

  /// Shadow offset of buttons and small controls.
  static const double depthSmall = 3;

  static const light = BrutalTheme(
    ink: Color(0xFF141414),
    shadow: Color(0xFF141414),
    paper: Color(0xFFF7F0E1),
    card: Color(0xFFFFFDF8),
    yellow: Color(0xFFFFD23F),
    cobalt: Color(0xFF3355FF),
    tomato: Color(0xFFFF6B4A),
    mint: Color(0xFF3DDC97),
    lilac: Color(0xFFC4B5FD),
    onAccent: Color(0xFF141414),
    hairline: Color(0xFFE3D9C6),
  );

  /// Dark mode, "warm charcoal": the light mode at night. Brown-grey ground, cream
  /// text and lines, near-black shadows, and the light mode's colour blocks
  /// outlined in dark ink.
  static const dark = BrutalTheme(
    ink: Color(0xFFF1E8D7),
    shadow: Color(0xFF0E0C0A),
    paper: Color(0xFF3B342E),
    card: Color(0xFF48403A),
    yellow: Color(0xFFFFD23F),
    cobalt: Color(0xFF6A84FF),
    tomato: Color(0xFFFF6B4A),
    mint: Color(0xFF3DDC97),
    lilac: Color(0xFFC4B5FD),
    onAccent: Color(0xFF17130F),
    hairline: Color(0xFF5C534A),
    accentLine: Color(0xFF17130F),
  );

  /// The outline for a block filled with [fill]: [accentLine] on the five
  /// accent colours, [ink] on anything else.
  Color lineFor(Color fill) =>
      fill == yellow ||
          fill == cobalt ||
          fill == tomato ||
          fill == mint ||
          fill == lilac
      ? accentLine
      : ink;

  static BrutalTheme of(BuildContext context) =>
      Theme.of(context).extension<BrutalTheme>() ?? light;

  /// A block border: [line] wide, with a hard shadow of [depth].
  BrutalBorder border({
    double depth = BrutalTheme.depth,
    double radius = 4,
    double shift = 0,
    double width = line,
    Color? color,
  }) => BrutalBorder(
    side: BorderSide(color: color ?? ink, width: width),
    radius: radius,
    depth: depth,
    shift: shift,
    shadowColor: shadow,
  );

  @override
  BrutalTheme copyWith({
    Color? ink,
    Color? shadow,
    Color? paper,
    Color? card,
    Color? yellow,
    Color? cobalt,
    Color? tomato,
    Color? mint,
    Color? lilac,
    Color? onAccent,
    Color? hairline,
    Color? accentLine,
  }) => BrutalTheme(
    ink: ink ?? this.ink,
    shadow: shadow ?? this.shadow,
    paper: paper ?? this.paper,
    card: card ?? this.card,
    yellow: yellow ?? this.yellow,
    cobalt: cobalt ?? this.cobalt,
    tomato: tomato ?? this.tomato,
    mint: mint ?? this.mint,
    lilac: lilac ?? this.lilac,
    onAccent: onAccent ?? this.onAccent,
    hairline: hairline ?? this.hairline,
    accentLine: accentLine ?? this.accentLine,
  );

  @override
  BrutalTheme lerp(BrutalTheme? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return BrutalTheme(
      ink: c(ink, other.ink),
      shadow: c(shadow, other.shadow),
      paper: c(paper, other.paper),
      card: c(card, other.card),
      yellow: c(yellow, other.yellow),
      cobalt: c(cobalt, other.cobalt),
      tomato: c(tomato, other.tomato),
      mint: c(mint, other.mint),
      lilac: c(lilac, other.lilac),
      onAccent: c(onAccent, other.onAccent),
      hairline: c(hairline, other.hairline),
      accentLine: c(accentLine, other.accentLine),
    );
  }
}

/// A barely rounded outline with a hard, unblurred offset shadow.
///
/// The shadow falls down and toward the end side: right in English, left in
/// Arabic. [shift] moves the face into its shadow (0 = resting, [depth] =
/// fully pressed), which gives buttons their tactile press. Because Material
/// animates shape changes, the press and hover moves animate for free.
///
/// The shadow is drawn outside the face only, so it works whether the border
/// is painted in front of or behind the content.
class BrutalBorder extends OutlinedBorder {
  const BrutalBorder({
    super.side = const BorderSide(width: BrutalTheme.line),
    this.radius = 4,
    this.depth = 0,
    this.shift = 0,
    this.shadowColor = const Color(0xFF141414),
  });

  final double radius;
  final double depth;
  final double shift;
  final Color shadowColor;

  double _dx(TextDirection? textDirection) =>
      textDirection == TextDirection.rtl ? -1 : 1;

  RRect _face(Rect rect, TextDirection? textDirection) =>
      RRect.fromRectAndRadius(
        rect.shift(Offset(_dx(textDirection) * shift, shift)),
        Radius.circular(radius),
      );

  @override
  OutlinedBorder copyWith({BorderSide? side}) => BrutalBorder(
    side: side ?? this.side,
    radius: radius,
    depth: depth,
    shift: shift,
    shadowColor: shadowColor,
  );

  @override
  ShapeBorder scale(double t) => BrutalBorder(
    side: side.scale(t),
    radius: radius * t,
    depth: depth * t,
    shift: shift * t,
    shadowColor: shadowColor,
  );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_face(rect, textDirection).deflate(side.strokeInset));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_face(rect, textDirection));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final face = _face(rect, textDirection);
    if (depth - shift > 0.1 && shadowColor.a > 0) {
      final dx = _dx(textDirection);
      final shadow = RRect.fromRectAndRadius(
        rect.shift(Offset(dx * depth, depth)),
        Radius.circular(radius),
      );
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRRect(shadow),
          Path()..addRRect(face),
        ),
        Paint()..color = shadowColor,
      );
    }
    if (side.style == BorderStyle.solid && side.width > 0) {
      canvas.drawRRect(face.inflate(side.strokeOffset / 2), side.toPaint());
    }
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is BrutalBorder) return _lerp(a, this, t);
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is BrutalBorder) return _lerp(this, b, t);
    return super.lerpTo(b, t);
  }

  static BrutalBorder _lerp(BrutalBorder a, BrutalBorder b, double t) =>
      BrutalBorder(
        side: BorderSide.lerp(a.side, b.side, t),
        radius: lerpDouble(a.radius, b.radius, t)!,
        depth: lerpDouble(a.depth, b.depth, t)!,
        shift: lerpDouble(a.shift, b.shift, t)!,
        shadowColor: Color.lerp(a.shadowColor, b.shadowColor, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is BrutalBorder &&
      other.side == side &&
      other.radius == radius &&
      other.depth == depth &&
      other.shift == shift &&
      other.shadowColor == shadowColor;

  @override
  int get hashCode => Object.hash(side, radius, depth, shift, shadowColor);
}
