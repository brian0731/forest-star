import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/notice_board.dart';
import 'package:forest_star/start_scene.dart';
import 'package:forest_star/start_screen.dart';
import 'package:forest_star/storybook_ui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final capture = Platform.environment['FOREST_START_CAPTURE'] == '1';
  for (final spec in [
    (const Size(393, 852), 1.0, false),
    (const Size(360, 640), 1.0, false),
    (const Size(768, 1024), 1.0, false),
    (const Size(360, 640), 2.0, true),
  ]) {
    testWidgets(
      'Start scene, native notice and input ${spec.$1} scale ${spec.$2}',
      (tester) async {
        tester.view.physicalSize = spec.$1;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        if (capture) {
          final font = File('assets/fonts/NotoSansTC.ttf').readAsBytesSync();
          for (final family in ['Ahem', 'Roboto', 'ForestUI']) {
            await (FontLoader(
              family,
            )..addFont(Future.value(ByteData.sublistView(font)))).load();
          }
          final sdk = Platform.environment['FLUTTER_ROOT'];
          if (sdk != null) {
            final icons = File(
              '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            );
            if (icons.existsSync()) {
              await (FontLoader('MaterialIcons')..addFont(
                    Future.value(ByteData.sublistView(icons.readAsBytesSync())),
                  ))
                  .load();
            }
          }
        }
        SharedPreferences.setMockInitialValues({});
        final notices = NoticeBoardController(
          prefs: await SharedPreferences.getInstance(),
          clientFactory: () => MockClient(
            (_) async => http.Response(
              '<h2>今天，也一起守護森林！</h2><p>歡迎回到森星小隊。點點夥伴，看看牠們可愛的回應。</p>'
              '<ul><li>彈珠屋：收集成長分。</li><li>守衛：編排四條隊伍。</li></ul>',
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            ),
          ),
        );
        await tester.runAsync(() async {
          await notices.refresh();
          await StoryArt.instance.load();
        });
        var started = 0, tutorial = 0;
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('start_capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'ForestUI'),
              home: MediaQuery(
                data: MediaQueryData(
                  size: spec.$1,
                  padding: const EdgeInsets.only(top: 24, bottom: 20),
                  textScaler: TextScaler.linear(spec.$2),
                  disableAnimations: spec.$3,
                ),
                child: Scaffold(
                  body: StartScreen(
                    notices: notices,
                    onStart: () => started++,
                    onTutorial: () => tutorial++,
                    onPrivacy: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        final scene = tester
            .widget<GameWidget<StartForestScene>>(
              find.byType(GameWidget<StartForestScene>),
            )
            .game!;
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 70)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
        expect(scene.sceneReady, isTrue);
        expect(scene.companions.length, 3);
        expect(scene.paused, spec.$3);
        if (!spec.$3) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(scene.paused, isTrue);
          final age = scene.age;
          await tester.pump(const Duration(milliseconds: 200));
          expect(scene.age, age);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump(const Duration(milliseconds: 16));
          expect(scene.paused, isFalse);
        }
        if (!spec.$3) {
          final surface = tester.getRect(
            find.byKey(const ValueKey('start_companions')),
          );
          final companion = scene.companions.last;
          final point =
              surface.topLeft +
              Offset(
                scene.grove.position.x +
                    companion.position.x * scene.grove.scale.x,
                scene.grove.position.y +
                    (companion.position.y - companion.size.y * .5) *
                        scene.grove.scale.y,
              );
          await tester.tapAt(point);
          await tester.pump(const Duration(milliseconds: 16));
          await tester.pump(const Duration(milliseconds: 16));
          expect(scene.activeBursts, greaterThan(0));
          expect(companion.hopping, isTrue);
        }

        Future<void> screenshot(String name) async {
          if (!capture) return;
          final folder = Directory('output/review/start-v2')
            ..createSync(recursive: true);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('start_capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '${folder.path}/$name.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await screenshot('start-${spec.$1.width.toInt()}-${spec.$2}');
        if (spec.$1.width == 393 && capture) {
          for (var i = 0; i < 24; i++) {
            await tester.pump(const Duration(milliseconds: 70));
            await screenshot('frame-${i.toString().padLeft(3, '0')}');
          }
        }
        await tester.tap(find.byKey(const ValueKey('start_notice_board')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(scene.paused, isTrue);
        expect(find.byTooltip('更新公告'), findsOneWidget);
        expect(find.byType(NoticeHtml), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await screenshot('notice-${spec.$1.width.toInt()}-${spec.$2}');
        await tester.tap(find.byTooltip('更新公告'));
        await tester.pump();
        await tester.tap(find.byTooltip('關閉公告'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(scene.paused, spec.$3);
        await tester.tap(find.byKey(const ValueKey('start_tutorial')));
        expect(tutorial, 1);
        await tester.tap(find.text('開始冒險'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(started, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
        notices.dispose();
      },
    );
  }
}
