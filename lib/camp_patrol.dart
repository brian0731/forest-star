import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'game.dart';
import 'game_session.dart';
import 'storybook_ui.dart';

/// Small equipped companions stroll in clearings; this component takes no input.
class CampPatrol extends Component {
  CampPatrol(this.session) : super(priority: 200);
  final GameSession session;
  final walkers = List.generate(BattleLayout.lanes, CampWalker.new);
  bool get visible =>
      session.tab == 3 && !session.result && session.celebration == null;

  @override
  void update(double dt) {
    super.update(dt);
    for (var slot = 0; slot < walkers.length; slot++) {
      final id = session.state.team[slot];
      walkers[slot].friend = id >= 0 && session.state.unlocked[id] ? id : -1;
    }
    if (!visible || !session.foreground || !dt.isFinite || dt <= 0) return;
    for (final walker in walkers) {
      if (walker.friend >= 0) walker.advance(dt.clamp(0.0, .1));
    }
  }

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final ordered = walkers.where((walker) => walker.friend >= 0).toList()
      ..sort((a, b) => a.foot.dy.compareTo(b.foot.dy));
    for (final walker in ordered) {
      final image = StoryArt.instance.images['friend${walker.friend}'];
      if (image == null) continue;
      final step = math.sin(walker.stride), walking = walker.moving;
      final bounce = walking
          ? step.abs() * 1.6
          : math.sin(walker.age * 2) * .25;
      final width = walker.size;
      canvas.drawOval(
        Rect.fromCenter(
          center: walker.foot + const Offset(0, 1),
          width: width * (walking ? .55 - step.abs() * .06 : .55),
          height: 4,
        ),
        Paint()..color = const Color(0x38284429),
      );
      canvas.save();
      canvas.translate(walker.foot.dx, walker.foot.dy - bounce);
      canvas.rotate(
        walking ? step * .055 : math.sin(walker.age * 1.2 + walker.slot) * .018,
      );
      final turn = walker.turnAge < .22
          ? math.cos(walker.turnAge / .22 * math.pi)
          : 1.0;
      canvas.scale(
        walker.facing * turn * (1 + (walking ? step * .025 : 0)),
        1 + (walking ? -step * .025 : math.sin(walker.age * 2) * .007),
      );
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(-width / 2, -width, width, width),
        image: image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
      canvas.restore();
    }
  }
}

class CampWalker {
  CampWalker(this.slot) : foot = paths[slot].first, wait = .4 + slot * .37;
  final int slot;
  int friend = -1, waypoint = 1, facing = 1;
  Offset foot;
  double wait, stride = 0, age = 0, turnAge = 1;
  bool moving = false;
  double get size => [34.0, 33.0, 36.0, 35.0][slot];
  double get speed => [15.0, 11.0, 12.5, 13.5][slot];
  Rect get footprint => Rect.fromLTWH(
    foot.dx - size / 2 - 2,
    foot.dy - size - 2,
    size + 4,
    size + 5,
  );

  // Feet follow these closed loops. Every whole sprite stays clear of the
  // buildings, their entrance labels, the sky and the bottom resource panel.
  static const paths = <List<Offset>>[
    [
      Offset(65, 485),
      Offset(110, 487),
      Offset(171, 480),
      Offset(218, 489),
      Offset(180, 500),
      Offset(117, 498),
    ],
    [
      Offset(174, 550),
      Offset(208, 552),
      Offset(230, 548),
      Offset(207, 546),
      Offset(184, 547),
    ],
    [
      Offset(60, 684),
      Offset(96, 665),
      Offset(111, 713),
      Offset(78, 744),
      Offset(50, 724),
    ],
    [
      Offset(404, 618),
      Offset(429, 645),
      Offset(417, 680),
      Offset(404, 733),
      Offset(438, 714),
      Offset(437, 665),
    ],
  ];

  void advance(double dt) {
    age += dt;
    moving = false;
    if (turnAge < .22) {
      turnAge += dt;
      if (turnAge >= .22) facing = -facing;
      return;
    }
    if (wait > 0) {
      wait = math.max(0, wait - dt);
      return;
    }
    final delta = paths[slot][waypoint] - foot;
    if (delta.dx.abs() > 1 && (delta.dx < 0 ? -1 : 1) != facing) {
      turnAge = 0;
      return;
    }
    final distance = delta.distance, travel = speed * dt;
    if (distance <= travel) {
      foot = paths[slot][waypoint];
      waypoint = (waypoint + 1) % paths[slot].length;
      wait = .65 + slot * .13 + waypoint % 3 * .2;
    } else {
      foot += delta / distance * travel;
      stride += travel * .42;
      moving = true;
    }
  }
}
