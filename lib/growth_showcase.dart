import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'game.dart';
import 'game_session.dart';
import 'storybook_ui.dart';

/// A bounded, time-based celebration with perspective, depth and radial particles.
/// Foreground coordinates share the safe frame; the backdrop covers the viewport.
/// Input is gated by GameSession.
class GrowthShowcase extends Component {
  GrowthShowcase(this.session, {this.viewport}) : super(priority: 2000);
  final GameSession session;
  final Rect Function()? viewport;
  final _text = <String, TextPainter>{};

  void label(Canvas canvas, String value, double y, double size, Color color) {
    final key = '$value/$size/${color.toARGB32()}';
    if (_text.length >= 32) _text.clear();
    final painter = _text.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'ForestUI',
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: color,
            shadows: const [Shadow(color: Color(0x990f2927), blurRadius: 8)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 440),
    );
    painter.paint(canvas, Offset((480 - painter.width) / 2, y));
  }

  @override
  void render(Canvas canvas) {
    final event = session.celebration;
    if (event == null || session.result) return;
    final t = session.celebrationAge;
    final evolved = event.evolved;
    final fade = math.min(
      (t / .2).clamp(0.0, 1.0),
      ((session.celebrationDuration - t) / .35).clamp(0.0, 1.0),
    );
    final reveal = ((t - .3) / .6).clamp(0.0, 1.0);
    final burst = math.max(0.0, t - .55);
    final color = friends[event.friend].color;
    final backdrop = viewport?.call() ?? const Rect.fromLTWH(0, 0, 480, 900);
    const center = Offset(240, 416);
    canvas.drawRect(
      backdrop,
      Paint()..color = const Color(0xff102f32).withValues(alpha: .93 * fade),
    );
    canvas.drawCircle(
      center,
      260,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: .65 * fade),
            color.withValues(alpha: .08 * fade),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 260)),
    );

    // Rays turn slowly behind the character; rings are flattened to imply depth.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * .13);
    for (var i = 0; i < 14; i++) {
      final angle = i * math.pi / 7;
      final ray = Path()
        ..moveTo(0, 0)
        ..lineTo(math.cos(angle - .045) * 330, math.sin(angle - .045) * 330)
        ..lineTo(math.cos(angle + .045) * 330, math.sin(angle + .045) * 330)
        ..close();
      canvas.drawPath(
        ray,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xffffefad).withValues(alpha: .21 * fade * reveal),
              Colors.transparent,
            ],
          ).createShader(const Rect.fromLTWH(-330, -330, 660, 660)),
      );
    }
    canvas.restore();
    for (var i = 0; i < 3; i++) {
      final r = 90 + ((burst * 75 + i * 43) % 130);
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(240, 550),
          width: r * 2,
          height: r * .46,
        ),
        Paint()
          ..color = const Color(
            0xffffdc84,
          ).withValues(alpha: .45 * fade * reveal * (1 - (r - 90) / 130))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.3,
      );
    }

    // Fixed particle count, analytical motion: no accumulating objects or timers.
    if (burst > 0) {
      for (var i = 0; i < (evolved ? 100 : 60); i++) {
        final phase = burst - (i % 4) * .055;
        if (phase <= 0) continue;
        final life = (1 - phase / 2.8).clamp(0.0, 1.0);
        final angle = i * 2.399963;
        final depth = math.sin(i * 1.73 + phase * .8);
        final perspective = 1 / (1 - depth * .32);
        final distance = (20 + phase * (60 + i % 7 * 19)) * perspective;
        final point =
            center +
            Offset(
              math.cos(angle) * distance,
              math.sin(angle) * distance * .9 + phase * phase * 13,
            );
        final radius = (1.7 + i % 4) * perspective * life;
        final paint = Paint()
          ..color = (i.isEven ? const Color(0xffffdf86) : color).withValues(
            alpha: life * fade * .9,
          );
        canvas.drawCircle(point, radius, paint);
        if (i % 5 == 0) {
          paint.strokeWidth = 1.4;
          canvas.drawLine(
            point - Offset(radius * 2, 0),
            point + Offset(radius * 2, 0),
            paint,
          );
          canvas.drawLine(
            point - Offset(0, radius * 2),
            point + Offset(0, radius * 2),
            paint,
          );
        }
      }
    }

    final image = StoryArt.instance.images['friend${event.friend}'];
    if (image != null) {
      final pop = Curves.easeOutBack.transform(reveal);
      final scale = .45 + pop * .65;
      final tilt = math.sin(t * 2.1) * .14 * reveal;
      canvas.save();
      canvas.translate(240, 418 - math.sin(t * 2.3) * 6 * reveal);
      final matrix = Matrix4.identity()
        ..setEntry(3, 2, .0014)
        ..rotateY(tilt)
        ..rotateX(-.06 + math.sin(t) * .035)
        ..scaleByDouble(scale, scale, 1, 1);
      canvas.transform(matrix.storage);
      // A soft colored silhouette behind the crisp original transparent sprite.
      final rect = const Rect.fromLTWH(-146, -146, 292, 292);
      canvas.saveLayer(
        rect.inflate(20),
        Paint()
          ..colorFilter = ColorFilter.mode(
            color.withValues(alpha: fade * .7),
            BlendMode.srcIn,
          )
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      );
      paintImage(
        canvas: canvas,
        rect: rect.inflate(6),
        image: image,
        fit: BoxFit.contain,
      );
      canvas.restore();
      paintImage(
        canvas: canvas,
        rect: rect,
        image: image,
        fit: BoxFit.contain,
        opacity: fade,
        filterQuality: FilterQuality.medium,
      );
      if (event.evolution > 0) {
        final crown = Path()
          ..moveTo(-24, -150)
          ..lineTo(-30, -177)
          ..lineTo(-10, -165)
          ..lineTo(0, -187)
          ..lineTo(11, -165)
          ..lineTo(30, -177)
          ..lineTo(24, -150)
          ..close();
        canvas.drawPath(
          crown.shift(const Offset(0, 45)),
          Paint()
            ..color = const Color(0xffffdd75).withValues(alpha: fade * reveal),
        );
      }
      canvas.restore();
    }
    // A short, restrained flash marks the instant of transformation.
    final flash = (1 - (t - .55).abs() / .13).clamp(0.0, 1.0);
    canvas.drawRect(
      backdrop,
      Paint()..color = const Color(0xfffff4cf).withValues(alpha: flash * .3),
    );
    label(
      canvas,
      evolved
          ? '星光覺醒 · ${event.evolution} 階進化'
          : event.joined
          ? '新的冒險夥伴'
          : '成長的瞬間',
      192,
      evolved ? 28 : 25,
      const Color(0xffffdf8b).withValues(alpha: fade),
    );
    label(
      canvas,
      friends[event.friend].name,
      584,
      31,
      Colors.white.withValues(alpha: fade),
    );
    label(
      canvas,
      event.joined ? '加入森星小隊！' : 'Lv.${event.oldLevel}  →  Lv.${event.level}',
      632,
      22,
      const Color(0xffffe6a2).withValues(alpha: fade),
    );
    if (event.points > 0) {
      label(
        canvas,
        '專屬成長分 +${event.points}',
        672,
        15,
        const Color(0xffd6e8cf).withValues(alpha: fade),
      );
    }
    if (t >= 1.2) {
      paintStoryFrame(
        canvas,
        const Rect.fromLTWH(115, 710, 250, 55),
        'cream',
        opacity: fade,
      );
      label(
        canvas,
        '繼續冒險',
        724,
        18,
        const Color(0xff345340).withValues(alpha: fade),
      );
    }
  }
}
