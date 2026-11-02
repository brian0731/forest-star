import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/main.dart';
import 'package:forest_star/rewarded_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio, enterGame;
import 'rewarded_ads_test.dart' show FakeBackend;

void main() {
  for (final device in ['iphone', 'ipad']) {
    testWidgets(
      'Export real $device gameplay for App Store artwork',
      (tester) async {
        final phone = device == 'iphone';
        tester.view.physicalSize = phone
            ? const Size(1179, 2556)
            : const Size(2732, 2048);
        tester.view.devicePixelRatio = phone ? 3 : 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final bytes = File('assets/fonts/NotoSansTC.ttf').readAsBytesSync();
        for (final family in ['Ahem', 'Roboto', 'ForestUI']) {
          await (FontLoader(
            family,
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        }
        SharedPreferences.setMockInitialValues({});
        final state = GameState()
          ..unlocked = List.filled(6, true)
          ..levels = [3, 3, 3, 3, 3, 3]
          ..evolutions = [1, 1, 1, 1, 1, 1]
          ..stage = 5
          ..clearedStage = 4
          ..team = [0, 1, 2, 3];
        final ads = RewardedAdsController(const AdSettings(), FakeBackend());
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('store_capture_root'),
            child: ForestStarApp(
              prefs: await SharedPreferences.getInstance(),
              initialState: state,
              audio: FakeAudio(),
              ads: ads,
            ),
          ),
        );
        final game = await enterGame(tester);
        final folder = Directory('output/review/app-store-20261030/$device')
          ..createSync(recursive: true);
        Future<void> frames(int count) async {
          for (var i = 0; i < count; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        }

        Future<void> shot(String name) async {
          await tester.pump();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('store_capture_root')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: phone ? 3 : 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            File(
              '${folder.path}/$name.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        await frames(30);
        await shot('01-camp');
        game.session.open(0);
        await frames(15);
        game.session.launch();
        await frames(12);
        await shot('02-pinball');
        // Finish the real shot before navigating to the companion page.
        await frames(220);
        game.session.open(1);
        game.session.selected = 2;
        await frames(18);
        await shot('03-companions');
        game.session.open(2);
        await frames(18);
        game.session.tap(const Offset(160, 780));
        var bestAction = -1;
        for (var frame = 0; frame < 165; frame++) {
          await frames(1);
          final combat = game.session.combat;
          final action = combat.enemies.length * 10 + combat.shots.length;
          if (action > bestAction) {
            bestAction = action;
            await shot('04-guard');
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
      skip: Platform.environment['FOREST_STORE_CAPTURE'] != '1',
    );
  }
}
