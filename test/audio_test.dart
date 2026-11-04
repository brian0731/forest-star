import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cached music and effects play locally; missing downloads remain silent',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      final calls = <MethodCall>[];
      final eventChannels = <MethodChannel>[];
      final temp = Directory.systemTemp.createTempSync('forest-audio-test-');
      addTearDown(() => temp.deleteSync(recursive: true));
      const playerChannel = MethodChannel('xyz.luan/audioplayers');
      const globalChannel = MethodChannel('xyz.luan/audioplayers.global');
      const globalEvents = MethodChannel('xyz.luan/audioplayers.global/events');
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      for (final channel in [globalChannel, globalEvents]) {
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      messenger.setMockMethodCallHandler(pathChannel, (_) async => temp.path);
      messenger.setMockMethodCallHandler(playerChannel, (call) async {
        calls.add(call);
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final player = args['playerId'] as String;
        final events = 'xyz.luan/audioplayers/events/$player';
        if (call.method == 'create') {
          final channel = MethodChannel(events);
          eventChannels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        if (call.method == 'setSourceUrl') {
          scheduleMicrotask(
            () => ui.channelBuffers.push(
              events,
              codec.encodeSuccessEnvelope({
                'event': 'audio.onPrepared',
                'value': true,
              }),
              (_) {},
            ),
          );
          if (args['url'] == '/missing/camp.mp3') {
            throw PlatformException(code: 'missing-file');
          }
        }
        if (call.method == 'getCurrentPosition' ||
            call.method == 'getDuration') {
          return 0;
        }
        return null;
      });
      addTearDown(() {
        for (final channel in [
          playerChannel,
          globalChannel,
          globalEvents,
          pathChannel,
          ...eventChannels,
        ]) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      Future<void> until(bool Function() ready) async {
        for (var attempt = 0; attempt < 400 && !ready(); attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(ready(), isTrue, reason: 'Audio operation did not finish');
      }

      List<MethodCall> sources() =>
          calls.where((call) => call.method == 'setSourceUrl').toList();
      int count(String method) =>
          calls.where((call) => call.method == method).length;
      final audio = AppAudio(
        campMusicPath: '/cache/sky-camp-v2.mp3',
        adventureMusicPath: '/cache/sky-adventure-v2.mp3',
        effectPaths: {'select': '/cache/select.wav'},
      );
      audio.setEnabled(true);
      await until(() => count('resume') == 1);
      expect(sources().last.arguments['url'], endsWith('sky-camp-v2.mp3'));
      expect(
        calls.any(
          (call) =>
              call.method == 'setReleaseMode' &&
              call.arguments['releaseMode'] == 'ReleaseMode.loop',
        ),
        isTrue,
      );
      audio.setScene(MusicScene.adventure);
      await until(() => count('resume') == 2);
      expect(sources().last.arguments['url'], endsWith('sky-adventure-v2.mp3'));
      final sourceCount = sources().length;
      audio.setEnabled(false);
      await until(() => count('pause') == 1);
      audio.play(SoundEffect.select);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sources(), hasLength(sourceCount));
      audio.setEnabled(true);
      await until(() => count('resume') == 3);
      expect(sources(), hasLength(sourceCount));
      audio.setForeground(false);
      await until(() => count('pause') == 2);
      audio.setForeground(true);
      await until(() => count('resume') == 4);
      audio.play(SoundEffect.select);
      await until(() => count('resume') == 5);
      expect(sources().last.arguments['url'], '/cache/select.wav');
      expect(sources().last.arguments['isLocal'], isTrue);
      audio.dispose();
      await until(() => count('dispose') == 2);
      final recovered = AppAudio(campMusicPath: '/missing/camp.mp3');
      recovered.setEnabled(true);
      await until(() => sources().last.arguments['url'] == '/missing/camp.mp3');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final failedSourceCount = sources().length;
      recovered.setEnabled(true);
      recovered.play(SoundEffect.select);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(sources(), hasLength(failedSourceCount));
      expect(count('resume'), 5);
      recovered.dispose();
      await until(() => count('dispose') == 4);
      final noDownloads = AppAudio();
      noDownloads.setEnabled(true);
      noDownloads.setScene(MusicScene.adventure);
      noDownloads.play(SoundEffect.select);
      noDownloads.setForeground(false);
      noDownloads.setForeground(true);
      noDownloads.dispose();
      await until(() => count('dispose') == 6);
      expect(sources(), hasLength(failedSourceCount));
      expect(count('resume'), 5);
    },
  );
}
