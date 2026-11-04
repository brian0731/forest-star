import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/content_updates.dart';
import 'package:forest_star/storybook_ui.dart';
import 'fixtures/sky_guard_pack.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SkyGuardPack pack;
  final services = <ContentUpdates>[];
  ContentUpdates service({int build = 23}) {
    final updates = pack.updates(root, build: build);
    services.add(updates);
    return updates;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('forest-sky-pack-');
    pack = SkyGuardPack();
  });
  tearDown(() async {
    for (final updates in services) {
      updates.dispose();
    }
    services.clear();
    await root.delete(recursive: true);
  });

  test(
    'actual media verifies, activates atomically and restores offline',
    () async {
      final updates = service();
      await updates.check();
      expect(updates.phase, UpdatePhase.available);
      await updates.download();
      expect(updates.phase, UpdatePhase.ready);
      expect(updates.receivedBytes, pack.catalog.totalBytes);
      expect(updates.active!.catalog.files, hasLength(21));
      expect(
        updates.active!.effectPaths.keys,
        unorderedEquals(remoteEffectKeys.keys),
      );
      expect(
        updates.active!.filePath('camp-music-v2'),
        endsWith('sky-camp-v2.mp3'),
      );
      expect(
        updates.active!.filePath('adventure-music-v2'),
        endsWith('sky-adventure-v2.mp3'),
      );
      expect(updates.active!.filePath('camp'), isNotNull);
      expect(updates.active!.filePath('field-level2'), isNotNull);
      expect(updates.active!.levels.keys, contains(2));
      pack.offline = true;
      final restored = service();
      await restored.check();
      expect(restored.phase, UpdatePhase.offline);
      expect(restored.active!.catalog.version, SkyGuardPack.version);
      for (final effect in restored.active!.effectPaths.values) {
        expect(File(effect).existsSync(), isTrue);
      }
      await StoryArt.instance.load(content: restored.active);
      for (var stage = 3; stage <= 10; stage++) {
        expect(StoryArt.instance.battleFieldKey(stage), 'field-level$stage');
      }
      await StoryArt.instance.load(reset: true);
      expect(StoryArt.instance.battleFieldKey(3), 'field');
    },
  );

  test(
    'old clients ignore the new pack and corrupted media never activates',
    () async {
      await service(build: 22).check();
      expect(pack.requests, [updateManifestUri]);
      pack.corrupt = true;
      final updates = service();
      await updates.check();
      await updates.download();
      expect(updates.active, isNull);
      expect(updates.phase, UpdatePhase.offline);
      expect(File('${root.path}/active.json').existsSync(), isFalse);
    },
  );

  test(
    'Flutter asset bundle contains no server music, scenes or soft effects',
    () async {
      final assets = (await AssetManifest.loadFromAssetBundle(
        rootBundle,
      )).listAssets();
      expect(assets, contains('assets/audio/magicCharge.wav'));
      expect(assets, contains('assets/audio/magicImpact.wav'));
      expect(
        assets.where((path) => path.startsWith('assets/audio/')),
        hasLength(2),
      );
      expect(assets.any((path) => path.contains('guard-stage-')), isFalse);
      expect(assets.any((path) => path.endsWith('.mid')), isFalse);
      expect(assets.any((path) => path.startsWith('server/')), isFalse);
    },
  );
}
