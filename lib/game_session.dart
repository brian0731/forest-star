import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio.dart';
import 'game.dart';
import 'vfx_event.dart';
import 'interaction_motion.dart';
import 'companion_layout.dart';
import 'package:flutter/foundation.dart';
import 'ultimate_spell.dart';

/// Persistent game rules, independent of Flutter rebuilds and display refresh rate.
class GameSession {
  GameSession(this.state, this.prefs, this.audio, {this.persist = true}) {
    audio.setScene(MusicScene.camp);
    audio.setEnabled(state.sound);
    pinball.onHit = (amount) {
      audio.play(SoundEffect.bounce);
      emit(VfxKind.spark, Offset(pinball.x, pinball.y), 0);
      if (tab == 0 && amount > 0) {
        motion.add(
          CueKind.score,
          Offset(pinball.x, pinball.y),
          0,
          label: '+$amount',
        );
      }
    };
    pinball.onSettled = (bonus, dew) {
      state.sugar += bonus;
      state.dew += dew;
      final growth = state.awardGrowth(pinball.lastBucket, pinball.earned);
      queueGrowth(growth);
      selected = pinball.lastBucket;
      if (tab == 0) {
        motion.add(
          CueKind.reward,
          Offset(Pinball.bucketCenter(selected), 620),
          0,
          label: '+${pinball.earned} 成長',
        );
      }
      notify('${friends[selected].name} +${pinball.earned} 成長分 · +$bonus 星糖');
      audio.play(SoundEffect.reward);
      emit(
        VfxKind.stars,
        Offset(Pinball.bucketCenter(pinball.lastBucket), 620),
        0,
      );
      save();
    };
    combat.onAttack = () => audio.play(SoundEffect.hit);
    combat.onImpact = (position, friend) => emit(
      friends[friend].element == 2
          ? VfxKind.fire
          : friends[friend].element == 1
          ? VfxKind.water
          : friends[friend].element == 0 ||
                friends[friend].skill == FriendSkill.guard
          ? VfxKind.leaf
          : VfxKind.stars,
      position,
      2,
    );
    combat.onFinished = (won) {
      audio.play(won ? SoundEffect.win : SoundEffect.fail);
      if (won) {
        final reward = 45 + combat.stage * 12;
        state.sugar += reward;
        state.dew += 2;
        state.marbles = math.min(999, state.marbles + 3);
        state.victories++;
        state.clearedStage = math.max(state.clearedStage, combat.stage);
        state.stage = math.min(10, combat.stage + 1);
        resultTitle = state.clearedStage == 10 ? '森星守護者！' : '營地守住了！';
        resultDetail = '+$reward 星糖   +2 星露   +3 彈珠';
      } else {
        resultTitle = '再試一次吧';
        resultDetail = '提升夥伴等級、調整路線，再回來挑戰。';
      }
      result = true;
      inputGeneration++;
      motion.resultAge = 0;
      motion.cancelInput();
      save();
    };
  }
  GameState state;
  final SharedPreferences prefs;
  final GameAudio audio;

  /// Practice sessions use independent state and never write the player's save.
  final bool persist;
  final pinball = Pinball(), combat = Combat();
  final motion = InteractionMotion();
  UltimateCast? ultimate;
  final ultimatePlaying = ValueNotifier(false);
  final effects = Queue<VfxEvent>();
  final _growthQueue = Queue<GrowthResult>();
  GrowthResult? celebration;
  double celebrationAge = 0;
  double get celebrationDuration => celebration?.evolved == true ? 4.2 : 3.0;
  void queueGrowth(GrowthResult growth) {
    if (!growth.celebrate) return;
    _growthQueue.add(growth);
  }

  void emit(VfxKind kind, Offset position, int page) {
    if (!foreground || tab != page || result) return;
    if (effects.length >= 24) effects.removeFirst();
    effects.add(VfxEvent(kind, position, page));
  }

  int tab = 3, selected = 0;
  Offset aim = const Offset(.19, 1);
  bool result = false, dragging = false, foreground = true;
  bool _lifecycleActive = true;
  final _externalOverlays = <String>{};
  void Function()? onAdRequested;
  void Function()? onGachaRequested;
  void Function()? onPetGalleryRequested;
  String? adLabel;
  String toast = '', resultTitle = '', resultDetail = '';
  double time = 0, toastUntil = 0, resetUntil = 0, accumulator = 0;
  int simulationSteps = 0;
  int inputGeneration = 0;
  Timer? _saveTimer;
  static const fixedStep = 1 / 120;

  void update(double dt) {
    if (!foreground || !dt.isFinite || dt <= 0) return;
    // Bounded catch-up prevents a long frame or resume from teleporting objects.
    dt = dt.clamp(0.0, .1);
    time += dt;
    motion.update(dt);
    accumulator += dt;
    var steps = 0;
    while (accumulator + 1e-10 >= fixedStep && steps < 12) {
      if (!result) {
        if (celebration != null) {
          celebrationAge += fixedStep;
          if (celebrationAge + 1e-10 >= celebrationDuration) celebration = null;
        }
        if (celebration == null && _growthQueue.isNotEmpty) {
          celebration = _growthQueue.removeFirst();
          celebrationAge = 0;
          dragging = false;
          inputGeneration++;
          motion.cancelInput();
          audio.play(
            celebration!.evolved ? SoundEffect.win : SoundEffect.reward,
          );
        }
      }
      final health = combat.health, wave = combat.wave;
      final cast = ultimate;
      if (cast != null) {
        cast.age += fixedStep;
        if (!cast.impacted && cast.age + 1e-10 >= UltimateCast.impactTime) {
          cast.impacted = true;
          combat.resolveUltimate(cast.lane);
          audio.play(SoundEffect.magicImpact);
        }
        if (cast.age + 1e-10 >= UltimateCast.duration) {
          ultimate = null;
          ultimatePlaying.value = false;
          inputGeneration++;
        }
      }
      if (celebration == null && ultimate == null) {
        pinball.tick(fixedStep);
        combat.tick(fixedStep);
      }
      if (tab == 2 && combat.health < health) motion.hurtAge = 0;
      if (tab == 2 && combat.active && combat.wave > wave) {
        motion.announce('第 ${combat.wave} 波 · 守住森林！');
      }
      accumulator = math.max(0, accumulator - fixedStep);
      simulationSteps++;
      steps++;
    }
  }

  void save() {
    if (!persist) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 100), flush);
  }

  void flush() {
    if (persist) {
      prefs.setString('forest_star_v1', jsonEncode(state.toJson()));
    }
  }

  void cancelPendingSave() => _saveTimer?.cancel();

  void setForeground(bool value) {
    _lifecycleActive = value;
    _syncForeground();
  }

  void setExternalOverlay(bool value, {String source = 'modal'}) {
    if (value) {
      _externalOverlays.add(source);
    } else {
      _externalOverlays.remove(source);
    }
    _syncForeground();
  }

  void _syncForeground() {
    final value = _lifecycleActive && _externalOverlays.isEmpty;
    if (foreground != value) inputGeneration++;
    foreground = value;
    dragging = false;
    motion.cancelInput();
    accumulator = 0;
    audio.setForeground(value);
    if (!value) flush();
  }

  void dispose() {
    ultimatePlaying.dispose();
    effects.clear();
    _growthQueue.clear();
    motion.cues.clear();
    _saveTimer?.cancel();
    flush();
    audio.dispose();
  }

  void notify(String value) {
    toast = value;
    toastUntil = time + 2.8;
    motion.toastAge = 0;
  }

  void click() => audio.play(SoundEffect.select);
  bool inside(Offset p, double x, double y, double w, double h) =>
      Rect.fromLTWH(x, y, w, h).contains(p);
  void setAim(Offset p) {
    final dx = (p.dx - 240).clamp(-230.0, 230.0),
        dy = math.max(90.0, p.dy - 248),
        len = math.sqrt(dx * dx + dy * dy);
    aim = Offset(dx / len, dy / len);
  }

  bool get canAim =>
      tab == 0 && !pinball.active && !result && celebration == null;
  bool aimArea(Offset p) => inside(p, 37, 237, 406, 397);

  /// Shared control regions let release-outside cancel rather than trigger
  /// another action. Decorative scenery and the aim surface have no button.
  Rect? controlAt(Offset p) {
    if (ultimate != null) return null;
    final regions = <Rect>[];
    if (result) {
      regions.add(const Rect.fromLTWH(69, 536, 342, 60));
    } else if (celebration != null) {
      if (celebrationAge >= 1.2)
        regions.add(const Rect.fromLTWH(115, 710, 250, 55));
    } else if (tab == 3) {
      regions.addAll(
        adLabel == null
            ? const [
                Rect.fromLTWH(20, 820, 150, 58),
                Rect.fromLTWH(176, 820, 142, 58),
                Rect.fromLTWH(324, 820, 136, 58),
              ]
            : const [
                Rect.fromLTWH(20, 820, 108, 58),
                Rect.fromLTWH(128, 820, 108, 58),
                Rect.fromLTWH(236, 820, 108, 58),
                Rect.fromLTWH(344, 820, 116, 58),
              ],
      );
    } else {
      for (var i = 0; i < 4; i++) {
        regions.add(Rect.fromLTWH(i * 120.0, 819, 120, 81));
      }
      if (tab == 1) {
        regions.addAll([
          CompanionLayout.gallery,
          CompanionLayout.previous,
          CompanionLayout.next,
          for (
            var page = 0;
            page < CompanionLayout.pageCount(friends.length);
            page++
          )
            CompanionLayout.page(page),
        ]);
        for (var i = 0; i < 6 && selected ~/ 6 * 6 + i < friends.length; i++) {
          regions.add(CompanionLayout.card(i));
        }
        if (!state.unlocked[selected]) {
          regions.add(const Rect.fromLTWH(24, 698, 432, 52));
        } else {
          regions.addAll(const [
            Rect.fromLTWH(24, 698, 211, 52),
            Rect.fromLTWH(245, 698, 211, 52),
          ]);
        }
        for (var i = 0; i < 4; i++) {
          regions.add(Rect.fromLTWH(118 + i * 85.0, 758, 80, 43));
        }
      } else {
        if (tab == 2 && combat.active) {
          for (var lane = 0; lane < BattleLayout.lanes; lane++) {
            if (combat.team[lane] >= 0 && !combat.ultimateUsed[lane]) {
              regions.add(BattleLayout.ultimateButton(lane));
            }
          }
        }
        if (!(tab == 0 ? pinball.active : combat.active)) {
          regions.add(const Rect.fromLTWH(24, 754, 311, 53));
        }
        regions.add(const Rect.fromLTWH(346, 754, 110, 53));
      }
    }
    for (final rect in regions) {
      if (rect.contains(p)) return rect;
    }
    return null;
  }

  void launch() {
    if (pinball.active || result || celebration != null || !foreground) return;
    if (state.marbles <= 0) {
      notify('彈珠用完了，點補給就可以繼續試玩。');
      return;
    }
    pinball.launch(aim);
    motion.launchAge = 0;
    state.marbles--;
    state.shots++;
    audio.play(SoundEffect.launch);
    emit(VfxKind.stars, const Offset(240, 248), 0);
    save();
  }

  void supply({bool fromAd = false}) {
    state.marbles = math.min(999, state.marbles + 12);
    notify(fromAd ? '廣告獎勵已到帳：+12 顆彈珠！' : '收到 12 顆彈珠，繼續冒險吧！');
    audio.play(SoundEffect.reward);
    motion.add(
      CueKind.reward,
      tab == 3 ? const Offset(95, 820) : const Offset(400, 770),
      tab,
      label: '+12 彈珠',
    );
    emit(
      VfxKind.stars,
      tab == 3 ? const Offset(240, 715) : const Offset(390, 620),
      tab,
    );
    save();
    if (fromAd) flush();
  }

  void open(int destination) {
    if (result ||
        ultimate != null ||
        celebration != null ||
        !foreground ||
        destination < 0 ||
        destination > 3)
      return;
    if (destination == tab) return;
    tab = destination;
    inputGeneration++;
    toastUntil = 0;
    motion.pageChanged();
    audio.setScene(tab == 3 ? MusicScene.camp : MusicScene.adventure);
    effects.clear();
    dragging = false;
    click();
  }

  void selectCompanion(int id) {
    if (id < 0 || id >= friends.length) return;
    selected = id;
    motion.select(id);
    click();
  }

  void tap(Offset p) {
    if (!foreground || ultimate != null) return;
    if (result) {
      if (inside(p, 69, 536, 342, 60)) {
        result = false;
        tab = 2;
        click();
      }
      return;
    }
    if (celebration != null) {
      if (celebrationAge >= 1.2 && inside(p, 115, 710, 250, 55)) {
        celebrationAge = celebrationDuration;
        click();
      }
      return;
    }
    if (tab != 3 && inside(p, 0, 819, 480, 81)) {
      open((p.dx / 120).floor().clamp(0, 3));
      return;
    }
    if (tab == 0) {
      if (canAim && aimArea(p)) {
        setAim(p);
        launch();
      } else if (inside(p, 24, 754, 311, 53)) {
        launch();
      } else if (inside(p, 346, 754, 110, 53)) {
        supply();
      }
      return;
    }
    if (tab == 1) {
      if (CompanionLayout.gallery.contains(p)) {
        click();
        onPetGalleryRequested?.call();
        return;
      }
      final pages = CompanionLayout.pageCount(friends.length);
      if (CompanionLayout.previous.contains(p) ||
          CompanionLayout.next.contains(p)) {
        final direction = CompanionLayout.previous.contains(p) ? -1 : 1;
        selectCompanion(((selected ~/ 6 + direction) % pages) * 6);
        return;
      }
      for (var page = 0; page < pages; page++) {
        if (CompanionLayout.page(page).contains(p)) {
          selectCompanion(page * 6);
          return;
        }
      }
      for (var i = 0; i < 6 && selected ~/ 6 * 6 + i < friends.length; i++) {
        if (CompanionLayout.card(i).contains(p)) {
          selectCompanion(selected ~/ 6 * 6 + i);
          return;
        }
      }
      if (inside(p, 24, 698, 432, 52)) {
        if (combat.active) {
          notify('戰鬥結束後就可以升級。');
          return;
        }
        bool success;
        final oldLevel = state.levels[selected],
            oldEvolution = state.evolutions[selected];
        final wasUnlocked = state.unlocked[selected];
        if (!state.unlocked[selected]) {
          if (selected >= 6) {
            onGachaRequested?.call();
            return;
          }
          success = state.unlock(selected);
          notify(success ? '新朋友加入了！' : '星糖不足，去彈珠台收集吧。');
        } else if (p.dx < 240) {
          success = state.upgrade(selected);
          notify(
            success
                ? '${friends[selected].name}升到 Lv.${state.levels[selected]}！'
                : '星糖不足或等級已滿。',
          );
        } else {
          success = state.evolve(selected);
          notify(
            success
                ? '進化成功！'
                : '需要 Lv.${3 + state.evolutions[selected] * 3} 及 ${state.evolveCost(selected)} 星露。',
          );
        }
        audio.play(success ? SoundEffect.reward : SoundEffect.fail);
        if (success) {
          emit(VfxKind.stars, const Offset(85, 590), 1);
          queueGrowth(
            GrowthResult(
              selected,
              0,
              oldLevel,
              state.levels[selected],
              oldEvolution,
              state.evolutions[selected],
              !wasUnlocked,
            ),
          );
        }
        save();
        return;
      }
      for (var i = 0; i < BattleLayout.lanes; i++) {
        if (!inside(p, 118 + i * 85, 758, 80, 43)) continue;
        if (combat.active) {
          notify('戰鬥進行中，結束後可以調整隊伍。');
        } else if (!state.unlocked[selected]) {
          notify('先結識這位夥伴吧。');
        } else {
          state.equip(i, selected);
          click();
          save();
          notify('${friends[selected].name}已安排到${BattleLayout.laneName(i)}');
        }
        return;
      }
    }
    if (tab == 2 && combat.active) {
      for (var lane = 0; lane < BattleLayout.lanes; lane++) {
        if (BattleLayout.ultimateButton(lane).contains(p)) {
          castUltimate(lane);
          return;
        }
      }
    }
    if (tab == 2 && !combat.active) {
      if (inside(p, 24, 754, 311, 53)) {
        combat.begin(state);
        motion.announce('四路出擊！');
        audio.play(SoundEffect.battle);
      } else if (inside(p, 346, 754, 110, 53)) {
        open(1);
      }
    }
    if (tab == 3) {
      final withAds = adLabel != null;
      if (withAds && inside(p, 128, 820, 108, 58)) {
        if (pinball.active || combat.active) {
          notify('本次遊玩結束後即可觀看廣告。');
        } else {
          onAdRequested?.call();
        }
      } else if (inside(p, 20, 820, withAds ? 108 : 150, 58)) {
        supply();
      } else if (inside(p, withAds ? 236 : 176, 820, withAds ? 108 : 142, 58)) {
        state.sound = !state.sound;
        audio.setEnabled(state.sound);
        click();
        save();
      } else if (inside(p, withAds ? 344 : 324, 820, withAds ? 116 : 136, 58)) {
        if (combat.active || pinball.active) {
          notify('本次遊玩結束後即可前往星願轉珠。');
        } else {
          click();
          onGachaRequested?.call();
        }
      }
    }
  }

  bool castUltimate(int lane) {
    if (!foreground ||
        tab != 2 ||
        result ||
        celebration != null ||
        ultimate != null) {
      return false;
    }
    if (!combat.reserveUltimate(lane)) {
      if (combat.active &&
          lane >= 0 &&
          lane < 4 &&
          !combat.ultimateUsed[lane] &&
          combat.team[lane] >= 0) {
        notify('等敵人出現，再施放大招！');
      }
      return false;
    }
    final id = combat.team[lane];
    ultimate = UltimateCast(lane, id, friends[id].ultimateKind);
    inputGeneration++;
    motion.cancelInput();
    dragging = false;
    ultimatePlaying.value = true;
    audio.play(SoundEffect.magicCharge);
    return true;
  }
}
