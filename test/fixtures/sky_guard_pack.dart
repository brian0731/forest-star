import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_star/content_updates.dart';

/// The actual server media, exercised through the same downloader as the app.
class SkyGuardPack {
  SkyGuardPack() {
    catalogBytes = File('${directory.path}/catalog.json').readAsBytesSync();
    catalog = ContentCatalog.parse(catalogBytes, version);
    for (final entry in catalog.files) {
      files[entry.path] = File(
        '${directory.path}/${entry.path}',
      ).readAsBytesSync();
    }
  }
  static const version = 'forest-sky-guard-v2';
  final directory = Directory('server/updates/media/$version');
  late final List<int> catalogBytes;
  late final ContentCatalog catalog;
  final files = <String, List<int>>{};
  final requests = <Uri>[];
  bool offline = false, corrupt = false;

  ContentUpdates updates(Directory root, {int build = 23}) => ContentUpdates(
    root: root,
    platform: 'ios',
    build: build,
    clientFactory: () => MockClient((request) async {
      requests.add(request.url);
      if (offline) throw const SocketException('offline');
      if (request.url == updateManifestUri) {
        final now = DateTime.now().toUtc();
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'schemaVersion': 1,
              'configRevision': 4,
              'publishedAt': now
                  .subtract(const Duration(minutes: 1))
                  .toIso8601String(),
              'expiresAt': now.add(const Duration(days: 1)).toIso8601String(),
              'platforms': {
                'ios': {
                  'applicationId': 'com.foreststar.foreststar',
                  'latestVersion': '1.12.0',
                  'latestBuild': 23,
                  'minimumBuild': 1,
                  'promptEnabled': false,
                  'storeUrl': '',
                },
              },
              'content': {
                'enabled': true,
                'version': version,
                'minimumClientBuild': {'ios': 23, 'android': 23},
                'catalogBytes': catalogBytes.length,
                'catalogSha256': sha256.convert(catalogBytes).toString(),
                'catalogUrl':
                    'https://$updateHost/content/$version/catalog.json',
              },
              'notice': {'enabled': false},
            }),
          ),
          200,
        );
      }
      if (request.url.path.endsWith('/catalog.json')) {
        return http.Response.bytes(catalogBytes, 200);
      }
      final bytes = files[request.url.pathSegments.last];
      if (bytes == null) return http.Response('missing', 404);
      return http.Response.bytes(
        corrupt ? List.filled(bytes.length, 0) : bytes,
        200,
      );
    }),
  );
}
