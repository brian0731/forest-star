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

// Android's Voice API has no gender field. Only use these named Google voices
// when that engine was selected; never assume a mutable '*-language' alias is
// female. Local voice mappings: RT-Voice PRO 2024.1.1, pp. 42–46:
// https://www.crosstales.com/media/data/assets/rtvoice/RTVoice-doc.pdf
const _googleFemaleVoiceIds = {
  'cmn-tw-x-ctc',
  'cmn-cn-x-ccc',
  'cmn-cn-x-ssa',
  'en-us-x-iob',
  'en-us-x-iog',
  'en-us-x-sfg',
  'en-us-x-tpc',
  'en-us-x-tpf',
  'en-gb-x-fis',
  'en-gb-x-gba',
  'en-gb-x-gbc',
  'en-gb-x-gbg',
  'en-au-x-afh',
  'en-au-x-aua',
  'en-au-x-auc',
  'yue-hk-x-jar',
  'yue-hk-x-yuc',
  'yue-hk-x-yue',
};

bool _isFemaleVoice(Map<String, dynamic> voice, bool googleEngine) {
  final gender = '${voice['gender'] ?? ''}'.trim().toLowerCase();
  if (gender == 'female') return true;
  if (gender == 'male') return false;
  final name = '${voice['name'] ?? ''}'.toLowerCase();
  if (!googleEngine) return false;
  // Older Google voice names explicitly include '#female_1', etc.
  if (RegExp(r'#female_\d+-(local|network)$').hasMatch(name)) return true;
  final id = name.replaceFirst(RegExp(r'-(local|network)$'), '');
  return _googleFemaleVoiceIds.contains(id);
}

/// Select a female voice for the requested language, preferring offline voices.
/// Unknown gender and male voices are excluded; Cantonese never uses Mandarin.
Map<String, String>? selectTutorialVoice(
  Iterable<Map<String, dynamic>> voices,
  TutorialLanguage language, {
  bool googleEngine = false,
}) {
  String normalize(String value) => value.replaceAll('_', '-').toLowerCase();
  final locales = switch (language) {
    TutorialLanguage.chinese => ['zh-tw', 'cmn-tw', 'zh-cn', 'cmn-cn', 'zh-sg'],
    TutorialLanguage.english => ['en-us', 'en-gb', 'en-au'],
    TutorialLanguage.cantonese => ['yue-hk', 'zh-hk', 'yue'],
  };
  final matches = voices.where((voice) {
    final features = '${voice['features'] ?? ''}'.toLowerCase();
    if (features.contains('notinstalled') ||
        !_isFemaleVoice(voice, googleEngine)) {
      return false;
    }
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
  bool _googleEngine = false;
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
    _googleEngine = false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final engines = await _bounded(_tts.getEngines);
      if (engines is List && engines.contains('com.google.android.tts')) {
        // flutter_tts 4.2.5 discards setEngine's native return value.
        await _bounded(_tts.setEngine('com.google.android.tts'));
        _googleEngine = true;
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
        final voice = selectTutorialVoice(
          voices,
          language,
          googleEngine: _googleEngine,
        );
        if (voice == null) {
          _voices = null; // Replay rechecks voices after a download.
          _setStatus(NarrationStatus.unavailable);
          return;
        }
        final configured = await _bounded(_tts.setLanguage(voice['locale']!));
        if (_disposed || generation != _generation) return;
        if (configured == 0 || configured == false) {
          _voices = null;
          _setStatus(NarrationStatus.unavailable);
          return;
        }
        final selected = await _bounded(_tts.setVoice(voice));
        if (_disposed || generation != _generation) return;
        if (selected == 0 || selected == false) {
          _voices = null;
          _setStatus(NarrationStatus.unavailable);
          return;
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
