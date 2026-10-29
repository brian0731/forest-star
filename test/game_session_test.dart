import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/game_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio;

void main() {
  test(
    'fixed simulation produces identical results at 60, 90 and 120 Hz',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final sessions = <GameSession>[];
      for (final rate in [60, 90, 120]) {
        final session = GameSession(GameState(), prefs, FakeAudio());
        session.aim = const Offset(.19, 1);
        session.launch();
        session.combat.begin(session.state);
        for (var frame = 0; frame < rate * 6; frame++) {
          session.update(1 / rate);
        }
        sessions.add(session);
      }
      for (final s in sessions.skip(1)) {
        final reference = sessions.first;
        expect(s.simulationSteps, 720);
        expect(
          (s.pinball.x, s.pinball.y),
          (reference.pinball.x, reference.pinball.y),
        );
        expect(s.pinball.earned, reference.pinball.earned);
        expect(s.state.toJson(), reference.state.toJson());
        expect(s.combat.health, reference.combat.health);
        expect(s.combat.kills, reference.combat.kills);
        expect(
          s.combat.enemies.map((e) => (e.id, e.x, e.y, e.hp)),
          reference.combat.enemies.map((e) => (e.id, e.x, e.y, e.hp)),
        );
      }
      for (final s in sessions) {
        s.dispose();
      }
    },
  );
  test('background and invalid deltas cannot advance the simulation', () async {
    SharedPreferences.setMockInitialValues({});
    final s = GameSession(
      GameState(),
      await SharedPreferences.getInstance(),
      FakeAudio(),
    );
    s.launch();
    s.update(1 / 60);
    final age = s.pinball.age;
    s.dragging = true;
    s.setForeground(false);
    s.update(30);
    expect(s.dragging, isFalse);
    expect(s.pinball.age, age);
    s.setForeground(true);
    s.update(double.nan);
    s.update(-1);
    expect(s.pinball.age, age);
    s.update(60);
    expect(s.pinball.age - age, lessThanOrEqualTo(.100001));
    s.dispose();
  });
}
