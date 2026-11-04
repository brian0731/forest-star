import 'dart:math' as math;
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game.dart';
import 'interaction_motion.dart';
import 'content_updates.dart';
import 'guard_themes.dart';
import 'companion_layout.dart';
import 'ultimate_spell.dart';

class StoryArt {
  StoryArt._();
  static final instance = StoryArt._();
  final images = <String, ui.Image>{};
  Future<void>? _loading;
  String battleFieldKey(int stage) {
    final key = GuardTheme.forStage(stage).fieldKey;
    return images.containsKey(key) ? key : 'field';
  }

  Future<void> load({ContentBundle? content, bool reset = false}) {
    if (content != null || _loading == null || reset) {
      _loading = _load(content: content).catchError((
        Object error,
        StackTrace stack,
      ) {
        _loading = null;
        Error.throwWithStackTrace(error, stack);
      });
    }
    return _loading!;
  }

  Future<void> _load({ContentBundle? content}) async {
    final paths = <String, String>{
      'board': 'assets/storybook/pinball-board-v2.webp',
      'field': 'assets/storybook/guard-horizontal-v1.webp',
      for (var stage = 2; stage <= 10; stage++)
        if (content?.filePath('field-level$stage') != null)
          'field-level$stage': 'assets/storybook/guard-horizontal-v1.webp',
      'camp': 'assets/storybook/camp.webp',
      'room': 'assets/storybook/companions.webp',
      'battle': 'assets/storybook/camp.webp',
      for (var i = 0; i < 3; i++)
        'location$i': [
          'assets/camp-pinball-sprite-v1.png',
          'assets/camp-companions-sprite-v1.png',
          'assets/camp-guard-sprite-v1.png',
        ][i],
      for (var i = 0; i < friends.length; i++)
        'friend$i': i < 6
            ? 'assets/storybook/character-$i.png'
            : 'assets/pets/character-$i.png',
      for (var i = 0; i < 4; i++) 'marble$i': 'assets/storybook/marble-$i.png',
      for (var i = 0; i < 4; i++)
        'nav$i': 'assets/storybook/navigation-$i-v1.png',
      for (final name in ['paper', 'green', 'cream', 'selected'])
        'frame-$name': 'assets/storybook/frame-$name-v1.png',
    };
    final loaded = <String, ui.Image>{};
    try {
      await Future.wait(
        paths.entries.map((entry) async {
          final path =
              content?.filePath(entry.key) ??
              (entry.key == 'battle' ? content?.filePath('camp') : null);
          final bytes = path == null
              ? (await rootBundle.load(entry.value)).buffer.asUint8List()
              : await File(path).readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          try {
            loaded[entry.key] = (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
        }),
      );
    } catch (_) {
      for (final image in loaded.values) {
        image.dispose();
      }
      rethrow;
    }
    for (final image in images.values) {
      image.dispose();
    }
    images
      ..clear()
      ..addAll(loaded);
  }
}

/// Keep painted corners and border thickness intact on every panel aspect ratio.
void paintStoryFrame(
  Canvas canvas,
  Rect rect,
  String style, {
  bool disabled = false,
  double opacity = 1,
}) {
  final image = StoryArt.instance.images['frame-$style'];
  if (image == null) return;
  final edge = (image.width * .17).roundToDouble();
  // Drawing at 4x reduces each fixed corner to 21 logical pixels; stretch only
  // the quiet centre and straight rail spans. Small controls retain their edges.
  const density = 4.0;
  canvas.save();
  canvas.translate(rect.left, rect.top);
  canvas.scale(1 / density);
  final paint = Paint()
    ..filterQuality = FilterQuality.low
    ..color = Colors.white.withValues(alpha: opacity);
  if (disabled) {
    paint.colorFilter = const ColorFilter.matrix([
      .30,
      .45,
      .10,
      0,
      24,
      .30,
      .45,
      .10,
      0,
      24,
      .30,
      .45,
      .10,
      0,
      24,
      0,
      0,
      0,
      1,
      0,
    ]);
  }
  // Integer slices and bilinear sampling keep compressed thin rails clean.
  final width = rect.width * density, height = rect.height * density;
  final dx = math.min(edge, width / 2), dy = math.min(edge, height / 2);
  final sx = [0.0, edge, image.width - edge, image.width.toDouble()];
  final sy = [0.0, edge, image.height - edge, image.height.toDouble()];
  final tx = [0.0, dx, width - dx, width], ty = [0.0, dy, height - dy, height];
  for (var row = 0; row < 3; row++) {
    for (var col = 0; col < 3; col++) {
      canvas.drawImageRect(
        image,
        Rect.fromLTRB(sx[col], sy[row], sx[col + 1], sy[row + 1]),
        Rect.fromLTRB(tx[col], ty[row], tx[col + 1], ty[row + 1]),
        paint,
      );
    }
  }
  canvas.restore();
}

class StartGlow extends CustomPainter {
  StartGlow(this.phase);
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 18; i++) {
      final x = (i * .173 + math.sin(phase * math.pi * 2 + i) * .035) % 1,
          y = (i * .137 - phase * .16 + 2) % 1,
          opacity = .25 + .22 * math.sin(phase * math.pi * 2 + i);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        i.isEven ? 2 : 1.3,
        Paint()..color = Color.fromRGBO(255, 245, 187, opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant StartGlow oldDelegate) =>
      oldDelegate.phase != phase;
}

/// All painted controls use the same 480 x 900 coordinates as the game input.
class GamePainter extends CustomPainter {
  static final _textCache =
      LinkedHashMap<
        (String, double, double, int, bool, bool, TextAlign),
        TextPainter
      >();
  static int textLayouts = 0;
  GamePainter(
    this.state,
    this.pinball,
    this.combat,
    this.tab,
    this.selected,
    this.aim,
    this.time,
    this.toast,
    this.result,
    this.resultTitle,
    this.resultDetail,
    this.resetting, {
    this.motion,
    this.dragging = false,
    this.adLabel,
  });
  final GameState state;
  final Pinball pinball;
  final Combat combat;
  final int tab, selected;
  final Offset aim;
  final double time;
  final String toast, resultTitle, resultDetail;
  final bool result, resetting;
  final InteractionMotion? motion;
  final bool dragging;
  final String? adLabel;
  late Canvas canvas;
  static const ink = Color(0xff39482f),
      muted = Color(0xff778365),
      green = Color(0xff426b48),
      gold = Color(0xffd5b36e),
      paper = Color(0xfffff6df),
      brown = Color(0xff82603e);

  void box(
    double x,
    double y,
    double w,
    double h,
    Color color, [
    double r = 12,
  ]) {
    if (w <= 0 || h <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
      Paint()..color = color,
    );
  }

  void circle(double x, double y, double r, Color color) =>
      canvas.drawCircle(Offset(x, y), r, Paint()..color = color);
  void line(Offset a, Offset b, Color color, [double width = 1]) =>
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );

  void text(
    double x,
    double y,
    double w,
    double h,
    String value,
    double size,
    Color color, {
    bool bold = false,
    TextAlign align = TextAlign.left,
    bool shadow = false,
  }) {
    final key = (value, size, w, color.toARGB32(), bold, shadow, align);
    var p = _textCache[key];
    if (p == null) {
      if (_textCache.length >= 512) {
        _textCache.remove(_textCache.keys.first)?.dispose();
      }
      textLayouts++;
      p = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'ForestUI',
            fontSize: size,
            height: 1.25,
            color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            shadows: shadow
                ? const [
                    Shadow(
                      color: Color(0xaa233f2c),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: w);
      _textCache[key] = p;
    }
    p.paint(
      canvas,
      Offset(
        x +
            (align == TextAlign.center
                ? (w - p.width) / 2
                : align == TextAlign.right
                ? w - p.width
                : 0),
        y + (h - p.height) / 2,
      ),
    );
  }

  void panel(
    double x,
    double y,
    double w,
    double h, {
    Color fill = paper,
    double radius = 18,
  }) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      Radius.circular(math.min(radius, 12)),
    );
    canvas.drawShadow(
      Path()..addRRect(rect),
      const Color(0xff243c25),
      5,
      false,
    );
    paintStoryFrame(
      canvas,
      rect.outerRect,
      fill == const Color(0xfffff2c9) ? 'selected' : 'paper',
    );
  }

  void leaf(double x, double y, double size, double angle) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size, height: size * .48),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xff8da95e), green],
        ).createShader(Rect.fromLTWH(-size / 2, -size / 2, size, size)),
    );
    line(
      Offset(-size * .35, 0),
      Offset(size * .35, 0),
      const Color(0xffc4d191),
      .7,
    );
    canvas.restore();
  }

  void button(
    double x,
    double y,
    double w,
    double h,
    String label, {
    bool secondary = false,
    double size = 16,
    bool disabled = false,
  }) {
    canvas.save();
    pressTransform(Rect.fromLTWH(x, y, w, h));
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(15),
    );
    canvas.drawShadow(
      Path()..addRRect(rect),
      const Color(0xff243c25),
      3,
      false,
    );
    paintStoryFrame(
      canvas,
      rect.outerRect,
      secondary ? 'cream' : 'green',
      disabled: disabled,
    );
    text(
      x + 8,
      y,
      w - 16,
      h,
      label,
      size,
      secondary ? brown : Colors.white,
      bold: true,
      align: TextAlign.center,
    );
    canvas.restore();
  }

  void pressTransform(Rect bounds) {
    final depth = motion?.compression(bounds) ?? 0;
    if (depth == 0) return;
    canvas.translate(bounds.center.dx, bounds.center.dy + depth * 36);
    canvas.scale(1 - depth, 1 - depth);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);
  }

  void image(
    String key,
    Rect rect, {
    double radius = 0,
    BoxFit fit = BoxFit.cover,
  }) {
    final img = StoryArt.instance.images[key];
    if (img == null) return;
    canvas.save();
    if (radius > 0)
      canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    paintImage(
      canvas: canvas,
      rect: rect,
      image: img,
      fit: fit,
      filterQuality: FilterQuality.medium,
    );
    canvas.restore();
  }

  void portrait(
    double x,
    double y,
    double size,
    int id, {
    bool locked = false,
  }) {
    final bob = math.sin(time * 2.2 + id) * 1.3;
    final selectedWave = motion?.selectedFriend == id && tab == 1
        ? math.sin((motion!.selectionAge / .5).clamp(0.0, 1.0) * math.pi)
        : 0.0;
    final rect = Rect.fromCenter(
      center: Offset(x, y + bob),
      width: size,
      height: size,
    );
    canvas.save();
    canvas.translate(x, y + size * .4);
    canvas.rotate(
      math.sin((motion?.selectionAge ?? 1) * 22) * selectedWave * .09,
    );
    canvas.scale(1 + selectedWave * .045, 1 + selectedWave * .045);
    canvas.translate(-x, -y - size * .4);
    if (locked)
      canvas.saveLayer(
        rect,
        Paint()
          ..colorFilter = const ColorFilter.matrix([
            .25,
            .45,
            .1,
            0,
            25,
            .25,
            .45,
            .1,
            0,
            25,
            .25,
            .45,
            .1,
            0,
            25,
            0,
            0,
            0,
            .65,
            0,
          ]),
      );
    image('friend$id', rect, fit: BoxFit.contain);
    if (locked) canvas.restore();
    canvas.restore();
  }

  void sprout(double x, double y) {
    line(Offset(x, y + 6), Offset(x, y - 5), const Color(0xffd7e8b7), 2);
    leaf(x - 6, y - 4, 16, .6);
    leaf(x + 6, y - 8, 16, -.6);
  }

  void resourceIcon(double x, double y, int id) {
    circle(x, y, 13, const Color(0x1f584d2e));
    if (id == 0) {
      final p = Path();
      for (var n = 0; n < 10; n++) {
        final a = -math.pi / 2 + n * math.pi / 5, r = n.isEven ? 10.0 : 4.7;
        if (n == 0) {
          p.moveTo(x + math.cos(a) * r, y + math.sin(a) * r);
        } else {
          p.lineTo(x + math.cos(a) * r, y + math.sin(a) * r);
        }
      }
      p.close();
      canvas.drawPath(p, Paint()..color = const Color(0xffe7b24e));
    } else {
      final rect = Rect.fromCircle(center: Offset(x, y), radius: 10);
      canvas.drawCircle(
        Offset(x, y),
        10,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.4, -.5),
            colors: [
              Colors.white,
              id == 1 ? const Color(0xff85d8e4) : const Color(0xffa3d4b3),
              id == 1 ? const Color(0xff3594b1) : const Color(0xff4c9b75),
            ],
          ).createShader(rect),
      );
      circle(x - 3, y - 4, 2.5, const Color(0xd9ffffff));
    }
  }

  void header() {
    text(
      0,
      15,
      480,
      29,
      '森星小隊',
      22,
      Colors.white,
      bold: true,
      align: TextAlign.center,
      shadow: true,
    );
    sprout(157, 29);
    sprout(323, 29);
    for (var i = 0; i < 3; i++) {
      final x = 20.0 + i * 149;
      panel(x, 62, 142, 54, radius: 18);
      resourceIcon(x + 24, 89, i);
      text(x + 44, 68, 88, 16, ['星糖', '星露', '彈珠'][i], 10, muted);
      text(
        x + 44,
        84,
        88,
        25,
        '${[state.sugar, state.dew, state.marbles][i]}',
        18,
        ink,
        bold: true,
      );
    }
  }

  void section(String kicker, String title, String detail) {
    panel(20, 132, 440, 71, fill: const Color(0xf5fff6df));
    text(36, 140, 240, 15, kicker, 9, green, bold: true);
    text(36, 158, 330, 33, title, 23, ink, bold: true);
    text(302, 146, 140, 18, detail, 10, muted, align: TextAlign.right);
  }

  void particles() {
    for (var i = 0; i < 15; i++) {
      final x = (i * 79.1 + math.sin(time * .38 + i) * 28) % 480,
          y = (i * 67.0 - time * 9 + 1800) % 900;
      final a = (.25 + .25 * math.sin(time * 1.5 + i)).clamp(0.0, 1.0);
      circle(x, y, i.isEven ? 2 : 1.3, Color.fromRGBO(255, 245, 190, a));
    }
  }

  void pinballPage() {
    section(
      '森林許願台',
      '彈珠育成冒險',
      pinball.active ? '連擊 ${pinball.combo}' : '瞄準 · 放開彈射',
    );
    panel(22, 218, 436, 454, radius: 24);
    // Prepared at exactly 2x this rectangle; contain keeps the full wood frame.
    image(
      'board',
      const Rect.fromLTWH(22, 218, 436, 454),
      radius: 24,
      fit: BoxFit.contain,
    );
    // The physics coordinates remain unchanged; the wood frame is decorative.
    box(38, 272, 404, 330, const Color(0x21fff9d8), 12);
    for (var i = 0; i < 3; i++) {
      final x = 52.0 + i * 128;
      image('marble$i', Rect.fromLTWH(x, 270, 18, 18), fit: BoxFit.contain);
      text(
        x + 22,
        268,
        103,
        22,
        '${i + 1} 碰 · ${[6, 14, 24][i]} 分',
        10,
        green,
        bold: true,
      );
    }
    if (!pinball.active) {
      for (var i = 1; i < 10; i++) {
        if (248 + aim.dy * i * 13 < 291) continue;
        circle(
          240 + aim.dx * i * 13,
          248 + aim.dy * i * 13,
          dragging ? 3.1 : 2.5,
          dragging ? const Color(0xccd5a747) : const Color(0x99517754),
        );
      }
    }
    if (dragging) {
      canvas.drawCircle(
        const Offset(240, 244),
        24 + math.sin(time * 7) * 2,
        Paint()
          ..color = const Color(0xaaffec9e)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final recoil =
        math.exp(-(motion?.launchAge ?? 1) * 14) *
        math.sin((motion?.launchAge ?? 1) * 25) *
        5;
    canvas.save();
    canvas.translate(0, -recoil);
    circle(240, 244, 17, brown);
    image(
      'marble3',
      const Rect.fromLTWH(225, 229, 30, 30),
      fit: BoxFit.contain,
    );
    canvas.restore();
    for (final p in pinball.pegs) {
      if (p.life <= 0) {
        circle(p.x, p.y, 2, const Color(0x44547744));
        continue;
      }
      circle(p.x, p.y + 2, 13, const Color(0x284e522c));
      final r = 14 + p.flash * 2;
      image(
        'marble${p.type}',
        Rect.fromCircle(center: Offset(p.x, p.y), radius: r),
        fit: BoxFit.contain,
      );
      for (var i = 0; i < p.maxLife; i++) {
        circle(
          p.x + (i - (p.maxLife - 1) / 2) * 6,
          p.y + 17,
          2.1,
          i < p.life ? green : const Color(0xffc7cfb3),
        );
      }
      if (p.flash > 0)
        circle(
          p.x,
          p.y,
          17 + p.flash * 8,
          Color.fromRGBO(255, 248, 185, p.flash * .35),
        );
    }
    for (var i = 0; i < 6; i++) {
      final x = Pinball.boardLeft + i * Pinball.basketWidth,
          w = Pinball.basketWidth;
      final active = pinball.enteringBucket == i;
      // Woven basket body and rim share the exact six physics lanes.
      box(x + 2, 608, w - 4, 48, const Color(0xffb8884b), 7);
      for (var lineIndex = 0; lineIndex < 4; lineIndex++) {
        line(
          Offset(x + 6, 615.0 + lineIndex * 10),
          Offset(x + w - 6, 615.0 + lineIndex * 10),
          const Color(0xffdcb77c),
          2,
        );
      }
      box(
        x + 1,
        604,
        w - 2,
        9,
        active ? const Color(0xffffd776) : const Color(0xffe1bc80),
        4,
      );
      portrait(x + w / 2, 622, 33, i);
      box(x + 2, 639, w - 4, 18, active ? green : const Color(0xeafff2d8), 4);
      text(
        x + 2,
        639,
        w - 4,
        17,
        friends[i].name,
        10,
        active ? Colors.white : brown,
        bold: true,
        align: TextAlign.center,
      );
    }
    for (final p in pinball.trail) {
      circle(p.dx, p.dy, 4, const Color(0x99fff9cb));
    }
    if (pinball.active) {
      circle(pinball.x, pinball.y, 13, const Color(0x45fff5ad));
      canvas.save();
      canvas.translate(pinball.x, pinball.y);
      canvas.rotate(pinball.age * 6);
      image(
        'marble3',
        const Rect.fromLTWH(-11, -11, 22, 22),
        fit: BoxFit.contain,
      );
      canvas.restore();
    }
    panel(24, 685, 432, 56);
    portrait(56, 712, 43, pinball.active ? 0 : pinball.lastBucket);
    text(
      89,
      691,
      347,
      21,
      pinball.active
          ? '本次成長分 ${pinball.earned} · 碰撞 ${pinball.combo}'
          : '落入誰的籃，就讓誰成長！',
      14,
      ink,
      bold: true,
    );
    text(
      89,
      715,
      347,
      17,
      pinball.active ? '擊破彩珠得分 · 六個籃對應六位夥伴' : 'Lv.3 / Lv.6 自動進化 · 放開發射',
      11,
      muted,
    );
    button(
      24,
      754,
      311,
      53,
      pinball.active ? '彈珠旅行中…' : '發射彈珠  ·  1 顆',
      disabled: pinball.active,
      size: 18,
    );
    button(346, 754, 110, 53, '補給 +12', secondary: true, size: 13);
  }

  void squadPage() {
    panel(20, 132, 440, 71);
    text(
      36,
      141,
      248,
      17,
      '夥伴小屋 · 已結識 ${state.unlocked.where((v) => v).length}/${friends.length}',
      11,
      green,
      bold: true,
    );
    text(36, 162, 250, 29, '一起長大的朋友', 22, ink, bold: true);
    final gallery = CompanionLayout.gallery;
    button(
      gallery.left,
      gallery.top,
      gallery.width,
      gallery.height,
      '全部寵物',
      size: 15,
    );
    final first = selected ~/ 6 * 6;
    for (var slot = 0; slot < 6 && first + slot < friends.length; slot++) {
      final i = first + slot;
      final bounds = CompanionLayout.card(slot);
      final x = bounds.left, y = bounds.top;
      canvas.save();
      pressTransform(bounds);
      panel(
        x,
        y,
        132,
        128,
        fill: selected == i ? const Color(0xfffff2c9) : paper,
        radius: 17,
      );
      portrait(x + 66, y + 43, 79, i, locked: !state.unlocked[i]);
      text(
        x + 4,
        y + 82,
        124,
        23,
        friends[i].name,
        16,
        ink,
        bold: true,
        align: TextAlign.center,
      );
      text(
        x + 3,
        y + 104,
        126,
        17,
        state.unlocked[i]
            ? 'Lv.${state.levels[i]} · ${state.levels[i] >= 10 ? '成長已滿' : '${state.growth[i]}/${state.growthCost(i)} 分'}'
            : i >= 6
            ? '星願轉珠可結識'
            : '成長 ${state.growth[i]}/40 可結識',
        10,
        muted,
        align: TextAlign.center,
      );
      if (state.evolutions[i] > 0) {
        circle(x + 115, y + 15, 8, gold);
        text(
          x + 108,
          y + 6,
          14,
          16,
          '${state.evolutions[i]}',
          9,
          Colors.white,
          bold: true,
          align: TextAlign.center,
        );
      }
      canvas.restore();
    }
    companionPager();
    panel(24, 533, 432, 151);
    portrait(85, 591, 92, selected, locked: !state.unlocked[selected]);
    final f = friends[selected];
    text(145, 546, 292, 28, f.name, 21, ink, bold: true);
    box(341, 550, 95, 23, const Color(0xffe4e9cf), 9);
    text(
      341,
      550,
      95,
      23,
      f.role,
      11,
      green,
      bold: true,
      align: TextAlign.center,
    );
    text(
      145,
      580,
      292,
      23,
      '攻擊 ${state.damage(selected).round()}    等級 ${state.levels[selected]}/10',
      13,
      green,
      bold: true,
    );
    text(
      145,
      609,
      292,
      21,
      state.levels[selected] >= 10
          ? '成長已滿 · 進化 ${state.evolutions[selected]}/2'
          : '成長 ${state.growth[selected]} / ${state.growthCost(selected)} · Lv.3 / 6 自動進化',
      11,
      muted,
    );
    text(41, 644, 395, 19, f.description, 11, muted, align: TextAlign.center);
    box(145, 635, 280, 4, const Color(0xffd6ddbf), 2);
    box(
      145,
      635,
      280 *
          (state.growth[selected] / state.growthCost(selected)).clamp(0.0, 1.0),
      4,
      green,
      2,
    );
    if (!state.unlocked[selected]) {
      button(
        24,
        698,
        432,
        52,
        selected >= 6 ? '前往星願轉珠結識' : '結識 ${f.name}  ·  80 星糖',
      );
    } else {
      button(
        24,
        698,
        211,
        52,
        state.levels[selected] >= 10
            ? '等級已滿'
            : '升級  ·  ${state.upgradeCost(selected)} 星糖',
      );
      button(
        245,
        698,
        211,
        52,
        state.evolutions[selected] >= 2
            ? '進化完成'
            : '進化  ·  ${state.evolveCost(selected)} 星露',
        secondary: true,
      );
    }
    panel(24, 758, 86, 43, radius: 13);
    text(24, 758, 86, 43, '安排隊伍', 11, ink, bold: true, align: TextAlign.center);
    for (var i = 0; i < BattleLayout.lanes; i++) {
      button(
        118 + i * 85,
        758,
        80,
        43,
        BattleLayout.laneName(i),
        secondary: state.team[i] != selected,
        size: 12,
      );
    }
  }

  void companionPager() {
    final current = selected ~/ CompanionLayout.pageSize;
    // Use drawn chevrons, generous touch bounds, and numbered album tabs;
    // typography no longer determines the shape of navigation arrows.
    for (final entry in [
      (CompanionLayout.previous, false),
      (CompanionLayout.next, true),
    ]) {
      final (rect, forward) = entry;
      button(rect.left, rect.top, rect.width, rect.height, '', secondary: true);
      canvas.save();
      pressTransform(rect);
      final x = forward ? rect.right - 19 : rect.left + 19;
      final y = rect.center.dy;
      final direction = forward ? 1.0 : -1.0;
      line(
        Offset(x - direction * 3, y - 5),
        Offset(x + direction * 2, y),
        brown,
        2.2,
      );
      line(
        Offset(x + direction * 2, y),
        Offset(x - direction * 3, y + 5),
        brown,
        2.2,
      );
      text(
        rect.left + (forward ? 9 : 27),
        rect.top,
        60,
        rect.height,
        forward ? '下一頁' : '上一頁',
        12,
        brown,
        bold: true,
        align: TextAlign.center,
      );
      canvas.restore();
    }
    for (
      var page = 0;
      page < CompanionLayout.pageCount(friends.length);
      page++
    ) {
      final rect = CompanionLayout.page(page);
      canvas.save();
      pressTransform(rect);
      final active = page == current;
      final pill = RRect.fromRectAndRadius(
        rect.deflate(3),
        const Radius.circular(12),
      );
      canvas.drawShadow(
        Path()..addRRect(pill),
        const Color(0x5538482e),
        2,
        false,
      );
      canvas.drawRRect(
        pill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: active
                ? [const Color(0xff678d61), green]
                : [const Color(0xfffff8e5), const Color(0xffefdfb9)],
          ).createShader(rect),
      );
      canvas.drawRRect(
        pill,
        Paint()
          ..color = active ? const Color(0xffd5be82) : const Color(0xffcdb881)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      text(
        rect.left,
        rect.top,
        rect.width,
        rect.height,
        '${page + 1}',
        15,
        active ? Colors.white : brown,
        bold: true,
        align: TextAlign.center,
      );
      canvas.restore();
    }
  }

  void enemy(double x, double y, double r, int element, bool boss) {
    final c = [
      const Color(0xff95ae7a),
      const Color(0xff82b8c3),
      const Color(0xffd5977a),
    ][element];
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y + r * .7),
        width: r * 1.6,
        height: r * .4,
      ),
      Paint()..color = const Color(0x352b4a26),
    );
    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.3, -.4),
          colors: [
            Color.lerp(c, Colors.white, .4)!,
            c,
            Color.lerp(c, green, .2)!,
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r)),
    );
    leaf(x - r * .25, y - r, r * .7, -.6);
    leaf(x + r * .2, y - r, r * .65, .4);
    circle(x - r * .3, y - r * .1, r * .08, ink);
    circle(x + r * .3, y - r * .1, r * .08, ink);
    line(
      Offset(x - r * .1, y + r * .22),
      Offset(x + r * .1, y + r * .22),
      ink,
      1.4,
    );
    if (boss) {
      resourceIcon(x, y - r * 1.25, 0);
    }
  }

  void battlePage() {
    final stage = combat.active ? combat.stage : state.stage;
    final theme = GuardTheme.forStage(stage);
    final readyHealth =
        100.0 +
        state.team
                .where(
                  (id) => id >= 0 && friends[id].skill == FriendSkill.guard,
                )
                .length *
            25;
    final hp = combat.active || result ? combat.health : readyHealth;
    final max = combat.active || result ? combat.maxHealth : readyHealth;
    section('${theme.name} · 四路防線', '四路夥伴，橫向出擊', '每路大招 · 每場 1 次');
    panel(24, 220, 432, 449, radius: 22);
    image(
      StoryArt.instance.battleFieldKey(stage),
      BattleLayout.field,
      radius: 8,
      fit: BoxFit.contain,
    );
    box(39, 232, 402, 31, const Color(0xcefff6df), 10);
    text(
      51,
      236,
      230,
      23,
      '第 $stage / 10 關 · 耐久 ${hp.ceil()}/${max.ceil()}',
      11,
      ink,
      bold: true,
    );
    text(
      269,
      236,
      158,
      23,
      combat.active ? 'WAVE ${combat.wave} / 3' : '森林需要你的守護',
      11,
      green,
      bold: true,
      align: TextAlign.right,
    );
    box(41, 264, 398, 3, const Color(0xffd8d2b5), 2);
    box(41, 264, 398 * (hp / max).clamp(0.0, 1.0), 3, green, 2);
    canvas.save();
    canvas.clipRect(BattleLayout.field);
    for (var lane = 0; lane < BattleLayout.lanes; lane++) {
      final y = BattleLayout.laneY(lane);
      box(40, y - 36, 89, 76, const Color(0x50fff4cc), 10);
      if (lane < BattleLayout.lanes - 1) {
        for (var dash = 0; dash < 20; dash++) {
          line(
            Offset(138 + dash * 15.0, y + 46.5),
            Offset(144 + dash * 15.0, y + 46.5),
            const Color(0x55fff5cb),
            1.2,
          );
        }
      }
      if (!combat.active && !result) {
        enemy(375 + lane % 2 * 25, y, 18, lane % 3, false);
        line(Offset(200, y), Offset(219, y), const Color(0x77587743), 2);
        line(Offset(211, y - 5), Offset(219, y), const Color(0x77587743), 2);
        line(Offset(211, y + 5), Offset(219, y), const Color(0x77587743), 2);
      }
    }
    for (final e in combat.enemies) {
      final x = e.x;
      canvas.save();
      canvas.translate(x + e.flash * 5, e.y + 17);
      canvas.rotate(math.sin(time * 7 + e.id) * .035);
      canvas.scale(1 + e.flash * .14, 1 - e.flash * .1);
      canvas.translate(-x, -e.y - 17);
      enemy(x, e.y, e.boss ? 27 : 19, e.element, e.boss);
      if (e.flash > .05) {
        canvas.drawCircle(
          Offset(x, e.y),
          (e.boss ? 28 : 20) + (1 - e.flash) * 9,
          Paint()
            ..color = const Color(0xfffff4ca).withValues(alpha: e.flash * .7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      canvas.restore();
      box(x - 21, e.y - (e.boss ? 39 : 30), 42, 5, const Color(0x553b4d2c), 3);
      box(
        x - 21,
        e.y - (e.boss ? 39 : 30),
        42 * (e.hp / e.maxHp).clamp(0.0, 1.0),
        5,
        e.slow > 0 ? const Color(0xff86d3e5) : const Color(0xffe9b35c),
        3,
      );
    }
    for (final s in combat.shots) {
      circle(s.x, s.y, 8, const Color(0x55fff2a7));
      line(
        Offset(s.x - 14, s.y),
        Offset(s.x - 3, s.y),
        friends[s.friend].color.withValues(alpha: .6),
        3,
      );
      circle(s.x, s.y, 4, friends[s.friend].color);
    }
    for (var i = 0; i < BattleLayout.lanes; i++) {
      final id = combat.active ? combat.team[i] : state.team[i],
          x = BattleLayout.friendX,
          y = BattleLayout.laneY(i);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y + 22), width: 53, height: 9),
        Paint()..color = const Color(0x402b4528),
      );
      if (id >= 0) {
        final attack = combat.attackFlash[i];
        final anticipation =
            combat.active && combat.enemies.any((enemy) => enemy.lane == i)
            ? (1 - combat.timers[i] / .16).clamp(0.0, 1.0) * (1 - attack)
            : 0.0;
        canvas.save();
        canvas.translate(x, y + 23);
        canvas.rotate(-attack * .08 + anticipation * .045);
        canvas.scale(
          1 + attack * .12 - anticipation * .04,
          1 - attack * .08 + anticipation * .025,
        );
        canvas.translate(-x, -y - 23);
        portrait(x + attack * 7 - anticipation * 2, y - 5, 59, id);
        canvas.restore();
      } else {
        circle(x, y - 5, 22, const Color(0x80fff8dc));
        text(x - 22, y - 26, 44, 42, '+', 26, muted, align: TextAlign.center);
      }
      box(44, y + 26, 84, 20, const Color(0xeefff5dc), 6);
      text(
        45,
        y + 26,
        82,
        20,
        id < 0
            ? '${BattleLayout.laneName(i)} · 待上陣'
            : '${friends[id].name} Lv.${state.levels[id]}',
        9,
        green,
        bold: true,
        align: TextAlign.center,
      );
    }
    canvas.restore();
    canvas.save();
    final hurt = motion?.hurtAge ?? 1;
    if (hurt < .35)
      canvas.translate(math.sin(hurt * 75) * 3 * (1 - hurt / .35), 0);
    for (var lane = 0; lane < BattleLayout.lanes; lane++) {
      final rect = BattleLayout.ultimateButton(lane);
      final id = (combat.active ? combat.team : state.team)[lane];
      final used = combat.active && combat.ultimateUsed[lane];
      final ready = combat.active && id >= 0 && !used;
      final spell = id < 0 ? null : UltimateSpell.of(friends[id].ultimateKind);
      button(
        rect.left,
        rect.top,
        rect.width,
        rect.height,
        '',
        secondary: !ready,
        disabled: !ready,
      );
      canvas.save();
      pressTransform(rect);
      text(
        rect.left + 5,
        rect.top + 7,
        rect.width - 10,
        15,
        '${lane + 1} 路 · ${used ? '0/1' : '1/1'}',
        10,
        ready ? const Color(0xffffefba) : muted,
        bold: true,
        align: TextAlign.center,
      );
      text(
        rect.left + 5,
        rect.top + 26,
        rect.width - 10,
        23,
        id < 0
            ? '待上陣'
            : used
            ? '本場已用'
            : !combat.active
            ? '開戰後可用'
            : spell!.name,
        13,
        ready ? Colors.white : muted,
        bold: true,
        align: TextAlign.center,
      );
      if (ready) {
        final glow = .45 + .35 * math.sin(time * 2.5 + lane);
        circle(
          rect.left + 13,
          rect.top + 14,
          2.0,
          spell!.highlight.withValues(alpha: glow),
        );
      }
      canvas.restore();
    }
    canvas.restore();
    button(
      24,
      754,
      311,
      53,
      combat.active
          ? '守衛中  ·  擊退 ${combat.kills} 隻'
          : '開始守衛  ·  第 ${state.stage} 關',
      disabled: combat.active,
      size: 17,
    );
    button(346, 754, 110, 53, '調整陣容', secondary: true, size: 13);
  }

  void campPage() {
    text(
      30,
      140,
      420,
      19,
      StoryArt.instance.images.containsKey('field-level2')
          ? '螢光亮起，朋友都在。'
          : '陽光正好，朋友都在。',
      12,
      Colors.white,
      align: TextAlign.center,
      shadow: true,
    );
    text(
      30,
      162,
      420,
      38,
      '我們的森林營地',
      27,
      Colors.white,
      bold: true,
      align: TextAlign.center,
      shadow: true,
    );
    // Small butterflies inhabit the clearing; portrait cards stay inside UI panels.
    for (var i = 0; i < 3; i++) {
      final x = 70 + i * 60 + math.sin(time * .55 + i * 1.3) * 16,
          y = 500 + i * 18 + math.sin(time * 1.2 + i) * 8,
          wing = 3 + math.sin(time * 8 + i).abs() * 4;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x - wing * .5, y),
          width: wing,
          height: 9,
        ),
        Paint()..color = const Color(0xffe8d994),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + wing * .5, y),
          width: wing,
          height: 9,
        ),
        Paint()..color = const Color(0xffebbe8b),
      );
      line(Offset(x, y - 3), Offset(x, y + 4), brown, 1.2);
    }
    panel(14, 782, 452, 106);
    text(
      25,
      790,
      430,
      23,
      '夥伴 ${state.unlocked.where((x) => x).length}/${friends.length}     通關 ${state.clearedStage}/10     彈射 ${state.shots} 次',
      12,
      green,
      bold: true,
      align: TextAlign.center,
    );
    final labels = adLabel == null
        ? ['補給 +12', state.sound ? '聲音：開啟' : '聲音：關閉', '星願轉珠']
        : ['免費 +12', adLabel!, state.sound ? '聲音：開啟' : '聲音：關閉', '星願轉珠'];
    for (var i = 0; i < labels.length; i++) {
      final x = 20.0 + i * (adLabel == null ? 152 : 108);
      final width = adLabel == null
          ? 150.0
          : i == 3
          ? 116.0
          : 108.0;
      canvas.save();
      pressTransform(Rect.fromLTWH(x, 820, width, 58));
      text(
        x,
        820,
        width,
        49,
        labels[i],
        adLabel != null
            ? 10.5
            : i == 2
            ? 11
            : 13,
        i == labels.length - 1 ? muted : green,
        bold: i != labels.length - 1,
        align: TextAlign.center,
      );
      if (i < labels.length - 1)
        line(
          Offset(x + width, 834),
          Offset(x + width, 857),
          const Color(0xffe1d3b1),
        );
      canvas.restore();
    }
    text(25, 864, 430, 13, '旅程已自動儲存在此裝置', 9, muted, align: TextAlign.center);
  }

  void navigation() {
    const tray = Rect.fromLTWH(9, 829, 462, 66);
    final rounded = RRect.fromRectAndRadius(tray, const Radius.circular(23));
    canvas.drawShadow(
      Path()..addRRect(rounded),
      const Color(0xff263f2a),
      6,
      false,
    );
    canvas.drawRRect(
      rounded,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xfffffbec), Color(0xffede2bf)],
        ).createShader(tray),
    );
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = const Color(0xffbe9d61)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tray.deflate(3), const Radius.circular(20)),
      Paint()
        ..color = const Color(0xbafffff7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (var i = 0; i < 4; i++) {
      final x = 60.0 + i * 120, active = tab == i;
      canvas.save();
      pressTransform(Rect.fromLTWH(i * 120.0, 819, 120, 81));
      if (active) {
        final card = Rect.fromLTWH(x - 47, 820, 94, 74);
        final shape = RRect.fromRectAndRadius(card, const Radius.circular(21));
        canvas.drawShadow(
          Path()..addRRect(shape),
          const Color(0xff4c5834),
          3,
          false,
        );
        canvas.drawRRect(
          shape,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xfffff9d9), Color(0xffe6d29b)],
            ).createShader(card),
        );
        canvas.drawRRect(
          shape,
          Paint()
            ..color = const Color(0xffc49a4d)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.7,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(card.deflate(3), const Radius.circular(18)),
          Paint()
            ..color = const Color(0xdffffce9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        circle(x, 846, 25, const Color(0x35fffefa));
        box(x - 32, 870, 64, 20, green, 10);
      } else if (i > 0 && tab != i - 1) {
        line(Offset(x - 60, 849), Offset(x - 60, 875), const Color(0x35a58f5d));
      }
      final lift = active ? math.sin(time * 2.6) * 1.2 : 0.0;
      image(
        'nav$i',
        Rect.fromCenter(
          center: Offset(x, (active ? 845 : 848) + lift),
          width: active ? 61 : 52,
          height: active ? 50 : 43,
        ),
        fit: BoxFit.contain,
      );
      text(
        x - 46,
        active ? 870 : 872,
        92,
        20,
        ['彈珠', '夥伴', '守衛', '營地'][i],
        12,
        active ? paper : green,
        bold: true,
        align: TextAlign.center,
      );
      canvas.restore();
    }
  }

  void interactionFeedback() {
    final m = motion;
    if (m == null || result) return;
    for (final cue in m.cues) {
      if (cue.page != tab) continue;
      final t = (cue.age / cue.duration).clamp(0.0, 1.0);
      if (cue.kind == CueKind.touch) {
        canvas.save();
        canvas.clipRect(const Rect.fromLTWH(8, 120, 464, 778));
        canvas.drawCircle(
          cue.position,
          7 + 23 * t,
          Paint()
            ..color = gold.withValues(alpha: (1 - t) * .65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * (1 - t),
        );
        canvas.restore();
        continue;
      }
      final floatArea = Rect.fromLTWH(
        cue.position.dx - 65,
        cue.position.dy - 75,
        130,
        85,
      );
      canvas.saveLayer(
        floatArea,
        Paint()
          ..color = Colors.white.withValues(
            alpha: (1 - t) * 1.4 > 1 ? 1 : (1 - t) * 1.4,
          ),
      );
      final dy = cue.position.dy - 18 - 36 * (1 - math.pow(1 - t, 2));
      final labelWidth = cue.kind == CueKind.score ? 52.0 : 122.0;
      box(
        cue.position.dx - labelWidth / 2,
        dy - 12,
        labelWidth,
        25,
        cue.kind == CueKind.score
            ? const Color(0xe9426b48)
            : const Color(0xfafff4cf),
        12,
      );
      text(
        cue.position.dx - labelWidth / 2,
        dy - 12,
        labelWidth,
        25,
        cue.label,
        cue.kind == CueKind.score ? 15 : 12,
        cue.kind == CueKind.score ? paper : green,
        bold: true,
        align: TextAlign.center,
      );
      canvas.restore();
      if (cue.kind == CueKind.reward) {
        final destination = Offset(cue.label.contains('彈珠') ? 398 : 82, 88);
        for (var i = 0; i < 5; i++) {
          final flight = ((cue.age - i * .07) / .7).clamp(0.0, 1.0);
          if (flight <= 0 || flight >= 1) continue;
          final control = Offset(
            (cue.position.dx + destination.dx) / 2 - 45,
            math.max(130, cue.position.dy - 190),
          );
          final p =
              cue.position * ((1 - flight) * (1 - flight)) +
              control * (2 * (1 - flight) * flight) +
              destination * (flight * flight);
          circle(p.dx, p.dy, 9, const Color(0x66fff0a3));
          image(
            cue.label.contains('彈珠') ? 'marble0' : 'marble3',
            Rect.fromCircle(center: p, radius: 6),
            fit: BoxFit.contain,
          );
        }
      }
    }
    if (tab == 2 && combat.active && m.bannerAge < 1.5) {
      final entry = (m.bannerAge / .18).clamp(0.0, 1.0);
      final fade = ((1.5 - m.bannerAge) / .25).clamp(0.0, 1.0);
      canvas.saveLayer(
        const Rect.fromLTWH(39, 231, 402, 33),
        Paint()..color = Colors.white.withValues(alpha: entry * fade),
      );
      box(39, 232, 402, 31, const Color(0xff426b48), 10);
      text(
        49,
        232,
        382,
        31,
        m.banner,
        14,
        paper,
        bold: true,
        align: TextAlign.center,
      );
      canvas.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    this.canvas = canvas;
    canvas.save();
    canvas.scale(size.width / 480, size.height / 900);
    particles();
    header();
    [pinballPage, squadPage, battlePage, campPage][tab]();
    if (tab != 3) navigation();
    interactionFeedback();
    if (toast.isNotEmpty) {
      final entrance =
          1 - math.pow(1 - ((motion?.toastAge ?? 1) / .2).clamp(0.0, 1.0), 3);
      canvas.save();
      canvas.translate(0, (-8 * (1 - entrance)).toDouble());
      box(25, 168, 430, 35, const Color(0xf23a573a), 12);
      text(36, 168, 408, 35, toast, 12, Colors.white, align: TextAlign.center);
      canvas.restore();
    }
    if (result) {
      box(0, 0, 480, 900, const Color(0xa32c432c), 0);
      final age = motion?.resultAge ?? 1;
      final progress = (age / .38).clamp(0.0, 1.0);
      final spring =
          1 + math.pow(1 - progress, 3) * (2.7 * (progress - 1) + 1.7);
      canvas.save();
      canvas.translate(240, 445);
      canvas.scale(.9 + .1 * spring);
      canvas.translate(-240, -445);
      panel(38, 277, 404, 337, radius: 25);
      resourceIcon(240, 332, 0);
      text(
        58,
        374,
        364,
        47,
        resultTitle,
        28,
        ink,
        bold: true,
        align: TextAlign.center,
      );
      text(57, 438, 366, 32, resultDetail, 13, green, align: TextAlign.center);
      text(
        63,
        486,
        354,
        23,
        '每一次成長，都有小夥伴陪著你。',
        11,
        muted,
        align: TextAlign.center,
      );
      button(69, 536, 342, 51, '繼續冒險');
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
