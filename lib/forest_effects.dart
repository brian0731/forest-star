import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'game_session.dart';
import 'game.dart';
import 'vfx_event.dart';

/// Native Flame particles, clipped to scenery so HUD and controls stay clear.
class ForestEffects extends Component {
  ForestEffects(this.session) : super(priority: 1100);
  final GameSession session;
  final _random = math.Random(1741);
  final _bursts = <_Burst>[];
  int _page = -1;
  int get activeBursts => _bursts.where((b) => !b.isRemoving).length;
  static const maxBursts = 18;
  static Rect area(int tab) => switch (tab) {
    0 => const Rect.fromLTWH(37, 270, 406, 386),
    1 => const Rect.fromLTWH(24, 220, 432, 463),
    2 => BattleLayout.field,
    _ => const Rect.fromLTWH(12, 215, 456, 554),
  };

  @override
  void update(double dt) {
    super.update(dt);
    if (_page != session.tab || session.result) {
      for (final burst in _bursts) {
        burst.removeFromParent();
      }
      _bursts.clear();
      _page = session.tab;
    }
    _bursts.removeWhere(
      (burst) => burst.isRemoving || burst.particle!.shouldRemove,
    );
    while (session.effects.isNotEmpty) {
      final event = session.effects.removeFirst();
      if (event.tab != session.tab || session.result) continue;
      if (_bursts.length >= maxBursts) _bursts.removeAt(0).removeFromParent();
      final burst = _Burst(
        session,
        event,
        Particle.generate(
          count: event.kind == VfxKind.stars ? 20 : 12,
          lifespan: event.kind == VfxKind.stars ? .85 : .5,
          generator: (index) {
            final angle = _random.nextDouble() * math.pi * 2,
                speed = 35 + _random.nextDouble() * 75,
                radius = 1.6 + _random.nextDouble() * 2.2;
            return AcceleratedParticle(
              speed: Vector2(
                math.cos(angle) * speed,
                math.sin(angle) * speed - 18,
              ),
              acceleration: Vector2(8, event.kind == VfxKind.fire ? -28 : 65),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final fade = 1 - particle.progress;
                  final color = switch (event.kind) {
                    VfxKind.fire =>
                      index.isEven
                          ? const Color(0xffffa64a)
                          : const Color(0xffffde7e),
                    VfxKind.water => const Color(0xff8bdef0),
                    VfxKind.leaf => const Color(0xffa4d56d),
                    VfxKind.stars =>
                      index.isEven
                          ? const Color(0xffffd76c)
                          : const Color(0xfffff6cb),
                    VfxKind.spark =>
                      index.isEven
                          ? const Color(0xffffd26b)
                          : const Color(0xfffff7d4),
                  };
                  final paint = Paint()
                    ..color = color.withValues(alpha: fade * .9);
                  canvas.drawCircle(Offset.zero, radius * fade, paint);
                  if (event.kind == VfxKind.spark ||
                      event.kind == VfxKind.fire) {
                    paint
                      ..strokeWidth = 1.4 * fade
                      ..strokeCap = StrokeCap.round;
                    canvas.drawLine(
                      Offset.zero,
                      Offset(
                        -math.cos(angle) * 7 * fade,
                        -math.sin(angle) * 7 * fade,
                      ),
                      paint,
                    );
                  } else if (event.kind == VfxKind.stars) {
                    paint.strokeWidth = 1 * fade;
                    canvas.drawLine(
                      Offset(-4 * fade, 0),
                      Offset(4 * fade, 0),
                      paint,
                    );
                    canvas.drawLine(
                      Offset(0, -4 * fade),
                      Offset(0, 4 * fade),
                      paint,
                    );
                  } else if (event.kind == VfxKind.water) {
                    canvas.drawCircle(
                      Offset.zero,
                      radius * (1 + particle.progress),
                      Paint()
                        ..color = color.withValues(alpha: fade * .6)
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 1,
                    );
                  }
                },
              ),
            );
          },
        ),
      );
      _bursts.add(burst);
      add(burst);
    }
  }

  @override
  void render(Canvas canvas) {
    if (session.result) return;
    final tab = session.tab, time = session.time, rect = area(tab);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    if (tab == 3) {
      // Air currents and leaves follow gentle arcs instead of obscuring buildings.
      for (var i = 0; i < 7; i++) {
        final x = (time * 23 + i * 79) % 530 - 25,
            y = 270 + i * 64 + math.sin(time * .7 + i) * 22;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(math.sin(time + i) * .65);
        canvas.drawOval(
          const Rect.fromLTWH(-5, -2, 10, 4),
          Paint()..color = const Color(0xffc9de95).withValues(alpha: .72),
        );
        canvas.drawLine(
          const Offset(-4, 0),
          const Offset(4, 0),
          Paint()
            ..color = const Color(0x99597942)
            ..strokeWidth = .7,
        );
        canvas.restore();
      }
      for (var i = 0; i < 3; i++) {
        final phase = (time * .18 + i * .33) % 1,
            x = phase * 620 - 90,
            y = 310 + i * 156.0;
        final path = Path()
          ..moveTo(x - 60, y)
          ..cubicTo(x - 25, y - 12, x + 5, y + 14, x + 48, y);
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white.withValues(
              alpha: math.sin(phase * math.pi) * .18,
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
        );
      }
    }
    if (tab == 2) {
      for (var i = 0; i < 34; i++) {
        final speed = 145.0 + i % 4 * 23,
            x = rect.left + (i * 73.7 - time * 26) % rect.width,
            y = rect.top + (time * speed + i * 41.7) % rect.height;
        canvas.drawLine(
          Offset(x, y),
          Offset(x - 3, y + 10 + i % 3 * 2),
          Paint()
            ..color = const Color(
              0xffc9eaf2,
            ).withValues(alpha: .25 + i % 3 * .07)
            ..strokeWidth = .8
            ..strokeCap = StrokeCap.round,
        );
      }
      for (var i = 0; i < 6; i++) {
        final phase = (time * .8 + i * .16) % 1;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(68 + i * 67, 450 + i % 3 * 44),
            width: 4 + phase * 15,
            height: 2 + phase * 5,
          ),
          Paint()
            ..color = const Color(
              0xffd4f1f2,
            ).withValues(alpha: (1 - phase) * .32)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8,
        );
      }
    }
    if (tab == 1 || tab == 3) {
      for (var i = 0; i < 12; i++) {
        final x =
                rect.left +
                (i * 87.1 + math.sin(time * .5 + i) * 16) % rect.width,
            y = rect.top + (i * 51.4 - time * 7) % rect.height,
            alpha = .15 + .35 * (1 + math.sin(time * 1.6 + i)) / 2;
        canvas.drawCircle(
          Offset(x, y),
          1.2 + i % 3 * .45,
          Paint()..color = const Color(0xffffe5a2).withValues(alpha: alpha),
        );
      }
    }
    canvas.restore();
  }
}

class _Burst extends ParticleSystemComponent {
  _Burst(this.session, this.event, Particle particles)
    : super(
        particle: particles,
        position: Vector2(event.position.dx, event.position.dy),
      );
  final GameSession session;
  final VfxEvent event;
  @override
  void render(Canvas canvas) {
    if (session.tab != event.tab || session.result) return;
    canvas.save();
    canvas.clipRect(ForestEffects.area(event.tab).shift(-event.position));
    super.render(canvas);
    canvas.restore();
  }
}
