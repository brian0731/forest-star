import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdSettings {
  const AdSettings({
    this.production = false,
    this.appId = '',
    this.unitId = '',
    this.audience = 'unconfirmed',
  });
  const AdSettings.environment()
    : production = const bool.fromEnvironment('ADMOB_PRODUCTION'),
      appId = const String.fromEnvironment('ADMOB_APP_ID'),
      unitId = const String.fromEnvironment('ADMOB_REWARDED_ID'),
      audience = const String.fromEnvironment(
        'ADMOB_AUDIENCE',
        defaultValue: 'unconfirmed',
      );
  final bool production;
  final String appId, unitId, audience;
  static const testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const testUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const iosTestUnitId = 'ca-app-pub-3940256099942544/1712485313';
  bool get childTreatment => audience != 'general';
  String get rewardedId => production
      ? unitId
      : defaultTargetPlatform == TargetPlatform.iOS
      ? iosTestUnitId
      : testUnitId;
  bool get valid =>
      !production ||
      (RegExp(r'^ca-app-pub-\d{16}~\d{10}$').hasMatch(appId) &&
          RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(unitId) &&
          !appId.contains('3940256099942544') &&
          !unitId.contains('3940256099942544') &&
          const ['children', 'general'].contains(audience));
}

class AdConsent {
  const AdConsent(this.allowed, this.optionsRequired);
  final bool allowed, optionsRequired;
}

abstract interface class RewardedSlot {
  Future<void> show(VoidCallback onReward);
  void dispose();
}

abstract interface class RewardedBackend {
  Future<void> configure(AdSettings settings);
  Future<AdConsent> consent({
    required bool childTreatment,
    bool options = false,
  });
  Future<void> initialize();
  Future<RewardedSlot> load(String unitId);
}

/// Owns one ad at a time; only a Google earned-reward callback grants currency.
class RewardedAdsController extends ChangeNotifier {
  RewardedAdsController(this.settings, this.backend);
  final AdSettings settings;
  final RewardedBackend backend;
  ValueChanged<bool>? onOverlayChanged;
  bool ready = false,
      busy = false,
      loading = false,
      privacyOptionsRequired = false;
  bool _disposed = false,
      _started = false,
      _allowed = false,
      _initialized = false;
  int _loadEpoch = 0;
  bool _starting = false;
  RewardedSlot? _slot;
  String status = '廣告尚未準備';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_started || _starting || _disposed) return;
    _started = true;
    if (!settings.valid) {
      status = '廣告設定尚未完成';
      _notify();
      return;
    }
    _starting = true;
    try {
      await backend.configure(settings);
      if (_disposed) return;
      if (settings.production) {
        onOverlayChanged?.call(true);
        try {
          final result = await backend.consent(
            childTreatment: settings.childTreatment,
          );
          _allowed = result.allowed;
          privacyOptionsRequired = result.optionsRequired;
        } finally {
          onOverlayChanged?.call(false);
        }
      } else {
        // Google's public demo app ID has no publisher-owned UMP message.
        // This bypass is restricted to official sample ads, never live IDs.
        _allowed = true;
      }
      if (_allowed && !_disposed) {
        await backend.initialize();
        _initialized = true;
        await load();
      } else {
        status = '未取得廣告許可';
        _notify();
      }
    } catch (_) {
      status = '廣告暫時無法使用';
      _notify();
    } finally {
      _starting = false;
    }
  }

  Future<void> load() async {
    if (_disposed || !_allowed || !_initialized || loading || ready || busy) {
      return;
    }
    final epoch = ++_loadEpoch;
    loading = true;
    status = '廣告準備中';
    _notify();
    try {
      final slot = await backend.load(settings.rewardedId);
      if (_disposed || !_allowed || epoch != _loadEpoch) {
        slot.dispose();
        return;
      }
      _slot = slot;
      ready = true;
      status = '觀看廣告 +12';
    } catch (_) {
      if (epoch == _loadEpoch) status = '暫無廣告・點此重試';
    } finally {
      if (epoch == _loadEpoch) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> retry() async {
    if (_disposed || _starting || busy || loading || ready) return;
    if (!_initialized || !_allowed) {
      _started = false;
      await start();
    } else {
      await load();
    }
  }

  Future<bool> show(VoidCallback onReward) async {
    if (_disposed || busy || !ready || _slot == null) return false;
    final slot = _slot!;
    _slot = null;
    ready = false;
    busy = true;
    var earned = false;
    onOverlayChanged?.call(true);
    _notify();
    try {
      await slot.show(() {
        if (!earned && !_disposed) {
          earned = true;
          onReward();
        }
      });
    } catch (_) {
      status = '廣告未能顯示';
    } finally {
      slot.dispose();
      busy = false;
      onOverlayChanged?.call(false);
      _notify();
      if (!_disposed) unawaited(load());
    }
    return earned;
  }

  Future<void> openPrivacyOptions() async {
    if (_disposed || busy || !settings.production || !privacyOptionsRequired) {
      return;
    }
    busy = true;
    onOverlayChanged?.call(true);
    _notify();
    _loadEpoch++;
    loading = false;
    _slot?.dispose();
    _slot = null;
    ready = false;
    try {
      final result = await backend.consent(
        childTreatment: settings.childTreatment,
        options: true,
      );
      _allowed = result.allowed;
      privacyOptionsRequired = result.optionsRequired;
      if (!_allowed) status = '未取得廣告許可';
      if (_allowed && !_initialized) {
        await backend.initialize();
        _initialized = true;
      }
    } catch (_) {
      _allowed = false;
      status = '請稍後再試隱私設定';
    } finally {
      busy = false;
      onOverlayChanged?.call(false);
      _notify();
    }
    if (_allowed) await load();
  }

  @override
  void dispose() {
    _disposed = true;
    _slot?.dispose();
    _slot = null;
    onOverlayChanged = null;
    super.dispose();
  }
}

class GoogleRewardedBackend implements RewardedBackend {
  @override
  Future<void> configure(AdSettings settings) =>
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          maxAdContentRating: MaxAdContentRating.g,
          ageRestrictedTreatment: settings.childTreatment
              ? AgeRestrictedTreatment.child
              : AgeRestrictedTreatment.unspecified,
        ),
      );

  @override
  Future<AdConsent> consent({
    required bool childTreatment,
    bool options = false,
  }) async {
    final complete = Completer<void>();
    if (options) {
      ConsentForm.showPrivacyOptionsForm((error) {
        if (error == null) {
          complete.complete();
        } else {
          complete.completeError(StateError('Privacy form unavailable'));
        }
      });
    } else {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(tagForUnderAgeOfConsent: childTreatment),
        () => ConsentForm.loadAndShowConsentFormIfRequired(
          (error) => complete.complete(),
        ),
        (error) => complete.complete(),
      );
    }
    await complete.future;
    return AdConsent(
      await ConsentInformation.instance.canRequestAds(),
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required,
    );
  }

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  @override
  Future<RewardedSlot> load(String unitId) async {
    final complete = Completer<RewardedSlot>();
    var expired = false;
    unawaited(
      RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(nonPersonalizedAds: true),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (expired) {
              ad.dispose();
            } else if (!complete.isCompleted) {
              complete.complete(_GoogleSlot(ad));
            }
          },
          onAdFailedToLoad: (error) {
            if (!complete.isCompleted) {
              complete.completeError(StateError('Ad unavailable'));
            }
          },
        ),
      ).catchError((Object error) {
        if (!complete.isCompleted) complete.completeError(error);
      }),
    );
    return complete.future.timeout(
      const Duration(seconds: 25),
      onTimeout: () {
        expired = true;
        throw TimeoutException('Ad load timed out');
      },
    );
  }
}

class _GoogleSlot implements RewardedSlot {
  _GoogleSlot(this.ad);
  final RewardedAd ad;
  bool _disposed = false;
  @override
  Future<void> show(VoidCallback onReward) async {
    final complete = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        if (!complete.isCompleted) complete.complete();
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        if (!complete.isCompleted) {
          complete.completeError(StateError('Ad failed to show'));
        }
      },
    );
    await Future.wait<void>([
      ad.show(onUserEarnedReward: (_, reward) => onReward()),
      complete.future,
    ], eagerError: true);
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      unawaited(ad.dispose());
    }
  }
}
