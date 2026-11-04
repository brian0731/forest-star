import 'dart:ui';

enum UltimateKind { nature, water, fire, earth, lightning, moon }

class UltimateSpell {
  const UltimateSpell(
    this.name,
    this.color,
    this.highlight,
    this.damage,
    this.splash,
    this.effect,
  );
  final String name, effect;
  final Color color, highlight;
  final double damage, splash;
  static UltimateSpell of(UltimateKind kind) => _spells[kind.index];
  static const _spells = [
    UltimateSpell(
      '森羅風暴',
      Color(0xff79e7a5),
      Color(0xffecffc3),
      7,
      3,
      '風暴席捲全場 · 擊退敵人',
    ),
    UltimateSpell(
      '蒼海星潮',
      Color(0xff61ccff),
      Color(0xffdefcff),
      6,
      3,
      '星潮席捲全場 · 敵人緩速',
    ),
    UltimateSpell(
      '焰星隕落',
      Color(0xffff9752),
      Color(0xfffff1ae),
      9,
      4,
      '隕星轟擊全場 · 烈焰爆發',
    ),
    UltimateSpell(
      '大地聖盾',
      Color(0xffd4b477),
      Color(0xfffff3bc),
      5,
      2.5,
      '大地震擊全場 · 修復營地',
    ),
    UltimateSpell(
      '雷霆星陣',
      Color(0xffbd9aff),
      Color(0xfff2e9ff),
      8,
      4.5,
      '雷光連鎖全場 · 震退敵人',
    ),
    UltimateSpell(
      '月華審判',
      Color(0xffb0bfff),
      Color(0xfff2efff),
      10,
      3.5,
      '月華降臨全場 · 強力重擊',
    ),
  ];
}

class UltimateCast {
  UltimateCast(this.lane, this.friend, this.kind);
  final int lane, friend;
  final UltimateKind kind;
  double age = 0;
  bool impacted = false;
  static const impactTime = 1.25;
  static const duration = 3.35;
  UltimateSpell get spell => UltimateSpell.of(kind);
}
