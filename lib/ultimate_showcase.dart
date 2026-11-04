import 'dart:math' as math;
import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'game.dart';
import 'game_session.dart';
import 'storybook_ui.dart';
import 'ultimate_spell.dart';

/// Flame cinematic with projected 3D rings, depth-sorted particles and a crisp
/// transparent character. The backdrop uses the physical viewport, including
/// the space outside the fitted game frame on tablets and tall phones.
class UltimateShowcase extends Component {
  UltimateShowcase(this.session, {required this.viewport, this.reduceMotion})
    : super(priority: 2100);
  final GameSession session;
  final Rect Function() viewport;
  final bool Function()? reduceMotion;
  final _text = <String, TextPainter>{};
  final _particles = List.generate(120, (i) => i)
    ..sort((a, b) => ((b * 61) % 500).compareTo((a * 61) % 500));
  static const center = Offset(240, 430);

  Offset project(double x, double y, double z, [Offset origin = center]) {
    final depth = 600 / (600 + z.clamp(-390, 900));
    return origin + Offset(x * depth, y * depth);
  }

  void glow(
    Canvas canvas,
    Offset position,
    double radius,
    Color color,
    double alpha,
  ) {
    if (radius <= 0 || alpha <= 0) return;
    canvas.drawCircle(
      position,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha.clamp(0, 1)),
            color.withValues(alpha: alpha.clamp(0, 1) * .25),
            Colors.transparent,
          ],
          stops: const [0, .4, 1],
        ).createShader(Rect.fromCircle(center: position, radius: radius)),
    );
  }

  void label(
    Canvas canvas,
    String value,
    double y,
    double size,
    Color color,
    double fade,
  ) {
    final key = '$value/$size/${color.toARGB32()}';
    final painter = _text.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'ForestUI',
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: color,
            shadows: const [
              Shadow(
                color: Color(0xff11242c),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
      )..layout(maxWidth: 448),
    );
    canvas.saveLayer(
      Rect.fromLTWH(8, y - 6, 464, painter.height + 20),
      Paint()..color = Colors.white.withValues(alpha: fade),
    );
    painter.paint(canvas, Offset((480 - painter.width) / 2, y));
    canvas.restore();
  }

  @override
  void render(Canvas canvas) {
    final cast = session.ultimate;
    if (cast == null) return;
    final t = cast.age, spell = cast.spell, kind = cast.kind;
    final reduced = reduceMotion?.call() ?? false;
    final fade = math.min(
      (t / .18).clamp(0.0, 1.0),
      ((UltimateCast.duration - t) / .4).clamp(0.0, 1.0),
    );
    final charge = (t / UltimateCast.impactTime).clamp(0.0, 1.0);
    final burst = math.max(0.0, t - UltimateCast.impactTime);
    final backdrop = viewport();
    canvas.save();
    canvas.clipRect(backdrop);
    canvas.drawRect(
      backdrop,
      Paint()..color = const Color(0xff071a29).withValues(alpha: .96 * fade),
    );
    glow(canvas, center, backdrop.longestSide * .8, spell.color, .45 * fade);
    // Slow rays extend into landscape/tablet margins as well as the safe frame.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(reduced ? .1 : t * .13);
    final rayPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              spell.color.withValues(alpha: .22 * fade),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: backdrop.longestSide),
          );
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      final ray = Path()
        ..moveTo(0, 0)
        ..lineTo(
          math.cos(angle - .025) * backdrop.longestSide,
          math.sin(angle - .025) * backdrop.longestSide,
        )
        ..lineTo(
          math.cos(angle + .025) * backdrop.longestSide,
          math.sin(angle + .025) * backdrop.longestSide,
        )
        ..close();
      canvas.drawPath(ray, rayPaint);
    }
    canvas.restore();
    canvas.save();
    if (!reduced && burst > 0 && burst < .45) {
      canvas.translate(
        math.sin(burst * 49) * 6 * (1 - burst / .45),
        math.cos(burst * 37) * 3 * (1 - burst / .45),
      );
    }
    _floor(canvas, spell, t, charge, fade, reduced);
    // The cone connects the summoning circle to the floating caster.
    final cone = Path()
      ..moveTo(95, 610)
      ..lineTo(212, 312)
      ..lineTo(268, 312)
      ..lineTo(385, 610)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            spell.color.withValues(alpha: .02 * fade),
            spell.color.withValues(alpha: .19 * fade),
          ],
        ).createShader(const Rect.fromLTWH(95, 312, 290, 298)),
    );
    _orbit(canvas, spell, t, charge, fade, false, reduced);
    final portrait = StoryArt.instance.images['friend${cast.friend}'];
    final casterFade = fade * (1 - (burst / .85).clamp(0.0, .82));
    if (portrait != null && casterFade > 0) {
      final reveal = Curves.easeOutBack.transform((t / .7).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(
        240,
        444 - 33 * charge - (reduced ? 0 : math.sin(t * 2) * 5),
      );
      final scale = .5 + reveal * .58;
      final matrix = Matrix4.identity()
        ..setEntry(3, 2, .0018)
        ..rotateY(reduced ? 0 : math.sin(t * 2) * .19)
        ..rotateX(-.07)
        ..scaleByDouble(scale, scale, 1, 1);
      canvas.transform(matrix.storage);
      glow(canvas, Offset.zero, 150, spell.color, .55 * casterFade);
      paintImage(
        canvas: canvas,
        rect: const Rect.fromLTWH(-105, -105, 210, 210),
        image: portrait,
        fit: BoxFit.contain,
        opacity: casterFade,
        filterQuality: FilterQuality.medium,
      );
      canvas.restore();
    }
    _orbit(canvas, spell, t, charge, fade, true, reduced);
    _element(canvas, kind, spell, t, charge, burst, fade, reduced);
    if (burst > 0) {
      // A pair of broad spherical shock fronts, then particles fly past camera.
      for (var ring = 0; ring < 3; ring++) {
        final phase = (burst - ring * .12).clamp(0.0, 2.0);
        if (phase <= 0) continue;
        final radius = 35 + phase * 420;
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = spell.color.withValues(
              alpha: fade * math.max(0.0, .7 - phase * .4),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, 18 - phase * 12),
        );
      }
      _burst(canvas, spell, kind, burst, fade, reduced);
    }
    canvas.restore();
    // One soft impact pulse; no repeating full-screen strobe.
    final pulse = (1 - burst / .22).clamp(0.0, 1.0);
    if (t >= UltimateCast.impactTime && !reduced) {
      canvas.drawRect(
        backdrop,
        Paint()..color = spell.highlight.withValues(alpha: pulse * .24 * fade),
      );
    }
    label(
      canvas,
      '${BattleLayout.laneName(cast.lane)} · ${friends[cast.friend].name}',
      156,
      17,
      spell.highlight,
      fade,
    );
    label(canvas, spell.name, 188, 39, Colors.white, fade);
    label(canvas, spell.effect, 711, 15, spell.highlight, fade);
    label(
      canvas,
      t < UltimateCast.impactTime ? '魔力匯聚中' : '大招已釋放 · 本場限用一次',
      747,
      12,
      const Color(0xffd4e0e9),
      fade,
    );
    canvas.restore();
  }

  void _floor(
    Canvas canvas,
    UltimateSpell spell,
    double t,
    double charge,
    double fade,
    bool reduced,
  ) {
    const origin = Offset(240, 607);
    glow(canvas, origin, 225, spell.color, .3 * fade);
    for (var ring = 0; ring < 4; ring++) {
      final radius = 95.0 + ring * 29;
      final path = Path();
      for (var segment = 0; segment <= 96; segment++) {
        final angle =
            segment / 96 * math.pi * 2 +
            (reduced ? .2 : t * (ring.isEven ? .3 : -.2));
        final point = project(
          math.cos(angle) * radius,
          math.sin(angle) * radius * .22,
          math.sin(angle) * radius * .9,
          origin,
        );
        if (segment == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = spell.color.withValues(alpha: fade * (.42 + charge * .28))
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring == 3 ? 3 : 1.2,
      );
    }
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 + (reduced ? 0 : t * .15);
      final p = project(
        math.cos(angle) * 179,
        math.sin(angle) * 179 * .22,
        math.sin(angle) * 179 * .9,
        origin,
      );
      canvas.drawCircle(
        p,
        2.4,
        Paint()..color = spell.highlight.withValues(alpha: fade),
      );
    }
    final star = Path();
    for (var i = 0; i <= 6; i++) {
      final angle = i * math.pi * 2 / 3 + .2;
      final p = project(
        math.cos(angle) * 155,
        math.sin(angle) * 155 * .22,
        math.sin(angle) * 155 * .9,
        origin,
      );
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      star,
      Paint()
        ..color = spell.highlight.withValues(alpha: .55 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _orbit(
    Canvas canvas,
    UltimateSpell spell,
    double t,
    double charge,
    double fade,
    bool front,
    bool reduced,
  ) {
    for (var i = 0; i < 44; i++) {
      final angle = i * math.pi * 2 / 44 + (reduced ? .4 : t * 1.1);
      final z = math.sin(angle) * 150;
      if ((z < 0) != front) continue;
      final point = project(
        math.cos(angle) * (125 + charge * 35),
        math.sin(angle) * 55,
        z,
      );
      final radius = 2 + (150 - z) / 90;
      canvas.drawCircle(
        point,
        radius,
        Paint()..color = spell.highlight.withValues(alpha: fade * .8),
      );
      if (i % 4 == 0) glow(canvas, point, radius * 4, spell.color, .45 * fade);
    }
  }

  void _element(
    Canvas canvas,
    UltimateKind kind,
    UltimateSpell spell,
    double t,
    double charge,
    double burst,
    double fade,
    bool reduced,
  ) {
    final power = fade * math.min(1.0, charge * 1.3);
    switch (kind) {
      case UltimateKind.nature:
        for (var ribbon = 0; ribbon < 6; ribbon++) {
          final path = Path();
          for (var step = 0; step <= 45; step++) {
            final height = step / 45;
            final angle =
                height * math.pi * 3 +
                ribbon * math.pi / 3 +
                (reduced ? 0 : t * 1.5);
            final r = (1 - height) * 195 + burst * 75;
            final p = project(
              math.cos(angle) * r,
              175 - height * 375,
              math.sin(angle) * r,
            );
            if (step == 0) {
              path.moveTo(p.dx, p.dy);
            } else {
              path.lineTo(p.dx, p.dy);
            }
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = spell.color.withValues(alpha: power * .5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4 - ribbon % 3,
          );
        }
      case UltimateKind.water:
        for (var i = 0; i < 9; i++) {
          final angle = i * math.pi * 2 / 9 + (reduced ? .5 : t * .7);
          final p = project(
            math.cos(angle) * (120 + burst * 110),
            math.sin(angle) * (150 + burst * 120),
            math.sin(angle + 1) * 130,
          );
          final r = 15.0 + i % 3 * 9;
          canvas.drawCircle(
            p,
            r,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-.4, -.5),
                colors: [
                  spell.highlight.withValues(alpha: .7 * power),
                  spell.color.withValues(alpha: .23 * power),
                  spell.color.withValues(alpha: .6 * power),
                ],
              ).createShader(Rect.fromCircle(center: p, radius: r)),
          );
          canvas.drawCircle(
            p,
            r,
            Paint()
              ..color = spell.highlight.withValues(alpha: power * .7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
        }
      case UltimateKind.fire:
        for (var i = 0; i < 4; i++) {
          final progress = ((t - .45 - i * .09) / .85).clamp(0.0, 1.0);
          final p = Offset.lerp(
            Offset(80 + i * 105.0, -40 - i * 60.0),
            center + Offset((i - 1.5) * 60, i.isEven ? 60 : -40),
            progress,
          )!;
          final r = 15 + progress * 22;
          canvas.drawLine(
            p - const Offset(85, 150),
            p,
            Paint()
              ..shader = LinearGradient(
                colors: [
                  Colors.transparent,
                  spell.color.withValues(alpha: power),
                ],
              ).createShader(Rect.fromPoints(p - const Offset(85, 150), p))
              ..strokeWidth = r * .8
              ..strokeCap = StrokeCap.round,
          );
          glow(canvas, p, r * 2.6, spell.color, power * .8);
          canvas.drawCircle(
            p,
            r * .6,
            Paint()..color = spell.highlight.withValues(alpha: power),
          );
        }
      case UltimateKind.earth:
        final shield = Path()
          ..moveTo(240, 282)
          ..lineTo(340, 327)
          ..lineTo(325, 463)
          ..quadraticBezierTo(300, 526, 240, 555)
          ..quadraticBezierTo(180, 526, 155, 463)
          ..lineTo(140, 327)
          ..close();
        canvas.drawPath(
          shield.shift(const Offset(7, 11)),
          Paint()
            ..color = const Color(0xff745239).withValues(alpha: power * .8),
        );
        canvas.drawPath(
          shield,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                spell.highlight.withValues(alpha: power * .65),
                spell.color.withValues(alpha: power * .12),
                spell.highlight.withValues(alpha: power * .45),
              ],
            ).createShader(const Rect.fromLTWH(140, 282, 200, 273)),
        );
        canvas.drawPath(
          shield,
          Paint()
            ..color = spell.highlight.withValues(alpha: power)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5,
        );
        canvas.drawLine(
          const Offset(240, 321),
          const Offset(240, 506),
          Paint()
            ..color = spell.highlight.withValues(alpha: power * .7)
            ..strokeWidth = 3,
        );
      case UltimateKind.lightning:
        for (var bolt = 0; bolt < 6; bolt++) {
          final start = Offset(30 + bolt * 84.0, 260 - bolt % 2 * 70);
          final path = Path()..moveTo(start.dx, start.dy);
          for (var step = 1; step <= 8; step++) {
            final p = Offset.lerp(
              start,
              center + Offset((bolt - 2.5) * 35, 115),
              step / 8,
            )!;
            path.lineTo(p.dx + (step.isEven ? -18 : 18), p.dy);
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = spell.color.withValues(alpha: power * .35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 10
              ..strokeJoin = StrokeJoin.round,
          );
          canvas.drawPath(
            path,
            Paint()
              ..color = spell.highlight.withValues(alpha: power)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..strokeJoin = StrokeJoin.round,
          );
        }
      case UltimateKind.moon:
        final radius = 80 + charge * 20 + burst * 65;
        glow(canvas, center, radius * 2, spell.color, power * .6);
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
          Path()..addOval(
            Rect.fromCircle(
              center: center + Offset(radius * .48, -radius * .16),
              radius: radius * .9,
            ),
          ),
        );
        canvas.drawPath(
          moon,
          Paint()
            ..shader = LinearGradient(
              colors: [
                spell.highlight.withValues(alpha: power * .95),
                spell.color.withValues(alpha: power * .55),
              ],
            ).createShader(Rect.fromCircle(center: center, radius: radius)),
        );
    }
    if (burst > 0) {
      glow(
        canvas,
        center,
        70 + burst * 170,
        spell.highlight,
        power * math.max(0, .85 - burst * .4),
      );
    }
  }

  void _burst(
    Canvas canvas,
    UltimateSpell spell,
    UltimateKind kind,
    double burst,
    double fade,
    bool reduced,
  ) {
    for (final i in _particles) {
      if (reduced && i % 5 != 0) continue;
      final angle = i * 2.399963;
      final distance = 45 + burst * (130 + i % 11 * 17);
      final z = ((i * 61) % 500) - 200 - burst * (reduced ? 40 : 190);
      final point = project(
        math.cos(angle) * distance,
        math.sin(angle) * distance * 1.18,
        z,
      );
      final depth = 600 / (600 + z.clamp(-390, 900));
      final radius = (1.4 + i % 4 * .7) * depth;
      final alpha = fade * (.9 - burst * .27).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = (i % 3 == 0 ? spell.highlight : spell.color).withValues(
          alpha: alpha,
        );
      if (i % 6 == 0) glow(canvas, point, radius * 5, spell.color, alpha * .5);
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle + burst * (reduced ? 0 : .4));
      if (kind == UltimateKind.nature) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 5,
            height: radius * 1.8,
          ),
          paint,
        );
      } else if (kind == UltimateKind.water) {
        canvas.drawCircle(
          Offset.zero,
          radius * 2.5,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
        );
        canvas.drawCircle(
          Offset(-radius, -radius),
          radius * .5,
          Paint()..color = spell.highlight.withValues(alpha: alpha),
        );
      } else if (kind == UltimateKind.earth) {
        final shard = Path()
          ..moveTo(0, -radius * 4)
          ..lineTo(radius * 1.5, 0)
          ..lineTo(0, radius * 2)
          ..lineTo(-radius * 1.5, 0)
          ..close();
        canvas.drawPath(shard, paint);
      } else if (kind == UltimateKind.fire) {
        canvas.drawLine(
          Offset(-radius * 6, 0),
          Offset.zero,
          paint
            ..strokeWidth = radius * 1.3
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          Offset.zero,
          radius,
          Paint()..color = spell.highlight.withValues(alpha: alpha),
        );
      } else {
        canvas.drawLine(
          Offset(-radius * 2.5, 0),
          Offset(radius * 2.5, 0),
          paint..strokeWidth = 1.5,
        );
        canvas.drawLine(
          Offset(0, -radius * 2.5),
          Offset(0, radius * 2.5),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  void onRemove() {
    for (final painter in _text.values) {
      painter.dispose();
    }
    _text.clear();
    super.onRemove();
  }
}
