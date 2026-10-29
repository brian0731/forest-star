import 'dart:math' as math;
import 'dart:ui';

enum CueKind { touch, score, reward }

class MotionCue {
  MotionCue(this.kind, this.position, this.page, {this.label = ''});
  final CueKind kind;
  final Offset position;
  final int page;
  final String label;
  double age = 0;
  double get duration => kind == CueKind.touch ? .38 : 1.15;
}

/// Presentation only: none of these clocks change physics, rewards or saves.
class InteractionMotion {
  final cues = <MotionCue>[];
  Rect? pressed;
  bool holding = false;
  double releaseAge = 1, transitionAge = 1, selectionAge = 1;
  double resultAge = 1, launchAge = 1, hurtAge = 1, bannerAge = 2;
  double toastAge = 1;
  int selectedFriend = -1;
  String banner = '';
  static const maxCues = 20;

  void press(Rect bounds) {
    pressed = bounds;
    holding = true;
    releaseAge = 0;
  }

  void release({bool cancelled = false}) {
    holding = false;
    releaseAge = 0;
    if (cancelled) pressed = null;
  }

  double compression(Rect bounds) {
    if (pressed == null || !bounds.contains(pressed!.center)) return 0;
    return holding
        ? .035
        : .035 * math.exp(-releaseAge * 15) * math.cos(releaseAge * 28);
  }

  double get reveal {
    final t = (transitionAge / .24).clamp(0.0, 1.0);
    return 1 - math.pow(1 - t, 3).toDouble();
  }

  void pageChanged() {
    transitionAge = 0;
    pressed = null;
    holding = false;
    cues.clear();
    banner = '';
  }

  void select(int friend) {
    selectedFriend = friend;
    selectionAge = 0;
  }

  void announce(String value) {
    banner = value;
    bannerAge = 0;
  }

  void add(CueKind kind, Offset position, int page, {String label = ''}) {
    if (cues.length >= maxCues) cues.removeAt(0);
    cues.add(MotionCue(kind, position, page, label: label));
  }

  void update(double dt) {
    releaseAge = math.min(1, releaseAge + dt);
    transitionAge = math.min(1, transitionAge + dt);
    selectionAge = math.min(1, selectionAge + dt);
    resultAge = math.min(1, resultAge + dt);
    launchAge = math.min(1, launchAge + dt);
    hurtAge = math.min(1, hurtAge + dt);
    bannerAge = math.min(2, bannerAge + dt);
    toastAge = math.min(1, toastAge + dt);
    if (!holding && releaseAge >= .4) pressed = null;
    for (final cue in cues) {
      cue.age += dt;
    }
    cues.removeWhere((cue) => cue.age >= cue.duration);
  }

  void cancelInput() {
    holding = false;
    pressed = null;
  }
}
