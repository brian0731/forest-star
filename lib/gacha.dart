import 'dart:convert';
import 'dart:math';
import 'game.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DrawKind { pet, sugar, marbles }

class DrawReward {
  const DrawReward(this.kind, this.amount, {this.pet});
  final DrawKind kind;
  final int amount;
  final int? pet;
  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'amount': amount,
    if (pet != null) 'pet': pet,
  };
  factory DrawReward.fromJson(Map<String, dynamic> data) {
    final kind = DrawKind.values.byName(data['kind'] as String);
    final amount = data['amount'];
    final pet = data['pet'];
    if (amount is! int ||
        !switch (kind) {
          DrawKind.pet =>
            amount == 1 && pet is int && pet >= 6 && pet < friends.length,
          DrawKind.sugar => const [20, 40, 80].contains(amount),
          DrawKind.marbles => const [3, 8, 15].contains(amount),
        }) {
      throw const FormatException('Invalid draw reward');
    }
    return DrawReward(kind, amount, pet: pet as int?);
  }
}

/// Weights out of 1000. Each of the 20 new pets has an unconditional 1.5% chance.
class DrawPool {
  static const freePerDay = 5;
  static const duplicateGrowth = 40;
  static const productId = 'forest_star_draws_10';
  static const productDraws = 10;
  static DrawReward roll(Random random) => at(random.nextInt(1000));
  static DrawReward at(int ticket) {
    if (ticket < 0 || ticket >= 1000) throw RangeError.range(ticket, 0, 999);
    if (ticket < 300) return DrawReward(DrawKind.pet, 1, pet: 6 + ticket ~/ 15);
    if (ticket < 550) return const DrawReward(DrawKind.sugar, 20);
    if (ticket < 700) return const DrawReward(DrawKind.sugar, 40);
    if (ticket < 750) return const DrawReward(DrawKind.sugar, 80);
    if (ticket < 900) return const DrawReward(DrawKind.marbles, 3);
    if (ticket < 980) return const DrawReward(DrawKind.marbles, 8);
    return const DrawReward(DrawKind.marbles, 15);
  }
}

class DrawResult {
  const DrawResult(this.reward, this.title, this.detail, {this.joined = false});
  final DrawReward reward;
  final String title, detail;
  final bool joined;
}

/// UTC+8 calendar day; moving the device clock backwards cannot reset the quota.
int drawDay(DateTime now) {
  final date = now.toUtc().add(const Duration(hours: 8));
  return date.year * 10000 + date.month * 100 + date.day;
}

int freeDrawsLeft(GameState state, DateTime now) => drawDay(now) > state.drawDay
    ? DrawPool.freePerDay
    : (DrawPool.freePerDay - state.freeDrawsUsed).clamp(0, DrawPool.freePerDay);

DrawResult applyDrawReward(GameState state, DrawReward reward) {
  if (reward.kind == DrawKind.pet) {
    final pet = reward.pet!;
    if (!state.unlocked[pet]) {
      state.unlocked[pet] = true;
      return DrawResult(
        reward,
        friends[pet].name,
        '新夥伴加入！可到夥伴小屋升級、進化及安排守衛。',
        joined: true,
      );
    }
    final growth = state.awardGrowth(pet, DrawPool.duplicateGrowth);
    return DrawResult(
      reward,
      friends[pet].name,
      '重複夥伴轉為 ${DrawPool.duplicateGrowth} 成長分${growth.evolved
          ? '，進化成功！'
          : growth.level > growth.oldLevel
          ? '，升到 Lv.${growth.level}！'
          : '。'}',
    );
  }
  if (reward.kind == DrawKind.sugar) {
    state.sugar = min(999999, state.sugar + reward.amount);
    return DrawResult(reward, '星糖 +${reward.amount}', '星糖可用來提升夥伴等級。');
  }
  final overflow = max(0, state.marbles + reward.amount - 999);
  state.marbles = min(999, state.marbles + reward.amount);
  state.sugar = min(999999, state.sugar + overflow);
  return DrawResult(
    reward,
    '彈珠 +${reward.amount}',
    overflow > 0 ? '超出 999 顆上限的 $overflow 顆已轉為等量星糖。' : '帶著彈珠到彈珠屋，陪夥伴一起成長。',
  );
}

/// Mutate a copy, persist the quota and reward in one save, then publish it.
/// A failed write never spends a free draw or applies a reward in memory.
Future<(GameState, DrawResult)?> performFreeDraw(
  GameState state,
  SharedPreferences prefs,
  Random random,
  DateTime now,
) async {
  if (freeDrawsLeft(state, now) == 0) return null;
  final next = GameState.fromJson(state.toJson());
  final day = drawDay(now);
  if (day > next.drawDay) {
    next.drawDay = day;
    next.freeDrawsUsed = 0;
  }
  next.freeDrawsUsed++;
  final result = applyDrawReward(next, DrawPool.roll(random));
  if (!await prefs.setString('forest_star_v1', jsonEncode(next.toJson()))) {
    throw StateError('Save failed');
  }
  return (next, result);
}

Future<(GameState, DrawResult)?> applyPaidDraw(
  GameState state,
  SharedPreferences prefs,
  String wallet,
  Map<String, dynamic> entry,
) async {
  final sequence = entry['sequence'];
  if (sequence is! int || sequence < 1) {
    throw const FormatException('Invalid draw sequence');
  }
  final applied = state.paidDrawSequences[wallet] ?? 0;
  if (sequence <= applied) return null;
  if (sequence != applied + 1) {
    throw const FormatException('Missing draw result');
  }
  final reward = DrawReward.fromJson(
    Map<String, dynamic>.from(entry['reward'] as Map),
  );
  final next = GameState.fromJson(state.toJson());
  final result = applyDrawReward(next, reward);
  next.paidDrawSequences[wallet] = sequence;
  if (!await prefs.setString('forest_star_v1', jsonEncode(next.toJson()))) {
    throw StateError('Save failed');
  }
  return (next, result);
}
