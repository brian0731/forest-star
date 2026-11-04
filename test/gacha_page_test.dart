import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/gacha_page.dart';
import 'package:forest_star/gacha_store.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/game_session.dart';
import 'package:forest_star/main.dart';
import 'package:forest_star/notice_board.dart';
import 'package:forest_star/storybook_ui.dart';
import 'package:forest_star/companion_layout.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gacha_test.dart' show MemoryWallet, FakeBilling;
import 'start_screen_test.dart' show FakeAudio, enterGame, gameTap;

class PetRandom implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => true;
}

void main() {
  final capture = Platform.environment['FOREST_GACHA_CAPTURE'] == '1';
  for (final spec in [
    (const Size(393, 852), 1.0),
    (const Size(360, 640), 2.0),
    (const Size(768, 1024), 1.0),
  ]) {
    testWidgets('gacha page draw, odds and scrolling ${spec.$1} ${spec.$2}', (
      tester,
    ) async {
      tester.view.physicalSize = spec.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (capture) {
        final bytes = File('assets/fonts/NotoSansTC.ttf').readAsBytesSync();
        for (final name in ['Ahem', 'Roboto', 'ForestUI'])
          await (FontLoader(
            name,
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        final sdk = Platform.environment['FLUTTER_ROOT'];
        if (sdk != null) {
          final icons = File(
            '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          );
          if (icons.existsSync())
            await (FontLoader('MaterialIcons')..addFont(
                  Future.value(ByteData.sublistView(icons.readAsBytesSync())),
                ))
                .load();
        }
      }
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = GameSession(GameState(), prefs, FakeAudio());
      final controller = GachaController(
        session,
        random: PetRandom(),
        clock: () => DateTime.utc(2026, 11, 4),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture_gacha'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'ForestUI'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(spec.$2)),
              child: child!,
            ),
            home: GachaPage(controller: controller),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      for (var i = 0; i < 5; i++)
        await tester.pump(const Duration(milliseconds: 16));
      Future<void> shot(String name) async {
        if (!capture) return;
        final folder = Directory('output/review/gacha-v1')
          ..createSync(recursive: true);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture_gacha')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${folder.path}/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await shot('gacha-${spec.$1.width.toInt()}-${spec.$2}');
      expect(tester.takeException(), isNull);
      final draw = find.byKey(const ValueKey('gacha_draw'));
      await tester.ensureVisible(draw);
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(draw);
      });
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      if (capture && spec.$1.width == 393) {
        for (var i = 0; i < 24; i++) {
          await tester.pump(const Duration(milliseconds: 90));
          await shot('spin-${i.toString().padLeft(3, '0')}');
        }
      }
      // Store persistence resumes on the real event loop; advance animation
      // frames only after that continuation has had an opportunity to run.
      for (
        var i = 0;
        i < 30 && find.byKey(const ValueKey('gacha_result')).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump();
      expect(session.state.unlocked[6], isTrue);
      expect(session.state.freeDrawsUsed, 1);
      expect(find.byKey(const ValueKey('gacha_result')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('gacha_result')));
      await tester.pump();
      await shot('result-${spec.$1.width.toInt()}-${spec.$2}');
      expect(find.text('新夥伴 · 花刺蝟'), findsOneWidget);
      final odds = find.text('完整獎池與機率');
      await tester.ensureVisible(odds);
      await tester.pump();
      await tester.tap(odds);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('星願獎池與機率'), findsOneWidget);
      expect(find.text('1.5%'), findsNWidgets(20));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
      controller.dispose();
      session.dispose();
    });
  }
  testWidgets('shop shows real price and odds before opening native billing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final billing = FakeBilling();
    final api = GachaApi(
      client: MockClient(
        (_) async => http.Response(
          '{"tickets":0,"platforms":["ios"],"productId":"forest_star_draws_10","packDraws":10,"rewards":[],"latestSequence":0}',
          200,
        ),
      ),
    );
    final session = GameSession(
      GameState()
        ..drawDay = 20261104
        ..freeDrawsUsed = 5,
      prefs,
      FakeAudio(),
    );
    final controller = GachaController(
      session,
      billing: billing,
      api: api,
      storage: MemoryWallet(),
      clock: () => DateTime.utc(2026, 11, 4),
    );
    await tester.runAsync(() => controller.initialize());
    await tester.pumpWidget(
      MaterialApp(home: GachaPage(controller: controller)),
    );
    await tester.pump();
    final buy = find.byKey(const ValueKey('gacha_buy'));
    await tester.ensureVisible(buy);
    await tester.pump();
    await tester.tap(buy);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('HK\$ 8.00 · 一次性消耗型商品'), findsOneWidget);
    expect(find.textContaining('寵物 30%（20 隻各 1.5%）'), findsOneWidget);
    expect(billing.buys, 0);
    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(billing.buys, 0);
    await tester.tap(buy);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      await tester.tap(find.text('繼續 · HK\$ 8.00'));
    });
    await tester.pump();
    expect(billing.buys, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    controller.dispose();
    session.dispose();
    await billing.stream.close();
  });
  testWidgets(
    'camp opens gacha; collection pages select, equip and render new pets',
    (tester) async {
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.runAsync(() => StoryArt.instance.load());
      final state = GameState()..unlocked[6] = true;
      final notices = NoticeBoardController(prefs: prefs);
      await tester.pumpWidget(
        ForestStarApp(
          prefs: prefs,
          initialState: state,
          audio: FakeAudio(),
          noticeBoard: notices,
        ),
      );
      final game = await enterGame(tester);
      await tester.tap(find.byTooltip('星願轉珠 · 每日免費 5 次'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GachaPage), findsOneWidget);
      expect(game.session.foreground, isFalse);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(game.session.foreground, isTrue);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gameTap(tester, game, campSpriteBounds[1].center);
      expect(game.session.tab, 1);
      await gameTap(tester, game, CompanionLayout.next.center);
      expect(game.session.selected, 6);
      await gameTap(tester, game, const Offset(415, 779));
      expect(game.session.state.team[3], 6);
      for (var i = 0; i < 4; i++)
        await gameTap(tester, game, CompanionLayout.next.center);
      expect(game.session.selected, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      notices.dispose();
    },
  );
}
