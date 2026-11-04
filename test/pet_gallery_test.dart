import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/companion_layout.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/main.dart';
import 'package:forest_star/pet_gallery.dart';
import 'package:forest_star/storybook_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio, enterGame, gameTap;

void main() {
  final capture = Platform.environment['FOREST_PET_GALLERY_CAPTURE'] == '1';
  Future<void> fonts() async {
    if (!capture) return;
    final bytes = File('assets/fonts/NotoSansTC.ttf').readAsBytesSync();
    for (final name in ['Ahem', 'Roboto', 'ForestUI']) {
      await (FontLoader(
        name,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk != null) {
      final file = File(
        '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (file.existsSync()) {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.sublistView(file.readAsBytesSync())),
            ))
            .load();
      }
    }
  }

  Future<void> snapshot(WidgetTester tester, String name) async {
    if (!capture) return;
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('gallery_capture')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = Directory('output/review/pet-gallery-v1')
        ..createSync(recursive: true);
      await File(
        '${out.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'room album navigation, all-pet selection and back preserve progress',
    (tester) async {
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await fonts();
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => StoryArt.instance.load());
      final state = GameState()..unlocked[6] = true;
      final before = jsonEncode(state.toJson());
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('gallery_capture'),
          child: ForestStarApp(
            prefs: await SharedPreferences.getInstance(),
            initialState: state,
            audio: FakeAudio(),
          ),
        ),
      );
      final game = await enterGame(tester), session = game.session;
      session.open(1);
      await tester.pump(const Duration(milliseconds: 300));
      await snapshot(tester, 'room');
      await gameTap(tester, game, CompanionLayout.next.center);
      expect(session.selected, 6);
      await gameTap(tester, game, CompanionLayout.previous.center);
      expect(session.selected, 0);
      await gameTap(tester, game, CompanionLayout.page(4).center);
      expect(session.selected, 24);
      expect(session.controlAt(CompanionLayout.card(2).center), isNull);
      await gameTap(tester, game, CompanionLayout.card(1).center);
      expect(session.selected, 25);
      await snapshot(tester, 'last-room-page');
      await gameTap(tester, game, CompanionLayout.next.center);
      expect(session.selected, 0);
      await gameTap(tester, game, CompanionLayout.gallery.center);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PetGalleryPage), findsOneWidget);
      expect(session.foreground, isFalse);
      final time = session.time;
      await tester.pump(const Duration(seconds: 1));
      expect(session.time, time);
      await snapshot(tester, 'all-pets');
      final scroll = find.descendant(
        of: find.byType(PetGalleryPage),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pet_gallery_25')),
        400,
        scrollable: scroll,
      );
      // Finish the scroll's ballistic motion before tapping a card.
      await tester.pump(const Duration(seconds: 1));
      await snapshot(tester, 'all-pets-last');
      await tester.tap(find.byKey(const ValueKey('pet_gallery_25')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(PetGalleryPage), findsNothing);
      expect(session.foreground, isTrue);
      expect(session.selected, 25);
      expect(session.tab, 1);
      expect(jsonEncode(state.toJson()), before);
      await gameTap(tester, game, CompanionLayout.gallery.center);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(session.selected, 25);
      expect(session.foreground, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  for (final spec in [
    (const Size(360, 640), 2.0),
    (const Size(768, 1024), 1.0),
  ]) {
    testWidgets(
      'all pets fit and scroll at ${spec.$1} with text scale ${spec.$2}',
      (tester) async {
        tester.view.physicalSize = spec.$1;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await fonts();
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('gallery_capture'),
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'ForestUI'),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(spec.$2)),
                child: child!,
              ),
              home: PetGalleryPage(state: GameState(), selected: 0),
            ),
          ),
        );
        await snapshot(tester, 'gallery-${spec.$1.width.toInt()}');
        final scroll = find.byType(Scrollable);
        for (var id = 0; id < friends.length; id++) {
          await tester.scrollUntilVisible(
            find.byKey(ValueKey('pet_gallery_$id')),
            250,
            scrollable: scroll,
          );
          expect(find.text(friends[id].name), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
