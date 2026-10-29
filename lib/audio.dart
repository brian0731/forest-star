import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum SoundEffect { select, launch, bounce, reward, battle, hit, win, fail }

enum MusicScene { camp, adventure }

abstract class GameAudio {
  void setEnabled(bool enabled);
  void setForeground(bool foreground);
  void setScene(MusicScene scene);
  void play(SoundEffect effect);
  void dispose();
}

class AppAudio implements GameAudio {
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _effects = AudioPlayer();
  bool _enabled = true,
      _foreground = true,
      _disposed = false,
      _effectsConfigured = false,
      _campMidiUnavailable = false;
  MusicScene _scene = MusicScene.camp;
  MusicScene? _loadedScene;
  Future<void> _queue = Future.value();
  DateTime? _lastBounce, _lastHit;

  void _enqueue(Future<void> Function() action) {
    _queue = _queue
        .then((_) async {
          if (!_disposed) await action();
        })
        .catchError((Object error, StackTrace stack) {
          debugPrint('Audio playback failed: $error');
        });
  }

  void _syncMusic() => _enqueue(() async {
    if (!_enabled || !_foreground) {
      await _music.pause();
      await _effects.stop();
      return;
    }
    final scene = _scene;
    if (_loadedScene != scene) {
      await _music.stop();
      await _music.setReleaseMode(ReleaseMode.loop);
      final nativeMidi =
          scene == MusicScene.camp &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          !_campMidiUnavailable;
      final path = scene == MusicScene.camp
          ? 'audio/forest_camp.${nativeMidi ? 'mid' : 'wav'}'
          : 'audio/forest_loop.wav';
      final volume = scene == MusicScene.camp ? .44 : .32;
      try {
        await _music.play(AssetSource(path), volume: volume);
      } catch (_) {
        if (!nativeMidi) rethrow;
        // Some vendor devices have no usable MIDI synthesizer. The same score
        // is bundled as rendered audio, so camp music is still available.
        _campMidiUnavailable = true;
        await _music.play(AssetSource('audio/forest_camp.wav'), volume: volume);
      }
      _loadedScene = scene;
    } else {
      await _music.resume();
    }
    // A mute or lifecycle change can arrive while the native source prepares.
    if (!_enabled || !_foreground || _disposed) await _music.pause();
  });

  @override
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _syncMusic();
  }

  @override
  void setForeground(bool foreground) {
    _foreground = foreground;
    _syncMusic();
  }

  @override
  void setScene(MusicScene scene) {
    if (_scene == scene) return;
    _scene = scene;
    _syncMusic();
  }

  @override
  void play(SoundEffect effect) {
    if (!_enabled || !_foreground || _disposed) return;
    final now = DateTime.now();
    if (effect == SoundEffect.bounce) {
      if (_lastBounce != null &&
          now.difference(_lastBounce!).inMilliseconds < 100) {
        return;
      }
      _lastBounce = now;
    }
    if (effect == SoundEffect.hit) {
      if (_lastHit != null && now.difference(_lastHit!).inMilliseconds < 300) {
        return;
      }
      _lastHit = now;
    }
    _enqueue(() async {
      if (!_enabled || !_foreground) return;
      if (!_effectsConfigured) {
        await _effects.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              usageType: AndroidUsageType.game,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.none,
            ),
          ),
        );
        _effectsConfigured = true;
      }
      await _effects.play(AssetSource('audio/${effect.name}.wav'), volume: .55);
    });
  }

  @override
  void dispose() {
    _queue = _queue
        .then((_) async {
          await _music.dispose();
          await _effects.dispose();
        })
        .catchError((Object error, StackTrace stack) {
          debugPrint('Audio disposal failed: $error');
        });
    _disposed = true;
  }
}
