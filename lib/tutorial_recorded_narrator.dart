import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'tutorial_narrator.dart';

class RecordedTutorialNarrator extends TutorialNarrator {
  RecordedTutorialNarrator(this.paths, {TutorialNarrator? fallback})
    : _fallback = fallback ?? DeviceTutorialNarrator() {
    _fallback.addListener(_syncFallback);
  }

  final Map<(TutorialLanguage, String), String> paths;
  final TutorialNarrator _fallback;
  AudioPlayer? _player;
  StreamSubscription<void>? _completion;
  Future<void> _queue = Future.value();
  int _generation = 0;
  bool _disposed = false, _usingFallback = false;
  NarrationStatus _status = NarrationStatus.idle;

  @override
  NarrationStatus get status => _status;

  void _setStatus(NarrationStatus value) {
    if (_disposed || _status == value) return;
    _status = value;
    notifyListeners();
  }

  void _syncFallback() {
    if (_usingFallback) _setStatus(_fallback.status);
  }

  @override
  Future<void> speak(String text, TutorialLanguage language) {
    if (_disposed) return Future.value();
    final generation = ++_generation;
    _setStatus(NarrationStatus.preparing);
    _queue = _queue
        .then((_) async {
          if (_disposed || generation != _generation) return;
          await _player?.stop();
          await _fallback.stop();
          if (_disposed || generation != _generation) return;
          final path = paths[(language, text)];
          if (path != null) {
            try {
              _usingFallback = false;
              final player = _player ??= AudioPlayer();
              _completion ??= player.onPlayerComplete.listen((_) {
                if (!_disposed && !_usingFallback) {
                  _setStatus(NarrationStatus.idle);
                }
              });
              await player.play(AssetSource(path));
              if (_disposed || generation != _generation) {
                await player.stop();
                return;
              }
              _setStatus(NarrationStatus.speaking);
              return;
            } catch (_) {
              // Device narration remains available if an audio asset cannot play.
            }
          }
          if (_disposed || generation != _generation) return;
          _usingFallback = true;
          await _fallback.speak(text, language);
        })
        .catchError((Object _) {
          if (!_disposed && generation == _generation) {
            _setStatus(NarrationStatus.failed);
          }
        });
    return _queue;
  }

  @override
  Future<void> stop() async {
    _generation++;
    _setStatus(NarrationStatus.idle);
    await Future.wait([
      if (_player case final player?) player.stop(),
      _fallback.stop(),
    ]);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _fallback.removeListener(_syncFallback);
    _fallback.dispose();
    if (_completion case final completion?) unawaited(completion.cancel());
    if (_player case final player?) unawaited(player.dispose());
    super.dispose();
  }
}
