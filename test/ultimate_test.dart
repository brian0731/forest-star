import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/audio.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/game_session.dart';
import 'package:forest_star/ultimate_spell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio;

GameState magicState() => GameState()
  ..unlocked = List.filled(friends.length, true)
  ..team = [0, 1, 2, 3];

void main() {
  test(
    'each equipped lane gets one ultimate per battle, never charged on invalid input',
    () {
      final combat = Combat();
      expect(combat.reserveUltimate(0), isFalse);
      combat.begin(magicState());
      expect(combat.reserveUltimate(0), isFalse);
      expect(combat.ultimateUsed, [false, false, false, false]);
      combat.enemies = [Enemy(0, 0, 10000, 0, 0, true)];
      expect(combat.reserveUltimate(-1), isFalse);
      expect(combat.reserveUltimate(4), isFalse);
      for (var lane = 0; lane < 4; lane++) {
        expect(combat.reserveUltimate(lane), isTrue);
        expect(
          combat.reserveUltimate((lane + 1) % 4),
          isFalse,
          reason: 'cannot queue another cast during the pending impact',
        );
        final hp = combat.enemies.single.hp;
        expect(combat.resolveUltimate(lane), isTrue);
        expect(combat.enemies.single.hp, lessThan(hp));
        final after = combat.enemies.single.hp;
        expect(combat.resolveUltimate(lane), isFalse);
        expect(combat.enemies.single.hp, after);
        expect(combat.reserveUltimate(lane), isFalse);
      }
      expect(combat.ultimateUsed, [true, true, true, true]);
      combat.begin(magicState()..team = [0, -1, 2, 3]);
      expect(combat.ultimateUsed, [false, false, false, false]);
      combat.enemies = [Enemy(0, 0, 100, 0, 0, false)];
      expect(combat.reserveUltimate(1), isFalse);
      expect(combat.reserveUltimate(0), isTrue);
      combat.finish(false);
      expect(combat.resolveUltimate(0), isFalse);
    },
  );

  for (var id = 0; id < 6; id++) {
    test(
      '${friends[id].name} ultimate has real field damage and its advertised effect',
      () {
        final state = magicState()..team = [id, -1, -1, -1];
        final combat = Combat()..begin(state);
        final primary = Enemy(0, 0, 10000, 0, 0, true)..x = 200;
        final secondary = Enemy(1, 2, 10000, 0, 1, false)..x = 230;
        combat.enemies = [primary, secondary];
        combat.health = combat.maxHealth - 40;
        final health = combat.health;
        final spell = UltimateSpell.of(friends[id].ultimateKind);
        expect(combat.reserveUltimate(0), isTrue);
        expect(primary.hp, 10000, reason: 'damage waits for the impact frame');
        expect(combat.resolveUltimate(0), isTrue);
        expect(
          primary.hp,
          closeTo(10000 - state.damage(id) * spell.damage, .0001),
        );
        expect(
          secondary.hp,
          closeTo(10000 - state.damage(id) * spell.splash, .0001),
        );
        if (id == 0 || id == 4) {
          expect(primary.x, 228);
          expect(secondary.x, 258);
        }
        if (id == 1) expect(primary.slow, 4);
        if (id == 3) {
          expect(
            combat.health,
            closeTo(health + combat.maxHealth * .25, .0001),
          );
          expect(combat.health, lessThanOrEqualTo(combat.maxHealth));
        } else {
          expect(combat.health, health);
        }
      },
    );
  }

  test(
    'ultimate kills count once, remove stale shots and use the normal victory reward flow',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = magicState();
      final session = GameSession(
        state,
        await SharedPreferences.getInstance(),
        FakeAudio(),
        persist: false,
      )..open(2);
      final combat = session.combat..begin(state);
      combat.wave = 3;
      combat.spawned = 8; // stage 1 final wave quota
      combat.spawnTimer = 999;
      combat.enemies = [
        Enemy(0, 0, 1, 0, 0, true),
        Enemy(1, 2, 1, 0, 1, false),
      ];
      combat.shots = [Shot(0, 0, 0, 8), Shot(2, 1, 2, 14)];
      expect(session.castUltimate(0), isTrue);
      for (var i = 0; i < 13; i++) {
        session.update(.1);
      }
      expect(combat.kills, 2);
      expect(combat.enemies, isEmpty);
      expect(combat.shots, isEmpty);
      expect(session.result, isFalse);
      for (var i = 0; i < 37; i++) {
        session.update(.1);
      }
      expect(session.result, isTrue);
      expect(state.victories, 1);
      expect(state.clearedStage, 1);
      for (var i = 0; i < 20; i++) {
        session.update(.1);
      }
      expect(state.victories, 1);
      session.dispose();
    },
  );

  test(
    'cinematic pauses combat, blocks repeat taps, pauses on lifecycle changes and hits once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final audio = FakeAudio();
      final session = GameSession(
        magicState(),
        await SharedPreferences.getInstance(),
        audio,
        persist: false,
      )..open(2);
      session.combat.begin(session.state);
      session.combat.spawnTimer = 999;
      session.combat.enemies = [Enemy(0, 0, 10000, 10, 0, false)..x = 260];
      expect(session.castUltimate(0), isTrue);
      final enemy = session.combat.enemies.single;
      final x = enemy.x;
      expect(session.ultimatePlaying.value, isTrue);
      expect(session.controlAt(BattleLayout.ultimateButton(1).center), isNull);
      expect(session.castUltimate(1), isFalse);
      session.open(3);
      expect(session.tab, 2);
      for (var i = 0; i < 10; i++) {
        session.update(.1);
      }
      expect(enemy.x, x);
      expect(enemy.hp, 10000);
      final age = session.ultimate!.age;
      session.setForeground(false);
      session.update(.1);
      expect(session.ultimate!.age, age);
      session.setForeground(true);
      for (var i = 0; i < 4; i++) {
        session.update(.1);
      }
      final hp = enemy.hp;
      expect(hp, lessThan(10000));
      for (var i = 0; i < 15; i++) {
        session.update(.1);
      }
      expect(enemy.hp, hp);
      expect(
        audio.events.where((event) => event == SoundEffect.magicCharge),
        hasLength(1),
      );
      expect(
        audio.events.where((event) => event == SoundEffect.magicImpact),
        hasLength(1),
      );
      for (var i = 0; i < 6; i++) {
        session.update(.1);
      }
      expect(session.ultimate, isNull);
      expect(session.ultimatePlaying.value, isFalse);
      expect(session.combat.ultimateUsed, [true, false, false, false]);
      session.dispose();
    },
  );
}
