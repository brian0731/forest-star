import 'dart:ui';

/// Shared paint and touch bounds for the companion room's album controls.
abstract final class CompanionLayout {
  static const pageSize = 6;
  static const gallery = Rect.fromLTWH(300, 148, 144, 44);
  static const previous = Rect.fromLTWH(24, 484, 96, 44);
  static const next = Rect.fromLTWH(360, 484, 96, 44);
  static int pageCount(int count) => (count / pageSize).ceil();
  static Rect page(int index) => Rect.fromLTWH(128 + index * 45.0, 484, 40, 44);
  static Rect card(int slot) =>
      Rect.fromLTWH(24 + slot % 3 * 149.0, 216 + slot ~/ 3 * 136.0, 132, 128);
}
