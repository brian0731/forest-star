import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/game.dart';

void main() {
  test(
    'old three-slot saves preserve order and add an eligible fourth friend',
    () {
      final old = GameState().toJson()..['team'] = [2, 0, 1];
      expect(GameState.fromJson(old).team, [2, 0, 1, -1]);
      old['unlocked'] = [true, true, true, false, false, true];
      final migrated = GameState.fromJson(old);
      expect(migrated.team, [2, 0, 1, 5]);
      migrated.equip(3, 0);
      expect(migrated.team, [2, 5, 1, 0]);
      expect(GameState.fromJson(migrated.toJson()).team, migrated.team);
      migrated.equip(3, 4);
      expect(migrated.team, [
        2,
        5,
        1,
        0,
      ], reason: 'Locked friends cannot be equipped');
      old['team'] = [0, 0, 1];
      expect(GameState.fromJson(old).team, [0, 1, 2, -1]);
    },
  );

  test(
    'all four lanes move left, shoot right and impact at their row centres',
    () {
      final state = GameState()..unlocked[3] = true;
      state.team = [0, 1, 2, 3];
      final combat = Combat()..begin(state);
      combat.spawnTimer = 999;
      final impacts = <int>{};
      combat.onImpact = (position, friend) {
        expect(position.dy, BattleLayout.laneY(friend));
        expect(position.dx, greaterThan(BattleLayout.breachX));
        impacts.add(friend);
      };
      combat.enemies = List.generate(
        4,
        (lane) => Enemy(lane, lane, 1000, 10, lane % 3, false),
      );
      for (var frame = 0; frame < 80; frame++) {
        combat.tick(1 / 120);
      }
      expect(
        combat.enemies.every((enemy) => enemy.x < BattleLayout.spawnX),
        isTrue,
      );
      expect(combat.attacks.every((count) => count > 0), isTrue);
      for (final shot in combat.shots) {
        expect(shot.x, greaterThan(BattleLayout.shotX));
        expect(shot.y, BattleLayout.laneY(shot.lane));
      }
      for (var frame = 0; frame < 90; frame++) {
        combat.tick(1 / 120);
      }
      expect(impacts, {0, 1, 2, 3});
    },
  );

  test('nearest enemy is targeted and an empty lane breaches exactly once', () {
    final combat = Combat()..begin(GameState());
    combat.spawnTimer = 999;
    combat.enemies = [
      Enemy(1, 0, 1000, 0, 0, false)..x = 300,
      Enemy(2, 0, 1000, 0, 0, false)..x = 220,
      Enemy(3, 3, 1000, 10, 0, false)..x = BattleLayout.breachX + .01,
    ];
    combat.tick(1 / 120);
    expect(combat.shots.single.targetId, 2);
    expect(combat.attacks[3], 0);
    expect(combat.health, 88);
    combat.tick(1 / 120);
    expect(combat.health, 88);
    expect(combat.enemies.any((enemy) => enemy.id == 3), isFalse);
  });

  test(
    'horizontal splash, slow and chain damage keep their element behaviour',
    () {
      for (final id in [1, 2, 4]) {
        final state = GameState()
          ..unlocked = List.filled(6, true)
          ..team = [id, -1, -1, -1];
        final combat = Combat()..begin(state);
        combat.spawnTimer = 999;
        final target = Enemy(10, 0, 1000, 0, 0, false)..x = 200;
        final neighbour = Enemy(11, id == 2 ? 0 : 1, 1000, 0, 0, false)
          ..x = 225;
        combat.enemies = [target, neighbour];
        for (var frame = 0; frame < 30; frame++) {
          combat.tick(1 / 120);
        }
        expect(target.hp, lessThan(1000));
        if (id == 1) {
          expect(target.slow, greaterThan(0));
          expect(neighbour.hp, 1000);
        } else {
          expect(neighbour.hp, lessThan(1000));
        }
      }
    },
  );
}
