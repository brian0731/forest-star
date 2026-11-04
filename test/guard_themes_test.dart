import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/content_updates.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/guard_themes.dart';
import 'package:forest_star/main.dart';
import 'package:forest_star/storybook_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio, enterGame;
import 'fixtures/sky_guard_pack.dart';

void main() {
  test(
    'new scenes and music remain compatible with verified server catalogs',
    () {
      const version = 'sky-v2';
      final files = [
        for (var stage = 3; stage <= 10; stage++)
          {
            'key': 'field-level$stage',
            'kind': 'image',
            'path': 'guard-$stage.webp',
          },
        for (final scene in ['camp', 'adventure'])
          {'key': '$scene-music-v2', 'kind': 'audio', 'path': '$scene.mp3'},
      ];
      final catalog = ContentCatalog.parse(
        utf8.encode(
          jsonEncode({
            'schemaVersion': 1,
            'contentVersion': version,
            'totalBytes': files.length * 100,
            'files': [
              for (final file in files)
                {
                  ...file,
                  'bytes': 100,
                  'sha256': '0' * 64,
                  'url': 'https://$updateHost/content/$version/${file['path']}',
                },
            ],
          }),
        ),
        version,
      );
      expect(catalog.files, hasLength(10));
      expect(GuardTheme.forStage(0).stage, 1);
      expect(GuardTheme.forStage(100).stage, 10);
    },
  );

  testWidgets(
    'all eight scenes render during combat with aligned roads and distinct weather',
    (tester) async {
      final capture =
          Platform.environment['FOREST_GUARD_THEMES_CAPTURE'] == '1';
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
      await tester.runAsync(() async {
        final root = await Directory.systemTemp.createTemp('forest-guard-art-');
        final updates = SkyGuardPack().updates(root);
        addTearDown(() async {
          updates.dispose();
          await root.delete(recursive: true);
        });
        await updates.check();
        await updates.download();
        expect(updates.active, isNotNull);
        await StoryArt.instance.load(content: updates.active);
      });
      final art = StoryArt.instance;
      final hashes = <String>{};
      for (var stage = 3; stage <= 10; stage++) {
        final key = art.battleFieldKey(stage);
        expect(key, 'field-level$stage');
        expect(art.images[key]!.width, 804);
        expect(art.images[key]!.height, 766);
        final bytes = File(
          'server/updates/media/forest-sky-guard-v2/guard-stage-$stage.webp',
        ).readAsBytesSync();
        hashes.add(sha256.convert(bytes).toString());
      }
      expect(hashes, hasLength(8));
      expect(
        GuardTheme.all.skip(2).map((theme) => theme.weather).toSet(),
        hasLength(8),
      );
      final state = GameState()
        ..team = [0, 1, 2, 3]
        ..unlocked[3] = true;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('guard_capture'),
          child: ForestStarApp(
            prefs: await SharedPreferences.getInstance(),
            initialState: state,
            audio: FakeAudio(),
          ),
        ),
      );
      final game = await enterGame(tester);
      final session = game.session;
      session.open(2);
      for (var stage = 3; stage <= 10; stage++) {
        state.stage = stage;
        session.combat.begin(state);
        session.combat.spawnTimer = 999;
        session.combat.enemies = List.generate(
          4,
          (lane) => Enemy(lane, lane, 10000, 1, lane % 3, false),
        );
        for (var frame = 0; frame < 12; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(session.combat.stage, stage);
        expect(session.combat.active, isTrue);
        expect(tester.takeException(), isNull);
        if (capture) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('guard_capture')),
            );
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final out = Directory('output/review/guard-stages-v1')
              ..createSync(recursive: true);
            await File(
              '${out.path}/stage-$stage.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        session.combat.active = false;
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
