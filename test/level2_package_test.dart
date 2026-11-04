import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forest_star/content_updates.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/level_data.dart';
import 'package:forest_star/main.dart';
import 'package:forest_star/storybook_ui.dart';
import 'start_screen_test.dart' show FakeAudio, enterGame, gameTap;

void main() {
  test(
    'catalog accepts >200 MiB of real media but retains per-file and bundle bounds',
    () {
      final files = [
        for (final key in ['camp-music', 'adventure-music'])
          {
            'key': key,
            'kind': 'audio',
            'path': '$key.mp3',
            'bytes': 115202325,
            'sha256': '0' * 64,
            'url': 'https://$updateHost/content/large-v1/$key.mp3',
          },
      ];
      final data = {
        'schemaVersion': 1,
        'contentVersion': 'large-v1',
        'totalBytes': 230404650,
        'files': files,
      };
      expect(
        ContentCatalog.parse(
          utf8.encode(jsonEncode(data)),
          'large-v1',
        ).totalBytes,
        greaterThan(200 * 1024 * 1024),
      );
      files[0]['bytes'] = maxContentFileBytes + 1;
      expect(
        () => ContentCatalog.parse(utf8.encode(jsonEncode(data)), 'large-v1'),
        throwsFormatException,
      );
      files[0]['bytes'] = 115202325;
      data['totalBytes'] = maxContentBundleBytes + 1;
      expect(
        () => ContentCatalog.parse(utf8.encode(jsonEncode(data)), 'large-v1'),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'stream the actual >200 MiB package, restore offline and render level 2',
    (tester) async {
      final site = Directory(Platform.environment['FOREST_LARGE_SITE']!);
      final root = Directory.systemTemp.createTempSync(
        'forest-large-update-test-',
      );
      var offline = false;
      final requests = <String>[];
      http.Client client() => MockClient.streaming((request, body) async {
        await body.drain<void>();
        if (offline) throw const SocketException('offline');
        requests.add(request.url.path);
        final file = File('${site.path}${request.url.path}');
        return http.StreamedResponse(
          file.openRead(),
          200,
          contentLength: await file.length(),
        );
      });
      final old = ContentUpdates(
        root: root,
        platform: 'ios',
        build: 20,
        clientFactory: client,
      );
      final updates = ContentUpdates(
        root: root,
        platform: 'ios',
        build: 21,
        clientFactory: client,
      );
      final restored = ContentUpdates(
        root: root,
        platform: 'ios',
        build: 21,
        clientFactory: client,
      );
      addTearDown(() async {
        old.dispose();
        updates.dispose();
        restored.dispose();
        LevelBook.current = {};
        root.deleteSync(recursive: true);
      });
      final samples = <int>[];
      updates.addListener(() => samples.add(updates.receivedBytes));
      await tester.runAsync(() async {
        await old.check();
        expect(old.phase, UpdatePhase.ready);
        expect(
          requests.length,
          1,
          reason: 'Build 20 must not fetch an unsupported large package',
        );
        await updates.check();
        expect(updates.phase, UpdatePhase.available);
        expect(updates.totalBytes, greaterThan(200 * 1024 * 1024));
        await updates.download();
        expect(updates.phase, UpdatePhase.ready);
        expect(updates.receivedBytes, updates.totalBytes);
        expect(
          samples.where((n) => n > 0 && n < updates.totalBytes),
          isNotEmpty,
        );
        expect(updates.active!.levels.keys, containsAll([1, 2]));
        expect(updates.active!.levels[2]!.health, 125);
        final state = GameState()..stage = 2;
        LevelBook.current = updates.active!.levels;
        final battle = Combat()..begin(state);
        battle.spawnTimer = 0;
        battle.tick(.01);
        expect(battle.enemies.single.hp, 36);
        expect(battle.enemies.single.speed, 27);
        await StoryArt.instance.load(content: updates.active);
        expect(StoryArt.instance.images['field-level2']!.width, 804);
        offline = true;
        await restored.check();
        expect(restored.phase, UpdatePhase.offline);
        expect(restored.active!.offer.version, 'forest-level2-v1');
      });
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = File('assets/fonts/NotoSansTC.ttf').readAsBytesSync();
      for (final name in ['Ahem', 'Roboto', 'ForestUI']) {
        await (FontLoader(
          name,
        )..addFont(Future.value(ByteData.sublistView(font)))).load();
      }
      final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
      await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('level2-capture'),
          child: ForestStarApp(
            prefs: prefs,
            initialState: GameState()..stage = 2,
            audio: FakeAudio(),
          ),
        ),
      );
      final game = await enterGame(tester);
      Future<void> capture(String name) async {
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('level2-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('output/review/level2').createSync(recursive: true);
          File(
            'output/review/level2/$name.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('camp');
      await gameTap(tester, game, campSpriteBounds[2].center);
      await gameTap(tester, game, const Offset(160, 780));
      for (var i = 0; i < 35; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await capture('battle');
      expect(game.session.combat.stage, 2);
      expect(game.session.combat.active, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: Platform.environment['FOREST_LARGE_SITE'] == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
