import 'dart:math' as math;
import 'dart:ui';
import 'level_data.dart';
import 'ultimate_spell.dart';

enum FriendSkill { rapid, slow, splash, guard, chain, heavy }

class Friend {
  const Friend(
    this.name,
    this.role,
    this.description,
    this.color,
    this.damage,
    this.interval, {
    this.skill = FriendSkill.rapid,
    this.element,
  });
  final String name, role, description;
  final Color color;
  final double damage, interval;
  final FriendSkill skill;
  final int? element;
  UltimateKind get ultimateKind {
    if (skill == FriendSkill.guard) return UltimateKind.earth;
    if (element == 2) return UltimateKind.fire;
    if (element == 1) return UltimateKind.water;
    if (element == 0) return UltimateKind.nature;
    if (skill == FriendSkill.chain) return UltimateKind.lightning;
    return UltimateKind.moon;
  }
}

const friends = <Friend>[
  Friend('芽耳兔', '連射', '輕快的森林射手，攻擊速度最快。', Color(0xff91c99d), 8, .78, element: 0),
  Friend(
    '泡泡獺',
    '緩速',
    '水泡命中後，使敵人減速 35%。',
    Color(0xff87c8df),
    11,
    1.05,
    skill: FriendSkill.slow,
    element: 1,
  ),
  Friend(
    '燈尾狐',
    '範圍',
    '火花同時傷害附近的敵人。',
    Color(0xfff2ad80),
    14,
    1.35,
    skill: FriendSkill.splash,
    element: 2,
  ),
  Friend(
    '苔石龜',
    '守護',
    '上陣時，營地耐久額外增加 25。',
    Color(0xffb4be91),
    18,
    1.5,
    skill: FriendSkill.guard,
  ),
  Friend(
    '星絨雀',
    '連鎖',
    '電光會跳向另一條路的敵人。',
    Color(0xfff0d780),
    10,
    1,
    skill: FriendSkill.chain,
  ),
  Friend(
    '月眠貓',
    '重擊',
    '每三次攻擊觸發一次雙倍傷害。',
    Color(0xffb8abd9),
    17,
    1.4,
    skill: FriendSkill.heavy,
  ),
  Friend('花刺蝟', '連射', '嫩芽飛針，輕快連射守護森林。', Color(0xff9ac9a2), 9, .84, element: 0),
  Friend(
    '蜜果熊',
    '守護',
    '上陣時，營地耐久額外增加 25。',
    Color(0xffd8b77f),
    16,
    1.45,
    skill: FriendSkill.guard,
  ),
  Friend(
    '櫻角鹿',
    '連鎖',
    '花光跳躍，連鎖另一條路的敵人。',
    Color(0xffe8adba),
    10,
    1.08,
    skill: FriendSkill.chain,
  ),
  Friend(
    '暮羽鴞',
    '重擊',
    '每三次月羽攻擊觸發雙倍傷害。',
    Color(0xffb6a4d3),
    16,
    1.36,
    skill: FriendSkill.heavy,
  ),
  Friend('橡果松鼠', '連射', '敏捷投出橡果，持續打擊敵人。', Color(0xffc9946b), 8, .79, element: 0),
  Friend(
    '雪團企鵝',
    '緩速',
    '冰涼雪球命中，使敵人減速 35%。',
    Color(0xffa5d9e6),
    11,
    1.12,
    skill: FriendSkill.slow,
    element: 1,
  ),
  Friend(
    '珊瑚螈',
    '範圍',
    '珊瑚泡泡傷害同一路的附近敵人。',
    Color(0xffeba7ae),
    13,
    1.30,
    skill: FriendSkill.splash,
    element: 1,
  ),
  Friend(
    '葉隱龍',
    '守護',
    '葉片屏障讓營地耐久額外增加 25。',
    Color(0xff95c8ae),
    17,
    1.48,
    skill: FriendSkill.guard,
  ),
  Friend(
    '楓尾熊貓',
    '範圍',
    '楓火花傷害同一路的附近敵人。',
    Color(0xffd99b7e),
    14,
    1.38,
    skill: FriendSkill.splash,
    element: 2,
  ),
  Friend('日葵犬', '連射', '陽光種子快速連射，充滿活力。', Color(0xffe8cc81), 9, .87, element: 0),
  Friend(
    '雲朵象',
    '守護',
    '雲朵護盾讓營地耐久額外增加 25。',
    Color(0xffa6c9e1),
    18,
    1.60,
    skill: FriendSkill.guard,
  ),
  Friend(
    '桃貝海豹',
    '緩速',
    '桃色水珠命中，使敵人減速 35%。',
    Color(0xffe2b0b6),
    12,
    1.18,
    skill: FriendSkill.slow,
    element: 1,
  ),
  Friend(
    '荷葉蛙',
    '連鎖',
    '荷光跳向另一條路的敵人。',
    Color(0xff9ccca9),
    10,
    1.04,
    skill: FriendSkill.chain,
  ),
  Friend(
    '星翼蝠',
    '重擊',
    '每三次星波攻擊觸發雙倍傷害。',
    Color(0xffb9a0cc),
    16,
    1.39,
    skill: FriendSkill.heavy,
  ),
  Friend(
    '鈴絨羊駝',
    '連鎖',
    '鈴聲星光連鎖另一條路的敵人。',
    Color(0xffd9bdab),
    11,
    1.14,
    skill: FriendSkill.chain,
  ),
  Friend(
    '霜角鯨',
    '緩速',
    '霜晶命中，使敵人減速 35%。',
    Color(0xffa4cde3),
    12,
    1.20,
    skill: FriendSkill.slow,
    element: 1,
  ),
  Friend(
    '青鱗穿山甲',
    '守護',
    '青鱗屏障讓營地耐久額外增加 25。',
    Color(0xffaab98c),
    18,
    1.58,
    skill: FriendSkill.guard,
  ),
  Friend('莓尾貂', '連射', '靈巧莓果連射，守住森林小路。', Color(0xffc6afd4), 9, .83, element: 0),
  Friend(
    '桃羽紅鶴',
    '連鎖',
    '羽光連鎖另一條路的敵人。',
    Color(0xffe6abb9),
    10,
    1.06,
    skill: FriendSkill.chain,
  ),
  Friend(
    '晶芽幼龍',
    '範圍',
    '晶焰同時傷害同一路的附近敵人。',
    Color(0xff8ecac4),
    15,
    1.46,
    skill: FriendSkill.splash,
    element: 2,
  ),
];

class GameState {
  int sugar = 60, dew = 3, marbles = 20, stage = 1, clearedStage = 0;
  int shots = 0, upgrades = 0, victories = 0;
  bool sound = true;
  List<int> levels = List.filled(friends.length, 1),
      evolutions = List.filled(friends.length, 0),
      team = [0, 1, 2, -1];
  List<bool> unlocked = List.generate(friends.length, (id) => id < 3);
  List<int> growth = List.filled(friends.length, 0);
  int drawDay = 0, freeDrawsUsed = 0;
  Map<String, int> paidDrawSequences = {};

  int growthCost(int id) => unlocked[id] ? 24 + levels[id] * 12 : 40;
  GrowthResult awardGrowth(int id, int points) {
    final beforeLevel = levels[id], beforeEvolution = evolutions[id];
    final wasUnlocked = unlocked[id];
    growth[id] = math.min(999999, growth[id] + math.max(0, points));
    if (!unlocked[id] && growth[id] >= 40) {
      growth[id] -= 40;
      unlocked[id] = true;
    }
    while (unlocked[id] && levels[id] < 10 && growth[id] >= growthCost(id)) {
      growth[id] -= growthCost(id);
      levels[id]++;
      upgrades++;
    }
    if (unlocked[id]) {
      final tier = levels[id] >= 6
          ? 2
          : levels[id] >= 3
          ? 1
          : 0;
      evolutions[id] = math.max(evolutions[id], tier);
    }
    return GrowthResult(
      id,
      points,
      beforeLevel,
      levels[id],
      beforeEvolution,
      evolutions[id],
      !wasUnlocked && unlocked[id],
    );
  }

  int upgradeCost(int id) => 14 + levels[id] * 8;
  int evolveCost(int id) => 3 + evolutions[id] * 3;
  double damage(int id) =>
      friends[id].damage *
      (1 + (levels[id] - 1) * .24) *
      (1 + evolutions[id] * .4);
  bool upgrade(int id) {
    if (!unlocked[id] || levels[id] >= 10 || sugar < upgradeCost(id))
      return false;
    sugar -= upgradeCost(id);
    levels[id]++;
    upgrades++;
    return true;
  }

  bool evolve(int id) {
    if (!unlocked[id] ||
        evolutions[id] >= 2 ||
        levels[id] < 3 + evolutions[id] * 3 ||
        dew < evolveCost(id))
      return false;
    dew -= evolveCost(id);
    evolutions[id]++;
    return true;
  }

  bool unlock(int id) {
    if (id >= 6 || unlocked[id] || sugar < 80) return false;
    sugar -= 80;
    unlocked[id] = true;
    return true;
  }

  void equip(int lane, int id) {
    if (lane < 0 ||
        lane >= BattleLayout.lanes ||
        id < 0 ||
        id >= friends.length ||
        !unlocked[id])
      return;
    final existing = team.indexOf(id);
    if (existing >= 0) team[existing] = team[lane];
    team[lane] = id;
  }

  Map<String, dynamic> toJson() => {
    'sugar': sugar,
    'dew': dew,
    'marbles': marbles,
    'stage': stage,
    'clearedStage': clearedStage,
    'shots': shots,
    'upgrades': upgrades,
    'victories': victories,
    'sound': sound,
    'levels': levels,
    'evolutions': evolutions,
    'team': team,
    'unlocked': unlocked,
    'growth': growth,
    'drawDay': drawDay,
    'freeDrawsUsed': freeDrawsUsed,
    'paidDrawSequences': paidDrawSequences,
  };
  static GameState fromJson(Map<String, dynamic> json) {
    final s = GameState();
    int value(String key, int fallback, int min, int max) => json[key] is num
        ? (json[key] as num).toInt().clamp(min, max)
        : fallback;
    List<int> ints(String key, List<int> fallback, int min, int max) {
      final raw = json[key];
      if (raw is! List ||
          (raw.length != fallback.length && raw.length != 6) ||
          raw.any((e) => e is! num))
        return fallback;
      return List.generate(
        fallback.length,
        (id) => id < raw.length
            ? (raw[id] as num).toInt().clamp(min, max)
            : fallback[id],
      );
    }

    s.sugar = value('sugar', 60, 0, 999999);
    s.dew = value('dew', 3, 0, 9999);
    s.marbles = value('marbles', 20, 0, 999);
    s.stage = value('stage', 1, 1, 10);
    s.clearedStage = value('clearedStage', 0, 0, 10);
    s.shots = value('shots', 0, 0, 999999);
    s.upgrades = value('upgrades', 0, 0, 999999);
    s.victories = value('victories', 0, 0, 999999);
    s.sound = json['sound'] != false;
    s.levels = ints('levels', s.levels, 1, 10);
    s.evolutions = ints('evolutions', s.evolutions, 0, 2);
    s.growth = ints('growth', s.growth, 0, 999999);
    s.drawDay = value('drawDay', 0, 0, 99999999);
    s.freeDrawsUsed = value('freeDrawsUsed', 0, 0, 5);
    final sequences = json['paidDrawSequences'];
    if (sequences is Map) {
      for (final entry in sequences.entries) {
        if (entry.key is String &&
            (entry.key as String).length == 36 &&
            entry.value is int &&
            entry.value >= 0 &&
            entry.value < 2147483647) {
          s.paidDrawSequences[entry.key as String] = entry.value as int;
        }
      }
    }
    final unlocked = json['unlocked'];
    if (unlocked is List &&
        (unlocked.length == 6 || unlocked.length == friends.length) &&
        unlocked.every((e) => e is bool))
      s.unlocked = List.generate(
        friends.length,
        (id) => id < unlocked.length ? unlocked[id] as bool : false,
      );
    s.unlocked.setRange(0, 3, [true, true, true]);
    final rawTeam = json['team'];
    if (rawTeam is List &&
        (rawTeam.length == 3 || rawTeam.length == 4) &&
        rawTeam.every((id) => id is int && id >= -1 && id < friends.length)) {
      final team = rawTeam.cast<int>().toList();
      final equipped = team.where((id) => id >= 0).toList();
      if (equipped.toSet().length == equipped.length &&
          equipped.every((id) => s.unlocked[id])) {
        if (team.length == 3) {
          final available = List.generate(
            friends.length,
            (id) => id,
          ).where((id) => s.unlocked[id] && !team.contains(id));
          team.add(available.isEmpty ? -1 : available.first);
        }
        s.team = team;
      }
    }
    return s;
  }
}

class GrowthResult {
  const GrowthResult(
    this.friend,
    this.points,
    this.oldLevel,
    this.level,
    this.oldEvolution,
    this.evolution,
    this.joined,
  );
  final int friend, points, oldLevel, level, oldEvolution, evolution;
  final bool joined;
  bool get evolved => evolution > oldEvolution;
  bool get celebrate => evolved || joined || level > oldLevel;
}

class Peg {
  Peg(this.x, this.y, this.type) : life = type + 1;
  final double x, y;
  final int type;
  int life;
  int get maxLife => type + 1;
  int get score => const [6, 14, 24][type];
  double flash = 0, cooldown = 0;
}

class Pinball {
  static const boardLeft = 37.0, boardWidth = 406.0;
  static const basketWidth = boardWidth / 6;
  static int bucketAt(double x) =>
      ((x - boardLeft) / basketWidth).floor().clamp(0, 5);
  static double bucketCenter(int id) => boardLeft + (id + .5) * basketWidth;
  List<Peg> pegs = [];
  List<Offset> trail = [];
  bool active = false;
  int shotsOnBoard = 0, combo = 0, earned = 0, lastBucket = 0;
  int? enteringBucket;
  double x = 240,
      y = 248,
      vx = 0,
      vy = 0,
      age = 0,
      accumulator = 0,
      trailTimer = 0;
  void Function(int)? onHit;
  void Function(int, int)? onSettled;
  Pinball() {
    resetBoard();
  }
  void resetBoard() {
    pegs = [
      for (var row = 0; row < 7; row++)
        for (var col = 0; col < 6; col++)
          Peg(67 + col * 66 + (row % 2) * 14, 305 + row * 42, (row + col) % 3),
    ];
    shotsOnBoard = 0;
  }

  void launch(Offset direction) {
    if (active) return;
    if (pegs.where((p) => p.life > 0).length < 9 || shotsOnBoard >= 5)
      resetBoard();
    shotsOnBoard++;
    final dy = math.max(.2, direction.dy),
        len = math.sqrt(direction.dx * direction.dx + dy * dy);
    x = 240;
    y = 248;
    vx = direction.dx / len * 410;
    vy = dy / len * 410;
    age = 0;
    accumulator = 0;
    trailTimer = 0;
    combo = 0;
    earned = 0;
    enteringBucket = null;
    trail = [];
    active = true;
  }

  void tick(double dt) {
    for (final p in pegs) {
      p.flash = math.max(0, p.flash - dt * 3);
    }
    if (!active) return;
    accumulator += math.min(dt, .1);
    while (accumulator >= 1 / 120 && active) {
      _step(1 / 120);
      accumulator -= 1 / 120;
    }
  }

  void _step(double dt) {
    age += dt;
    trailTimer += dt;
    if (trailTimer > .025) {
      trail.add(Offset(x, y));
      if (trail.length > 15) trail.removeAt(0);
      trailTimer = 0;
    }
    vy += 475 * dt;
    final speed = math.sqrt(vx * vx + vy * vy);
    if (speed > 690) {
      vx *= 690 / speed;
      vy *= 690 / speed;
    }
    x += vx * dt;
    y += vy * dt;
    if (x < 45) {
      x = 45;
      vx = vx.abs() * .88;
    }
    if (x > 435) {
      x = 435;
      vx = -vx.abs() * .88;
    }
    if (y < 236) {
      y = 236;
      vy = vy.abs();
    }
    for (var i = 0; i < pegs.length; i++) {
      final p = pegs[i];
      p.cooldown -= dt;
      if (p.life <= 0 || enteringBucket != null) continue;
      var dx = x - p.x, dy = y - p.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance >= 21) continue;
      if (distance < .001) {
        dx = 0;
        dy = 1;
      } else {
        dx /= distance;
        dy /= distance;
      }
      x = p.x + dx * 21.2;
      y = p.y + dy * 21.2;
      final dot = vx * dx + vy * dy;
      if (dot < 0) {
        vx = (vx - 2 * dot * dx) * .87;
        vy = (vy - 2 * dot * dy) * .87;
      }
      vx += (i.isEven ? 1 : -1) * 24;
      if (p.cooldown > 0) continue;
      p.cooldown = .13;
      p.life--;
      p.flash = 1;
      combo++;
      final reward = p.life == 0 ? p.score : 0;
      earned += reward;
      onHit?.call(reward);
    }
    // After a long rally, let gravity finish the drop instead of teleporting.
    if (age >= 8) vy = math.max(100, vy);
    if (y >= 603) enteringBucket ??= bucketAt(x);
    if (enteringBucket case final int bucket) {
      final left = boardLeft + bucket * basketWidth + 10;
      final right = boardLeft + (bucket + 1) * basketWidth - 10;
      if (x < left) {
        x = left;
        vx = vx.abs() * .55;
      }
      if (x > right) {
        x = right;
        vx = -vx.abs() * .55;
      }
    }
    if (y >= 638) {
      lastBucket = enteringBucket!;
      const bonus = 8, dew = 1;
      earned += bonus;
      active = false;
      trail.clear();
      onSettled?.call(bonus, dew);
    }
  }
}

class BattleLayout {
  static const lanes = 4;
  static const friendX = 86.0, shotX = 112.0, spawnX = 415.0, breachX = 118.0;
  static const field = Rect.fromLTWH(39, 270, 402, 383);
  static double laneY(int lane) => 316 + lane * 93.0;
  static String laneName(int lane) => '第 ${lane + 1} 路';
  static Rect ultimateButton(int lane) =>
      Rect.fromLTWH(24 + lane * 110.0, 684, 102, 59);
}

class Enemy {
  Enemy(this.id, this.lane, this.hp, this.speed, this.element, this.boss)
    : maxHp = hp;
  final int id, lane, element;
  final double maxHp, speed;
  final bool boss;
  double hp, x = BattleLayout.spawnX, slow = 0, flash = 0;
  double get y => BattleLayout.laneY(lane);
}

class Shot {
  Shot(this.lane, this.targetId, this.friend, this.damage)
    : x = BattleLayout.shotX,
      y = BattleLayout.laneY(lane);
  final int lane, targetId, friend;
  final double damage;
  double x, y;
}

class Combat {
  LevelDefinition? _level;
  bool active = false;
  int stage = 1, wave = 1, kills = 0, spawned = 0, nextId = 0;
  double health = 100, maxHealth = 100, spawnTimer = 0, waveTimer = 0;
  List<int> team = [0, 1, 2, -1], attacks = List.filled(4, 0);
  List<double> damages = [],
      intervals = [],
      timers = [],
      attackFlash = List.filled(4, 0);
  List<Enemy> enemies = [];
  List<Shot> shots = [];
  List<bool> ultimateUsed = List.filled(BattleLayout.lanes, false);
  int? _pendingUltimate;
  void Function(bool)? onFinished;
  void Function()? onAttack;
  void Function(Offset position, int friend)? onImpact;
  void begin(GameState state) {
    stage = state.stage;
    _level = LevelBook.current[stage];
    maxHealth = _level?.health ?? 100;
    team = List.of(state.team);
    attacks = List.filled(BattleLayout.lanes, 0);
    attackFlash = List.filled(BattleLayout.lanes, 0);
    ultimateUsed = List.filled(BattleLayout.lanes, false);
    _pendingUltimate = null;
    damages = [];
    intervals = [];
    timers = [];
    for (var i = 0; i < BattleLayout.lanes; i++) {
      final id = team[i];
      damages.add(id < 0 ? 0 : state.damage(id));
      intervals.add(id < 0 ? 1 : friends[id].interval);
      timers.add(.2 * i);
      if (id >= 0 && friends[id].skill == FriendSkill.guard) maxHealth += 25;
    }
    health = maxHealth;
    wave = 1;
    kills = 0;
    spawned = 0;
    nextId = 0;
    spawnTimer = .6;
    waveTimer = 0;
    enemies = [];
    shots = [];
    active = true;
  }

  bool canCastUltimate(int lane) =>
      active &&
      _pendingUltimate == null &&
      lane >= 0 &&
      lane < BattleLayout.lanes &&
      team[lane] >= 0 &&
      !ultimateUsed[lane] &&
      enemies.any((enemy) => enemy.hp > 0);

  bool reserveUltimate(int lane) {
    if (!canCastUltimate(lane)) return false;
    ultimateUsed[lane] = true;
    _pendingUltimate = lane;
    return true;
  }

  /// Resolve at the cinematic impact frame, never at button press. Kills feed
  /// the regular wave/reward flow; a reserved spell cannot resolve twice.
  bool resolveUltimate(int lane) {
    if (!active || _pendingUltimate != lane) return false;
    _pendingUltimate = null;
    final id = team[lane], kind = friends[id].ultimateKind;
    final spell = UltimateSpell.of(kind);
    if (kind == UltimateKind.earth) {
      health = math.min(maxHealth, health + maxHealth * .25);
    }
    for (final enemy in enemies.where((enemy) => enemy.hp > 0)) {
      enemy.hp -=
          damages[lane] * (enemy.lane == lane ? spell.damage : spell.splash);
      enemy.flash = 1;
      if (kind == UltimateKind.water) enemy.slow = math.max(enemy.slow, 4);
      if (kind == UltimateKind.nature || kind == UltimateKind.lightning) {
        enemy.x = math.min(BattleLayout.spawnX, enemy.x + 28);
      }
      onImpact?.call(Offset(enemy.x, enemy.y), id);
    }
    final dead = enemies.where((enemy) => enemy.hp <= 0).toList();
    kills += dead.length;
    enemies.removeWhere((enemy) => enemy.hp <= 0);
    // Discard projectiles whose target was removed, avoiding phantom impacts.
    final living = enemies.map((enemy) => enemy.id).toSet();
    shots.removeWhere((shot) => !living.contains(shot.targetId));
    return true;
  }

  void tick(double dt) {
    if (!active) return;
    dt = math.min(dt, .05);
    final definition = _level?.waves[wave - 1];
    final quota = definition?.count ?? 5 + stage ~/ 3 + wave;
    spawnTimer -= dt;
    if (spawned < quota && spawnTimer <= 0) {
      final boss = spawned == quota - 1 && (definition?.bossLast ?? wave == 3),
          hp =
              (definition?.health ?? (18 + stage * 8 + wave * 4)) *
              (boss ? 3.4 : 1.0);
      enemies.add(
        Enemy(
          nextId++,
          (spawned + wave - 1) % BattleLayout.lanes,
          hp,
          (definition?.speed ?? (23 + stage * 1.7 + wave * 1.3)) *
              (boss ? .7 : 1),
          (spawned + stage + wave) % 3,
          boss,
        ),
      );
      spawned++;
      spawnTimer = definition?.interval ?? math.max(.43, .91 - stage * .035);
    }
    for (final e in enemies) {
      e.slow = math.max(0, e.slow - dt);
      e.flash = math.max(0, e.flash - dt * 5);
      e.x -= e.speed * dt * (e.slow > 0 ? .65 : 1);
    }
    for (final e in List<Enemy>.of(enemies)) {
      if (e.x > BattleLayout.breachX) continue;
      health = math.max(0, health - (e.boss ? 34 : 12));
      enemies.remove(e);
      if (health <= 0) {
        finish(false);
        return;
      }
    }
    for (var lane = 0; lane < BattleLayout.lanes; lane++) {
      attackFlash[lane] = math.max(0, attackFlash[lane] - dt * 4);
      timers[lane] -= dt;
      final targets = enemies.where((e) => e.lane == lane).toList()
        ..sort((a, b) => a.x.compareTo(b.x));
      if (team[lane] < 0 || targets.isEmpty || timers[lane] > 0) continue;
      final id = team[lane];
      attacks[lane]++;
      var damage = damages[lane];
      if (friends[id].skill == FriendSkill.heavy && attacks[lane] % 3 == 0)
        damage *= 2;
      shots.add(Shot(lane, targets.first.id, id, damage));
      onAttack?.call();
      attackFlash[lane] = 1;
      timers[lane] = intervals[lane];
    }
    for (final shot in List<Shot>.of(shots)) {
      final targets = enemies.where((e) => e.id == shot.targetId);
      if (targets.isEmpty) {
        shots.remove(shot);
        continue;
      }
      final target = targets.first,
          tx = target.x,
          ty = target.y,
          dx = tx - shot.x,
          dy = ty - shot.y,
          len = math.sqrt(dx * dx + dy * dy),
          travel = math.min(len, 600 * dt);
      if (len > 0) {
        shot.x += dx / len * travel;
        shot.y += dy / len * travel;
      }
      if ((Offset(shot.x, shot.y) - Offset(tx, ty)).distance > 9) continue;
      final affected = <Enemy>[target];
      if (friends[shot.friend].skill == FriendSkill.splash) {
        affected.addAll(
          enemies.where(
            (e) =>
                e != target &&
                (e.x - target.x).abs() < 50 &&
                e.lane == target.lane,
          ),
        );
      }
      if (friends[shot.friend].skill == FriendSkill.chain) {
        final others = enemies.where(
          (e) =>
              e != target &&
              e.lane != target.lane &&
              (e.x - target.x).abs() < 100,
        );
        if (others.isNotEmpty) affected.add(others.first);
      }
      for (final e in affected) {
        final element = friends[shot.friend].element;
        final mult = element != null && e.element != element
            ? ((element + 1) % 3 == e.element ? 1.35 : .8)
            : 1.0;
        e.hp -= shot.damage * mult * (e == target ? 1 : .55);
        e.flash = 1;
        onImpact?.call(Offset(e.x, e.y), shot.friend);
        if (friends[shot.friend].skill == FriendSkill.slow) e.slow = 1.8;
      }
      shots.remove(shot);
    }
    final dead = enemies.where((e) => e.hp <= 0).toList();
    kills += dead.length;
    enemies.removeWhere((e) => e.hp <= 0);
    if (spawned == quota && enemies.isEmpty) {
      waveTimer += dt;
      if (waveTimer > 1.3) {
        if (wave == 3) {
          finish(true);
          return;
        }
        wave++;
        spawned = 0;
        spawnTimer = .5;
        waveTimer = 0;
      }
    }
  }

  void finish(bool won) {
    active = false;
    _pendingUltimate = null;
    shots.clear();
    onFinished?.call(won);
  }
}
