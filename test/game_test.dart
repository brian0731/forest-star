import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/game.dart';

void main() {
  test('state upgrades, evolves, equips and round trips', () {
    final state = GameState();
    expect(state.upgrade(0), isTrue);
    expect(state.upgrade(0), isTrue);
    expect(state.evolve(0), isTrue);
    state.equip(1, 0);
    expect(state.team, [1, 0, 2, -1]);
    final loaded = GameState.fromJson(state.toJson());
    expect(loaded.toJson(), state.toJson());
    expect(loaded.unlock(3), isFalse);
  });
  test('pinball settles and resets after five shots', () {
    final ball = Pinball();
    var hits = 0;
    var settlements = 0;
    ball.onHit = (_) => hits++;
    ball.onSettled = (_, _) => settlements++;
    for (var i = 0; i < 100; i++) {
      ball.launch(Offset((i % 15 - 7) * .035, 1));
      for (var t = 0; t < 1200 && ball.active; t++) {
        ball.tick(1 / 60);
      }
      expect(ball.active, isFalse);
    }
    expect(settlements, 100);
    expect(hits, greaterThan(100));
    expect(ball.shotsOnBoard, 5);
  });
  test('default team wins first level and trained team wins all levels', () {
    final state = GameState();
    bool play() {
      final combat = Combat();
      bool? won;
      combat.onFinished = (value) => won = value;
      combat.begin(state);
      for (var i = 0; i < 30000 && combat.active; i++) {
        combat.tick(1 / 60);
      }
      expect(combat.active, isFalse);
      return won ?? false;
    }

    expect(play(), isTrue);
    state.levels = List.filled(6, 10);
    state.evolutions = List.filled(6, 2);
    state.unlocked[3] = true;
    state.team = [0, 1, 2, 3];
    for (var stage = 1; stage <= 10; stage++) {
      state.stage = stage;
      expect(play(), isTrue, reason: 'stage $stage');
    }
    expect(state.damage(0), closeTo(8 * (1 + 9 * .24) * 1.8, .001));
    expect(math.max(state.clearedStage, 0), 0);
  });
}
