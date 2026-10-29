"""Compose an original 32-bar 6/8 camp theme as SMF MIDI and a WAV preview.

Both outputs use the same note events. No downloaded music, samples or soundfont.
MIDI uses General MIDI instruments; the preview uses a small additive synthesizer.
"""
from pathlib import Path
import json
import math
import struct
import wave
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'output/audio/camp-v1'
ASSETS = ROOT / 'assets/audio'
BPM, PPQ, RATE = 84, 480, 22050
SECONDS_PER_BEAT = 60 / BPM
BARS, BEATS_PER_BAR = 32, 3
BEATS = BARS * BEATS_PER_BAR
DURATION = BEATS * SECONDS_PER_BEAT

# D major, alternating open major-seventh/suspended chords and a gentle cadence.
CHORDS = [
    [50, 57, 62, 66], [47, 54, 59, 62], [43, 50, 57, 59], [45, 52, 57, 61],
    [50, 57, 62, 66], [54, 57, 61, 64], [43, 50, 55, 59], [45, 52, 57, 62],
    [47, 54, 59, 62], [54, 57, 61, 64], [43, 50, 57, 59], [45, 52, 57, 61],
    [43, 50, 55, 59], [45, 52, 57, 62], [45, 52, 57, 61], [50, 57, 62, 66],
]
# Each bar contains six eighth-note positions. Repeated pitches become held notes.
MELODY = [
    [74, 78, 81, 81, 78, 76], [74, 73, 71, 71, 74, 78],
    [79, 78, 74, 74, 71, 74], [76, 78, 76, 73, 73, None],
    [74, 78, 81, 86, 86, 81], [80, 81, 78, 76, 76, 73],
    [74, 79, 78, 74, 71, 74], [76, 78, 76, 74, 73, None],
    [78, 81, 83, 83, 81, 78], [80, 81, 85, 85, 81, 78],
    [79, 83, 81, 79, 78, 74], [76, 78, 81, 81, 78, 76],
    [79, 78, 74, 71, 74, 78], [76, 78, 81, 83, 81, 78],
    [76, 74, 73, 73, 69, 73], [74, 74, 74, None, None, None],
]
TRACKS = [
    ('Harp - dappled sunlight', 46, 43, .22),
    ('Celesta - firefly melody', 8, 77, .69),
    ('Flute - woodland breeze', 73, 65, .53),
    ('Strings - soft meadow', 48, 45, .47),
]
notes = [[] for _ in TRACKS]

def note(track, start, length, pitch, velocity):
    if pitch is not None:
        notes[track].append((start, min(length, BEATS - start), pitch, velocity))

for bar in range(BARS):
    start = bar * BEATS_PER_BAR
    chord = CHORDS[bar % 16]
    # Lilt in 6/8; sparse low anchors and a flowing, soft arpeggio.
    for step, index in enumerate([0, 1, 2, 3, 2, 1]):
        note(0, start + step * .5, .7, chord[index] + 12,
             42 + (step % 3 == 0) * 8 + bar % 3)
    note(0, start, 1.9, chord[0] - 12, 43)
    for index, pitch in enumerate(chord[1:]):
        note(3, start + .02 * index, 2.85, pitch, 31 + index * 2)
    melody = MELODY[bar % 16]
    position = 0
    while position < 6:
        pitch = melody[position]
        end = position + 1
        while end < 6 and melody[end] == pitch:
            end += 1
        # First half: music-box lead. Second half: flute answers the same theme.
        lead = 1 if bar < 16 else 2
        note(lead, start + position * .5, (end - position) * .5 * .91,
             pitch, 57 + (position == 0) * 5 + bar % 4)
        if bar >= 16 and position in (0, 3):
            note(1, start + position * .5, .65, pitch, 34)
        position = end

def vlq(value):
    value = int(value)
    data = [value & 127]
    while value >> 7:
        value >>= 7
        data.insert(0, (value & 127) | 128)
    return bytes(data)

def meta(kind, payload):
    return bytes([255, kind]) + vlq(len(payload)) + payload

def track_chunk(events):
    events.sort(key=lambda event: (event[0], event[1]))
    result, previous = bytearray(), 0
    for tick, _, event in events:
        result += vlq(tick - previous) + event
        previous = tick
    end = int(BEATS * PPQ)
    result += vlq(end - previous) + meta(47, b'')
    return b'MTrk' + struct.pack('>I', len(result)) + result

OUTPUT.mkdir(parents=True, exist_ok=True)
ASSETS.mkdir(parents=True, exist_ok=True)
conductor = [(0, 0, meta(3, b'Our Forest Camp - original theme')),
    (0, 1, meta(81, int(60000000 / BPM).to_bytes(3, 'big'))),
    (0, 2, meta(88, bytes([6, 3, 36, 8]))),
    (0, 3, meta(89, bytes([2, 0]))),
    (0, 4, meta(6, b'LOOP_START')),
    (BEATS * PPQ, 5, meta(6, b'LOOP_END'))]
chunks = [track_chunk(conductor)]
for channel, (name, program, volume, pan) in enumerate(TRACKS):
    events = [(0, 0, meta(3, name.encode())),
        (0, 1, bytes([192 + channel, program])),
        (0, 2, bytes([176 + channel, 7, volume])),
        (0, 3, bytes([176 + channel, 10, round(pan * 127)])),
        (0, 4, bytes([176 + channel, 91, 38]))]
    for start, length, pitch, velocity in notes[channel]:
        events.append((round(start * PPQ), 10, bytes([144 + channel, pitch, velocity])))
        events.append((round((start + length) * PPQ), 9, bytes([128 + channel, pitch, 0])))
    chunks.append(track_chunk(events))
midi = b'MThd' + struct.pack('>IHHH', 6, 1, len(chunks), PPQ) + b''.join(chunks)
(ASSETS / 'forest_camp.mid').write_bytes(midi)
(OUTPUT / 'our-forest-camp.mid').write_bytes(midi)

# A loop-safe, stereo preview of precisely the same composition.
count = round(DURATION * RATE)
mix = np.zeros((count, 2), dtype=np.float64)
for track, (_, _, _, pan) in enumerate(TRACKS):
    for start, length, pitch, velocity in notes[track]:
        sustain = length * SECONDS_PER_BEAT
        release = [.8, 1.2, .18, .55][track]
        t = np.arange(round((sustain + release) * RATE)) / RATE
        frequency = 440 * 2 ** ((pitch - 69) / 12)
        phase = 2 * math.pi * frequency * t
        if track == 0:
            wave_data = np.sin(phase) + .25 * np.sin(2 * phase) + .10 * np.sin(3 * phase)
            envelope = (1 - np.exp(-t / .006)) * np.exp(-t / .48)
            gain = .10
        elif track == 1:
            wave_data = (np.sin(phase) * np.exp(-t / 1.0) +
                .30 * np.sin(2 * phase) * np.exp(-t / .35) +
                .13 * np.sin(3.99 * phase) * np.exp(-t / .18))
            envelope = (1 - np.exp(-t / .004)) * np.exp(-t / .85)
            gain = .16
        elif track == 2:
            phase += .022 * np.sin(2 * math.pi * 4.8 * t)
            wave_data = np.sin(phase) + .12 * np.sin(2 * phase) + .035 * np.sin(3 * phase)
            envelope = np.minimum(t / .055, 1) * np.minimum(np.maximum(0, sustain + release - t) / release, 1)
            gain = .105
        else:
            wave_data = (np.sin(phase) + .11 * np.sin(2 * phase + .1) +
                .05 * np.sin(3 * phase) + .025 * np.sin(phase * 1.002))
            envelope = np.minimum(t / .3, 1) * np.minimum(np.maximum(0, sustain + release - t) / release, 1)
            gain = .044
        audio = wave_data * envelope * gain * (velocity / 64)
        # Wrap note tails across the loop seam; no chopped reverb or note decay.
        indices = (round(start * SECONDS_PER_BEAT * RATE) + np.arange(len(t))) % count
        mix[indices, 0] += audio * math.cos(pan * math.pi / 2)
        mix[indices, 1] += audio * math.sin(pan * math.pi / 2)
dry = mix.copy()
for delay, level in [(.101, .10), (.173, .08), (.283, .06), (.419, .04)]:
    mix += np.roll(dry[:, ::-1], round(delay * RATE), axis=0) * level
mix *= .76 / max(np.max(np.abs(mix)), .001)
# Enforce a continuous, near-zero seam without touching the musical phrase.
fade = np.minimum(np.arange(count) / (RATE * .012), 1)
fade *= np.minimum(np.arange(count)[::-1] / (RATE * .012), 1)
mix *= fade[:, None]
pcm = np.round(mix * 32767).astype('<i2')
def write_wav(path, samples):
    with wave.open(str(path), 'wb') as file:
        file.setnchannels(2)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(samples.tobytes())
write_wav(ASSETS / 'forest_camp.wav', pcm)
write_wav(OUTPUT / 'our-forest-camp.wav', pcm)
preview = pcm[:RATE * 22].copy()
preview[-RATE * 2:] = (preview[-RATE * 2:] * np.linspace(1, 0, RATE * 2)[:, None]).astype('<i2')
write_wav(OUTPUT / 'camp-preview.wav', preview)
report = dict(title='我們的森林營地 · 螢光小夜曲', bpm=BPM, meter='6/8', key='D major',
    bars=BARS, seconds=DURATION, midi_type=1, tracks=len(chunks),
    notes=sum(map(len, notes)), midi_bytes=len(midi), sample_rate=RATE,
    peak=float(np.max(np.abs(mix))), rms=float(np.sqrt(np.mean(mix ** 2))),
    clipped_samples=int(np.count_nonzero(np.abs(mix) >= 1)),
    instruments=[track[0] for track in TRACKS])
(OUTPUT / 'composition.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))
