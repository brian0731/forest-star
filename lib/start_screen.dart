import 'dart:async';
import 'dart:math' as math;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'notice_board.dart';
import 'start_scene.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({
    super.key,
    required this.onStart,
    required this.notices,
    this.onNotice,
    this.onPrivacy,
    this.onTutorial,
    this.tutorialCompleted = false,
  });
  final VoidCallback onStart;
  final NoticeBoardController notices;
  final Future<void> Function()? onNotice;
  final VoidCallback? onPrivacy, onTutorial;
  final bool tutorialCompleted;
  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  final scene = StartForestScene();
  final tilt = ValueNotifier(Offset.zero);
  bool _noticeOpen = false, _foreground = true;
  bool get _reduced => MediaQuery.disableAnimationsOf(context);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (!mounted) return;
    final active =
        _foreground &&
        !_noticeOpen &&
        !_reduced &&
        TickerMode.valuesOf(context).enabled;
    scene.setMotion(active);
    if (active) {
      if (!motion.isAnimating) motion.repeat();
    } else {
      motion.stop();
    }
  }

  Future<void> _openNotice() async {
    if (_noticeOpen) return;
    _noticeOpen = true;
    _syncMotion();
    try {
      if (widget.onNotice != null) {
        await widget.onNotice!();
      } else {
        await showForestNotice(context, widget.notices);
      }
    } finally {
      _noticeOpen = false;
      if (mounted) _syncMotion();
    }
  }

  void _point(Offset position, Size size) {
    if (_reduced || _noticeOpen) return;
    final value = Offset(
      (position.dx / size.width * 2 - 1).clamp(-1, 1),
      (position.dy / size.height * 2 - 1).clamp(-1, 1),
    );
    tilt.value = value;
    scene.targetTilt = value;
  }

  void _release() {
    tilt.value = Offset.zero;
    scene.targetTilt = Offset.zero;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scene.pauseEngine();
    motion.dispose();
    tilt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, full) => Listener(
      onPointerHover: (e) => _point(e.localPosition, full.biggest),
      onPointerMove: (e) => _point(e.localPosition, full.biggest),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([motion, tilt]),
              builder: (_, child) => Transform.translate(
                offset: Offset(
                  tilt.value.dx * -7 +
                      (_reduced ? 0 : math.sin(motion.value * math.pi * 2) * 2),
                  tilt.value.dy * -5,
                ),
                child: Transform.scale(scale: 1.065, child: child),
              ),
              child: Image.asset(
                'assets/start/forest-stage-v1.webp',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .35, 1],
                  colors: [
                    Color(0x80214431),
                    Color(0x001c3e29),
                    Color(0x6623402f),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: LayoutBuilder(
                  builder: (context, space) {
                    final compact = space.maxHeight < 700;
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    return Column(
                      children: [
                        SizedBox(height: compact ? 8 : 22),
                        Text(
                          'FOREST STAR',
                          style: TextStyle(
                            color: const Color(0xffffecc0),
                            fontSize: compact ? 11 : 12,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(color: Color(0xaa173d2b), blurRadius: 9),
                            ],
                          ),
                        ),
                        Text(
                          '森星小隊',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 35 : 43,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            shadows: const [
                              Shadow(
                                color: Color(0xaa163a2b),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '跟著星光，和夥伴一起出發',
                          style: TextStyle(
                            color: Color(0xfffff5d7),
                            fontSize: 12,
                            shadows: [
                              Shadow(color: Color(0xaa183b2c), blurRadius: 5),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Semantics(
                            label: '點點夥伴，牠們會跳躍回應',
                            child: AnimatedBuilder(
                              animation: tilt,
                              builder: (_, child) => Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, .0013)
                                  ..rotateY(tilt.value.dx * .04)
                                  ..rotateX(-tilt.value.dy * .025),
                                child: child,
                              ),
                              child: RepaintBoundary(
                                child: GameWidget<StartForestScene>(
                                  key: const ValueKey('start_companions'),
                                  game: scene,
                                  loadingBuilder: (_) =>
                                      const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 22 : 30,
                          ),
                          child: SizedBox(
                            height:
                                ((compact ? 118.0 : 148.0) *
                                        math.min(scale, 1.3))
                                    .clamp(118, 182),
                            child: ForestNoticeBoard(
                              controller: widget.notices,
                              onOpen: () => unawaited(_openNotice()),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 9 : 15),
                        AdventureArtButton(
                          onPressed: widget.onStart,
                          compact: compact,
                        ),
                        if (widget.onTutorial != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: TextButton.icon(
                              key: const ValueKey('start_tutorial'),
                              onPressed: widget.onTutorial,
                              icon: const Icon(Icons.school_rounded, size: 18),
                              label: Text(
                                widget.tutorialCompleted
                                    ? '重溫遊戲教學'
                                    : '新手教學 · 中 / English / 粵',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xe6fff4d7),
                                foregroundColor: const Color(0xff355e3d),
                                minimumSize: const Size(210, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 7,
                                ),
                              ),
                            ),
                          ),
                        if (widget.onPrivacy != null)
                          TextButton(
                            onPressed: widget.onPrivacy,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size(44, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            child: const Text(
                              '隱私權與廣告設定',
                              style: TextStyle(
                                fontSize: 10,
                                shadows: [
                                  Shadow(
                                    color: Color(0xbb173823),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        SizedBox(height: compact ? 5 : 12),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class AdventureArtButton extends StatefulWidget {
  const AdventureArtButton({
    super.key,
    required this.onPressed,
    this.compact = false,
  });
  final VoidCallback onPressed;
  final bool compact;
  @override
  State<AdventureArtButton> createState() => _AdventureArtButtonState();
}

class _AdventureArtButtonState extends State<AdventureArtButton>
    with SingleTickerProviderStateMixin {
  late final gleam = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  bool pressed = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      gleam.stop();
    } else if (!gleam.isAnimating) {
      gleam.repeat();
    }
  }

  @override
  void dispose() {
    gleam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '開始冒險',
    excludeSemantics: true,
    onTap: widget.onPressed,
    child: FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: GestureDetector(
        key: const ValueKey('start_adventure'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => pressed = true),
        onTapCancel: () => setState(() => pressed = false),
        onTapUp: (_) => setState(() => pressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0012)
            ..rotateX(pressed ? 0.10 : 0.0)
            ..scaleByDouble(pressed ? 0.96 : 1.0, pressed ? 0.96 : 1.0, 1, 1),
          width: widget.compact ? 280 : 310,
          height: widget.compact ? 78 : 86,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x66314e28),
                      blurRadius: pressed ? 7 : 15,
                      spreadRadius: -8,
                      offset: Offset(0, pressed ? 4 : 10),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/start/adventure-button-v1.png',
                  fit: BoxFit.fill,
                ),
              ),
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: gleam,
                  builder: (_, _) =>
                      CustomPaint(painter: _ButtonGleam(gleam.value)),
                ),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Text(
                    '開始冒險',
                    style: TextStyle(
                      color: Color(0xfffff0c5),
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: Color(0xff18391c),
                          offset: Offset(0, 2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ButtonGleam extends CustomPainter {
  _ButtonGleam(this.phase);
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    final region = RRect.fromRectAndRadius(
      Rect.fromLTWH(41, 17, size.width - 82, size.height - 35),
      const Radius.circular(22),
    );
    canvas.save();
    canvas.clipRRect(region);
    final x = -90 + phase * (size.width + 180);
    final band = Rect.fromLTWH(x, -20, 65, size.height + 40);
    canvas.drawRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.transparent, Color(0x37fff6c8), Colors.transparent],
        ).createShader(band),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ButtonGleam old) => old.phase != phase;
}
