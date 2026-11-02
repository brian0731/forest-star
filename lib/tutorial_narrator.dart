import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TutorialLanguage {
  chinese('zh-TW', '中文'),
  english('en-US', 'English'),
  cantonese('yue-HK', '粵語');

  const TutorialLanguage(this.code, this.label);
  final String code, label;

  static TutorialLanguage fromCode(String? code) => values.firstWhere(
    (language) => language.code == code,
    orElse: () => chinese,
  );
}

enum NarrationStatus { idle, preparing, speaking, unavailable, failed }

/// Select only voices for the requested language; Cantonese never falls back
/// to Mandarin. Prefer an installed offline voice when one is advertised.
Map<String, String>? selectTutorialVoice(
  Iterable<Map<String, dynamic>> voices,
  TutorialLanguage language,
) {
  String normalize(String value) => value.replaceAll('_', '-').toLowerCase();
  final locales = switch (language) {
    TutorialLanguage.chinese => ['zh-tw', 'cmn-tw', 'zh-cn', 'cmn-cn', 'zh-sg'],
    TutorialLanguage.english => ['en-us', 'en-gb', 'en-au'],
    TutorialLanguage.cantonese => ['yue-hk', 'zh-hk', 'yue'],
  };
  final matches = voices.where((voice) {
    final locale = normalize('${voice['locale'] ?? ''}');
    return locales.contains(locale) ||
        (language == TutorialLanguage.english && locale.startsWith('en-')) ||
        (language == TutorialLanguage.cantonese && locale.startsWith('yue-'));
  }).toList();
  int rank(Map<String, dynamic> voice) {
    final locale = normalize('${voice['locale']}');
    final index = locales.indexOf(locale);
    final network = voice['network_required'];
    return (network == true || network == '1' || network == 'true' ? 100 : 0) +
        (index < 0 ? locales.length : index);
  }

  matches.sort((a, b) => rank(a).compareTo(rank(b)));
  if (matches.isEmpty) return null;
  final voice = matches.first;
  return {
    if (voice['identifier'] != null) 'identifier': '${voice['identifier']}',
    if (voice['name'] != null) 'name': '${voice['name']}',
    'locale': '${voice['locale']}',
  };
}

abstract class TutorialNarrator extends ChangeNotifier {
  NarrationStatus get status;
  Future<void> speak(String text, TutorialLanguage language);
  Future<void> stop();
}

class DeviceTutorialNarrator extends TutorialNarrator {
  DeviceTutorialNarrator({FlutterTts? tts}) : _tts = tts ?? FlutterTts();
  final FlutterTts _tts;
  Future<void> _queue = Future.value();
  Future<List<Map<String, dynamic>>>? _voices;
  int _generation = 0;
  bool _disposed = false;
  NarrationStatus _status = NarrationStatus.idle;
  @override
  NarrationStatus get status => _status;

  void _setStatus(NarrationStatus value) {
    if (_disposed) return;
    _status = value;
    notifyListeners();
  }

  Future<T> _bounded<T>(Future<T> future) =>
      future.timeout(const Duration(seconds: 8));

  Future<List<Map<String, dynamic>>> _initialize() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final engines = await _bounded(_tts.getEngines);
      if (engines is List && engines.contains('com.google.android.tts')) {
        await _bounded(_tts.setEngine('com.google.android.tts'));
      }
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _bounded(_tts.setSharedInstance(true));
      await _bounded(
        _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ]),
      );
    }
    await _bounded(_tts.awaitSpeakCompletion(false));
    await _bounded(_tts.setSpeechRate(.44));
    await _bounded(_tts.setVolume(1));
    _tts.setCompletionHandler(() => _setStatus(NarrationStatus.idle));
    _tts.setErrorHandler((_) => _setStatus(NarrationStatus.failed));
    final voices = await _bounded(_tts.getVoices);
    return voices is List
        ? voices
              .whereType<Map>()
              .map((v) => Map<String, dynamic>.from(v))
              .toList()
        : [];
  }

  @override
  Future<void> speak(String text, TutorialLanguage language) {
    if (_disposed) return Future.value();
    final generation = ++_generation;
    _setStatus(NarrationStatus.preparing);
    // Interrupt current speech immediately; queued configuration is serialized.
    unawaited(_stopNative());
    _queue = _queue.then((_) async {
      if (_disposed || generation != _generation) return;
      try {
        final voices = await (_voices ??= _initialize());
        if (_disposed || generation != _generation) return;
        final voice = selectTutorialVoice(voices, language);
        String? locale = voice?['locale'];
        if (locale == null) {
          final candidates = switch (language) {
            TutorialLanguage.chinese => ['zh-TW', 'zh-CN'],
            TutorialLanguage.english => ['en-US', 'en-GB'],
            TutorialLanguage.cantonese => ['yue-HK', 'zh-HK'],
          };
          for (final candidate in candidates) {
            final available = await _bounded(
              _tts.isLanguageAvailable(candidate),
            );
            if (_disposed || generation != _generation) return;
            if (available == true || available == 1) {
              locale = candidate;
              break;
            }
          }
        }
        if (locale == null) {
          _setStatus(NarrationStatus.unavailable);
          return;
        }
        final configured = await _bounded(_tts.setLanguage(locale));
        if (_disposed || generation != _generation) return;
        if (configured == 0 || configured == false) {
          _setStatus(NarrationStatus.unavailable);
          return;
        }
        if (voice != null) {
          final selected = await _bounded(_tts.setVoice(voice));
          if (_disposed || generation != _generation) return;
          if (selected == 0 || selected == false) {
            _setStatus(NarrationStatus.unavailable);
            return;
          }
        }
        if (_disposed || generation != _generation) return;
        _setStatus(NarrationStatus.speaking);
        final result = await _bounded(_tts.speak(text));
        if (!_disposed && generation == _generation && result == 0) {
          _setStatus(NarrationStatus.failed);
        }
      } catch (_) {
        _voices = null; // Permit a retry after installing a voice/engine.
        if (!_disposed && generation == _generation) {
          _setStatus(NarrationStatus.failed);
        }
      }
    });
    return _queue;
  }

  Future<void> _stopNative() async {
    try {
      await _bounded(_tts.stop());
    } catch (_) {
      // Text teaching remains available when a platform has no TTS plugin.
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _setStatus(NarrationStatus.idle);
    await _stopNative();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_stopNative());
    super.dispose();
  }
}
