import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_star/content_updates.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/level_data.dart';
import 'package:forest_star/storybook_ui.dart';

List<int> encode(Object data) => utf8.encode(jsonEncode(data));
String digest(List<int> bytes) => sha256.convert(bytes).toString();

Map<String, dynamic> levelData(String version) => {
  'schemaVersion': 1,
  'contentVersion': version,
  'levels': [
    {
      'id': 1,
      'lanes': 4,
      'baseHealth': 180,
      'waves': [
        for (var i = 0; i < 3; i++)
          {
            'count': 2,
            'enemyHealth': 90,
            'enemySpeed': 12,
            'spawnIntervalSeconds': .5,
            'bossLast': i == 2,
          },
      ],
    },
  ],
};

class UpdateFixture {
  UpdateFixture(
    this.version, {
    bool images = false,
    bool invalidImage = false,
  }) {
    files['levels.json'] = encode(levelData(version));
    if (images) {
      files['camp.png'] = invalidImage
          ? [1, 2, 3]
          : base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFUlEQVR4nGPUWBDwn4GBgYEJRIAwAB+AAhvNjKjTAAAAAElFTkSuQmCC',
            );
    }
    final entries = [
      for (final file in files.entries)
        {
          'key': file.key == 'levels.json' ? 'levels' : 'camp',
          'kind': file.key == 'levels.json' ? 'levels' : 'image',
          'path': file.key,
          'bytes': file.value.length,
          'sha256': digest(file.value),
          'url': 'https://$updateHost/content/$version/${file.key}',
        },
    ];
    catalog = encode({
      'schemaVersion': 1,
      'contentVersion': version,
      'totalBytes': files.values.fold<int>(0, (n, b) => n + b.length),
      'files': entries,
    });
    content = {
      'enabled': true,
      'version': version,
      'minimumClientBuild': {'ios': 20, 'android': 20},
      'catalogBytes': catalog.length,
      'catalogSha256': digest(catalog),
      'catalogUrl': 'https://$updateHost/content/$version/catalog.json',
    };
  }
  final String version;
  final files = <String, List<int>>{};
  late final List<int> catalog;
  late final Map<String, dynamic> content;
  bool enabled = true, corrupt = false, offline = false;
  int requests = 0;
  Map<String, dynamic> get manifest => {
    'schemaVersion': 1,
    'configRevision': 1,
    'publishedAt': DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    'expiresAt': DateTime.now()
        .toUtc()
        .add(const Duration(days: 30))
        .toIso8601String(),
    'platforms': {
      for (final p in ['ios', 'android'])
        p: {
          'applicationId': p == 'ios'
              ? 'com.foreststar.foreststar'
              : 'com.foreststar.forest_star',
          'latestVersion': '1.10.0',
          'latestBuild': 20,
          'minimumBuild': 1,
          'promptEnabled': false,
          'storeUrl': '',
        },
    },
    'content': {...content, 'enabled': enabled},
    'notice': {'enabled': false},
  };
  Future<http.Response> respond(http.Request request) async {
    requests++;
    if (offline) throw const SocketException('offline');
    if (request.url == updateManifestUri) {
      return http.Response.bytes(encode(manifest), 200);
    }
    if (request.url.path.endsWith('/catalog.json')) {
      return http.Response.bytes(catalog, 200);
    }
    final data = files[request.url.pathSegments.last];
    if (data == null) return http.Response('missing', 404);
    return http.Response.bytes(
      corrupt ? List.filled(data.length, 0) : data,
      200,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late UpdateFixture fixture;
  final services = <ContentUpdates>[];
  ContentUpdates service({int build = 20, http.Client Function()? factory}) {
    final s = ContentUpdates(
      root: root,
      platform: 'ios',
      build: build,
      clientFactory: factory ?? () => MockClient((r) => fixture.respond(r)),
    );
    services.add(s);
    return s;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('forest-update-test-');
    fixture = UpdateFixture('test-v1');
  });
  tearDown(() async {
    for (final s in services) {
      s.dispose();
    }
    services.clear();
    LevelBook.current = {};
    await root.delete(recursive: true);
  });

  test('disabled content and older clients do not fetch a catalog', () async {
    fixture.enabled = false;
    final s = service();
    await s.check();
    expect(s.phase, UpdatePhase.ready);
    expect(fixture.requests, 1);
    fixture.enabled = true;
    await service(build: 19).check();
    expect(fixture.requests, 2);
  });

  test(
    'verified download activates levels and restores them offline',
    () async {
      final s = service();
      await s.check();
      expect(s.phase, UpdatePhase.available);
      final progress = <int>[];
      s.addListener(() => progress.add(s.receivedBytes));
      await s.download();
      expect(s.phase, UpdatePhase.ready);
      expect(s.progress, 1);
      expect(progress, contains(s.totalBytes));
      expect(s.active!.levels[1]!.health, 180);
      expect(File(s.active!.filePath('levels')!).existsSync(), isTrue);
      fixture.offline = true;
      final restored = service();
      await restored.check();
      expect(restored.phase, UpdatePhase.offline);
      expect(restored.active!.offer.version, 'test-v1');
    },
  );

  test(
    'checksum failure keeps the old pointer and retry can install',
    () async {
      final s = service();
      await s.check();
      await s.download();
      final pointer = File('${root.path}/active.json').readAsStringSync();
      fixture = UpdateFixture('test-v2')..corrupt = true;
      await s.check();
      await s.download();
      expect(s.phase, UpdatePhase.offline);
      expect(s.active!.offer.version, 'test-v1');
      expect(File('${root.path}/active.json').readAsStringSync(), pointer);
      fixture.corrupt = false;
      await s.download();
      expect(s.phase, UpdatePhase.ready);
      expect(s.active!.offer.version, 'test-v2');
    },
  );

  test('corrupt cache falls back one version and can be repaired', () async {
    final s = service();
    await s.check();
    await s.download();
    fixture = UpdateFixture('test-v2');
    await s.check();
    await s.download();
    await File(s.active!.filePath('levels')!).writeAsString('broken');
    fixture.offline = true;
    final restored = service();
    await restored.check();
    expect(restored.active!.offer.version, 'test-v1');
    fixture.offline = false;
    await restored.check();
    await restored.download();
    expect(restored.phase, UpdatePhase.ready);
    expect(restored.active!.offer.version, 'test-v2');
  });

  test('cancelled stream never installs a partial package', () async {
    final started = Completer<void>();
    final chunks = StreamController<List<int>>();
    final s = service(
      factory: () => MockClient.streaming((request, body) async {
        await body.drain<void>();
        if (request.url.path.endsWith('/levels.json')) {
          started.complete();
          return http.StreamedResponse(chunks.stream, 200);
        }
        final response = await fixture.respond(
          http.Request('GET', request.url),
        );
        return http.StreamedResponse(Stream.value(response.bodyBytes), 200);
      }),
    );
    await s.check();
    final downloading = s.download();
    await started.future;
    chunks.add([123]);
    s.cancel();
    await chunks.close();
    await downloading;
    expect(s.active, isNull);
    expect(File('${root.path}/active.json').existsSync(), isFalse);
    expect(root.listSync().whereType<Directory>(), isEmpty);
  });

  test(
    'HTTP redirects, untrusted URLs, expired config and script files are rejected',
    () async {
      final s = service(
        factory: () => MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {'location': 'https://untrusted.example/payload'},
          ),
        ),
      );
      await s.check();
      expect(s.phase, UpdatePhase.offline);
      expect(
        () => ContentOffer({
          ...fixture.content,
          'catalogUrl': 'https://other.example/content/test-v1/catalog.json',
        }),
        throwsFormatException,
      );
      final expired = fixture.manifest..['expiresAt'] = '2000-01-01T00:00:00Z';
      expect(
        () => UpdateInfo.parse(expired, 'ios', 20, DateTime.now().toUtc()),
        throwsFormatException,
      );
      final catalog = decodeObject(fixture.catalog);
      final file = catalog['files'][0] as Map;
      file['path'] = '../code.dart';
      file['url'] = 'https://$updateHost/content/test-v1/../code.dart';
      expect(
        () => ContentCatalog.parse(encode(catalog), 'test-v1'),
        throwsFormatException,
      );
    },
  );

  test(
    'levels are bounded and battles snapshot the downloaded definitions',
    () {
      final data = levelData('test-v1');
      LevelBook.current = LevelBook.parse(data, 'test-v1');
      final combat = Combat()..begin(GameState()..team = [-1, -1, -1, -1]);
      LevelBook.current = {};
      combat.spawnTimer = 0;
      combat.tick(.01);
      expect(combat.health, 180);
      expect(combat.enemies.single.hp, 90);
      expect(combat.enemies.single.speed, 12);
      expect(combat.spawnTimer, .5);
      final fallback = Combat()..begin(GameState()..stage = 2);
      expect(fallback.health, 100);
      (data['levels'][0]['waves'][0] as Map)['enemySpeed'] = 999999;
      expect(() => LevelBook.parse(data, 'test-v1'), throwsFormatException);
    },
  );

  test('valid PNG can be activated but invalid encoded image cannot', () async {
    fixture = UpdateFixture('image-v1', images: true);
    final s = service();
    await s.check();
    await s.download();
    expect(s.phase, UpdatePhase.ready);
    expect(s.active!.filePath('camp'), endsWith('camp.png'));
    await StoryArt.instance.load(content: s.active);
    final camp = StoryArt.instance.images['camp'];
    expect(camp!.width, 2);
    await StoryArt.instance.load();
    expect(
      StoryArt.instance.images['camp'],
      same(camp),
      reason: 'Flame loading must retain the activated artwork',
    );
    fixture = UpdateFixture('image-v2', images: true, invalidImage: true);
    await s.check();
    await s.download();
    expect(s.phase, UpdatePhase.offline);
    expect(s.active!.offer.version, 'image-v1');
  });

  test(
    'download and decode a verified capture of the live server package',
    () async {
      final capture = Directory(Platform.environment['FOREST_LIVE_SITE']!);
      final s = service(
        factory: () => MockClient((request) async {
          final bytes = await File(
            '${capture.path}${request.url.path}',
          ).readAsBytes();
          if (request.url == updateManifestUri) {
            final data = decodeObject(bytes);
            data['content']['enabled'] = true;
            return http.Response.bytes(encode(data), 200);
          }
          return http.Response.bytes(bytes, 200);
        }),
      );
      await s.check();
      expect(s.phase, UpdatePhase.available);
      await s.download();
      expect(s.phase, UpdatePhase.ready);
      expect(s.active!.catalog.files.length, 4);
      expect(s.active!.filePath('camp-music'), isNotNull);
      expect(s.active!.levels[1]!.health, 100);
      expect(s.receivedBytes, s.active!.catalog.totalBytes);
    },
    skip: Platform.environment['FOREST_LIVE_SITE'] == null,
  );
}
