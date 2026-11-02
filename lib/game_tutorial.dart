import 'dart:async';
import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'audio.dart';
import 'forest_flame_game.dart';
import 'game.dart';
import 'game_session.dart';
import 'tutorial_narrator.dart';

const tutorialCompletedKey = 'forest_tutorial_completed_v1';
const tutorialLanguageKey = 'forest_tutorial_language';
const tutorialVoiceKey = 'forest_tutorial_voice';

class TutorialLesson {
  const TutorialLesson(
    this.page,
    this.focus,
    this.zhTitle,
    this.enTitle,
    this.zh,
    this.en,
    this.yue,
  );
  final int page;
  final Rect focus;
  final String zhTitle, enTitle, zh, en, yue;
  String title(TutorialLanguage language) =>
      language == TutorialLanguage.english ? enTitle : zhTitle;
  String body(TutorialLanguage language) => switch (language) {
    TutorialLanguage.chinese => zh,
    TutorialLanguage.english => en,
    TutorialLanguage.cantonese => yue,
  };
}

const tutorialLessons = [
  TutorialLesson(
    3,
    Rect.fromLTWH(38, 221, 210, 220),
    '歡迎來到森林營地',
    'Welcome to the forest',
    '這是練習營地，不會改變你的正式進度。點亮起的彈珠屋，開始冒險吧！',
    'This practice camp keeps your real progress safe. Tap the glowing marble house to begin!',
    '呢度係練習營地，唔會影響你嘅正式進度。撳發光嘅彈珠屋，開始冒險啦！',
  ),
  TutorialLesson(
    0,
    Rect.fromLTWH(24, 754, 311, 53),
    '試射一顆彈珠',
    'Launch a marble',
    '正式遊玩時，在彈珠台拖曳可以瞄準，放開就發射。現在點亮起的發射區，試射一顆。',
    'In the game, drag on the board to aim and release to launch. Tap the highlighted launch area to try a shot.',
    '正式玩嗰陣，喺彈珠台拖曳就可以瞄準，放手就發射。而家撳發光嘅發射區試吓啦。',
  ),
  TutorialLesson(
    0,
    Rect.fromLTWH(36, 590, 408, 104),
    '六個籃子，六位夥伴',
    'Six baskets, six friends',
    '不同顏色的彈珠有不同碰撞次數和分數。彈珠落入哪個籃子，就把成長分送給對應夥伴。先看看它落在哪裡！',
    'Marble colors have different hit counts and scores. The landing basket gives growth points to its matching companion. Watch where it lands!',
    '唔同顏色嘅彈珠有唔同碰撞次數同分數。跌入邊個籃，就加成長分畀嗰位夥伴。睇吓佢跌去邊！',
  ),
  TutorialLesson(
    1,
    Rect.fromLTWH(24, 220, 432, 291),
    '認識你的夥伴',
    'Meet your companions',
    '點選夥伴可以查看能力。每位夥伴的攻擊方式都不同；我們先選芽耳兔來練習升級。',
    'Select a companion to view its abilities. Each has a different attack style. Let us practice with the rabbit.',
    '撳夥伴就睇到能力，每位夥伴嘅攻擊方法都唔同。我哋先揀芽耳兔，試吓升級。',
  ),
  TutorialLesson(
    1,
    Rect.fromLTWH(24, 698, 211, 52),
    '用星糖提升等級',
    'Level up with Star Candy',
    '收集星糖後，可以提升夥伴等級及攻擊力。練習資源已準備好，點升級看看！',
    'Spend Star Candy to increase a companion’s level and attack power. Practice resources are ready. Tap Upgrade!',
    '儲夠星糖就可以提升夥伴等級同攻擊力。練習資源準備好喇，撳升級睇吓！',
  ),
  TutorialLesson(
    1,
    Rect.fromLTWH(245, 698, 211, 52),
    '見證夥伴進化',
    'Watch an evolution',
    '達到所需等級，並有足夠星露，就可以進化。點進化，看看夥伴的粒子爆發動畫！',
    'Reach the required level and collect enough Star Dew to evolve. Tap Evolve for a burst of magical particles!',
    '到咗指定等級，再儲夠星露，就可以進化。撳進化，睇吓夥伴嘅粒子爆發動畫啦！',
  ),
  TutorialLesson(
    1,
    Rect.fromLTWH(118, 758, 335, 43),
    '安排四路守衛',
    'Build a four-lane team',
    '先選夥伴，再點路線就能安排守衛。每條路可放一位；現在幫你把苔石龜安排到第四路。',
    'Select a companion, then choose a lane to assign it. Each lane holds one companion. Let us place the turtle in lane four.',
    '先揀夥伴，再撳路線就安排到守衛，每條路可以放一位。而家將苔石龜放去第四路。',
  ),
  TutorialLesson(
    2,
    Rect.fromLTWH(24, 754, 311, 53),
    '出發，守護營地',
    'Defend your camp',
    '準備好隊伍後，點開始守衛。夥伴會自動攻擊，試著觀察四條路的戰況。',
    'Once your team is ready, tap Start Defense. Your companions attack automatically. Watch all four lanes.',
    '隊伍準備好，就撳開始守衛。夥伴會自動攻擊，一齊睇住四條路嘅戰況啦！',
  ),
  TutorialLesson(
    2,
    Rect.fromLTWH(24, 290, 432, 350),
    '觀察戰況，再調整隊伍',
    'Watch and improve your team',
    '敵人會沿四條路進攻。勝利能獲得資源；如果失敗，升級夥伴及調整隊伍後可以再試。',
    'Enemies approach along four lanes. Winning earns resources. If you lose, upgrade your companions, adjust your team, and try again.',
    '敵人會沿住四條路進攻。贏咗就有資源；輸咗都唔緊要，升級夥伴、調整隊伍，再試過！',
  ),
  TutorialLesson(
    3,
    Rect.fromLTWH(20, 820, 150, 58),
    '免費補給，隨時再玩',
    'Free supplies, more adventures',
    '彈珠不足時，可用免費補給增加十二顆彈珠。廣告是自選的，不是繼續遊玩的條件。完成後就回到正式冒險！',
    'Use free supplies to get twelve more marbles. Ads are optional and never required to keep playing. Finish to return to your real adventure!',
    '彈珠唔夠，可以用免費補給加十二粒。廣告係自選，唔睇都可以繼續玩。完成教學就返去正式冒險啦！',
  ),
];

/// An intentionally silent practice world: narration has the audio stage.
class _PracticeAudio implements GameAudio {
  @override
  void setEnabled(bool value) {}
  @override
  void setForeground(bool value) {}
  @override
  void setScene(MusicScene scene) {}
  @override
  void play(SoundEffect effect) {}
  @override
  void dispose() {}
}

GameSession createTutorialSession(SharedPreferences prefs) {
  final state = GameState()
    ..sugar = 300
    ..dew = 12
    ..marbles = 40
    ..levels = List.filled(6, 2)
    ..unlocked = List.filled(6, true)
    ..sound = false;
  return GameSession(state, prefs, _PracticeAudio(), persist: false);
}

class _PracticeGame extends ForestFlameGame {
  _PracticeGame(super.session, this.onReady);
  final VoidCallback onReady;
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    onReady();
  }
}

class GameTutorialPage extends StatefulWidget {
  const GameTutorialPage({super.key, required this.prefs, this.narrator});
  final SharedPreferences prefs;
  final TutorialNarrator? narrator;
  @override
  State<GameTutorialPage> createState() => _GameTutorialPageState();
}

class _GameTutorialPageState extends State<GameTutorialPage>
    with WidgetsBindingObserver {
  late final GameSession _session = createTutorialSession(widget.prefs);
  late final ForestFlameGame _game = _PracticeGame(_session, () {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _present();
    });
  });
  late final TutorialNarrator _narrator =
      widget.narrator ?? DeviceTutorialNarrator();
  late TutorialLanguage _language = TutorialLanguage.fromCode(
    widget.prefs.getString(tutorialLanguageKey),
  );
  late bool _voice = widget.prefs.getBool(tutorialVoiceKey) ?? true;
  final _surface = GlobalKey();
  final _cardRevision = ValueNotifier(0);
  TutorialCoachMark? _coach;
  int _step = 0, _presentation = 0;
  bool _ready = false, _busy = false, _closing = false, _active = true;
  String tr(String zh, String en) =>
      _language == TutorialLanguage.english ? en : zh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _narrator.addListener(_refreshCard);
  }

  void _refreshCard() {
    if (mounted && !_closing) _cardRevision.value++;
  }

  void _read() {
    if (!_voice || !_active || _closing) return;
    final lesson = tutorialLessons[_step];
    unawaited(
      _narrator.speak(
        '${lesson.title(_language)}。${lesson.body(_language)}',
        _language,
      ),
    );
  }

  void _present() {
    final presentation = ++_presentation;
    _coach?.removeOverlayEntry();
    _coach = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closing || _busy || presentation != _presentation) {
        return;
      }
      final box = _surface.currentContext?.findRenderObject() as RenderBox?;
      final layout = _game.layout;
      if (box == null || layout == null || !_ready) return;
      final lesson = tutorialLessons[_step];
      final offset = box.localToGlobal(layout.toScreen(lesson.focus.topLeft));
      final size = lesson.focus.size * layout.scale;
      final screen = MediaQuery.sizeOf(context);
      final safe = MediaQuery.paddingOf(context);
      final cardAbove = lesson.focus.center.dy > 450;
      final cardTop = cardAbove ? safe.top + 66 : offset.dy + size.height + 18;
      final available = math.max(
        100.0,
        screen.height - cardTop - safe.bottom - 12,
      );
      final coach = TutorialCoachMark(
        targets: [
          TargetFocus(
            identify: 'lesson-$_step',
            targetPosition: TargetPosition(size, offset),
            shape: ShapeLightFocus.RRect,
            radius: 20,
            enableOverlayTab: false,
            contents: [
              TargetContent(
                align: ContentAlign.custom,
                customPosition: CustomTargetContentPosition(
                  top: cardTop,
                  left: 0,
                ),
                padding: EdgeInsets.zero,
                builder: (context, controller) => ValueListenableBuilder<int>(
                  valueListenable: _cardRevision,
                  builder: (context, _, child) => Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 440,
                        maxHeight: available,
                      ),
                      child: _buildCard(coachNext: controller.next),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        hideSkip: true,
        useSafeArea: false,
        colorShadow: const Color(0xff173e31),
        opacityShadow: .72,
        paddingFocus: 5,
        focusAnimationDuration: const Duration(milliseconds: 220),
        unFocusAnimationDuration: const Duration(milliseconds: 160),
        onFinish: () => unawaited(_advance()),
      );
      _coach = coach;
      coach.show(context: context, rootOverlay: true);
      // The plugin schedules insertion for the next frame. Also remove an
      // insertion that was pending when the route closed or size changed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _coach != coach) coach.removeOverlayEntry();
      });
      _read();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Widget _buildCard({required VoidCallback coachNext}) => Material(
    color: Colors.transparent,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xfffff6df),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffd5b36e), width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_stories_rounded,
                        color: Color(0xff356f58),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${tr('森林小教室', 'Forest lessons')}  ${_step + 1}/${tutorialLessons.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xff356f58),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _exit,
                        tooltip: tr('離開教學', 'Exit tutorial'),
                        icon: const Icon(Icons.close),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  LinearProgressIndicator(
                    value: (_step + 1) / tutorialLessons.length,
                    color: const Color(0xff356f58),
                    backgroundColor: const Color(0xffe5dcc4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tutorialLessons[_step].title(_language),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff284b36),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tutorialLessons[_step].body(_language),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Color(0xff354936),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final language in TutorialLanguage.values)
                        ChoiceChip(
                          label: Text(language.label),
                          selected: _language == language,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) {
                            setState(() => _language = language);
                            unawaited(
                              widget.prefs.setString(
                                tutorialLanguageKey,
                                language.code,
                              ),
                            );
                            _refreshCard();
                            unawaited(
                              _narrator.stop().then((_) {
                                if (mounted) _read();
                              }),
                            );
                          },
                        ),
                      IconButton(
                        tooltip: _voice
                            ? tr('關閉朗讀', 'Mute narration')
                            : tr('開啟朗讀', 'Enable narration'),
                        onPressed: () {
                          _voice = !_voice;
                          unawaited(
                            widget.prefs.setBool(tutorialVoiceKey, _voice),
                          );
                          if (_voice) {
                            _read();
                          } else {
                            unawaited(_narrator.stop());
                          }
                          _refreshCard();
                        },
                        icon: Icon(
                          _voice
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _voice ? _read : null,
                        icon: const Icon(Icons.replay_rounded, size: 18),
                        label: Text(tr('再聽一次', 'Replay')),
                      ),
                    ],
                  ),
                  if (_voice &&
                      (_narrator.status == NarrationStatus.unavailable ||
                          _narrator.status == NarrationStatus.failed))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        tr(
                          '未能使用此語音。請在裝置的語音設定下載對應語言，之後點「再聽一次」；文字教學仍可繼續。',
                          'Voice unavailable. Install this language in device speech settings, then tap Replay. You can continue with text.',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xff805323),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('tutorial_next'),
                onPressed: coachNext,
                icon: Icon(
                  _step == tutorialLessons.length - 1
                      ? Icons.check_rounded
                      : Icons.touch_app_rounded,
                ),
                label: Text(
                  _step == tutorialLessons.length - 1
                      ? tr('完成教學', 'Finish tutorial')
                      : tr('試試看・下一步', 'Try it · Next'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _waitWhile(bool Function() condition, int ticks) async {
    var elapsed = 0;
    while (elapsed < ticks && mounted && !_closing && condition()) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_active) elapsed++;
    }
  }

  Future<void> _advance() async {
    if (_busy || _closing || !mounted) return;
    _busy = true;
    _coach = null;
    await _narrator.stop();
    if (!mounted || _closing) return;
    switch (_step) {
      case 1:
        _session.launch();
      case 2:
        await _waitWhile(
          () => _session.pinball.active || _session.celebration != null,
          200,
        );
      case 3:
        _session.selected = 0;
        _session.state.levels[0] = 2;
        _session.state.evolutions[0] = 0;
      case 4:
        _session.tap(const Offset(125, 722));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await _waitWhile(() => _session.celebration != null, 45);
      case 5:
        _session.tap(const Offset(350, 722));
        // Let the game mount the queued celebration, then wait for its finale.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await _waitWhile(() => _session.celebration != null, 50);
      case 6:
        _session.selected = 3;
        _session.tap(const Offset(413, 780));
      case 7:
        _session.tap(const Offset(160, 780));
      case 9:
        _session.supply();
    }
    if (!mounted || _closing) return;
    if (_step == tutorialLessons.length - 1) {
      await widget.prefs.setBool(tutorialCompletedKey, true);
      if (mounted) _exit();
      return;
    }
    setState(() {
      _step++;
      _session.result = false;
      _session.tab = tutorialLessons[_step].page;
      _session.motion.pageChanged();
      _busy = false;
    });
    _present();
  }

  void _exit() {
    if (_closing) return;
    _closing = true;
    _coach?.removeOverlayEntry();
    _coach = null;
    unawaited(_narrator.stop());
    Navigator.of(context).pop();
  }

  @override
  void didChangeMetrics() {
    if (_ready && !_busy && !_closing) _present();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _session.setForeground(_active);
    if (!_active) unawaited(_narrator.stop());
  }

  @override
  void dispose() {
    _closing = true;
    _presentation++;
    WidgetsBinding.instance.removeObserver(this);
    _coach?.removeOverlayEntry();
    _narrator.removeListener(_refreshCard);
    unawaited(_narrator.stop());
    if (widget.narrator == null) _narrator.dispose();
    _cardRevision.dispose();
    _game.pauseEngine();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff3b5737),
    body: LayoutBuilder(
      builder: (context, constraints) {
        _game.setSafeInsets(MediaQuery.paddingOf(context));
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: GameWidget<ForestFlameGame>(key: _surface, game: _game),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xeefff6df),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.school_rounded,
                        color: Color(0xff356f58),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          tr(
                            '練習模式 · 正式進度安全保存',
                            'Practice · Your real progress is safe',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xff284b36),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _exit,
                        tooltip: tr('離開教學', 'Exit tutorial'),
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
