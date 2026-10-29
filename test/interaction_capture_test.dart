import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio, enterGame, gameTap;

void main() {
  testWidgets(
    'Capture actual press, aim, reward and combat interactions',
    (tester) async {
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = File('assets/fonts/NotoSansTC.ttf').readAsBytesSync();
      for (final name in ['Ahem', 'Roboto', 'ForestUI']) {
        await (FontLoader(
          name,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
      SharedPreferences.setMockInitialValues({});
      final state = GameState()
        ..unlocked = List.filled(6, true)
        ..levels = List.filled(6, 4)
        ..team = [0, 1, 2, 3];
      await tester.pumpWidget(
        ForestStarApp(
          prefs: await SharedPreferences.getInstance(),
          initialState: state,
          audio: FakeAudio(),
        ),
      );
      final game = await enterGame(tester);
      final folder = Directory('output/review/interaction-v1')
        ..createSync(recursive: true);
      final counts = <String, int>{};
      Future<void> frames(String name, int count) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(const Duration(milliseconds: 80));
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('game_surface')),
            );
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final index = counts[name] ?? 0;
            File(
              '${folder.path}/$name-${index.toString().padLeft(3, '0')}.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            counts[name] = index + 1;
            image.dispose();
          });
        }
      }

      await gameTap(tester, game, campSpriteBounds[0].center);
      await frames('navigation', 5);
      final press = await tester.startGesture(const Offset(400, 780));
      await frames('navigation', 5);
      await press.up();
      await frames('navigation', 15);
      final nav = await tester.startGesture(const Offset(180, 852));
      await frames('navigation', 3);
      await nav.up();
      await frames('navigation', 4);
      await gameTap(tester, game, const Offset(385, 260));
      await frames('navigation', 9);
      await gameTap(tester, game, const Offset(60, 852));
      await frames('pinball', 4);
      final aim = await tester.startGesture(const Offset(240, 350));
      await aim.moveTo(const Offset(330, 450));
      await frames('pinball', 7);
      await aim.moveTo(const Offset(210, 455));
      await frames('pinball', 5);
      await aim.up();
      await frames('pinball', 140);
      await gameTap(tester, game, const Offset(300, 852));
      await frames('guard', 6);
      await gameTap(tester, game, const Offset(160, 780));
      await frames('guard', 100);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 120));
    },
    skip: Platform.environment['FOREST_INTERACTION_CAPTURE'] != '1',
  );
}
