/// Fixed data schema: remote content can describe existing four-lane battles.
/// It cannot introduce executable behavior, new abilities or enemy types.
class WaveDefinition {
  const WaveDefinition(
    this.count,
    this.health,
    this.speed,
    this.interval,
    this.bossLast,
  );
  final int count;
  final double health, speed, interval;
  final bool bossLast;
}

class LevelDefinition {
  const LevelDefinition(this.id, this.health, this.waves);
  final int id;
  final double health;
  final List<WaveDefinition> waves;
}

class LevelBook {
  static Map<int, LevelDefinition> current = {};

  static Map<int, LevelDefinition> parse(
    Map<String, dynamic> data,
    String version,
  ) {
    if (data['schemaVersion'] != 1 || data['contentVersion'] != version) {
      throw const FormatException('Unsupported level schema');
    }
    final entries = data['levels'];
    if (entries is! List || entries.isEmpty || entries.length > 10) {
      throw const FormatException('Invalid level count');
    }
    final result = <int, LevelDefinition>{};
    for (final entry in entries) {
      final level = Map<String, dynamic>.from(entry as Map);
      final id = boundedInt(level['id'], 1, 10);
      if (result.containsKey(id) || level['lanes'] != 4) {
        throw const FormatException('Invalid level identity or lanes');
      }
      final waves = level['waves'];
      if (waves is! List || waves.length != 3) {
        throw const FormatException('Exactly three waves required');
      }
      result[id] =
          LevelDefinition(id, boundedNumber(level['baseHealth'], 1, 10000), [
            for (final raw in waves)
              WaveDefinition(
                boundedInt(raw['count'], 1, 100),
                boundedNumber(raw['enemyHealth'], 1, 100000),
                boundedNumber(raw['enemySpeed'], 1, 300),
                boundedNumber(raw['spawnIntervalSeconds'], .2, 10),
                strictBool(raw['bossLast']),
              ),
          ]);
    }
    return result;
  }
}

int boundedInt(dynamic value, int minimum, int maximum) {
  if (value is! int || value < minimum || value > maximum) {
    throw const FormatException('Integer out of range');
  }
  return value;
}

double boundedNumber(dynamic value, double minimum, double maximum) {
  if (value is! num || !value.isFinite || value < minimum || value > maximum) {
    throw const FormatException('Number out of range');
  }
  return value.toDouble();
}

bool strictBool(dynamic value) {
  if (value is! bool) throw const FormatException('Boolean required');
  return value;
}
