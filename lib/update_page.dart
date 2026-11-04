import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'content_updates.dart';
import 'level_data.dart';
import 'storybook_ui.dart';

class GameUpdateGate extends StatefulWidget {
  const GameUpdateGate({
    super.key,
    required this.prefs,
    required this.gameBuilder,
  });
  final SharedPreferences prefs;
  final Widget Function(ContentBundle? content) gameBuilder;
  @override
  State<GameUpdateGate> createState() => _GameUpdateGateState();
}

class _GameUpdateGateState extends State<GameUpdateGate> {
  ContentUpdates? _updates;
  ContentBundle? _content;
  bool _entered = false, _opening = false, _failed = false;
  String? _startupError;
  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      if (kIsWeb) {
        await _enter();
        return;
      }
      final package = await PackageInfo.fromPlatform().timeout(
        const Duration(seconds: 8),
      );
      final support = await getApplicationSupportDirectory().timeout(
        const Duration(seconds: 8),
      );
      if (!mounted) return;
      final updates = ContentUpdates(
        root: Directory('${support.path}/forest-content-v1'),
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        build: int.tryParse(package.buildNumber) ?? 0,
      );
      setState(() => _updates = updates);
      await updates.check();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _enter() async {
    if (_opening || !mounted) return;
    setState(() => _opening = true);
    _updates?.cancel();
    var content = _updates?.active;
    try {
      try {
        await StoryArt.instance.load(content: content);
      } catch (_) {
        content = null;
        await StoryArt.instance.load();
      }
    } catch (_) {
      if (!mounted) return;
      _updates?.dispose();
      setState(() {
        _updates = null;
        _opening = false;
        _failed = true;
        _startupError = '森林素材未能準備完成，請重試';
      });
      return;
    }
    if (!mounted) return;
    LevelBook.current = content?.levels ?? {};
    setState(() {
      _content = content;
      _entered = true;
    });
  }

  @override
  void dispose() {
    _updates?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_entered) return widget.gameBuilder(_content);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'ForestUI',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff426b48)),
      ),
      home: _updates == null
          ? Scaffold(
              backgroundColor: const Color(0xfff5edda),
              body: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.forest_rounded,
                        size: 70,
                        color: Color(0xff426b48),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _startupError ??
                            (_opening
                                ? '正在準備森林…'
                                : _failed
                                ? '暫時無法檢查更新，可離線遊玩'
                                : '正在準備森林更新…'),
                      ),
                      const SizedBox(height: 20),
                      if (!_failed && !_opening)
                        const CircularProgressIndicator(),
                      if (_failed)
                        FilledButton(
                          onPressed: () => unawaited(_enter()),
                          child: const Text('使用內附內容'),
                        ),
                    ],
                  ),
                ),
              ),
            )
          : UpdateProgressPage(
              updates: _updates!,
              prefs: widget.prefs,
              opening: _opening,
              onContinue: () => unawaited(_enter()),
            ),
    );
  }
}

class UpdateProgressPage extends StatefulWidget {
  const UpdateProgressPage({
    super.key,
    required this.updates,
    required this.prefs,
    required this.onContinue,
    this.opening = false,
  });
  final ContentUpdates updates;
  final SharedPreferences prefs;
  final VoidCallback onContinue;
  final bool opening;
  @override
  State<UpdateProgressPage> createState() => _UpdateProgressPageState();
}

class _UpdateProgressPageState extends State<UpdateProgressPage>
    with SingleTickerProviderStateMixin {
  late final _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();
  String? _linkError;
  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  Future<void> _openStore(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Unavailable');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _linkError = '未能開啟商店，請稍後從 App Store／Google Play 更新。');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/forest-star-start.png', fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x55334b34), Color(0xbb173e31)],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _glow,
          builder: (_, _) => IgnorePointer(
            child: CustomPaint(painter: StartGlow(_glow.value)),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ListenableBuilder(
                  listenable: widget.updates,
                  builder: (context, _) {
                    final updates = widget.updates;
                    final downloading =
                        updates.phase == UpdatePhase.downloading;
                    final verifying = updates.phase == UpdatePhase.verifying;
                    final checking = updates.phase == UpdatePhase.checking;
                    final hasOffer = updates.pendingCatalog != null;
                    final active = updates.active;
                    final notice = updates.info?.notice;
                    final noticeId = updates.info?.noticeId;
                    final showNotice =
                        notice != null &&
                        widget.prefs.getString('forest_update_notice') !=
                            noticeId;
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xfffff6df),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xffd5b36e),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 25,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xffdcebd5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              updates.phase == UpdatePhase.ready
                                  ? Icons.check_rounded
                                  : Icons.forest_rounded,
                              size: 42,
                              color: const Color(0xff356f58),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '準備森林冒險',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff284b36),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.opening ? '正在打開森林…' : updates.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xff526344),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              key: const ValueKey('content_update_progress'),
                              minHeight: 12,
                              value: checking || verifying || widget.opening
                                  ? null
                                  : downloading
                                  ? updates.progress
                                  : updates.phase == UpdatePhase.ready
                                  ? 1
                                  : 0,
                              backgroundColor: const Color(0xffe1dcc3),
                              color: const Color(0xff50855a),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (downloading)
                            Text(
                              '${(updates.progress * 100).floor()}% · ${_mb(updates.receivedBytes)} / ${_mb(updates.totalBytes)} MB',
                              key: const ValueKey('content_update_bytes'),
                            )
                          else if (hasOffer)
                            Text('圖片・音樂・關卡　${_mb(updates.totalBytes)} MB')
                          else
                            Text(
                              active == null
                                  ? '內附森林內容 · 可離線遊玩'
                                  : '已下載：${active.offer.version}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (hasOffer && !downloading && !verifying)
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text(
                                '下載會使用網路數據；也可稍後再更新。',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff756442),
                                ),
                              ),
                            ),
                          if (showNotice)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                notice,
                                style: const TextStyle(height: 1.6),
                              ),
                            ),
                          if (updates.info?.storeUri case final Uri uri)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: OutlinedButton.icon(
                                onPressed: widget.opening
                                    ? null
                                    : () => unawaited(_openStore(uri)),
                                icon: const Icon(Icons.system_update),
                                label: Text(
                                  '前往商店更新 ${updates.info!.storeVersion}',
                                ),
                              ),
                            ),
                          if (_linkError != null)
                            Text(
                              _linkError!,
                              style: const TextStyle(color: Colors.brown),
                            ),
                          const SizedBox(height: 22),
                          if (!checking && !downloading && !verifying)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const ValueKey('content_update_primary'),
                                onPressed: widget.opening
                                    ? null
                                    : hasOffer
                                    ? () => unawaited(updates.download())
                                    : () {
                                        if (showNotice) {
                                          unawaited(
                                            widget.prefs.setString(
                                              'forest_update_notice',
                                              noticeId!,
                                            ),
                                          );
                                        }
                                        widget.onContinue();
                                      },
                                icon: Icon(
                                  hasOffer
                                      ? Icons.download_rounded
                                      : Icons.eco_rounded,
                                ),
                                label: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(hasOffer ? '下載森林更新' : '進入遊戲'),
                                ),
                              ),
                            ),
                          if (checking || downloading || verifying || hasOffer)
                            TextButton(
                              key: const ValueKey('content_update_skip'),
                              onPressed: widget.opening
                                  ? null
                                  : () {
                                      updates.cancel();
                                      widget.onContinue();
                                    },
                              child: Text(
                                downloading || verifying
                                    ? '停止下載，使用原有內容'
                                    : '稍後更新，先玩遊戲',
                              ),
                            ),
                          if (updates.phase == UpdatePhase.offline && !hasOffer)
                            TextButton(
                              onPressed: widget.opening
                                  ? null
                                  : () => unawaited(updates.check()),
                              child: const Text('重新檢查'),
                            ),
                          const SizedBox(height: 8),
                          const Text(
                            '森星小隊 · star.singtu.hk',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xff8c8364),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
