import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gacha.dart';
import 'gacha_store.dart';
import 'game.dart';

class GachaPage extends StatefulWidget {
  const GachaPage({super.key, required this.controller});
  final GachaController controller;
  @override
  State<GachaPage> createState() => _GachaPageState();
}

class _GachaPageState extends State<GachaPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );
  late final idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  bool rolling = false;
  double drag = 0;
  Timer? _dayTimer;
  DrawResult? result;
  GachaController get controller => widget.controller;
  bool get reduced => MediaQuery.disableAnimationsOf(context);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.initialize());
    _dayTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion();
  }

  void _motion() {
    if (reduced) {
      idle.stop();
    } else if (!idle.isAnimating) {
      idle.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _motion();
      if (rolling) spin.forward();
      setState(() {});
    } else {
      idle.stop();
      spin.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    spin.dispose();
    idle.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    if (rolling || !controller.canDraw) return;
    setState(() {
      rolling = true;
      result = null;
    });
    final reward = await controller.draw();
    if (!mounted) return;
    if (reward != null && !reduced) {
      try {
        await spin.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (mounted) {
      setState(() {
        rolling = false;
        result = reward;
      });
    }
  }

  Future<void> _buy() async {
    final product = controller.product;
    if (product == null || !controller.canPurchase) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('購買 10 次轉珠'),
        content: SingleChildScrollView(
          child: Text(
            '${product.price} · 一次性消耗型商品，非訂閱。\n\n'
            '每次隨機獲得一項：\n寵物 30%（20 隻各 1.5%）\n星糖 45% · 彈珠 25%\n'
            '不保證獲得寵物，重複寵物轉為 40 成長分。\n\n'
            '付款由 ${controller.billing?.platform == 'ios' ? 'App Store' : 'Google Play'} 處理。購買後須連線轉珠；免費次數會優先使用。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('繼續 · ${product.price}'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.buy();
  }

  Future<void> _wallet() async {
    final wallet = controller.wallet;
    if (wallet == null) return;
    final field = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('轉珠錢包備份'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('此備份碼可取回付費次數及轉珠獎品紀錄。請私人保存；不要公開或傳給他人。遊戲其餘進度仍保存在裝置上。'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: wallet.recoveryCode),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('備份碼已複製，請儲存到私人位置。')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('複製私人備份碼'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: field,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: '貼上舊錢包備份碼',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '匯入會切換目前錢包；請先備份現有錢包。已消耗的商品不會由商店重新發放。',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
          FilledButton(
            onPressed: controller.busy
                ? null
                : () async {
                    try {
                      await controller.importWallet(field.text);
                      if (context.mounted) Navigator.pop(context);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('未能匯入，請檢查備份碼及網絡。')),
                        );
                      }
                    }
                  },
            child: const Text('匯入舊錢包'),
          ),
        ],
      ),
    );
    // A closing dialog can retain its text field during the route animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    field.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !rolling,
    child: Scaffold(
      backgroundColor: const Color(0xffebf1df),
      appBar: AppBar(
        backgroundColor: const Color(0xfffff7df),
        title: const Text('星願轉珠'),
        leading: BackButton(
          onPressed: rolling ? null : () => Navigator.maybePop(context),
        ),
        actions: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => IconButton(
              tooltip: '轉珠錢包備份',
              onPressed: rolling || controller.wallet == null ? null : _wallet,
              icon: const Icon(Icons.key_rounded),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/start/forest-stage-v1.webp',
            fit: BoxFit.cover,
            color: const Color(0x80fff8e5),
            colorBlendMode: BlendMode.screen,
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => LayoutBuilder(
              builder: (context, space) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Column(
                      children: [
                        const Text(
                          '轉一顆星願，遇見森林新朋友',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Color(0xff31563e),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            _Pill(
                              '今日免費 ${controller.freeLeft}/5',
                              Icons.card_giftcard_rounded,
                            ),
                            _Pill(
                              '付費次數 ${controller.paidTickets}',
                              Icons.confirmation_number_rounded,
                            ),
                          ],
                        ),
                        SizedBox(
                          height: space.maxHeight < 700 ? 230 : 280,
                          child: Semantics(
                            label: '星願轉珠機，拖動旋鈕或按下方按鈕轉珠',
                            button: true,
                            onTap: controller.canDraw && !rolling
                                ? () => unawaited(_draw())
                                : null,
                            child: GestureDetector(
                              key: const ValueKey('gacha_machine'),
                              onPanStart: (_) {
                                drag = 0;
                              },
                              onPanUpdate: (e) {
                                drag += e.delta.distance;
                              },
                              onPanEnd: (_) {
                                if (drag > 40) unawaited(_draw());
                              },
                              child: AnimatedBuilder(
                                animation: Listenable.merge([spin, idle]),
                                builder: (_, _) => CustomPaint(
                                  painter: _GachaMachine(
                                    rolling ? spin.value : 0,
                                    idle.value,
                                    rolling,
                                  ),
                                  size: Size.infinite,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (result != null) _RewardCard(result: result!),
                        if (result == null && !rolling)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final id in [6, 8, 14, 25])
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Image.asset(
                                      'assets/pets/character-$id.png',
                                      width: 52,
                                      height: 52,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        const Text(
                          '寵物 30% · 星糖 45% · 彈珠 25%',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xff466348),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 9),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const ValueKey('gacha_draw'),
                            onPressed: rolling || !controller.canDraw
                                ? null
                                : () => unawaited(_draw()),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xff426b48),
                              foregroundColor: const Color(0xfffff9e8),
                              minimumSize: const Size(200, 54),
                            ),
                            icon: Icon(
                              rolling
                                  ? Icons.auto_awesome
                                  : Icons.rotate_right_rounded,
                            ),
                            label: Text(
                              rolling
                                  ? '星願正在閃耀…'
                                  : controller.freeLeft > 0
                                  ? '免費轉珠 · 剩餘 ${controller.freeLeft} 次'
                                  : controller.paidTickets > 0
                                  ? '轉珠 · 使用 1 次付費次數'
                                  : '今日免費已用完',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (controller.freeLeft == 0)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              key: const ValueKey('gacha_buy'),
                              onPressed: !rolling && controller.canPurchase
                                  ? () => unawaited(_buy())
                                  : null,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xe6fff5da),
                                minimumSize: const Size(200, 48),
                              ),
                              child: Text(
                                controller.product != null
                                    ? '購買 10 次轉珠 · ${controller.product!.price}'
                                    : '付費轉珠準備中',
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Text(
                            rolling ? '獎品已安全儲存，正在揭曉。' : controller.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff426047),
                            ),
                          ),
                        ),
                        const Text(
                          '每天香港時間 00:00 補滿 5 次，不累積。\n免費與付費機率相同；每次隨機一項，沒有保底。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xff5d7052),
                          ),
                        ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            TextButton(
                              onPressed: rolling
                                  ? null
                                  : () => showDrawOdds(context),
                              child: const Text('完整獎池與機率'),
                            ),
                            if (controller.billing != null)
                              TextButton(
                                onPressed: rolling || controller.busy
                                    ? null
                                    : () => unawaited(
                                        controller.restoreTransactions(),
                                      ),
                                child: const Text('同步／補領'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.icon);
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xf5fff6df),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: const Color(0xffd8bb77)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xff687a49)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xff426047),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.result});
  final DrawResult result;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('gacha_result'),
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xfffff5d8),
      borderRadius: BorderRadius.circular(23),
      border: Border.all(color: const Color(0xffd3a959), width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x30395029),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      children: [
        if (result.reward.kind == DrawKind.pet)
          Image.asset(
            'assets/pets/character-${result.reward.pet}.png',
            height: 130,
          )
        else
          Icon(
            result.reward.kind == DrawKind.sugar
                ? Icons.star_rounded
                : Icons.bubble_chart_rounded,
            size: 75,
            color: const Color(0xffc49b48),
          ),
        Text(
          result.joined ? '新夥伴 · ${result.title}' : result.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: Color(0xff375d40),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          result.detail,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xff65734e)),
        ),
      ],
    ),
  );
}

Future<void> showDrawOdds(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: const Color(0xfffff7e6),
  builder: (context) => FractionallySizedBox(
    heightFactor: .83,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '星願獎池與機率',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text('每次轉珠獨立隨機獲得一項，免費與付費機率相同。\n寵物總機率 30%，以下 20 隻各 1.5%。'),
          const SizedBox(height: 10),
          for (var id = 6; id < friends.length; id++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Image.asset(
                    'assets/pets/character-$id.png',
                    height: 44,
                    width: 44,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(friends[id].name)),
                  const Text('1.5%'),
                ],
              ),
            ),
          const Divider(),
          const Text(
            '星糖 20：25%\n星糖 40：15%\n星糖 80：5%\n彈珠 3 顆：15%\n彈珠 8 顆：8%\n彈珠 15 顆：2%',
            style: TextStyle(height: 1.9),
          ),
          const SizedBox(height: 12),
          const Text(
            '沒有保底，不保證獲得新寵物。重複寵物轉為該寵物 40 成長分，可觸發升級／進化。'
            '彈珠上限 999，超出部分按 1:1 轉為星糖；星糖上限 999,999，超出不累積。\n\n'
            '免費額度按香港時間每日 00:00 補滿 5 次，不累積，保存在裝置上。付費次數由商店交易核驗後發放，須連線使用；請備份轉珠錢包以便更換裝置。',
          ),
        ],
      ),
    ),
  ),
);

class _GachaMachine extends CustomPainter {
  _GachaMachine(this.progress, this.idle, this.rolling);
  final double progress, idle;
  final bool rolling;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 340, size.height / 290);
    canvas.save();
    canvas.translate(
      (size.width - 340 * scale) / 2,
      (size.height - 290 * scale) / 2,
    );
    canvas.scale(scale);
    final shaking = rolling
        ? math.sin(progress * math.pi * 18) * (1 - progress) * 3
        : 0.0;
    canvas.translate(shaking, 0);
    canvas.drawOval(
      const Rect.fromLTWH(72, 262, 196, 18),
      Paint()
        ..color = const Color(0x4045623d)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    final base = RRect.fromRectAndRadius(
      const Rect.fromLTWH(82, 175, 176, 91),
      const Radius.circular(23),
    );
    canvas.drawRRect(
      base,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xfff3d592), Color(0xffd9a758), Color(0xff94652f)],
        ).createShader(base.outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(94, 184, 152, 70),
        const Radius.circular(15),
      ),
      Paint()..color = const Color(0xff4b7854),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(133, 222, 74, 26),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xff28452f),
    );
    final globe = const Rect.fromLTWH(66, 14, 208, 192);
    canvas.drawOval(
      globe,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.4, -.5),
          radius: .85,
          colors: [Color(0xaaffffff), Color(0x7079c9c2), Color(0xb3438e83)],
        ).createShader(globe),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(globe.deflate(6)));
    final time = idle * math.pi * 2 + (rolling ? progress * math.pi * 12 : 0);
    for (var i = 0; i < 17; i++) {
      final depth = (i % 4) / 3;
      final angle = time * (.3 + depth * .5) + i * 2.399;
      final centre = Offset(
        170 + math.cos(angle) * (46 + depth * 33),
        125 + math.sin(angle * .85 + i) * (28 + depth * 34),
      );
      final colour = const [
        Color(0xffb4d594),
        Color(0xffa6d9e1),
        Color(0xffdfb5d9),
        Color(0xffedcd7d),
      ][i % 4];
      _ball(canvas, centre, 14 + depth * 5, colour, angle * .4);
    }
    canvas.restore();
    canvas.drawOval(
      globe,
      Paint()
        ..color = const Color(0xffd7e8ce)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawArc(
      globe.deflate(13),
      math.pi * 1.05,
      math.pi * .38,
      false,
      Paint()
        ..color = const Color(0xcafffff2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(76, 177, 188, 19),
        const Radius.circular(9),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xfff1d78f), Color(0xfff9e7b2), Color(0xffb18a43)],
        ).createShader(const Rect.fromLTWH(76, 177, 188, 19)),
    );
    canvas.save();
    canvas.translate(170, 211);
    canvas.rotate(rolling ? progress * math.pi * 8 : 0);
    canvas.drawCircle(
      Offset.zero,
      22,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(-6, -8), 32, [
          const Color(0xffffedb9),
          const Color(0xffb2823d),
        ]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-16, -6, 32, 12),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xfffff0bc),
    );
    canvas.restore();
    if (rolling) {
      final t = Curves.easeOut.transform(((progress - .65) / .35).clamp(0, 1));
      if (t > 0) {
        _ball(
          canvas,
          Offset(170, 238 - t * 85),
          20 + t * 12,
          const Color(0xffe6c779),
          progress * 6,
        );
      }
      for (var i = 0; i < 20; i++) {
        final angle = i * math.pi * 2 / 20 + progress;
        final radius = 40 + 100 * progress;
        final p = Offset(
          170 + math.cos(angle) * radius,
          128 + math.sin(angle) * radius * .7,
        );
        canvas.drawCircle(
          p,
          2 + (i % 3),
          Paint()
            ..color = const Color(
              0xffffeeb3,
            ).withValues(alpha: math.sin(progress * math.pi).abs()),
        );
      }
    }
    canvas.restore();
  }

  void _ball(Canvas canvas, Offset p, double r, Color colour, double angle) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.5),
          radius: .9,
          colors: [
            Color.lerp(colour, Colors.white, .75)!,
            colour,
            Color.lerp(colour, const Color(0xff426343), .3)!,
          ],
        ).createShader(rect),
    );
    canvas.drawArc(
      rect,
      0,
      math.pi,
      false,
      Paint()
        ..color = const Color(0x88fff6da)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(-r * .3, -r * .4),
      r * .2,
      Paint()..color = const Color(0xbfffffff),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GachaMachine old) =>
      old.progress != progress || old.idle != idle || old.rolling != rolling;
}
