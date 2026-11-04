import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'level_data.dart';

const updateHost = 'star.singtu.hk';
final updateManifestUri = Uri.https(updateHost, '/game/update-v1.json');
const maxContentFileBytes = 128 * 1024 * 1024;
const maxContentBundleBytes = 512 * 1024 * 1024;
const remoteEffectKeys = {
  'select': 'sfx-select-v2',
  'launch': 'sfx-launch-v2',
  'bounce': 'sfx-bounce-v2',
  'reward': 'sfx-reward-v2',
  'battle': 'sfx-battle-v2',
  'hit': 'sfx-hit-v2',
  'win': 'sfx-win-v2',
  'fail': 'sfx-fail-v2',
};
const imageContentKeys = {
  'camp',
  'board',
  'room',
  'battle',
  'field',
  'field-level2',
  'field-level3',
  'field-level4',
  'field-level5',
  'field-level6',
  'field-level7',
  'field-level8',
  'field-level9',
  'field-level10',
  'location0',
  'location1',
  'location2',
  'friend0',
  'friend1',
  'friend2',
  'friend3',
  'friend4',
  'friend5',
  'marble0',
  'marble1',
  'marble2',
  'marble3',
  'nav0',
  'nav1',
  'nav2',
  'nav3',
  'frame-paper',
  'frame-green',
  'frame-cream',
  'frame-selected',
};

Map<String, dynamic> decodeObject(List<int> bytes) =>
    Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);

String _version(dynamic value) {
  if (value is! String ||
      !RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$').hasMatch(value)) {
    throw const FormatException('Invalid content version');
  }
  return value;
}

String _hash(dynamic value) {
  if (value is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw const FormatException('Invalid SHA-256');
  }
  return value;
}

Uri _trustedUri(dynamic value, String path) {
  if (value is! String) throw const FormatException('URL required');
  final uri = Uri.parse(value);
  if (uri.scheme != 'https' ||
      uri.host != updateHost ||
      uri.port != 443 ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.path != path) {
    throw const FormatException('Untrusted content URL');
  }
  return uri;
}

class ContentOffer {
  ContentOffer(Map<String, dynamic> data)
    : version = _version(data['version']),
      catalogBytes = boundedInt(data['catalogBytes'], 1, 256 * 1024),
      catalogHash = _hash(data['catalogSha256']),
      catalogUri = _trustedUri(
        data['catalogUrl'],
        '/content/${_version(data['version'])}/catalog.json',
      );
  final String version, catalogHash;
  final int catalogBytes;
  final Uri catalogUri;
}

class UpdateInfo {
  UpdateInfo(
    this.content,
    this.storeUri,
    this.storeVersion,
    this.noticeId,
    this.notice,
  );
  final ContentOffer? content;
  final Uri? storeUri;
  final String? storeVersion, noticeId, notice;

  static UpdateInfo parse(
    Map<String, dynamic> data,
    String platform,
    int build,
    DateTime now,
  ) {
    if (data['schemaVersion'] != 1) {
      throw const FormatException('Unsupported update schema');
    }
    boundedInt(data['configRevision'], 1, 2147483647);
    final published = DateTime.parse(data['publishedAt'] as String);
    final expires = DateTime.parse(data['expiresAt'] as String);
    if (!published.isUtc ||
        !expires.isUtc ||
        published.isAfter(now.add(const Duration(minutes: 5))) ||
        !expires.isAfter(now) ||
        !expires.isAfter(published)) {
      throw const FormatException('Expired update configuration');
    }
    final release = data['platforms'][platform] as Map;
    final applicationId = platform == 'ios'
        ? 'com.foreststar.foreststar'
        : 'com.foreststar.forest_star';
    if (release['applicationId'] != applicationId) {
      throw const FormatException('Wrong application');
    }
    final latest = boundedInt(release['latestBuild'], 1, 2147483647);
    final minimum = boundedInt(release['minimumBuild'], 1, latest);
    // Updates remain optional; this offline game never blocks for a network gate.
    assert(minimum >= 1);
    Uri? storeUri;
    if (strictBool(release['promptEnabled']) && latest > build) {
      final uri = Uri.parse(release['storeUrl'] as String);
      final valid = platform == 'ios'
          ? uri.host == 'apps.apple.com' && RegExp(r'/id\d+').hasMatch(uri.path)
          : uri.host == 'play.google.com' &&
                uri.path == '/store/apps/details' &&
                uri.queryParameters['id'] == applicationId;
      if (uri.scheme != 'https' ||
          !valid ||
          uri.userInfo.isNotEmpty ||
          uri.port != 443) {
        throw const FormatException('Invalid store URL');
      }
      storeUri = uri;
    }
    final content = data['content'] as Map;
    ContentOffer? offer;
    if (strictBool(content['enabled']) &&
        build >=
            boundedInt(
              content['minimumClientBuild'][platform],
              1,
              2147483647,
            )) {
      offer = ContentOffer(Map<String, dynamic>.from(content));
    }
    String? notice, id;
    final announcement = data['notice'] as Map;
    if (strictBool(announcement['enabled'])) {
      id = announcement['id'] as String;
      final title = announcement['title']['zh-Hant'] as String;
      final body = announcement['body']['zh-Hant'] as String;
      if (id.isEmpty ||
          id.length > 100 ||
          title.length > 100 ||
          body.length > 2000) {
        throw const FormatException('Invalid notice');
      }
      notice = '$title\n$body';
    }
    return UpdateInfo(
      offer,
      storeUri,
      release['latestVersion'] as String,
      id,
      notice,
    );
  }
}

class ContentFile {
  ContentFile(Map<String, dynamic> data, String version)
    : key = data['key'] as String,
      kind = data['kind'] as String,
      path = data['path'] as String,
      bytes = boundedInt(data['bytes'], 1, maxContentFileBytes),
      hash = _hash(data['sha256']),
      uri = _trustedUri(data['url'], '/content/$version/${data['path']}') {
    if (!RegExp(
      r'^[a-zA-Z0-9][a-zA-Z0-9-]*\.(png|webp|jpg|wav|mp3|m4a|json)$',
    ).hasMatch(path)) {
      throw const FormatException('Invalid content path');
    }
    final extension = path.split('.').last;
    final valid = switch (kind) {
      'image' =>
        imageContentKeys.contains(key) &&
            bytes <= 20 * 1024 * 1024 &&
            {'png', 'webp', 'jpg'}.contains(extension),
      'audio' =>
        {
              'camp-music',
              'adventure-music',
              'camp-music-v2',
              'adventure-music-v2',
              ...remoteEffectKeys.values,
            }.contains(key) &&
            {'wav', 'mp3', 'm4a'}.contains(extension),
      'levels' => key == 'levels' && extension == 'json' && bytes <= 256 * 1024,
      _ => false,
    };
    if (!valid) throw const FormatException('Unknown content key or kind');
  }
  final String key, kind, path, hash;
  final Uri uri;
  final int bytes;
}

class ContentCatalog {
  ContentCatalog(this.version, this.files, this.totalBytes);
  final String version;
  final List<ContentFile> files;
  final int totalBytes;
  static ContentCatalog parse(List<int> bytes, String version) {
    final data = decodeObject(bytes);
    if (data['schemaVersion'] != 1 || data['contentVersion'] != version) {
      throw const FormatException('Wrong catalog version');
    }
    final entries = data['files'] as List;
    if (entries.isEmpty || entries.length > 40) {
      throw const FormatException('Invalid file count');
    }
    final files = [
      for (final file in entries)
        ContentFile(Map<String, dynamic>.from(file as Map), version),
    ];
    final total = files.fold<int>(0, (sum, file) => sum + file.bytes);
    if (total != boundedInt(data['totalBytes'], 1, maxContentBundleBytes) ||
        files.map((f) => f.key).toSet().length != files.length ||
        files.map((f) => f.path).toSet().length != files.length) {
      throw const FormatException('Invalid catalog totals or duplicate files');
    }
    return ContentCatalog(version, files, total);
  }
}

class ContentBundle {
  ContentBundle(this.directory, this.offer, this.catalog, this.levels);
  final Directory directory;
  final ContentOffer offer;
  final ContentCatalog catalog;
  final Map<int, LevelDefinition> levels;
  String? filePath(String key) {
    for (final file in catalog.files) {
      if (file.key == key) return '${directory.path}/${file.path}';
    }
    return null;
  }

  Map<String, String> get effectPaths => {
    for (final entry in remoteEffectKeys.entries)
      if (filePath(entry.value) case final String path) entry.key: path,
  };
}

enum UpdatePhase { checking, available, downloading, verifying, ready, offline }

class ContentUpdates extends ChangeNotifier {
  ContentUpdates({
    required this.root,
    required this.platform,
    required this.build,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;
  final Directory root;
  final String platform;
  final int build;
  final http.Client Function() _clientFactory;
  http.Client? _client;
  int _epoch = 0;
  bool _disposed = false;
  UpdatePhase phase = UpdatePhase.checking;
  String message = '正在檢查森林更新…';
  int receivedBytes = 0, totalBytes = 0;
  UpdateInfo? info;
  ContentCatalog? pendingCatalog;
  ContentBundle? active;
  double get progress =>
      totalBytes == 0 ? 0 : (receivedBytes / totalBytes).clamp(0, 1);
  String? currentFileKey;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _check(int epoch) {
    if (_disposed || epoch != _epoch) throw const _Cancelled();
  }

  int _begin() {
    cancel();
    _client = _clientFactory();
    return _epoch;
  }

  void cancel() {
    _epoch++;
    _client?.close();
    _client = null;
  }

  Future<Uint8List> _fetch(
    Uri uri,
    int limit,
    int epoch, {
    void Function(int)? onChunk,
  }) async {
    _check(epoch);
    final request = http.Request('GET', uri)..followRedirects = false;
    request.headers['Accept'] = '*/*';
    final response = await _client!
        .send(request)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200 || (response.contentLength ?? 0) > limit) {
      throw const FormatException('Invalid update response');
    }
    final output = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 10),
    )) {
      _check(epoch);
      if (output.length + chunk.length > limit) {
        throw const FormatException('Download exceeds limit');
      }
      output.add(chunk);
      onChunk?.call(chunk.length);
    }
    _check(epoch);
    return output.takeBytes();
  }

  void _verify(List<int> bytes, int length, String hash) {
    if (bytes.length != length || sha256.convert(bytes).toString() != hash) {
      throw const FormatException('Content checksum mismatch');
    }
  }

  Future<void> _downloadFile(ContentFile item, File file, int epoch) async {
    _check(epoch);
    final response = await _client!
        .send(http.Request('GET', item.uri)..followRedirects = false)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 ||
        response.contentLength != null &&
            response.contentLength != item.bytes) {
      throw const FormatException('Invalid content response');
    }
    final sink = file.openWrite();
    var count = 0;
    final hash = _DigestSink();
    final hasher = sha256.startChunkedConversion(hash);
    var lastNotification = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        _check(epoch);
        count += chunk.length;
        if (count > item.bytes) {
          throw const FormatException('Download exceeds size');
        }
        sink.add(chunk);
        // Apply backpressure: never queue an entire MP3 in the IOSink buffer.
        await sink.flush();
        hasher.add(chunk);
        receivedBytes += chunk.length;
        final now = DateTime.now();
        if (count == item.bytes ||
            now.difference(lastNotification).inMilliseconds >= 100) {
          lastNotification = now;
          _notify();
        }
      }
      hasher.close();
      _check(epoch);
      if (count != item.bytes || hash.value.toString() != item.hash) {
        throw const FormatException('Content checksum mismatch');
      }
    } finally {
      await sink.close();
    }
  }

  String _folder(ContentOffer offer) =>
      '${offer.version}-${offer.catalogHash.substring(0, 16)}';

  Future<void> _prune(Set<String> keep) async {
    try {
      await for (final entry in root.list(followLinks: false)) {
        if (entry is! Directory) continue;
        final name = entry.uri.pathSegments.where((p) => p.isNotEmpty).last;
        if (!keep.contains(name) &&
            (name.startsWith('staging-') ||
                RegExp(
                  r'^[a-z0-9][a-z0-9-]{0,63}-[a-f0-9]{16}$',
                ).hasMatch(name))) {
          await entry.delete(recursive: true);
        }
      }
    } catch (_) {
      // Cleanup is optional: an installed bundle remains usable on disk errors.
    }
  }

  Future<ContentBundle> _validateBundle(
    Directory directory,
    ContentOffer offer,
    int epoch,
  ) async {
    final catalogFile = File('${directory.path}/catalog.json');
    if (await catalogFile.length() != offer.catalogBytes) {
      throw const FormatException('Cached catalog size mismatch');
    }
    final raw = await catalogFile.readAsBytes();
    _verify(raw, offer.catalogBytes, offer.catalogHash);
    final catalog = ContentCatalog.parse(raw, offer.version);
    var levels = <int, LevelDefinition>{};
    for (final item in catalog.files) {
      _check(epoch);
      final file = File('${directory.path}/${item.path}');
      if (await file.length() != item.bytes) {
        throw const FormatException('Cached file size mismatch');
      }
      final hash = await sha256
          .bind(
            file.openRead().map((chunk) {
              _check(epoch);
              return chunk;
            }),
          )
          .first;
      if (hash.toString() != item.hash) {
        throw const FormatException('Cached checksum mismatch');
      }
      if (item.kind == 'levels') {
        levels = LevelBook.parse(
          decodeObject(await file.readAsBytes()),
          offer.version,
        );
      }
      if (item.kind == 'image') {
        final bytes = await file.readAsBytes();
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        ui.ImageDescriptor? descriptor;
        ui.Codec? codec;
        try {
          descriptor = await ui.ImageDescriptor.encoded(buffer);
          if (descriptor.width > 4096 || descriptor.height > 4096) {
            throw const FormatException('Image too large');
          }
          codec = await descriptor.instantiateCodec();
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec?.dispose();
          descriptor?.dispose();
          buffer.dispose();
        }
      }
      if (item.kind == 'audio') {
        final handle = await file.open();
        late final List<int> bytes;
        try {
          bytes = await handle.read(12);
        } finally {
          await handle.close();
        }
        final wave =
            bytes.length >= 12 &&
            ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
            ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WAVE';
        final mp3 =
            bytes.length >= 3 &&
            (ascii.decode(bytes.sublist(0, 3), allowInvalid: true) == 'ID3' ||
                bytes[0] == 255 && bytes[1] & 224 == 224);
        final m4a =
            bytes.length >= 12 &&
            ascii.decode(bytes.sublist(4, 8), allowInvalid: true) == 'ftyp';
        if (!(item.path.endsWith('.wav') && wave ||
            item.path.endsWith('.mp3') && mp3 ||
            item.path.endsWith('.m4a') && m4a)) {
          throw const FormatException('Invalid audio file');
        }
      }
    }
    _check(epoch);
    return ContentBundle(directory, offer, catalog, levels);
  }

  Future<ContentBundle?> _restore(String pointer, int epoch) async {
    try {
      final file = File('${root.path}/$pointer');
      if (await file.length() > 64 * 1024) {
        throw const FormatException('Invalid cached pointer');
      }
      final data = decodeObject(await file.readAsBytes());
      final offer = ContentOffer(data);
      return await _validateBundle(
        Directory('${root.path}/${_folder(offer)}'),
        offer,
        epoch,
      );
    } catch (_) {
      _check(epoch);
      return null;
    }
  }

  Future<void> check() async {
    final epoch = _begin();
    phase = UpdatePhase.checking;
    message = '正在檢查森林更新…';
    pendingCatalog = null;
    info = null;
    _notify();
    try {
      await root.create(recursive: true);
      active =
          await _restore('active.json', epoch) ??
          await _restore('previous.json', epoch);
      _check(epoch);
      final raw = await _fetch(
        updateManifestUri,
        64 * 1024,
        epoch,
      ).timeout(const Duration(seconds: 8));
      info = UpdateInfo.parse(
        decodeObject(raw),
        platform,
        build,
        DateTime.now().toUtc(),
      );
      final offer = info!.content;
      if (offer != null &&
          (active?.offer.catalogHash != offer.catalogHash ||
              active?.offer.version != offer.version)) {
        final catalogBytes = await _fetch(
          offer.catalogUri,
          offer.catalogBytes,
          epoch,
        ).timeout(const Duration(seconds: 8));
        _verify(catalogBytes, offer.catalogBytes, offer.catalogHash);
        pendingCatalog = ContentCatalog.parse(catalogBytes, offer.version);
        _pendingCatalogBytes = catalogBytes;
        totalBytes = pendingCatalog!.totalBytes;
        receivedBytes = 0;
        phase = UpdatePhase.available;
        message = '森林有新內容，準備出發！';
      } else {
        phase = UpdatePhase.ready;
        message = offer == null ? '森林已準備好，暫無內容更新' : '已是最新森林內容';
      }
      _check(epoch);
      _client?.close();
      _notify();
    } catch (_) {
      if (_disposed || epoch != _epoch) return;
      cancel();
      phase = UpdatePhase.offline;
      message = active == null ? '暫時無法檢查更新，可使用內附內容遊玩' : '暫時無法連線，將使用已下載的森林';
      _notify();
    }
  }

  Uint8List? _pendingCatalogBytes;
  Future<void> download() async {
    final catalog = pendingCatalog,
        offer = info?.content,
        raw = _pendingCatalogBytes;
    if (catalog == null ||
        offer == null ||
        raw == null ||
        phase == UpdatePhase.downloading ||
        phase == UpdatePhase.verifying) {
      return;
    }
    final epoch = _begin();
    final staging = Directory(
      '${root.path}/staging-$epoch-${DateTime.now().microsecondsSinceEpoch}',
    );
    phase = UpdatePhase.downloading;
    receivedBytes = 0;
    totalBytes = catalog.totalBytes;
    message = '正在下載森林內容…';
    _notify();
    try {
      await staging.create(recursive: true);
      await File('${staging.path}/catalog.json').writeAsBytes(raw, flush: true);
      for (final file in catalog.files) {
        currentFileKey = file.key;
        message = switch (file.kind) {
          'audio' => '正在下載森林音樂…',
          'levels' => '正在下載關卡資料…',
          _ => '正在下載森林圖片…',
        };
        _notify();
        await _downloadFile(
          file,
          File('${staging.path}/${file.path}'),
          epoch,
        ).timeout(const Duration(minutes: 30));
      }
      _check(epoch);
      phase = UpdatePhase.verifying;
      message = '下載完成，正在校驗圖片、音樂及關卡…';
      _notify();
      final verified = await _validateBundle(staging, offer, epoch);
      _check(epoch);
      final destination = Directory('${root.path}/${_folder(offer)}');
      if (await destination.exists()) {
        // An interrupted earlier activation may already contain this bundle.
        try {
          await _validateBundle(destination, offer, epoch);
        } catch (_) {
          _check(epoch);
          await destination.delete(recursive: true);
          await staging.rename(destination.path);
        }
      } else {
        await staging.rename(destination.path);
      }
      _check(epoch);
      final bundle = ContentBundle(
        destination,
        offer,
        catalog,
        verified.levels,
      );
      final pointer = File('${root.path}/active.json');
      final next = File('${root.path}/active.next');
      await next.writeAsString(
        jsonEncode({
          'version': offer.version,
          'catalogBytes': offer.catalogBytes,
          'catalogSha256': offer.catalogHash,
          'catalogUrl': offer.catalogUri.toString(),
        }),
        flush: true,
      );
      _check(epoch);
      if (active != null) {
        await File('${root.path}/previous.json').writeAsString(
          jsonEncode({
            'version': active!.offer.version,
            'catalogBytes': active!.offer.catalogBytes,
            'catalogSha256': active!.offer.catalogHash,
            'catalogUrl': active!.offer.catalogUri.toString(),
          }),
          flush: true,
        );
      }
      _check(epoch);
      await next.rename(pointer.path);
      final previousOffer = active?.offer;
      active = bundle;
      pendingCatalog = null;
      phase = UpdatePhase.ready;
      message = '更新完成！森林已準備好';
      _client?.close();
      _notify();
      await _prune({
        _folder(offer),
        if (previousOffer != null) _folder(previousOffer),
      });
    } catch (_) {
      if (_disposed || epoch != _epoch) return;
      cancel();
      phase = UpdatePhase.offline;
      message = '下載或校驗未完成，保留原有內容。可以重試';
      _notify();
    } finally {
      try {
        if (await staging.exists()) await staging.delete(recursive: true);
      } catch (_) {
        /* Cleanup must not hide a download/disk error. */
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

class _Cancelled implements Exception {
  const _Cancelled();
}
