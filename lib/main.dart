import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game.dart';
import 'audio.dart';
import 'storybook_ui.dart';
import 'game_session.dart';
import 'forest_flame_game.dart';
import 'rewarded_ads.dart';
import 'privacy_page.dart';
export 'storybook_ui.dart' show GamePainter;
export 'forest_flame_game.dart' show campSprites, campSpriteBounds;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await StoryArt.instance.load();
  final prefs = await SharedPreferences.getInstance();
  GameState state;
  try {
    state = GameState.fromJson(
      jsonDecode(prefs.getString('forest_star_v1') ?? '{}')
          as Map<String, dynamic>,
    );
  } catch (_) {
    state = GameState();
  }
  final ads =
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)
      ? RewardedAdsController(
          const AdSettings.environment(),
          GoogleRewardedBackend(),
        )
      : null;
  runApp(ForestStarApp(prefs: prefs, initialState: state, ads: ads));
}

class ForestStarApp extends StatefulWidget {
  const ForestStarApp({
    super.key,
    required this.prefs,
    required this.initialState,
    this.audio,
    this.ads,
  });
  final SharedPreferences prefs;
  final GameState initialState;
  final GameAudio? audio;
  final RewardedAdsController? ads;
  @override
  State<ForestStarApp> createState() => _ForestStarAppState();
}

class _ForestStarAppState extends State<ForestStarApp>
    with WidgetsBindingObserver {
  late final GameSession session;
  late final ForestFlameGame game;
  bool started = false;
  bool _dialogOpen = false;
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session = GameSession(
      widget.initialState,
      widget.prefs,
      widget.audio ?? AppAudio(),
    );
    game = ForestFlameGame(session);
    final ads = widget.ads;
    if (ads != null) {
      ads.onOverlayChanged = (value) =>
          session.setExternalOverlay(value, source: 'advertising');
      ads.addListener(_syncAdLabel);
      session.onAdRequested = () => unawaited(_requestReward());
      _syncAdLabel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(ads.start());
      });
    }
  }

  void _syncAdLabel() {
    final ads = widget.ads!;
    session.adLabel = ads.busy
        ? '廣告播放中'
        : ads.loading
        ? '廣告準備中'
        : ads.ready
        ? '廣告 +12'
        : '廣告・重試';
  }

  Future<void> _requestReward() async {
    final ads = widget.ads;
    if (ads == null || _dialogOpen || ads.busy || !session.foreground) return;
    if (!ads.ready) {
      session.notify(ads.status);
      unawaited(ads.retry());
      return;
    }
    if (session.state.marbles > 987) {
      session.notify('彈珠庫存充足，稍後再領取吧！');
      return;
    }
    _dialogOpen = true;
    session.setExternalOverlay(true);
    try {
      final confirmed = await showDialog<bool>(
        context: _navigator.currentContext!,
        builder: (context) => AlertDialog(
          title: const Text('觀看廣告，獲得 12 顆彈珠'),
          content: Text(
            '由你選擇是否觀看。達成廣告獎勵條件後，會自動獲得 12 顆彈珠；提早關閉不會發放獎勵。免費補給仍可照常使用。${ads.settings.production ? '' : '\n\n目前是測試廣告，不會產生收益。'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('暫不觀看'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('觀看廣告 +12'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      final earned = await ads.show(() => session.supply(fromAd: true));
      if (mounted && !earned) session.notify('這次未取得廣告獎勵，免費補給仍可使用。');
    } finally {
      if (mounted) session.setExternalOverlay(false);
      _dialogOpen = false;
    }
  }

  Future<void> _showPrivacy() async {
    if (_dialogOpen || widget.ads?.busy == true) return;
    _dialogOpen = true;
    session.setExternalOverlay(true, source: 'privacy');
    try {
      await _navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => PrivacyPage(ads: widget.ads)),
      );
    } finally {
      if (mounted) session.setExternalOverlay(false, source: 'privacy');
      _dialogOpen = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    session.setForeground(lifecycle == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.pauseEngine();
    widget.ads?.removeListener(_syncAdLabel);
    widget.ads?.dispose();
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'ForestUI',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff426b48)),
    ),
    home: Scaffold(
      backgroundColor: const Color(0xff3b5737),
      body: !started
          ? StartScreen(
              onPrivacy: () => unawaited(_showPrivacy()),
              onStart: () {
                session.click();
                setState(() => started = true);
              },
            )
          : Builder(
              builder: (context) {
                game.setSafeInsets(MediaQuery.paddingOf(context));
                return Stack(
                  children: [
                    RepaintBoundary(
                      key: const ValueKey('game_surface'),
                      child: GameWidget<ForestFlameGame>(
                        game: game,
                        loadingBuilder: (context) => Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/forest-star-start.png',
                              fit: BoxFit.cover,
                            ),
                            const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xfffff6df),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      child: SafeArea(
                        child: IconButton.filledTonal(
                          tooltip: '隱私權與廣告設定',
                          onPressed: () => unawaited(_showPrivacy()),
                          icon: const Icon(
                            Icons.privacy_tip_outlined,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    ),
  );
}

class StartScreen extends StatefulWidget {
  const StartScreen({super.key, required this.onStart, this.onPrivacy});
  final VoidCallback onStart;
  final VoidCallback? onPrivacy;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();
  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: motion,
          builder: (context, child) => Transform.scale(
            scale: 1.015 + math.sin(motion.value * math.pi * 2) * .01,
            child: child,
          ),
          child: Image.asset('assets/forest-star-start.png', fit: BoxFit.cover),
        ),
        IgnorePointer(
          child: AnimatedBuilder(
            animation: motion,
            builder: (context, _) =>
                CustomPaint(painter: StartGlow(motion.value)),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                SizedBox(height: constraints.maxHeight * .06),
                const Text(
                  'FOREST STAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Color(0xbb163a32), blurRadius: 8)],
                  ),
                ),
                const Text(
                  '森星小隊',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Color(0xcc163a32),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
                  child: SizedBox(
                    width: 240,
                    height: 54,
                    child: FilledButton(
                      onPressed: widget.onStart,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff356f58),
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(0xffd5b36e),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        '開始冒險',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.onPrivacy != null)
                  TextButton(
                    onPressed: widget.onPrivacy,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text(
                      '隱私權與廣告設定',
                      style: TextStyle(
                        shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
