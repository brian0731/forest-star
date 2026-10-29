import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const rate = 22050;

class Note {
  const Note(this.start, this.duration, this.frequency, this.volume);
  final double start, duration, frequency, volume;
}

void writeSound(String name, double duration, List<Note> notes) {
  final count = (duration * rate).round();
  final bytes = ByteData(44 + count * 2);
  void str(int pos, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(pos + i, value.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  bytes.setUint32(4, 36 + count * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  str(36, 'data');
  bytes.setUint32(40, count * 2, Endian.little);
  for (var i = 0; i < count; i++) {
    final t = i / rate;
    var sample = 0.0;
    for (final note in notes) {
      final local = t - note.start;
      if (local < 0 || local >= note.duration) continue;
      final envelope =
          math.min(1.0, local / .018) * math.pow(1 - local / note.duration, 2);
      final phase = 2 * math.pi * note.frequency * local;
      sample +=
          note.volume *
          envelope *
          (math.sin(phase) +
              .25 * math.sin(phase * 2) +
              .12 * math.sin(phase * 3));
    }
    bytes.setInt16(
      44 + i * 2,
      (sample.clamp(-.95, .95) * 32767).round(),
      Endian.little,
    );
  }
  File('assets/audio/$name.wav').writeAsBytesSync(bytes.buffer.asUint8List());
}

void main() {
  Directory('assets/audio').createSync(recursive: true);
  const melody = [
    523.25,
    659.25,
    783.99,
    659.25,
    587.33,
    698.46,
    880.0,
    698.46,
    659.25,
    783.99,
    1046.5,
    783.99,
    587.33,
    659.25,
    523.25,
    0.0,
  ];
  final notes = <Note>[];
  for (var i = 0; i < melody.length; i++) {
    if (melody[i] > 0) notes.add(Note(i * .5, .65, melody[i], .16));
    if (i % 4 == 0)
      notes.add(
        Note(i * .5, 1.5, [130.81, 146.83, 164.81, 130.81][i ~/ 4], .13),
      );
  }
  writeSound('forest_loop', 8, notes);
  writeSound('select', .18, [
    const Note(0, .17, 784, .32),
    const Note(.055, .12, 1046.5, .2),
  ]);
  writeSound('launch', .35, [
    const Note(0, .15, 440, .30),
    const Note(.1, .2, 659, .25),
  ]);
  writeSound('bounce', .14, [const Note(0, .13, 1046, .27)]);
  writeSound('reward', .65, [
    const Note(0, .3, 659, .28),
    const Note(.12, .3, 784, .25),
    const Note(.24, .4, 1046, .24),
  ]);
  writeSound('battle', .5, [
    const Note(0, .24, 392, .27),
    const Note(.14, .3, 523, .26),
  ]);
  writeSound('hit', .13, [
    const Note(0, .12, 330, .2),
    const Note(.02, .09, 659, .13),
  ]);
  writeSound('win', 1.0, [
    const Note(0, .35, 523, .27),
    const Note(.18, .35, 659, .26),
    const Note(.36, .35, 784, .25),
    const Note(.55, .43, 1046, .25),
  ]);
  writeSound('fail', .6, [
    const Note(0, .35, 440, .23),
    const Note(.2, .4, 330, .22),
  ]);
}
