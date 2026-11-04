import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'storybook_ui.dart';

/// A layered Flame scene. Sprites keep their original alpha; light, depth and
/// perspective come from projection, motion and shadows rather than a 3D model.
class StartForestScene extends FlameGame {
  final grove = PositionComponent(size: Vector2(480, 300));
  final companions = <StartCompanion>[];
  final _bursts = <ParticleSystemComponent>[];
  final _random = math.Random(732);
  double age = 0, _nextGreeting = 5;
  bool sceneReady = false, _removed = false, _motion = true;
  Offset targetTilt = Offset.zero, tilt = Offset.zero;
  int get activeBursts => _bursts.length;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await StoryArt.instance.load();
    if (_removed) return;
    await add(grove);
    await grove.add(_ClearingLight());
    await grove.add(
      ParticleSystemComponent(
        priority: 1,
        particle: Particle.generate(
          count: 30,
          lifespan: 1e9,
          generator: (i) =>
              ComputedParticle(renderer: (canvas, _) => _light(canvas, i)),
        ),
      ),
    );
    for (final specification in [
      (1, 131.0, 267.0, 151.0, 10),
      (2, 350.0, 267.0, 161.0, 11),
      (0, 240.0, 277.0, 205.0, 12),
    ]) {
      final character = StartCompanion(
        this,
        specification.$1,
        StoryArt.instance.images['friend${specification.$1}']!,
        specification.$2,
        specification.$3,
        specification.$4,
        specification.$5,
      );
      companions.add(character);
      await grove.add(character);
    }
    sceneReady = true;
    _layout();
    if (!_motion) pauseEngine();
  }

  void setMotion(bool enabled) {
    _motion = enabled;
    if (sceneReady) {
      if (enabled) {
        resumeEngine();
      } else {
        pauseEngine();
      }
    }
  }

  void _layout() {
    if (!sceneReady || size.x <= 0 || size.y <= 0) return;
    final fit = math.min(size.x / 480, size.y / 300);
    grove.scale.setValues(fit, fit);
    grove.position.setValues(
      (size.x - 480 * fit) / 2,
      (size.y - 300 * fit) / 2,
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout();
  }

  @override
  void onRemove() {
    _removed = true;
    super.onRemove();
  }

  @override
  void update(double dt) {
    dt = math.min(dt, .05);
    super.update(dt);
    age += dt;
    tilt = Offset.lerp(tilt, targetTilt, math.min(1, dt * 5))!;
    _bursts.removeWhere((b) => b.isRemoving || b.parent == null);
    if (sceneReady && age >= _nextGreeting) {
      _nextGreeting = age + 6;
      companions[(age ~/ 6) % companions.length].hop(burst: false);
    }
  }

  void celebrate(StartCompanion companion) {
    if (!_motion) return;
    if (_bursts.length >= 6) _bursts.removeAt(0).removeFromParent();
    final origin = companion.position - Vector2(0, companion.size.y * .55);
    final burst = ParticleSystemComponent(
      position: origin,
      priority: 30,
      particle: Particle.generate(
        count: 15,
        lifespan: .8,
        generator: (i) {
          final angle = _random.nextDouble() * math.pi * 2,
              speed = 35 + _random.nextDouble() * 75;
          return AcceleratedParticle(
            speed: Vector2(
              math.cos(angle) * speed,
              math.sin(angle) * speed - 30,
            ),
            acceleration: Vector2(0, 95),
            child: ComputedParticle(
              renderer: (canvas, p) {
                final fade = 1 - p.progress;
                final paint = Paint()
                  ..color =
                      (i.isEven
                              ? const Color(0xffffe89c)
                              : const Color(0xffd7f5cc))
                          .withValues(alpha: fade);
                canvas.rotate(p.progress * 2 + i);
                final r = 2.5 * fade;
                canvas.drawRRect(
                  RRect.fromRectAndRadius(
                    Rect.fromLTWH(-r, -r, r * 2, r * 2),
                    Radius.circular(r * .3),
                  ),
                  paint,
                );
              },
            ),
          );
        },
      ),
    );
    _bursts.add(burst);
    grove.add(burst);
  }

  void _light(Canvas canvas, int i) {
    final depth = (i % 5) / 4, phase = age * (.18 + depth * .2) + i * 2.399;
    final x =
        240 + math.cos(phase) * (180 + depth * 55) + tilt.dx * (depth * 16 - 6);
    final y =
        157 +
        math.sin(phase * .71 + i) * (75 + depth * 25) +
        tilt.dy * (depth * 12 - 3);
    final radius = 1.3 + depth * 2.5;
    final centre = Offset(x, y);
    canvas.drawCircle(
      centre,
      radius * 4,
      Paint()
        ..shader = ui.Gradient.radial(centre, radius * 4, [
          const Color(0xffffe7a1).withValues(alpha: .16 + depth * .12),
          Colors.transparent,
        ]),
    );
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = Color.lerp(
          const Color(0xffe2f9cf),
          const Color(0xffffe8a1),
          depth,
        )!.withValues(alpha: .5 + math.sin(age + i) * .17),
    );
    if (i % 7 == 0) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(age * .35 + i);
      canvas.scale(math.cos(age * .6 + i).abs() * .65 + .35, 1);
      final r = radius * 2.2;
      final path = Path()
        ..moveTo(0, -r)
        ..quadraticBezierTo(r * .22, -r * .22, r, 0)
        ..quadraticBezierTo(r * .22, r * .22, 0, r)
        ..quadraticBezierTo(-r * .22, r * .22, -r, 0)
        ..quadraticBezierTo(-r * .22, -r * .22, 0, -r);
      canvas.drawPath(path, Paint()..color = const Color(0xd9fff2c4));
      canvas.restore();
    }
  }
}

class _ClearingLight extends Component {
  @override
  void render(Canvas canvas) {
    const rect = Rect.fromLTWH(70, 241, 340, 45);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          180,
          [
            const Color(0x60fff4b5),
            const Color(0x15468048),
            Colors.transparent,
          ],
          [0, .55, 1],
        ),
    );
  }
}

class StartCompanion extends PositionComponent with TapCallbacks {
  StartCompanion(
    this.scene,
    this.friend,
    ui.Image image,
    double x,
    double y,
    double width,
    int z,
  ) : super(
        position: Vector2(x, y),
        size: Vector2.all(width),
        anchor: Anchor.bottomCenter,
        priority: z,
      ) {
    body = SpriteComponent(
      sprite: Sprite(image),
      size: Vector2.all(width),
      position: Vector2(width / 2, width),
      anchor: Anchor.bottomCenter,
    );
  }
  final StartForestScene scene;
  final int friend;
  late final SpriteComponent body;
  bool hopping = false;
  double get altitude => size.y - body.position.y;

  @override
  Future<void> onLoad() async {
    await add(body);
    await body.add(
      ScaleEffect.to(
        Vector2(1.022, 1.035),
        EffectController(
          duration: 1.5 + friend * .2,
          alternate: true,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  void hop({bool burst = true}) {
    if (hopping || !scene._motion) return;
    hopping = true;
    body.add(
      MoveEffect.by(
        Vector2(0, -(friend == 0 ? 32.0 : 24.0)),
        EffectController(duration: .24, alternate: true, curve: Curves.easeOut),
        onComplete: () => hopping = false,
      ),
    );
    if (burst) scene.celebrate(this);
  }

  @override
  void onTapDown(TapDownEvent event) => hop();
  @override
  void render(Canvas canvas) {
    final elevation = (altitude / 35).clamp(0, 1);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 3),
        width: size.x * (.5 - elevation * .15),
        height: 12 - elevation * 4,
      ),
      Paint()
        ..color = Color.fromRGBO(35, 59, 35, .24 - elevation * .11)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Front sprites respond more than distant companions, establishing depth.
    final depth = friend == 0 ? 1.0 : .6;
    angle =
        math.sin(scene.age * .9 + friend) * .018 + scene.tilt.dx * .018 * depth;
    scale.setValues(
      1 + scene.tilt.dy * .015 * depth,
      1 - scene.tilt.dy * .01 * depth,
    );
  }
}
