import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio, enterGame;

void main() {
  testWidgets(
    'real basket reward opens a perspective evolution popup and dismisses',
    (tester) async {
      final capture = Platform.environment['FOREST_GROWTH_CAPTURE'] == '1';
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (capture) {
        final bytes = File('assets/fonts/NotoSansTC.ttf').readAsBytesSync();
        for (final name in ['Ahem', 'Roboto', 'ForestUI']) {
          await (FontLoader(
            name,
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        }
      }
      SharedPreferences.setMockInitialValues({});
      // A near-threshold test save makes an actual shot reach evolution promptly.
      final state = GameState()
        ..levels = List.filled(6, 2)
        ..growth = List.filled(6, 47)
        ..unlocked = List.filled(6, true);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('growth_capture'),
          child: ForestStarApp(
            prefs: await SharedPreferences.getInstance(),
            initialState: state,
            audio: FakeAudio(),
          ),
        ),
      );
      final game = await enterGame(tester), session = game.session;
      session.open(0);
      final directory = Directory('output/review/growth-v1');
      if (capture) directory.createSync(recursive: true);
      Future<void> snapshot(String name) async {
        if (!capture) return;
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('growth_capture')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${directory.path}/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pump(const Duration(milliseconds: 16));
      await snapshot('pinball-ready');
      session.launch();
      for (var frame = 0; frame < 180 && session.celebration == null; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (frame < 24)
          await snapshot('pinball-${frame.toString().padLeft(3, '0')}');
      }
      expect(session.pinball.active, isFalse);
      expect(session.celebration, isNotNull);
      final recipient = session.pinball.lastBucket;
      expect(session.celebration!.friend, recipient);
      expect(session.celebration!.evolved, isTrue);
      expect(state.evolutions[recipient], greaterThan(0));
      for (var id = 0; id < 6; id++) {
        if (id == recipient) continue;
        expect(state.growth[id], 47);
        expect(state.levels[id], 2);
      }
      session.tap(const Offset(180, 865));
      expect(session.tab, 0);
      if (capture) {
        for (var frame = 0; frame < 36; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
          await snapshot('evolution-${frame.toString().padLeft(3, '0')}');
        }
      } else {
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      expect(session.celebration, isNotNull);
      // The on-screen continue action works and leaves the awarded state intact.
      await tester.tapAt(game.layout!.toScreen(const Offset(240, 737)));
      await tester.pump(const Duration(milliseconds: 16));
      expect(session.celebration, isNull);
      session.open(1);
      await tester.pump(const Duration(milliseconds: 100));
      await snapshot('companion-growth');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
