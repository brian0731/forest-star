import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/camp_patrol.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio, enterGame, gameTap;

void main() {
  test(
    'patrol routes stay clear of all buildings and UI while walking and turning',
    () {
      for (var slot = 0; slot < 4; slot++) {
        final walker = CampWalker(slot), directions = <int>{};
        var moving = 0, resting = 0;
        for (var frame = 0; frame < 120 * 60; frame++) {
          walker.advance(1 / 120);
          final bounds = walker.footprint;
          for (final building in campSpriteBounds) {
            expect(
              bounds.overlaps(building),
              isFalse,
              reason: 'Slot $slot at ${walker.foot}',
            );
          }
          expect(bounds.left, greaterThan(12));
          expect(bounds.right, lessThan(468));
          expect(bounds.bottom, lessThan(782));
          directions.add(walker.facing);
          if (walker.moving) {
            moving++;
          } else {
            resting++;
          }
        }
        expect(directions, {1, -1});
        expect(moving, greaterThan(0));
        expect(resting, greaterThan(0));
      }
    },
  );

  testWidgets(
    'camp follows equipped friends, pauses offscreen and never intercepts entrances',
    (tester) async {
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = Platform.environment['FOREST_PATROL_CAPTURE'] == '1';
      if (capture) {
        final bytes = File('assets/fonts/NotoSansTC.ttf').readAsBytesSync();
        for (final name in ['Ahem', 'Roboto', 'ForestUI']) {
          await (FontLoader(
            name,
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        }
      }
      SharedPreferences.setMockInitialValues({});
      final state = GameState()
        ..unlocked = List.filled(6, true)
        ..team = [0, 1, 2, 3];
      await tester.pumpWidget(
        ForestStarApp(
          prefs: await SharedPreferences.getInstance(),
          initialState: state,
          audio: FakeAudio(),
        ),
      );
      final game = await enterGame(tester),
          session = game.session,
          patrol = game.patrol;
      expect(patrol.walkers.map((w) => w.friend), [0, 1, 2, 3]);
      await tester.pump(const Duration(milliseconds: 100));
      if (capture) {
        final folder = Directory('output/review/camp-patrol-v1')
          ..createSync(recursive: true);
        for (var i = 0; i < 160; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('game_surface')),
            );
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            File(
              '${folder.path}/camp-${i.toString().padLeft(3, '0')}.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      final before = patrol.walkers.map((w) => w.foot).toList();
      session.setForeground(false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(patrol.walkers.map((w) => w.foot), before);
      session.setForeground(true);
      session.open(1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(patrol.walkers.map((w) => w.foot), before);
      session.state.equip(3, 5);
      await tester.pump(const Duration(milliseconds: 100));
      expect(patrol.walkers.map((w) => w.friend), [0, 1, 2, 5]);
      session.open(3);
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 3; i++) {
        await gameTap(tester, game, campSpriteBounds[i].center);
        expect(session.tab, i);
        session.open(3);
        await tester.pump(const Duration(milliseconds: 100));
      }
      session.state.team[3] = -1;
      await tester.pump(const Duration(milliseconds: 100));
      expect(patrol.walkers.where((w) => w.friend >= 0).length, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 120));
    },
  );
}
