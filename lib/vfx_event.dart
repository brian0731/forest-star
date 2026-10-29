import 'dart:ui';

enum VfxKind { spark, fire, water, leaf, stars }

class VfxEvent {
  const VfxEvent(this.kind, this.position, this.tab);
  final VfxKind kind;
  final Offset position;
  final int tab;
}
