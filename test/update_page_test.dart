import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forest_star/content_updates.dart';
import 'package:forest_star/update_page.dart';

class PageUpdates extends ContentUpdates {
  PageUpdates() : super(root: Directory('unused'), platform: 'ios', build: 20);
  int downloads = 0, cancellations = 0;
  @override
  Future<void> download() async {
    downloads++;
    phase = UpdatePhase.downloading;
    receivedBytes = 3 * 1024 * 1024;
    totalBytes = 6 * 1024 * 1024;
    message = '正在下載森林內容…';
    notifyListeners();
  }

  @override
  void cancel() {
    cancellations++;
    super.cancel();
  }
}

void main() {
  testWidgets(
    'small screen progress shows bytes and permits cancel without blocking play',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final updates = PageUpdates()
        ..phase = UpdatePhase.available
        ..message = '森林有新內容，準備出發！'
        ..pendingCatalog = ContentCatalog('forest-base-v1', [], 6 * 1024 * 1024)
        ..totalBytes = 6 * 1024 * 1024;
      addTearDown(updates.dispose);
      var entered = false;
      await tester.pumpWidget(
        MaterialApp(
          home: UpdateProgressPage(
            updates: updates,
            prefs: prefs,
            onContinue: () => entered = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      final download = find.byKey(const ValueKey('content_update_primary'));
      await tester.ensureVisible(download);
      await tester.tap(download);
      await tester.pump();
      expect(updates.downloads, 1);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('content_update_progress')),
            )
            .value,
        .5,
      );
      expect(find.textContaining('50%'), findsOneWidget);
      final skip = find.byKey(const ValueKey('content_update_skip'));
      await tester.ensureVisible(skip);
      await tester.tap(skip);
      expect(entered, isTrue);
      expect(updates.cancellations, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('offline screen keeps enter and retry controls available', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final updates = PageUpdates()
      ..phase = UpdatePhase.offline
      ..message = '暫時無法檢查更新，可使用內附內容遊玩';
    addTearDown(updates.dispose);
    var entered = false;
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateProgressPage(
          updates: updates,
          prefs: prefs,
          onContinue: () => entered = true,
        ),
      ),
    );
    expect(find.text('重新檢查'), findsOneWidget);
    await tester.tap(find.text('進入遊戲'));
    expect(entered, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'capture update screen',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = File('assets/fonts/NotoSansTC.ttf').readAsBytesSync();
      for (final family in ['Ahem', 'Roboto', 'ForestUI']) {
        await (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
      SharedPreferences.setMockInitialValues({});
      final updates = PageUpdates();
      addTearDown(updates.dispose);
      await updates.download();
      final prefs = await SharedPreferences.getInstance();
      final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
      await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'ForestUI',
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff426b48),
              ),
            ),
            home: UpdateProgressPage(
              updates: updates,
              prefs: prefs,
              onContinue: () {},
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 200));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('output/review/updates').createSync(recursive: true);
        File(
          'output/review/updates/download.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: Platform.environment['FOREST_UPDATE_CAPTURE'] != '1',
  );
}
