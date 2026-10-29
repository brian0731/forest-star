import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/forest_effects.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/game_session.dart';
import 'package:forest_star/main.dart';
import 'package:forest_star/vfx_event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio, enterGame;

void main() {
  test('real impacts emit effects without changing the simulation', () async {
    SharedPreferences.setMockInitialValues({});
    final s = GameSession(
      GameState(),
      await SharedPreferences.getInstance(),
      FakeAudio(),
    );
    s.open(0);
    s.launch();
    for (var i = 0; i < 200 && s.pinball.combo == 0; i++) {
      s.update(1 / 120);
    }
    expect(s.pinball.combo, greaterThan(0));
    expect(s.effects.any((e) => e.kind == VfxKind.spark), isTrue);
    s.open(2);
    s.combat.begin(s.state);
    for (
      var i = 0;
      i < 1500 && !s.effects.any((e) => e.kind == VfxKind.fire);
      i++
    ) {
      s.update(1 / 120);
    }
    expect(s.effects.any((e) => e.kind == VfxKind.fire), isTrue);
    expect(s.effects.any((e) => e.kind == VfxKind.water), isTrue);
    s.dispose();
  });

  testWidgets('particles are bounded, pause, expire and clear on navigation', (
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
    final game = await enterGame(tester), s = game.session;
    for (var i = 0; i < 100; i++) {
      s.emit(VfxKind.stars, const Offset(240, 450), 3);
    }
    expect(s.effects.length, 24);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.effects.activeBursts, ForestEffects.maxBursts);
    final time = s.time;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3));
    expect(s.time, time);
    expect(game.effects.activeBursts, ForestEffects.maxBursts);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.effects.activeBursts, 0);
    expect(game.effects.children, isEmpty);
    s.emit(VfxKind.stars, const Offset(240, 450), 3);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.effects.activeBursts, 1);
    s.open(1);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.effects.activeBursts, 0);
    expect(game.effects.children, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
