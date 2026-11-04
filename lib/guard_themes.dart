/// Visual themes share one four-lane geometry; combat rules remain in Combat.
enum GuardWeather {
  rain,
  fireflies,
  breeze,
  leaves,
  snow,
  crystals,
  dust,
  embers,
  clouds,
  stars,
}

class GuardTheme {
  const GuardTheme(this.stage, this.name, this.weather);
  final int stage;
  final String name;
  final GuardWeather weather;
  String get fieldKey => stage == 1 ? 'field' : 'field-level$stage';

  static const all = [
    GuardTheme(1, '苔光林地', GuardWeather.rain),
    GuardTheme(2, '螢光秘林', GuardWeather.fireflies),
    GuardTheme(3, '竹溪晴谷', GuardWeather.breeze),
    GuardTheme(4, '楓葉山徑', GuardWeather.leaves),
    GuardTheme(5, '霜雪松林', GuardWeather.snow),
    GuardTheme(6, '水晶幽谷', GuardWeather.crystals),
    GuardTheme(7, '金沙綠洲', GuardWeather.dust),
    GuardTheme(8, '熔光花園', GuardWeather.embers),
    GuardTheme(9, '雲海浮島', GuardWeather.clouds),
    GuardTheme(10, '星穹聖域', GuardWeather.stars),
  ];

  static GuardTheme forStage(int stage) =>
      all[(stage - 1).clamp(0, all.length - 1)];
}
