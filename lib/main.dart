import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game.dart';
import 'audio.dart';
import 'game_session.dart';
import 'forest_flame_game.dart';
import 'rewarded_ads.dart';
import 'privacy_page.dart';
import 'game_tutorial.dart';
import 'update_page.dart';
import 'notice_board.dart';
import 'start_screen.dart';
import 'gacha_store.dart';
import 'gacha_page.dart';
import 'pet_gallery.dart';
export 'start_screen.dart' show StartScreen;
export 'storybook_ui.dart' show GamePainter;
export 'forest_flame_game.dart' show campSprites, campSpriteBounds;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
  runApp(
    GameUpdateGate(
      prefs: prefs,
      gameBuilder: (content) => ForestStarApp(
        prefs: prefs,
        initialState: state,
        ads: ads,
        billing:
            !kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS)
            ? NativeBillingStore()
            : null,
        audio: AppAudio(
          campMusicPath: content?.filePath('camp-music-v2'),
          adventureMusicPath: content?.filePath('adventure-music-v2'),
          effectPaths: content?.effectPaths ?? const {},
        ),
      ),
    ),
  );
}

class ForestStarApp extends StatefulWidget {
  const ForestStarApp({
    super.key,
    required this.prefs,
    required this.initialState,
    this.audio,
    this.ads,
    this.noticeBoard,
    this.billing,
  });
  final SharedPreferences prefs;
  final GameState initialState;
  final GameAudio? audio;
  final RewardedAdsController? ads;
  final NoticeBoardController? noticeBoard;
  final BillingStore? billing;
  @override
  State<ForestStarApp> createState() => _ForestStarAppState();
}

class _ForestStarAppState extends State<ForestStarApp>
    with WidgetsBindingObserver {
  late final GameSession session;
  late final ForestFlameGame game;
  late final NoticeBoardController notices;
  late final GachaController gacha;
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
    gacha = GachaController(session, billing: widget.billing);
    session.onGachaRequested = () => unawaited(_showGacha());
    session.onPetGalleryRequested = () => unawaited(_showPetGallery());
    unawaited(gacha.initialize());
    notices = widget.noticeBoard ?? NoticeBoardController(prefs: widget.prefs);
    if (widget.noticeBoard == null) unawaited(notices.refresh());
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

  Future<void> _showTutorial() async {
    if (_dialogOpen || widget.ads?.busy == true || !session.foreground) return;
    _dialogOpen = true;
    session.setExternalOverlay(true, source: 'tutorial');
    try {
      await _navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => GameTutorialPage(prefs: widget.prefs),
        ),
      );
      if (mounted) setState(() {});
    } finally {
      if (mounted) session.setExternalOverlay(false, source: 'tutorial');
      _dialogOpen = false;
    }
  }

  Future<void> _showNotice() async {
    if (_dialogOpen || widget.ads?.busy == true) return;
    _dialogOpen = true;
    session.setExternalOverlay(true, source: 'notice-board');
    try {
      await showForestNotice(_navigator.currentContext!, notices);
    } finally {
      if (mounted) session.setExternalOverlay(false, source: 'notice-board');
      _dialogOpen = false;
    }
  }

  Future<void> _showGacha() async {
    if (_dialogOpen || widget.ads?.busy == true) return;
    _dialogOpen = true;
    session.setExternalOverlay(true, source: 'gacha');
    try {
      await _navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => GachaPage(controller: gacha)),
      );
    } finally {
      if (mounted) session.setExternalOverlay(false, source: 'gacha');
      _dialogOpen = false;
    }
  }

  Future<void> _showPetGallery() async {
    if (_dialogOpen || widget.ads?.busy == true || !session.foreground) return;
    _dialogOpen = true;
    session.setExternalOverlay(true, source: 'pet-gallery');
    int? selected;
    try {
      selected = await _navigator.currentState!.push<int>(
        MaterialPageRoute<int>(
          builder: (_) =>
              PetGalleryPage(state: session.state, selected: session.selected),
        ),
      );
    } finally {
      if (mounted) session.setExternalOverlay(false, source: 'pet-gallery');
      _dialogOpen = false;
    }
    if (mounted && selected != null) session.selectCompanion(selected);
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
    gacha.dispose();
    session.dispose();
    if (widget.noticeBoard == null) notices.dispose();
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
              notices: notices,
              onNotice: _showNotice,
              onPrivacy: () => unawaited(_showPrivacy()),
              onTutorial: () => unawaited(_showTutorial()),
              tutorialCompleted:
                  widget.prefs.getBool(tutorialCompletedKey) ?? false,
              onStart: () {
                session.click();
                setState(() => started = true);
              },
            )
          : Builder(
              builder: (context) {
                game.setSafeInsets(MediaQuery.paddingOf(context));
                game.reducedMotion = MediaQuery.disableAnimationsOf(context);
                return ValueListenableBuilder<bool>(
                  valueListenable: session.ultimatePlaying,
                  builder: (context, casting, _) => Stack(
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
                      if (!casting)
                        Positioned(
                          left: 8,
                          top: 0,
                          child: SafeArea(
                            child: IconButton.filledTonal(
                              tooltip: '遊戲教學・中 / English / 粵',
                              onPressed: () => unawaited(_showTutorial()),
                              icon: const Icon(Icons.school_rounded, size: 21),
                            ),
                          ),
                        ),
                      if (!casting)
                        Positioned(
                          right: 8,
                          top: 0,
                          child: SafeArea(
                            child: IconButton.filledTonal(
                              tooltip: '星願轉珠 · 每日免費 5 次',
                              onPressed: () => unawaited(_showGacha()),
                              icon: const Icon(Icons.auto_awesome, size: 21),
                            ),
                          ),
                        ),
                      if (!casting)
                        Positioned(
                          right: 8,
                          top: 48,
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
                  ),
                );
              },
            ),
    ),
  );
}
