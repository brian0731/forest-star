import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum SoundEffect {
  select,
  launch,
  bounce,
  reward,
  battle,
  hit,
  win,
  fail,
  magicCharge,
  magicImpact,
}

enum MusicScene { camp, adventure }

abstract class GameAudio {
  void setEnabled(bool enabled);
  void setForeground(bool foreground);
  void setScene(MusicScene scene);
  void play(SoundEffect effect);
  void dispose();
}

class AppAudio implements GameAudio {
  AppAudio({
    this.campMusicPath,
    this.adventureMusicPath,
    this.effectPaths = const {},
  });
  final String? campMusicPath, adventureMusicPath;
  final Map<String, String> effectPaths;
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _effects = AudioPlayer();
  bool _enabled = true,
      _foreground = true,
      _disposed = false,
      _musicAvailable = false,
      _effectsConfigured = false;
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
      _musicAvailable = false;
      await _music.stop();
      await _music.setReleaseMode(ReleaseMode.loop);
      final volume = scene == MusicScene.camp ? .40 : .34;
      final remotePath = scene == MusicScene.camp
          ? campMusicPath
          : adventureMusicPath;
      // Music is downloaded and verified by ContentUpdates. There is no BGM
      // in the application bundle, nor a direct network stream during play.
      if (remotePath != null) {
        try {
          await _music.play(DeviceFileSource(remotePath), volume: volume);
          _musicAvailable = true;
        } catch (error) {
          debugPrint('Cached music unavailable: $error');
          await _music.stop();
        }
      }
      _loadedScene = scene;
    } else if (_musicAvailable) {
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
    final localMagic =
        effect == SoundEffect.magicCharge || effect == SoundEffect.magicImpact;
    final cachedPath = effectPaths[effect.name];
    if (!localMagic && cachedPath == null) return;
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
      await _effects.play(
        cachedPath != null
            ? DeviceFileSource(cachedPath)
            : AssetSource('audio/${effect.name}.wav'),
        volume: switch (effect) {
          SoundEffect.hit || SoundEffect.bounce => .24,
          SoundEffect.magicCharge => .42,
          SoundEffect.magicImpact => .52,
          _ => .36,
        },
      );
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
