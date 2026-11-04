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
      await tester.runAsync(() => StoryArt.instance.load());
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
  for (final size in [
    const Size(393, 852),
    const Size(360, 640),
    const Size(768, 1024),
  ]) {
    testWidgets('growth backgrounds fill screen and safe insets at $size', (
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
      await tester.pumpWidget(
        ForestStarApp(
          prefs: await SharedPreferences.getInstance(),
          initialState: GameState(),
          audio: FakeAudio(),
        ),
      );
      final game = await enterGame(tester), session = game.session;
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('game_surface')),
      );
      final before = (await tester.runAsync(() => boundary.toImage()))!;
      final pixelsBefore = (await tester.runAsync(
        () => before.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      before.dispose();
      for (final evolved in [false, true]) {
        session.queueGrowth(
          GrowthResult(0, 36, 1, 2, 0, evolved ? 1 : 0, false),
        );
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(session.celebration?.evolved, evolved);
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final pixels = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        // The overlay must reach every screen corner, including areas outside
        // the fitted game frame and the simulated notch / home indicator.
        for (final point in [
          const Offset(3, 3),
          Offset(size.width - 4, 3),
          Offset(3, size.height - 4),
          Offset(size.width - 4, size.height - 4),
        ]) {
          final offset =
              (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
          for (var channel = 0; channel < 3; channel++) {
            final expected =
                pixelsBefore.getUint8(offset + channel) * .07 +
                [16, 47, 50][channel] * .93;
            expect(
              pixels.getUint8(offset + channel),
              closeTo(expected, 4),
              reason:
                  'Screen corner $point, channel $channel, evolved=$evolved',
            );
          }
        }
        if (Platform.environment['FOREST_GROWTH_CAPTURE'] == '1') {
          final directory = Directory('output/review/growth-fullscreen')
            ..createSync(recursive: true);
          final png = (await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.png),
          ))!;
          File(
            '${directory.path}/${evolved ? 'evolution' : 'upgrade'}-${size.width.toInt()}x${size.height.toInt()}.png',
          ).writeAsBytesSync(png.buffer.asUint8List());
        }
        image.dispose();
        await tester.tapAt(game.layout!.toScreen(const Offset(240, 737)));
        await tester.pump(const Duration(milliseconds: 16));
        expect(session.celebration, isNull);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  }
}
