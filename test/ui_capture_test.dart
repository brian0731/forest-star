import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/main.dart';
import 'package:forest_star/forest_flame_game.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio, enterGame, gameTap;

void main() {
  final stage = Platform.environment['FOREST_UI_CAPTURE'];
  testWidgets('Capture real game pages and animation', (tester) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fontBytes = File('assets/fonts/NotoSansTC.ttf').readAsBytesSync();
    for (final name in ['Ahem', 'Roboto', 'ForestUI']) {
      await (FontLoader(
        name,
      )..addFont(Future.value(ByteData.sublistView(fontBytes)))).load();
    }
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = GameState();
    if (stage == 'guard-horizontal' || stage == 'navigation') {
      state.awardGrowth(3, 40);
      state.equip(3, 3);
    }
    final folder = Directory('output/review/$stage')
      ..createSync(recursive: true);
    Future<void> capture(String filename, Finder finder) async {
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '${folder.path}/$filename.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    // A local boundary provides identical 480 x 900 captures for the splash too.
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture_root'),
        child: ForestStarApp(
          prefs: prefs,
          initialState: state,
          audio: FakeAudio(),
        ),
      ),
    );
    final splash = find.byKey(const ValueKey('capture_root'));
    // Resolve splash artwork before exporting its first frame.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 100));
    await capture('00-start', splash);
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await capture('start-${i.toString().padLeft(3, '0')}', splash);
    }
    final ForestFlameGame game = await enterGame(tester);
    final surface = find.byKey(const ValueKey('game_surface'));
    Future<void> page(String name, String shot) async {
      await tester.pump(const Duration(milliseconds: 100));
      await capture(shot, surface);
      if (stage == 'frames') return;
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await capture('$name-${i.toString().padLeft(3, '0')}', surface);
      }
    }

    await page('camp', '01-camp');
    await gameTap(tester, game, campSpriteBounds[0].center);
    await page('pinball', '02-pinball');
    await gameTap(tester, game, const Offset(180, 862));
    await page('companions', '03-companions');
    await gameTap(tester, game, const Offset(300, 862));
    await capture('04-guard', surface);
    await gameTap(tester, game, const Offset(160, 780));
    for (var i = 0; i < 34; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await page('guard', '05-guard-active');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 60));
  }, skip: stage == null);
}
