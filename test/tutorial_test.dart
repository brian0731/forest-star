import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/forest_flame_game.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/game_tutorial.dart';
import 'package:forest_star/main.dart';
import 'package:forest_star/storybook_ui.dart';
import 'package:forest_star/tutorial_narrator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/src/widgets/tutorial_coach_mark_widget.dart';
import 'start_screen_test.dart' show FakeAudio, enterGame;

class FakeNarrator extends TutorialNarrator {
  final readings = <(String, TutorialLanguage)>[];
  int stops = 0;
  @override
  NarrationStatus get status => NarrationStatus.idle;
  @override
  Future<void> speak(String text, TutorialLanguage language) async {
    readings.add((text, language));
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

Future<void> frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['FOREST_TUTORIAL_CAPTURE'] != '1') return;
  await tester.runAsync(() async {
    final boundary =
        tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    final image = await boundary.toImage(
      ui.Offset.zero & tester.view.physicalSize,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('output/review/tutorial')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['FOREST_TUTORIAL_CAPTURE'] != '1') return;
    final bytes = File('assets/fonts/NotoSansTC.ttf').readAsBytesSync();
    for (final family in ['Ahem', 'Roboto', 'ForestUI']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test('Cantonese voice selection does not substitute Mandarin', () {
    final voices = [
      {'name': 'Mandarin', 'locale': 'zh-CN', 'gender': 'female'},
      {'name': 'English', 'locale': 'en-US', 'gender': 'female'},
      {
        'name': 'Cantonese network',
        'locale': 'yue-HK',
        'network_required': '1',
        'gender': 'female',
      },
      {
        'name': 'Cantonese offline',
        'locale': 'zh_HK',
        'network_required': '0',
        'gender': 'female',
      },
    ];
    expect(
      selectTutorialVoice(voices, TutorialLanguage.cantonese)?['name'],
      'Cantonese offline',
    );
    expect(
      selectTutorialVoice(voices.take(2), TutorialLanguage.cantonese),
      isNull,
    );
    expect(
      selectTutorialVoice(voices, TutorialLanguage.chinese)?['name'],
      'Mandarin',
    );
  });

  for (final language in TutorialLanguage.values) {
    test(
      '${language.name} selects female ahead of default/offline male voices',
      () {
        final voices = [
          {'name': 'Default male', 'locale': language.code, 'gender': 'male'},
          {'name': 'Unknown', 'locale': language.code},
          {
            'name': 'Female online',
            'locale': language.code,
            'gender': 'female',
            'network_required': '1',
          },
        ];
        expect(selectTutorialVoice(voices, language)?['name'], 'Female online');
        expect(selectTutorialVoice(voices.take(2), language), isNull);
      },
    );
  }

  test(
    'Google female IDs require Google engine and exclude male/default aliases',
    () {
      for (final (language, female, male) in [
        (TutorialLanguage.chinese, 'cmn-tw-x-ctc-local', 'cmn-tw-x-ctd-local'),
        (TutorialLanguage.english, 'en-us-x-tpf-local', 'en-us-x-tpd-local'),
        (
          TutorialLanguage.cantonese,
          'yue-hk-x-yuc-local',
          'yue-hk-x-yuf-local',
        ),
      ]) {
        final voices = [
          {'name': male, 'locale': language.code},
          {'name': '${language.code}-language', 'locale': language.code},
          {'name': female, 'locale': language.code},
        ];
        expect(selectTutorialVoice(voices, language), isNull);
        expect(
          selectTutorialVoice(voices, language, googleEngine: true)?['name'],
          female,
        );
        expect(
          selectTutorialVoice(voices.take(2), language, googleEngine: true),
          isNull,
        );
        expect(
          selectTutorialVoice(
            [
              {'name': female, 'locale': language.code, 'gender': 'male'},
            ],
            language,
            googleEngine: true,
          ),
          isNull,
        );
      }
    },
  );

  test(
    'female voices requiring a download are excluded; legacy female names work',
    () {
      expect(
        selectTutorialVoice([
          {
            'name': 'Not downloaded',
            'locale': 'en-US',
            'gender': 'female',
            'features': 'notInstalled\tnetworkRetriesCount',
          },
        ], TutorialLanguage.english),
        isNull,
      );
      expect(
        selectTutorialVoice(
          [
            {'name': 'en-us-x-sfg#male_1-local', 'locale': 'en-US'},
            {'name': 'en-us-x-sfg#female_1-local', 'locale': 'en-US'},
          ],
          TutorialLanguage.english,
          googleEngine: true,
        )?['name'],
        'en-us-x-sfg#female_1-local',
      );
    },
  );

  test(
    'practice rewards, pause and disposal never overwrite the player save',
    () async {
      final save = jsonEncode((GameState()..sugar = 888).toJson());
      SharedPreferences.setMockInitialValues({'forest_star_v1': save});
      final prefs = await SharedPreferences.getInstance();
      final session = createTutorialSession(prefs);
      session.launch();
      session.supply();
      session.state.upgrade(0);
      for (var i = 0; i < 1000; i++) {
        session.update(.1);
      }
      session.setForeground(false);
      session.flush();
      session.dispose();
      expect(prefs.getString('forest_star_v1'), save);
    },
  );

  group('native speech adapter', () {
    const channel = MethodChannel('flutter_tts');
    final calls = <MethodCall>[];
    late List<Map<String, String>> availableVoices;
    var voiceSelectionResult = 1;
    setUp(() {
      calls.clear();
      voiceSelectionResult = 1;
      availableVoices = [
        {'name': 'yue-hk-x-yuf-local', 'locale': 'yue-HK'},
        {'name': 'yue-hk-x-yuc-local', 'locale': 'yue-HK'},
        {'name': 'en-us-x-tpf-local', 'locale': 'en-US'},
      ];
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'getEngines' => ['com.google.android.tts'],
              'getVoices' => availableVoices,
              // Even if a language exists, its default might be male.
              'isLanguageAvailable' => true,
              'setVoice' => voiceSelectionResult,
              _ => 1,
            };
          });
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    test('Google engine and Cantonese voice are used on Android', () async {
      final narrator = DeviceTutorialNarrator();
      await narrator.speak('一齊守護森林啦！', TutorialLanguage.cantonese);
      expect(
        calls.any(
          (c) =>
              c.method == 'setEngine' &&
              c.arguments == 'com.google.android.tts',
        ),
        isTrue,
      );
      expect(
        calls.any((c) => c.method == 'setLanguage' && c.arguments == 'yue-HK'),
        isTrue,
      );
      expect(calls.where((c) => c.method == 'speak').length, 1);
      expect(
        calls.firstWhere((c) => c.method == 'setVoice').arguments['name'],
        'yue-hk-x-yuc-local',
      );
      await narrator.speak('中文', TutorialLanguage.chinese);
      expect(narrator.status, NarrationStatus.unavailable);
      expect(calls.where((c) => c.method == 'speak').length, 1);
      narrator.dispose();
    });
    test(
      'missing female voice never speaks a male default; Replay detects download',
      () async {
        availableVoices = [
          {'name': 'Male', 'locale': 'en-US', 'gender': 'male'},
        ];
        final narrator = DeviceTutorialNarrator();
        await narrator.speak('Hello', TutorialLanguage.english);
        expect(narrator.status, NarrationStatus.unavailable);
        expect(calls.where((c) => c.method == 'speak'), isEmpty);
        availableVoices = [
          {'name': 'en-us-x-tpf-local', 'locale': 'en-US'},
        ];
        await narrator.speak('Hello again', TutorialLanguage.english);
        expect(
          calls.lastWhere((c) => c.method == 'setVoice').arguments['name'],
          'en-us-x-tpf-local',
        );
        expect(calls.where((c) => c.method == 'speak').length, 1);
        narrator.dispose();
      },
    );
    test(
      'failed female selection does not fall back to the system voice',
      () async {
        voiceSelectionResult = 0;
        final narrator = DeviceTutorialNarrator();
        await narrator.speak('Hello', TutorialLanguage.english);
        expect(narrator.status, NarrationStatus.unavailable);
        expect(calls.where((c) => c.method == 'speak'), isEmpty);
        narrator.dispose();
      },
    );
    test(
      'rapid switch only speaks the latest language; stop cancels pending speech',
      () async {
        final narrator = DeviceTutorialNarrator();
        final old = narrator.speak('old', TutorialLanguage.cantonese);
        final latest = narrator.speak('latest', TutorialLanguage.english);
        await Future.wait([old, latest]);
        final spoken = calls.where((c) => c.method == 'speak').toList();
        expect(spoken.length, 1);
        expect(spoken.single.arguments, 'latest');
        final pending = narrator.speak('cancel', TutorialLanguage.english);
        await narrator.stop();
        await pending;
        expect(calls.where((c) => c.method == 'speak').length, 1);
        narrator.dispose();
      },
    );
    test(
      'iOS configures native speech without requesting an Android engine',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        availableVoices = [
          {
            'name': 'Aaron',
            'locale': 'en-US',
            'gender': 'male',
            'identifier': 'test.male.en-US',
          },
          {
            'name': 'Samantha',
            'locale': 'en-US',
            'gender': 'female',
            'identifier': 'test.female.en-US',
          },
        ];
        final narrator = DeviceTutorialNarrator();
        await narrator.speak('Hello', TutorialLanguage.english);
        expect(calls.any((c) => c.method == 'setSharedInstance'), isTrue);
        expect(calls.any((c) => c.method == 'setEngine'), isFalse);
        expect(
          calls
              .firstWhere((c) => c.method == 'setVoice')
              .arguments['identifier'],
          'test.female.en-US',
        );
        narrator.dispose();
      },
    );
  });

  testWidgets(
    'complete all ten lessons with actual progression and preserve real save',
    (tester) async {
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final save = jsonEncode((GameState()..sugar = 888).toJson());
      SharedPreferences.setMockInitialValues({'forest_star_v1': save});
      final prefs = await SharedPreferences.getInstance(),
          narrator = FakeNarrator();
      await tester.runAsync(() => StoryArt.instance.load());
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'ForestUI',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff426b48),
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        GameTutorialPage(prefs: prefs, narrator: narrator),
                  ),
                ),
                child: const Text('Learn'),
              ),
            ),
          ),
        ),
      );
      late ForestFlameGame game;
      await tester.runAsync(() async {
        await tester.tap(find.text('Learn'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        game = tester
            .widget<GameWidget<ForestFlameGame>>(
              find.byType(GameWidget<ForestFlameGame>),
            )
            .game!;
        await game.toBeLoaded();
      });
      await frames(tester, 24);
      await capture(tester, '01-camp-zh');
      expect(narrator.readings.last.$2, TutorialLanguage.chinese);
      for (var step = 0; step < tutorialLessons.length; step++) {
        expect(
          find.text(tutorialLessons[step].zhTitle),
          findsOneWidget,
          reason: 'step $step',
        );
        expect(tester.takeException(), isNull);
        if (step == 2) {
          expect(game.session.state.shots, 1);
          await capture(tester, '03-marble-baskets');
        }
        if (step == 5) expect(game.session.state.levels[0], 3);
        if (step == 6) expect(game.session.state.evolutions[0], 1);
        if (step == 7) expect(game.session.state.team[3], 3);
        if (step == 8) {
          expect(game.session.combat.active, isTrue);
          await capture(tester, '09-four-lane-defense');
        }
        await tester.tap(find.byKey(const ValueKey('tutorial_next')));
        // Timed animation waiters use real futures; advance both game frames and
        // the test clock rather than waiting for the infinite Flame ticker.
        await frames(
          tester,
          step == 2 ? 450 : (step == 4 || step == 5 ? 110 : 24),
        );
      }
      expect(find.text('Learn'), findsOneWidget);
      expect(prefs.getBool(tutorialCompletedKey), isTrue);
      expect(prefs.getString('forest_star_v1'), save);
      expect(narrator.stops, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 2);
      narrator.dispose();
    },
  );

  for (final device in [
    (const Size(1179, 2556), 3.0, const FakeViewPadding(top: 177, bottom: 102)),
    (const Size(1290, 2796), 3.0, const FakeViewPadding(top: 177, bottom: 102)),
    (const Size(750, 1334), 2.0, const FakeViewPadding(top: 40)),
  ]) {
    testWidgets(
      'iOS slide-in keeps lesson 01 on the marble house ${device.$1}',
      (tester) async {
        tester.view.physicalSize = device.$1;
        tester.view.devicePixelRatio = device.$2;
        tester.view.padding = device.$3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final narrator = FakeNarrator();
        // Preload like reopening the tutorial from an already running game.
        await tester.runAsync(() => StoryArt.instance.load());
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              platform: TargetPlatform.iOS,
              fontFamily: 'ForestUI',
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff426b48),
              ),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          GameTutorialPage(prefs: prefs, narrator: narrator),
                    ),
                  ),
                  child: const Text('Learn'),
                ),
              ),
            ),
          ),
        );
        late ForestFlameGame game;
        await tester.runAsync(() async {
          await tester.tap(find.text('Learn'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          game = tester
              .widget<GameWidget<ForestFlameGame>>(
                find.byType(GameWidget<ForestFlameGame>),
              )
              .game!;
          await game.toBeLoaded();
        });
        await frames(tester, 24);
        final coach = tester.widget<TutorialCoachMarkWidget>(
          find.byType(TutorialCoachMarkWidget),
        );
        final target = coach.targets.single.targetPosition!;
        final surface = tester.renderObject<RenderBox>(
          find.byType(GameWidget<ForestFlameGame>),
        );
        final house = game.locations.first;
        // The spotlight's bottom center must meet the rendered house's anchor.
        final expected = surface.localToGlobal(
          house.absolutePosition.toOffset(),
        );
        final highlighted = target.offset & target.size;
        expect(highlighted.center.dx, closeTo(expected.dx, 2));
        expect(highlighted.bottom, closeTo(expected.dy, 3));
        expect(
          highlighted.overlaps(
            tester.getRect(find.byKey(const ValueKey('tutorial_next'))),
          ),
          isFalse,
        );
        await capture(tester, '01-camp-ios-${device.$1.width.toInt()}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await frames(tester, 2);
        narrator.dispose();
      },
    );
  }

  for (final size in [const Size(360, 640), const Size(1366, 1024)]) {
    testWidgets(
      'language switch and early exit fit $size and preserve progress',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance(),
            narrator = FakeNarrator();
        await tester.runAsync(() => StoryArt.instance.load());
        late ForestFlameGame game;
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                fontFamily: 'ForestUI',
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xff426b48),
                ),
              ),
              home: GameTutorialPage(prefs: prefs, narrator: narrator),
            ),
          );
          game = tester
              .widget<GameWidget<ForestFlameGame>>(
                find.byType(GameWidget<ForestFlameGame>),
              )
              .game!;
          await game.toBeLoaded();
        });
        await frames(tester, 24);
        await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'English'));
        await tester.tap(find.widgetWithText(ChoiceChip, 'English'));
        await frames(tester);
        expect(find.text('Welcome to the forest'), findsOneWidget);
        expect(narrator.readings.last.$2, TutorialLanguage.english);
        await capture(tester, 'english-${size.width.toInt()}');
        await tester.ensureVisible(find.widgetWithText(ChoiceChip, '粵語'));
        await tester.tap(find.widgetWithText(ChoiceChip, '粵語'));
        await frames(tester);
        expect(narrator.readings.last.$2, TutorialLanguage.cantonese);
        expect(prefs.getString(tutorialLanguageKey), 'yue-HK');
        await capture(tester, 'cantonese-${size.width.toInt()}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await frames(tester, 2);
        expect(prefs.getBool(tutorialCompletedKey), isNull);
        expect(prefs.getString('forest_star_v1'), isNull);
        narrator.dispose();
      },
    );
  }

  testWidgets('in-game help pauses the real session, back restores it', (
    tester,
  ) async {
    const channel = MethodChannel('flutter_tts');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => 1,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({tutorialVoiceKey: false});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ForestStarApp(
        prefs: prefs,
        initialState: GameState(),
        audio: FakeAudio(),
      ),
    );
    final game = await enterGame(tester);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('遊戲教學・中 / English / 粵'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(game.session.foreground, isFalse);
      final practice = tester
          .widgetList<GameWidget<ForestFlameGame>>(
            find.byType(GameWidget<ForestFlameGame>),
          )
          .last
          .game!;
      await practice.toBeLoaded();
    });
    await frames(tester, 24);
    await tester.runAsync(() async {
      await tester.binding.handlePopRoute();
    });
    await frames(tester, 24);
    expect(find.byType(GameTutorialPage), findsNothing);
    expect(game.session.foreground, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 2);
  });
}
