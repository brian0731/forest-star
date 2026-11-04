import 'dart:convert';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/game_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio;

void main() {
  test('each color takes its own number of hits and scores once on break', () {
    for (var type = 0; type < 3; type++) {
      final ball = Pinball()..launch(const Offset(0, 1));
      final peg = Peg(240, 350, type);
      ball.pegs = [peg];
      for (var hit = 1; hit <= type + 1; hit++) {
        ball.x = 240;
        ball.y = 329.5;
        ball.vx = 0;
        ball.vy = 80;
        peg.cooldown = 0;
        ball.tick(1 / 120);
        expect(peg.life, type + 1 - hit);
        expect(ball.earned, hit == type + 1 ? [6, 14, 24][type] : 0);
      }
      expect(ball.combo, type + 1);
      ball.x = 240;
      ball.y = 329.5;
      ball.vy = 80;
      ball.tick(1 / 120);
      expect(ball.earned, [6, 14, 24][type]);
    }
  });

  test(
    'all six physical baskets credit only their matching companion once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      for (var id = 0; id < 6; id++) {
        final state = GameState();
        final session = GameSession(state, prefs, FakeAudio());
        session.open(0);
        session.launch();
        final ball = session.pinball;
        ball.x = Pinball.bucketCenter(id);
        ball.y = 602;
        ball.vx = 600;
        ball.vy = 500;
        ball.earned = 9;
        session.update(1 / 120);
        expect(ball.enteringBucket, id);
        // Basket walls stop a late lateral move from changing the recipient.
        ball.vx = -600;
        for (var frame = 0; frame < 100 && ball.active; frame++) {
          session.update(1 / 120);
        }
        expect(ball.active, isFalse);
        expect(ball.lastBucket, id);
        expect(
          state.growth,
          List.generate(friends.length, (i) => i == id ? 17 : 0),
        );
        expect(state.sugar, 68);
        session.update(.1);
        expect(state.growth[id], 17);
        session.flush();
        final saved = GameState.fromJson(
          jsonDecode(prefs.getString('forest_star_v1')!),
        );
        expect(saved.toJson(), state.toJson());
        session.dispose();
      }
      expect(Pinball.bucketAt(-50), 0);
      expect(Pinball.bucketAt(500), 5);
    },
  );

  test(
    'growth carries over, unlocks friends and evolves at levels three and six',
    () {
      final state = GameState();
      var change = state.awardGrowth(0, 35);
      expect(change.celebrate, isFalse);
      change = state.awardGrowth(0, 1);
      expect(state.levels[0], 2);
      expect(state.growth[0], 0);
      change = state.awardGrowth(0, 48 + 7);
      expect(change.evolved, isTrue);
      expect(state.evolutions[0], 1);
      expect(state.growth[0], 7);
      change = state.awardGrowth(0, 60 + 72 + 84 - 7);
      expect(state.levels[0], 6);
      expect(state.evolutions[0], 2);
      expect(change.evolved, isTrue);
      change = state.awardGrowth(5, 40 + 36 + 5);
      expect(change.joined, isTrue);
      expect(state.unlocked[5], isTrue);
      expect(state.levels[5], 2);
      expect(state.growth[5], 5);
      state.awardGrowth(0, 9999999);
      expect(state.levels[0], 10);
      expect(state.evolutions[0], 2);
      expect(state.growth[0], lessThanOrEqualTo(999999));
      final old = GameState().toJson()..remove('growth');
      expect(GameState.fromJson(old).growth, List.filled(friends.length, 0));
      expect(GameState.fromJson(state.toJson()).toJson(), state.toJson());
    },
  );

  test(
    'celebration pauses in background and blocks actions until it expires',
    () async {
      SharedPreferences.setMockInitialValues({});
      final session = GameSession(
        GameState(),
        await SharedPreferences.getInstance(),
        FakeAudio(),
      );
      session.open(0);
      session.queueGrowth(session.state.awardGrowth(0, 84));
      session.update(.1);
      expect(session.celebration!.evolved, isTrue);
      session.launch();
      session.open(2);
      expect(session.pinball.active, isFalse);
      expect(session.tab, 0);
      final ageBeforeBackground = session.celebrationAge;
      session.setForeground(false);
      session.update(5);
      expect(session.celebrationAge, ageBeforeBackground);
      session.setForeground(true);
      for (var i = 0; i < 44; i++) {
        session.update(.1);
      }
      expect(session.celebration, isNull);
      session.launch();
      expect(session.pinball.active, isTrue);
      session.dispose();
    },
  );
}
