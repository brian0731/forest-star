import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/main.dart';
import 'package:forest_star/storybook_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio, enterGame, gameTap;

void main() {
  final capture = Platform.environment['FOREST_ULTIMATE_CAPTURE'] == '1';
  Future<void> fonts() async {
    if (!capture) return;
    final bytes = File('assets/fonts/NotoSansTC.ttf').readAsBytesSync();
    for (final name in ['Ahem', 'Roboto', 'ForestUI']) {
      await (FontLoader(
        name,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk != null) {
      final file = File(
        '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (file.existsSync()) {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.sublistView(file.readAsBytesSync())),
            ))
            .load();
      }
    }
  }

  Future<void> snapshot(WidgetTester tester, String name) async {
    if (!capture) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('ultimate_capture')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = Directory('output/review/ultimate-v1')
        ..createSync(recursive: true);
      await File(
        '${out.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'four real lane buttons cast once, six spell cinematics finish and gameplay resumes',
    (tester) async {
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await fonts();
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => StoryArt.instance.load());
      final state = GameState()
        ..unlocked = List.filled(friends.length, true)
        ..team = [0, 1, 2, 3]
        ..stage = 9;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('ultimate_capture'),
          child: ForestStarApp(
            prefs: await SharedPreferences.getInstance(),
            initialState: state,
            audio: FakeAudio(),
          ),
        ),
      );
      final game = await enterGame(tester), session = game.session;
      session.open(2);
      session.combat.begin(state);
      session.combat.spawnTimer = 999;
      session.combat.enemies = List.generate(
        4,
        (lane) =>
            Enemy(lane, lane, 100000, 10, lane % 3, lane == 3)
              ..x = 290 + lane * 25.0,
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await snapshot(tester, 'battle-ready');
      for (var id = 0; id < 6; id++) {
        final lane = id % 4;
        if (id >= 4) {
          state.team[lane] = id;
          session.combat.begin(state);
          session.combat.spawnTimer = 999;
          session.combat.enemies = List.generate(
            4,
            (lane) => Enemy(lane, lane, 100000, 10, lane % 3, false)..x = 310,
          );
        }
        final kind = friends[id].ultimateKind.name;
        await gameTap(tester, game, BattleLayout.ultimateButton(lane).center);
        expect(session.ultimate, isNotNull);
        expect(session.ultimate!.kind, friends[id].ultimateKind);
        expect(find.byTooltip('星願轉珠 · 每日免費 5 次'), findsNothing);
        expect(session.combat.ultimateUsed[lane], isTrue);
        final positions = session.combat.enemies
            .map((enemy) => enemy.x)
            .toList();
        final hp = session.combat.enemies.map((enemy) => enemy.hp).toList();
        await gameTap(
          tester,
          game,
          BattleLayout.ultimateButton((lane + 1) % 4).center,
        );
        expect(session.ultimate!.lane, lane);
        for (var frame = 0; frame < 34; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (frame == 6) {
            expect(
              session.combat.enemies.map((enemy) => enemy.x).toList(),
              positions,
            );
            expect(
              session.combat.enemies.map((enemy) => enemy.hp).toList(),
              hp,
            );
          }
          if (frame % 2 == 0) {
            await snapshot(tester, '$kind-${frame.toString().padLeft(2, '0')}');
          }
          expect(tester.takeException(), isNull);
        }
        expect(session.ultimate, isNull);
        expect(session.ultimatePlaying.value, isFalse);
        expect(find.byTooltip('星願轉珠 · 每日免費 5 次'), findsOneWidget);
        expect(session.combat.enemies.first.hp, lessThan(hp.first));
        expect(
          session.controlAt(BattleLayout.ultimateButton(lane).center),
          isNull,
        );
        expect(session.castUltimate(lane), isFalse);
        if (id == 3) {
          expect(session.combat.ultimateUsed, [true, true, true, true]);
        }
      }
      await snapshot(tester, 'battle-used');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  for (final size in [
    const Size(393, 852),
    const Size(768, 1024),
    const Size(1024, 768),
  ]) {
    testWidgets('magic fills physical viewport and safe insets at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => StoryArt.instance.load());
      final state = GameState();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('ultimate_capture'),
          child: ForestStarApp(
            prefs: await SharedPreferences.getInstance(),
            initialState: state,
            audio: FakeAudio(),
          ),
        ),
      );
      final game = await enterGame(tester), session = game.session;
      session.open(2);
      session.combat.begin(state);
      session.combat.spawnTimer = 999;
      session.combat.enemies = [Enemy(0, 0, 10000, 0, 0, false)];
      expect(session.castUltimate(0), isTrue);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('ultimate_capture')),
        );
        final image = await boundary.toImage();
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        for (final point in [
          const Offset(2, 2),
          Offset(size.width - 3, 2),
          Offset(2, size.height - 3),
          Offset(size.width - 3, size.height - 3),
        ]) {
          final offset =
              (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
          expect(
            bytes[offset],
            lessThan(100),
            reason: 'cinematic must cover outer margin at $point',
          );
          expect(bytes[offset + 1], lessThan(120));
          expect(bytes[offset + 2], lessThan(130));
        }
        image.dispose();
      });
      expect(session.ultimate!.age, closeTo(.8, .02));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  }
}
