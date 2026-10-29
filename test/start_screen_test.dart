import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/audio.dart';
import 'package:forest_star/main.dart';
import 'package:forest_star/forest_flame_game.dart';
import 'package:forest_star/storybook_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAudio implements GameAudio {
  bool enabled = true, foreground = true, disposed = false;
  final events = <SoundEffect>[];
  MusicScene scene = MusicScene.camp;
  @override
  void setScene(MusicScene value) {
    scene = value;
  }

  @override
  void setEnabled(bool value) {
    enabled = value;
  }

  @override
  void setForeground(bool value) {
    foreground = value;
  }

  @override
  void play(SoundEffect effect) {
    if (enabled && foreground) events.add(effect);
  }

  @override
  void dispose() {
    disposed = true;
  }
}

Future<ForestFlameGame> enterGame(WidgetTester tester) async {
  await tester.runAsync(() => StoryArt.instance.load());
  late ForestFlameGame game;
  await tester.runAsync(() async {
    await tester.tap(find.text('開始冒險'));
    await tester.pump();
    game = tester
        .widget<GameWidget<ForestFlameGame>>(
          find.byType(GameWidget<ForestFlameGame>),
        )
        .game!;
    await game.toBeLoaded();
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  expect(game.sceneReady, isTrue);
  return game;
}

Future<void> gameTap(
  WidgetTester tester,
  ForestFlameGame game,
  Offset p, {
  bool scenery = false,
}) async {
  final rect = tester.getRect(find.byKey(const ValueKey('game_surface')));
  final layout = game.layout!;
  await tester.tapAt(rect.topLeft + layout.toScreen(p));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(430, 932),
    const Size(360, 800),
    const Size(768, 1024),
  ]) {
    testWidgets('Flame scene, transforms and location input at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance(), audio = FakeAudio();
      await tester.pumpWidget(
        ForestStarApp(prefs: prefs, initialState: GameState(), audio: audio),
      );
      final game = await enterGame(tester);
      expect(audio.events, contains(SoundEffect.select));
      expect(game.session.tab, 3);
      expect(game.locations.length, 3);
      expect(game.locations.every((location) => location.isMounted), isTrue);
      expect(game.stage.scale.x, game.stage.scale.y);
      expect(game.scenery.scale.x, game.scenery.scale.y);
      expect(game.sceneLayout!.contentRect.left, lessThanOrEqualTo(.001));
      expect(
        game.sceneLayout!.contentRect.right,
        greaterThanOrEqualTo(size.width - .001),
      );
      expect(
        game.sceneLayout!.contentRect.bottom,
        greaterThanOrEqualTo(size.height - .001),
      );
      final surface = find.byKey(const ValueKey('game_surface'));
      expect(tester.getSize(surface), size);
      expect(game.layout!.contentRect.top, greaterThanOrEqualTo(24));
      expect(
        game.layout!.contentRect.bottom,
        lessThanOrEqualTo(size.height - 20 + .001),
      );
      final element = tester.element(find.byType(GameWidget<ForestFlameGame>));
      final updates = game.updateCount;
      final textLayouts = GamePainter.textLayouts;
      final images = <ui.Image>[];
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final boundary = tester.renderObject<RenderRepaintBoundary>(surface);
        images.add((await tester.runAsync(() => boundary.toImage()))!);
      }
      final a = await tester.runAsync(() => images[0].toByteData()),
          b = await tester.runAsync(() => images[1].toByteData());
      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(
        a!.buffer.asUint8List(),
        isNot(orderedEquals(b!.buffer.asUint8List())),
      );
      expect(game.updateCount, greaterThan(updates));
      expect(
        GamePainter.textLayouts,
        textLayouts,
        reason: 'Idle animation reuses text layouts',
      );
      expect(
        identical(
          element,
          tester.element(find.byType(GameWidget<ForestFlameGame>)),
        ),
        isTrue,
      );
      for (final image in images) {
        image.dispose();
      }
      if (Platform.environment['FOREST_CAMP_CAPTURE'] == '1') {
        final boundary = tester.renderObject<RenderRepaintBoundary>(surface);
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('build/verification')
            ..createSync(recursive: true);
          File(
            '${dir.path}/flame-${size.width.toInt()}x${size.height.toInt()}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await gameTap(tester, game, const Offset(30, 500), scenery: true);
      expect(game.session.tab, 3);
      for (var i = 0; i < 3; i++) {
        await gameTap(tester, game, campSpriteBounds[i].center, scenery: true);
        expect(game.session.tab, i);
        expect(audio.scene, MusicScene.adventure);
        await gameTap(tester, game, const Offset(425, 860));
        expect(game.session.tab, 3);
        expect(audio.scene, MusicScene.camp);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 60));
      expect(audio.disposed, isTrue);
    });
  }
  testWidgets('drag release and lifecycle pause simulation', (tester) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance(), audio = FakeAudio();
    await tester.pumpWidget(
      ForestStarApp(prefs: prefs, initialState: GameState(), audio: audio),
    );
    final game = await enterGame(tester), s = game.session;
    await gameTap(tester, game, campSpriteBounds[0].center, scenery: true);
    final cancelled = await tester.startGesture(const Offset(240, 350));
    await cancelled.moveTo(const Offset(350, 480));
    await tester.pump(const Duration(milliseconds: 16));
    expect(s.dragging, isTrue);
    await cancelled.cancel();
    await tester.pump(const Duration(milliseconds: 60));
    expect(s.state.shots, 0);
    expect(s.pinball.active, isFalse);
    expect(s.dragging, isFalse);
    final gesture = await tester.startGesture(const Offset(240, 350));
    await gesture.moveTo(const Offset(350, 480));
    await tester.pump(const Duration(milliseconds: 16));
    expect(s.dragging, isTrue);
    final extra = await tester.startGesture(
      const Offset(280, 420),
      pointer: 99,
    );
    await extra.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(s.state.shots, 0);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(s.state.shots, 1);
    expect(s.pinball.active, isTrue);
    final age = s.pinball.age;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5));
    expect(audio.foreground, isFalse);
    expect(s.pinball.age, age);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(audio.foreground, isTrue);
    expect(s.pinball.age - age, lessThan(.1));
    await gameTap(tester, game, const Offset(425, 860));
    await gameTap(tester, game, const Offset(247, 845));
    await tester.pump(const Duration(milliseconds: 150));
    expect(audio.enabled, isFalse);
    expect(prefs.getString('forest_star_v1'), contains('"sound":false'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 60));
  });
}
