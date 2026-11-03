import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/game_session.dart';
import 'package:forest_star/main.dart';
import 'package:forest_star/rewarded_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio, enterGame, gameTap;

class FakeSlot implements RewardedSlot {
  int rewardCalls = 1, shows = 0;
  bool disposed = false;
  bool failShow = false;
  Completer<void>? dismissed;
  VoidCallback? reward;
  @override
  Future<void> show(VoidCallback onReward) async {
    shows++;
    if (failShow) throw StateError('native show failed');
    reward = onReward;
    for (var i = 0; i < rewardCalls; i++) {
      onReward();
    }
    if (dismissed != null) await dismissed!.future;
  }

  @override
  void dispose() {
    disposed = true;
  }
}

class FakeBackend implements RewardedBackend {
  bool allowed = true, requiredOptions = false, failLoad = false;
  int initialized = 0, loads = 0;
  int configurations = 0;
  Completer<void>? configurePending;
  String? requestedId;
  AdSettings? configured;
  final slots = <FakeSlot>[];
  Completer<RewardedSlot>? pending;
  @override
  Future<void> configure(AdSettings settings) async {
    configurations++;
    configured = settings;
    if (configurePending != null) await configurePending!.future;
  }

  @override
  Future<AdConsent> consent({
    required bool childTreatment,
    bool options = false,
  }) async => AdConsent(allowed, requiredOptions);
  @override
  Future<void> initialize() async {
    initialized++;
  }

  @override
  Future<RewardedSlot> load(String unitId) async {
    loads++;
    requestedId = unitId;
    if (failLoad) throw StateError('no fill');
    if (pending != null) return pending!.future;
    final slot = FakeSlot();
    slots.add(slot);
    return slot;
  }
}

const liveSettings = AdSettings(
  production: true,
  appId: 'ca-app-pub-1234567890123456~1234567890',
  unitId: 'ca-app-pub-1234567890123456/1234567890',
  audience: 'children',
);

void main() {
  test(
    'iOS release config requests the publisher rewarded unit after consent',
    () async {
      final config =
          jsonDecode(
                File('config/admob.ios.production.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final settings = AdSettings(
        production: config['ADMOB_PRODUCTION'] as bool,
        appId: config['ADMOB_APP_ID'] as String,
        unitId: config['ADMOB_REWARDED_ID'] as String,
        audience: config['ADMOB_AUDIENCE'] as String,
      );
      expect(settings.valid, isTrue);
      expect(settings.childTreatment, isTrue);
      expect(settings.appId, 'ca-app-pub-7872649564668474~3617467257');
      const compiled = AdSettings.environment();
      if (compiled.production) {
        expect(compiled.appId, settings.appId);
        expect(compiled.unitId, settings.unitId);
        expect(compiled.audience, settings.audience);
      }
      final backend = FakeBackend();
      final ads = RewardedAdsController(settings, backend);
      await ads.start();
      expect(backend.requestedId, 'ca-app-pub-7872649564668474/6817511518');
      expect(backend.configured!.childTreatment, isTrue);
      expect(ads.ready, isTrue);
      var marbles = 0;
      backend.slots.single.rewardCalls = 2;
      expect(await ads.show(() => marbles += 12), isTrue);
      expect(marbles, 12);
      ads.dispose();
    },
  );
  test('iOS and Android request their own rewarded test ad units', () async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      debugDefaultTargetPlatformOverride = platform;
      final backend = FakeBackend();
      final controller = RewardedAdsController(const AdSettings(), backend);
      await controller.start();
      expect(
        backend.requestedId,
        platform == TargetPlatform.iOS
            ? 'ca-app-pub-3940256099942544/1712485313'
            : 'ca-app-pub-3940256099942544/5224354917',
      );
      controller.dispose();
    }
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  test('retry during startup cannot launch a second initialization', () async {
    final backend = FakeBackend()..configurePending = Completer<void>();
    final ads = RewardedAdsController(const AdSettings(), backend);
    final starting = ads.start();
    await ads.retry();
    expect(backend.configurations, 1);
    backend.configurePending!.complete();
    await starting;
    expect(backend.initialized, 1);
    expect(backend.loads, 1);
    ads.dispose();
  });
  test(
    'native show failure restores overlays without granting a reward',
    () async {
      final backend = FakeBackend();
      final controller = RewardedAdsController(const AdSettings(), backend);
      final overlays = <bool>[];
      controller.onOverlayChanged = overlays.add;
      await controller.start();
      backend.slots.first.failShow = true;
      backend.failLoad = true;
      var credits = 0;
      expect(await controller.show(() => credits++), isFalse);
      expect(credits, 0);
      expect(controller.busy, isFalse);
      expect(overlays, [true, false]);
      expect(backend.slots.first.disposed, isTrue);
      controller.dispose();
    },
  );
  test(
    'test builds always use official sample IDs and child treatment by default',
    () async {
      final backend = FakeBackend();
      final ads = RewardedAdsController(
        const AdSettings(unitId: 'ignored-live-id'),
        backend,
      );
      await ads.start();
      expect(backend.requestedId, AdSettings.testUnitId);
      expect(backend.configured!.childTreatment, isTrue);
      expect(ads.ready, isTrue);
      ads.dispose();
    },
  );
  test(
    'invalid production configuration never initializes or loads ads',
    () async {
      for (final config in [
        const AdSettings(production: true),
        const AdSettings(
          production: true,
          appId: AdSettings.testAppId,
          unitId: AdSettings.testUnitId,
          audience: 'children',
        ),
      ]) {
        final backend = FakeBackend();
        // The controller must refuse the configuration before touching its backend.
        final controller = RewardedAdsController(config, backend);
        await controller.start();
        expect(backend.initialized, 0);
        expect(backend.loads, 0);
        controller.dispose();
      }
    },
  );
  test(
    'production consent denial blocks SDK initialization and ad requests',
    () async {
      final backend = FakeBackend()..allowed = false;
      final ads = RewardedAdsController(liveSettings, backend);
      final overlays = <bool>[];
      ads.onOverlayChanged = overlays.add;
      await ads.start();
      expect(backend.initialized, 0);
      expect(backend.loads, 0);
      expect(overlays, [true, false]);
      expect(ads.ready, isFalse);
      ads.dispose();
    },
  );
  test(
    'one ad cannot show twice or grant duplicate earned callbacks',
    () async {
      final backend = FakeBackend();
      final controller = RewardedAdsController(const AdSettings(), backend);
      await controller.start();
      final slot = backend.slots.first
        ..rewardCalls = 2
        ..dismissed = Completer<void>();
      var credits = 0;
      final first = controller.show(() => credits++);
      expect(controller.busy, isTrue);
      expect(controller.ready, isFalse);
      expect(await controller.show(() => credits++), isFalse);
      expect(slot.shows, 1);
      expect(credits, 1);
      slot.dismissed!.complete();
      expect(await first, isTrue);
      expect(slot.disposed, isTrue);
      controller.dispose();
    },
  );
  test(
    'early close and no-fill never award currency and retry can recover',
    () async {
      final backend = FakeBackend();
      final ads = RewardedAdsController(const AdSettings(), backend);
      await ads.start();
      backend.slots.first.rewardCalls = 0;
      backend.failLoad = true;
      var credits = 0;
      expect(await ads.show(() => credits++), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(credits, 0);
      expect(ads.ready, isFalse);
      backend.failLoad = false;
      await ads.retry();
      expect(ads.ready, isTrue);
      ads.dispose();
    },
  );
  test('disposing while an ad loads releases the late native object', () async {
    final backend = FakeBackend()..pending = Completer<RewardedSlot>();
    final ads = RewardedAdsController(const AdSettings(), backend);
    final starting = ads.start();
    await Future<void>.delayed(Duration.zero);
    ads.dispose();
    final late = FakeSlot();
    backend.pending!.complete(late);
    await starting;
    expect(late.disposed, isTrue);
  });
  test('changing privacy choices invalidates an in-flight ad', () async {
    final backend = FakeBackend()
      ..requiredOptions = true
      ..pending = Completer<RewardedSlot>();
    final ads = RewardedAdsController(liveSettings, backend);
    final starting = ads.start();
    await Future<void>.delayed(Duration.zero);
    backend.allowed = false;
    await ads.openPrivacyOptions();
    final late = FakeSlot();
    backend.pending!.complete(late);
    await starting;
    expect(late.disposed, isTrue);
    expect(ads.ready, isFalse);
    ads.dispose();
  });
  test(
    'ad overlays and lifecycle pauses compose, and earned currency persists',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance(), audio = FakeAudio();
      final session = GameSession(GameState(), prefs, audio);
      session.setExternalOverlay(true, source: 'advertising');
      session.setForeground(false);
      session.setForeground(true);
      expect(session.foreground, isFalse);
      expect(audio.foreground, isFalse);
      session.update(1 / 60);
      expect(session.simulationSteps, 0);
      session.setExternalOverlay(true, source: 'privacy');
      session.setExternalOverlay(false, source: 'advertising');
      expect(session.foreground, isFalse);
      session.setForeground(false);
      session.setExternalOverlay(false, source: 'privacy');
      expect(session.foreground, isFalse);
      session.supply(fromAd: true);
      expect(jsonDecode(prefs.getString('forest_star_v1')!)['marbles'], 32);
      session.setForeground(true);
      expect(session.foreground, isTrue);
      session.dispose();
    },
  );
  testWidgets(
    'camp ads require an explicit opt-in and free supply still works',
    (tester) async {
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend();
      final controller = RewardedAdsController(const AdSettings(), backend);
      await tester.pumpWidget(
        ForestStarApp(
          prefs: await SharedPreferences.getInstance(),
          initialState: GameState(),
          audio: FakeAudio(),
          ads: controller,
        ),
      );
      final game = await enterGame(tester);
      await tester.pump();
      expect(controller.ready, isTrue);
      await gameTap(tester, game, const Offset(182, 842));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('觀看廣告，獲得 12 顆彈珠'), findsOneWidget);
      expect(game.session.foreground, isFalse);
      await tester.tap(find.text('暫不觀看'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(backend.slots.first.shows, 0);
      expect(game.session.state.marbles, 20);
      await gameTap(tester, game, const Offset(182, 842));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('觀看廣告 +12'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(backend.slots.first.shows, 1);
      expect(game.session.state.marbles, 32);
      await gameTap(tester, game, const Offset(60, 842));
      expect(game.session.state.marbles, 44);
      await tester.tap(find.byTooltip('隱私權與廣告設定'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(find.textContaining('info@foodbuyer.com.hk'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
