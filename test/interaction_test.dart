import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/game_session.dart';
import 'package:forest_star/interaction_motion.dart';
import 'package:forest_star/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio, enterGame, gameTap;

void main() {
  testWidgets('held controls cancel on drag, interruption and background', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ForestStarApp(
        prefs: await SharedPreferences.getInstance(),
        initialState: GameState(),
        audio: FakeAudio(),
      ),
    );
    final game = await enterGame(tester), session = game.session;
    session.open(0);
    final count = session.state.marbles;
    final gesture = await tester.startGesture(const Offset(400, 780));
    await tester.pump(const Duration(milliseconds: 80));
    expect(session.motion.holding, isTrue);
    expect(
      session.motion.compression(const Rect.fromLTWH(346, 754, 110, 53)),
      greaterThan(0),
    );
    await gesture.moveTo(const Offset(160, 780));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 80));
    expect(session.state.marbles, count);
    expect(session.pinball.active, isFalse);
    expect(session.motion.holding, isFalse);
    final interrupted = await tester.startGesture(const Offset(400, 780));
    session.setForeground(false);
    session.setForeground(true);
    await interrupted.up();
    await tester.pump(const Duration(milliseconds: 80));
    expect(session.state.marbles, count);
    await gameTap(tester, game, const Offset(400, 780));
    expect(session.state.marbles, count + 12);
    await gameTap(tester, game, const Offset(180, 825));
    expect(session.tab, 1);
    await gameTap(tester, game, const Offset(390, 260));
    expect(session.selected, 2);
    expect(session.motion.selectedFriend, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 120));
  });

  test(
    'growth celebration pauses combat and motion feedback expires without accumulation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final session = GameSession(
        GameState(),
        await SharedPreferences.getInstance(),
        FakeAudio(),
      );
      session.combat.begin(session.state);
      for (var i = 0; i < 100; i++) {
        session.update(1 / 120);
      }
      final before = session.combat.enemies.first.x;
      session.queueGrowth(const GrowthResult(0, 36, 1, 2, 0, 0, false));
      for (var i = 0; i < 120; i++) {
        session.update(1 / 120);
      }
      expect(session.celebration, isNotNull);
      expect(session.combat.enemies.first.x, before);
      final clock = session.celebrationAge;
      session.setForeground(false);
      session.update(.1);
      expect(session.celebrationAge, clock);
      session.setForeground(true);
      for (var i = 0; i < 360; i++) {
        session.update(1 / 120);
      }
      expect(session.celebration, isNull);
      expect(
        session.combat.enemies.isEmpty ||
            session.combat.enemies.first.x < before,
        isTrue,
      );
      for (var i = 0; i < 100; i++) {
        session.motion.add(
          CueKind.reward,
          const Offset(200, 600),
          0,
          label: '+12',
        );
      }
      expect(
        session.motion.cues.length,
        lessThanOrEqualTo(InteractionMotion.maxCues),
      );
      for (var i = 0; i < 150; i++) {
        session.update(1 / 120);
      }
      expect(session.motion.cues, isEmpty);
      session.dispose();
    },
  );
}
