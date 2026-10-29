import 'dart:math' as math;
import 'dart:ui';

class Friend {
  const Friend(
    this.name,
    this.role,
    this.description,
    this.color,
    this.damage,
    this.interval,
  );
  final String name, role, description;
  final Color color;
  final double damage, interval;
}

const friends = <Friend>[
  Friend('芽耳兔', '連射', '輕快的森林射手，攻擊速度最快。', Color(0xff91c99d), 8, .78),
  Friend('泡泡獺', '緩速', '水泡命中後，使敵人減速 35%。', Color(0xff87c8df), 11, 1.05),
  Friend('燈尾狐', '範圍', '火花同時傷害附近的敵人。', Color(0xfff2ad80), 14, 1.35),
  Friend('苔石龜', '守護', '上陣時，營地耐久額外增加 25。', Color(0xffb4be91), 18, 1.5),
  Friend('星絨雀', '連鎖', '電光會跳向另一條路的敵人。', Color(0xfff0d780), 10, 1),
  Friend('月眠貓', '重擊', '每三次攻擊觸發一次雙倍傷害。', Color(0xffb8abd9), 17, 1.4),
];

class GameState {
  int sugar = 60, dew = 3, marbles = 20, stage = 1, clearedStage = 0;
  int shots = 0, upgrades = 0, victories = 0;
  bool sound = true;
  List<int> levels = [1, 1, 1, 1, 1, 1],
      evolutions = [0, 0, 0, 0, 0, 0],
      team = [0, 1, 2, -1];
  List<bool> unlocked = [true, true, true, false, false, false];
  List<int> growth = List.filled(6, 0);

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
    if (unlocked[id] || sugar < 80) return false;
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
  };
  static GameState fromJson(Map<String, dynamic> json) {
    final s = GameState();
    int value(String key, int fallback, int min, int max) => json[key] is num
        ? (json[key] as num).toInt().clamp(min, max)
        : fallback;
    List<int> ints(String key, List<int> fallback, int min, int max) {
      final raw = json[key];
      if (raw is! List ||
          raw.length != fallback.length ||
          raw.any((e) => e is! num))
        return fallback;
      return raw.map((e) => (e as num).toInt().clamp(min, max)).toList();
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
    final unlocked = json['unlocked'];
    if (unlocked is List &&
        unlocked.length == 6 &&
        unlocked.every((e) => e is bool))
      s.unlocked = unlocked.cast<bool>().toList();
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
            6,
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
  void Function(bool)? onFinished;
  void Function()? onAttack;
  void Function(Offset position, int friend)? onImpact;
  void begin(GameState state) {
    stage = state.stage;
    maxHealth = 100;
    team = List.of(state.team);
    attacks = List.filled(BattleLayout.lanes, 0);
    attackFlash = List.filled(BattleLayout.lanes, 0);
    damages = [];
    intervals = [];
    timers = [];
    for (var i = 0; i < BattleLayout.lanes; i++) {
      final id = team[i];
      damages.add(id < 0 ? 0 : state.damage(id));
      intervals.add(id < 0 ? 1 : friends[id].interval);
      timers.add(.2 * i);
      if (id == 3) maxHealth += 25;
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

  void tick(double dt) {
    if (!active) return;
    dt = math.min(dt, .05);
    final quota = 5 + stage ~/ 3 + wave;
    spawnTimer -= dt;
    if (spawned < quota && spawnTimer <= 0) {
      final boss = spawned == quota - 1 && wave == 3,
          hp = (18 + stage * 8 + wave * 4) * (boss ? 3.4 : 1.0);
      enemies.add(
        Enemy(
          nextId++,
          (spawned + wave - 1) % BattleLayout.lanes,
          hp,
          (23 + stage * 1.7 + wave * 1.3) * (boss ? .7 : 1),
          (spawned + stage + wave) % 3,
          boss,
        ),
      );
      spawned++;
      spawnTimer = math.max(.43, .91 - stage * .035);
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
      if (id == 5 && attacks[lane] % 3 == 0) damage *= 2;
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
      if (shot.friend == 2) {
        affected.addAll(
          enemies.where(
            (e) =>
                e != target &&
                (e.x - target.x).abs() < 50 &&
                e.lane == target.lane,
          ),
        );
      }
      if (shot.friend == 4) {
        final others = enemies.where(
          (e) =>
              e != target &&
              e.lane != target.lane &&
              (e.x - target.x).abs() < 100,
        );
        if (others.isNotEmpty) affected.add(others.first);
      }
      for (final e in affected) {
        final mult = shot.friend < 3 && e.element != shot.friend
            ? ((shot.friend + 1) % 3 == e.element ? 1.35 : .8)
            : 1.0;
        e.hp -= shot.damage * mult * (e == target ? 1 : .55);
        e.flash = 1;
        onImpact?.call(Offset(e.x, e.y), shot.friend);
        if (shot.friend == 1) e.slow = 1.8;
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
    shots.clear();
    onFinished?.call(won);
  }
}
