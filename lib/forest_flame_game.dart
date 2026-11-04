import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game_session.dart';
import 'storybook_ui.dart';
import 'forest_effects.dart';
import 'growth_showcase.dart';
import 'interaction_motion.dart';
import 'camp_patrol.dart';
import 'ultimate_showcase.dart';

const campSprites = [
  'assets/camp-pinball-sprite-v1.png',
  'assets/camp-companions-sprite-v1.png',
  'assets/camp-guard-sprite-v1.png',
];
const campSpriteBounds = [
  Rect.fromLTWH(38, 221, 210, 220),
  Rect.fromLTWH(254, 359, 214, 214),
  Rect.fromLTWH(141, 559, 230, 205),
];

/// One uniform transform for visuals and input; extra screen area shows scenery.
class SceneLayout {
  factory SceneLayout(
    Size size, {
    bool cover = false,
    EdgeInsets insets = EdgeInsets.zero,
  }) {
    final width = math.max(1.0, size.width - insets.horizontal),
        height = math.max(1.0, size.height - insets.vertical),
        scale = cover
            ? math.max(width / 480, height / 900)
            : math.min(width / 480, height / 900);
    return SceneLayout._(
      scale,
      Offset(
        insets.left + (width - 480 * scale) / 2,
        insets.top + (height - 900 * scale) / 2,
      ),
    );
  }
  SceneLayout._(this.scale, this.offset);
  final double scale;
  final Offset offset;
  Offset toScreen(Offset point) => offset + point * scale;
  Offset toScene(Offset point) => (point - offset) / scale;
  Rect get contentRect => offset & Size(480 * scale, 900 * scale);
}

class ForestFlameGame extends FlameGame {
  ForestFlameGame(this.session);
  final GameSession session;
  late final PositionComponent stage;
  late final PositionComponent scenery;
  late final ForestEffects effects;
  late final CampPatrol patrol;
  final locations = <CampLocation>[];
  SceneLayout? layout;
  SceneLayout? sceneLayout;
  EdgeInsets safeInsets = EdgeInsets.zero;
  int updateCount = 0;
  bool sceneReady = false;
  bool reducedMotion = false;
  late GamePainter lastPainter;

  @override
  Color backgroundColor() => const Color(0xff3b5737);

  @override
  Future<void> onLoad() async {
    await StoryArt.instance.load();
    stage = PositionComponent(size: Vector2(480, 900), priority: 20);
    scenery = PositionComponent(size: Vector2(480, 900), priority: 10);
    await add(scenery);
    await add(stage);
    // All foreground art and controls retain the same uncropped safe frame.
    for (var i = 0; i < 3; i++) {
      final image = StoryArt.instance.images['location$i']!;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final location = CampLocation(
        session,
        i,
        image,
        data!.buffer.asUint8List(),
      );
      locations.add(location);
      await scenery.add(location);
    }
    patrol = CampPatrol(session);
    await scenery.add(patrol);
    await stage.add(_SceneControls(session));
    effects = ForestEffects(session);
    await stage.add(effects);
    await stage.add(
      UltimateShowcase(
        session,
        viewport: () => Rect.fromPoints(
          layout!.toScene(Offset.zero),
          layout!.toScene(Offset(canvasSize.x, canvasSize.y)),
        ),
        reduceMotion: () => reducedMotion,
      ),
    );
    await stage.add(
      GrowthShowcase(
        session,
        // Draw beyond the fitted safe frame, including notches and the bottom
        // gesture area. Keep character, text and input on the existing layout.
        viewport: () => Rect.fromPoints(
          layout!.toScene(Offset.zero),
          layout!.toScene(Offset(canvasSize.x, canvasSize.y)),
        ),
      ),
    );
    _resizeStage();
    sceneReady = true;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    layout = SceneLayout(Size(size.x, size.y), insets: safeInsets);
    sceneLayout = SceneLayout(Size(size.x, size.y), cover: true);
    if (sceneReady) _resizeStage();
  }

  void setSafeInsets(EdgeInsets insets) {
    if (safeInsets == insets) return;
    safeInsets = insets;
    if (layout != null) {
      layout = SceneLayout(Size(canvasSize.x, canvasSize.y), insets: insets);
      if (sceneReady) _resizeStage();
    }
  }

  void _resizeStage() {
    final l = layout!;
    stage.position.setValues(l.offset.dx, l.offset.dy);
    stage.scale.setAll(l.scale);
    scenery.position.setValues(l.offset.dx, l.offset.dy);
    scenery.scale.setAll(l.scale);
  }

  @override
  void update(double dt) {
    session.update(dt);
    super.update(session.foreground && dt.isFinite ? dt.clamp(0.0, .1) : 0);
    updateCount++;
  }

  @override
  void render(Canvas canvas) {
    final screen = Offset.zero & Size(canvasSize.x, canvasSize.y);
    canvas.save();
    canvas.clipRect(screen);
    final art = StoryArt.instance.images;
    final background =
        art[session.tab == 1
            ? 'room'
            : session.tab == 2
            ? StoryArt.instance.battleFieldKey(
                session.combat.active
                    ? session.combat.stage
                    : session.state.stage,
              )
            : 'camp'];
    if (background != null) {
      final l = sceneLayout!;
      canvas.save();
      canvas.translate(l.offset.dx, l.offset.dy);
      canvas.scale(l.scale);
      paintImage(
        canvas: canvas,
        rect: const Rect.fromLTWH(0, 0, 480, 900),
        image: background,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
      canvas.restore();
    }
    canvas.drawRect(
      screen,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x602d4938),
            const Color(0x00374e31),
            session.tab == 1
                ? const Color(0x554d3f28)
                : const Color(0x33394e30),
          ],
          stops: const [0, .4, 1],
        ).createShader(screen),
    );
    // A short fade reveals the destination without moving its touch targets.
    final reveal = session.motion.reveal;
    if (reveal < 1) {
      canvas.saveLayer(
        screen,
        Paint()..color = Colors.white.withValues(alpha: .25 + .75 * reveal),
      );
    }
    super.render(canvas);
    if (reveal < 1) canvas.restore();
    canvas.restore();
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    session.setForeground(state == AppLifecycleState.resumed);
    super.lifecycleStateChange(state);
  }
}

class CampLocation extends SpriteComponent with TapCallbacks {
  CampLocation(this.session, this.destination, ui.Image image, this.alpha)
    : imageWidth = image.width,
      imageHeight = image.height,
      super(sprite: Sprite(image), anchor: Anchor.bottomCenter) {
    final bounds = campSpriteBounds[destination];
    final fit = math.min(
      bounds.width / imageWidth,
      bounds.height / imageHeight,
    );
    size.setValues(imageWidth * fit, imageHeight * fit);
    position.setValues(bounds.center.dx, bounds.bottom);
    priority = 100 + destination;
  }
  final GameSession session;
  final int destination, imageWidth, imageHeight;
  final Uint8List alpha;
  int? _pointer;
  int _generation = -1;
  late final TextPainter label = TextPainter(
    text: TextSpan(
      text: ['彈珠', '夥伴', '守衛'][destination],
      style: const TextStyle(
        fontFamily: 'ForestUI',
        fontSize: 23,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        shadows: [
          Shadow(color: Color(0xff284c30), blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  bool get visible => session.tab == 3;
  @override
  Future<void> onLoad() async {
    // Keep the foundation planted; only a subtle breathing scale changes.
    add(
      ScaleEffect.to(
        Vector2(1.004, 1.007),
        EffectController(
          duration: 1.8 + destination * .2,
          alternate: true,
          infinite: true,
        ),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final bounds = campSpriteBounds[destination];
    final compression = session.motion.compression(bounds);
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    canvas.scale(1 + compression * .5, 1 - compression);
    canvas.translate(-size.x / 2, -size.y);
    super.render(canvas);
    label.paint(canvas, Offset((size.x - label.width) / 2, size.y - 17));
    canvas.restore();
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    if (!visible ||
        session.result ||
        session.celebration != null ||
        !super.containsLocalPoint(point)) {
      return false;
    }
    final x = (point.x / size.x * imageWidth).floor().clamp(0, imageWidth - 1),
        y = (point.y / size.y * imageHeight).floor().clamp(0, imageHeight - 1);
    return alpha[(y * imageWidth + x) * 4 + 3] > 35;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!session.foreground || session.motion.holding) return;
    _pointer = event.pointerId;
    _generation = session.inputGeneration;
    session.motion.press(campSpriteBounds[destination]);
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    if (_pointer != event.pointerId) return;
    _pointer = null;
    session.motion.release(cancelled: true);
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (_pointer != event.pointerId) return;
    _pointer = null;
    session.motion.release();
    if (_generation == session.inputGeneration) session.open(destination);
  }
}

class _SceneControls extends PositionComponent
    with TapCallbacks, DragCallbacks {
  _SceneControls(this.session) : super(size: Vector2(480, 900), priority: 1000);
  final GameSession session;
  int? activePointer;
  Rect? downControl;
  bool downAim = false;
  int pointerGeneration = -1;
  @override
  bool containsLocalPoint(Vector2 point) {
    if (!super.containsLocalPoint(point)) return false;
    if (session.tab != 3 || session.result || session.celebration != null)
      return true;
    return point.y >= 782;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!session.foreground) return;
    activePointer ??= event.pointerId;
    if (activePointer != event.pointerId) return;
    pointerGeneration = session.inputGeneration;
    downControl = session.controlAt(event.localPosition.toOffset());
    downAim = session.canAim && session.aimArea(event.localPosition.toOffset());
    if (downControl != null) session.motion.press(downControl!);
    if (activePointer == event.pointerId &&
        session.canAim &&
        session.aimArea(event.localPosition.toOffset())) {
      session.setAim(event.localPosition.toOffset());
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (activePointer != event.pointerId) return;
    activePointer = null;
    session.motion.release();
    final point = event.localPosition.toOffset();
    if (pointerGeneration == session.inputGeneration &&
        (downControl != null && downControl == session.controlAt(point) ||
            downAim && session.canAim && session.aimArea(point))) {
      final page = session.tab;
      session.tap(point);
      if (page == session.tab &&
          !session.result &&
          session.celebration == null) {
        session.motion.add(CueKind.touch, point, page);
      }
    }
    downControl = null;
    downAim = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    if (activePointer == event.pointerId) {
      activePointer = null;
      downControl = null;
      downAim = false;
      session.motion.release(cancelled: true);
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (activePointer != null && activePointer != event.pointerId) return;
    if (!session.canAim || !session.aimArea(event.localPosition.toOffset())) {
      return;
    }
    activePointer = event.pointerId;
    pointerGeneration = session.inputGeneration;
    session.motion.release(cancelled: true);
    session.dragging = true;
    session.setAim(event.localPosition.toOffset());
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (session.dragging && activePointer == event.pointerId) {
      final p = event.localStartPosition;
      if (p.x.isFinite && p.y.isFinite) session.setAim(p.toOffset());
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (activePointer != event.pointerId) return;
    if (session.dragging &&
        session.foreground &&
        pointerGeneration == session.inputGeneration)
      session.launch();
    session.dragging = false;
    activePointer = null;
    downControl = null;
    downAim = false;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    session.dragging = false;
    activePointer = null;
    downControl = null;
    downAim = false;
    session.motion.release(cancelled: true);
    super.onDragCancel(event);
  }

  @override
  void render(Canvas canvas) {
    final s = session;
    final painter = GamePainter(
      s.state,
      s.pinball,
      s.combat,
      s.tab,
      s.selected,
      s.aim,
      s.time,
      s.toastUntil > s.time ? s.toast : '',
      s.result,
      s.resultTitle,
      s.resultDetail,
      s.resetUntil > s.time,
      motion: s.motion,
      dragging: s.dragging,
      adLabel: s.adLabel,
    );
    painter.paint(canvas, const Size(480, 900));
    (findGame()! as ForestFlameGame).lastPainter = painter;
  }
}
