"""Original sky-adventure MIDI scores, rendered consistently for Android/iOS.

Python 3.12: pip install tinysoundfont==0.3.7 mido numpy scipy imageio-ffmpeg
No quoted film melody or third-party MIDI is used. SoundFont is a build input,
not bundled in the game; its upstream license is retained alongside the score.
"""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import urllib.request
import wave
import mido
import numpy as np
from scipy import signal
import tinysoundfont
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/audio/sky-v2'
ASSETS = ROOT / 'server/updates/media/forest-sky-guard-v2'
SCORES = ROOT / 'server/updates/source/sky-v2'
RATE = 44100
PPQ = 480
FONT_URL = 'https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/97049183643d5fc5a9322a69c5b09efb667c6c3a/GeneralUser-GS.sf2'
FONT_SHA256 = '9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe'
LICENSE_URL = 'https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/main/documentation/LICENSE.txt'

# Each bar is an original three-beat phrase, expressed as (pitch, beats).
# Rests, long notes, and small melodic steps leave room around the accompaniment.
CAMP_MELODY = [
 [(74,1.5),(73,.5),(69,1)], [(71,2),(66,1)],
 [(67,1),(71,.5),(69,.5),(67,1)], [(66,2),(0,1)],
 [(69,1),(74,1),(76,1)], [(73,1.5),(71,.5),(69,1)],
 [(67,1),(66,1),(64,1)], [(66,2),(0,1)],
 [(66,1),(69,.5),(71,.5),(74,1)], [(73,2),(69,1)],
 [(71,1),(76,1),(74,1)], [(73,2),(0,1)],
 [(71,1.5),(69,.5),(67,1)], [(69,1),(66,2)],
 [(64,1),(67,1),(73,1)], [(74,2.5),(0,.5)],
 [(78,1.5),(76,.5),(74,1)], [(73,1),(69,2)],
 [(76,1),(74,.5),(71,.5),(67,1)], [(71,2),(0,1)],
 [(74,1),(78,1),(76,1)], [(73,1.5),(74,.5),(69,1)],
 [(71,1),(67,1),(64,1)], [(69,2),(0,1)],
 [(74,1),(73,.5),(69,.5),(66,1)], [(71,2),(69,1)],
 [(67,1),(71,1),(76,1)], [(73,2),(0,1)],
 [(71,1),(69,1),(67,1)], [(66,1),(69,2)],
 [(64,1),(73,1),(71,1)], [(74,2),(0,1)],
]
ADVENTURE_MELODY = [
 [(71,1),(74,.5),(76,.5),(79,1)], [(78,1.5),(74,.5),(71,1)],
 [(72,1),(76,1),(79,1)], [(76,2),(0,1)],
 [(74,1),(78,1),(81,1)], [(79,1),(76,2)],
 [(78,1),(74,1),(72,1)], [(71,2),(0,1)],
 [(67,1),(71,1),(74,1)], [(76,1.5),(74,.5),(71,1)],
 [(72,1),(67,1),(76,1)], [(79,2),(0,1)],
 [(78,1),(76,1),(74,1)], [(72,1),(71,2)],
 [(69,1),(72,1),(78,1)], [(79,2),(0,1)],
 [(83,1.5),(81,.5),(79,1)], [(78,1),(74,2)],
 [(76,1),(79,.5),(81,.5),(84,1)], [(83,2),(0,1)],
 [(81,1),(78,1),(74,1)], [(79,1),(76,2)],
 [(78,1),(76,.5),(74,.5),(72,1)], [(71,2),(0,1)],
 [(74,1),(71,1),(67,1)], [(72,1.5),(76,.5),(79,1)],
 [(78,1),(74,1),(71,1)], [(76,2),(0,1)],
 [(74,1),(72,1),(69,1)], [(71,1),(74,2)],
 [(72,1),(78,1),(74,1)], [(79,2),(0,1)],
]

def score(name, melody, bpm, chords):
    midi = mido.MidiFile(type=1, ticks_per_beat=PPQ)
    conductor = mido.MidiTrack()
    conductor.extend([
        mido.MetaMessage('track_name', name=name),
        mido.MetaMessage('text', text='Forest Star original composition, 2026; no film melody or imported MIDI'),
        mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(bpm)),
        mido.MetaMessage('time_signature', numerator=3, denominator=4),
        mido.MetaMessage('key_signature', key='D' if 'camp' in name else 'G'),
        mido.MetaMessage('end_of_track', time=32 * 3 * PPQ),
    ])
    midi.tracks.append(conductor)
    tracks = [[] for _ in range(5)]
    def note(ch, beat, duration, pitch, velocity):
        if pitch == 0:
            return
        tracks[ch].append((round(beat * PPQ), mido.Message('note_on', channel=ch, note=pitch, velocity=velocity)))
        tracks[ch].append((round(min(32 * 3, beat + duration) * PPQ), mido.Message('note_off', channel=ch, note=pitch, velocity=0)))
    for bar, phrase in enumerate(melody):
        beat = bar * 3.0
        chord = chords[bar % len(chords)]
        # Warm low strings and a cello root; phrase-level changes, no percussion.
        for pitch in chord[1:]:
            note(2, beat, 2.92, pitch, 32 + bar % 3)
        note(3, beat, 2.85, chord[0], 38)
        # Harp with a soft six-eighth-note pulse and relaxed last note.
        for step, index in enumerate([0, 1, 2, 3, 2, 1]):
            note(1, beat + step * .5 + (.014 if step % 2 else 0), .72, chord[index] + 12, 44 + [3,-3,0,-4,2,-5][step])
        local = beat
        for index, (pitch, duration) in enumerate(phrase):
            # Breathing gaps keep the sampled flute from sounding mechanical.
            note(0, local, max(.12, duration - .12), pitch, 61 + (bar % 4) * 2 - index * 2)
            local += duration
        if bar % 4 == 3:
            note(4, beat + 1.0, 1.5, chord[2] + 24, 26)
    # GM flute, orchestral harp, warm strings, cello, very quiet celesta.
    programs = [73, 46, 48, 42, 8]
    pans = [72, 40, 59, 65, 88]
    for ch, events in enumerate(tracks):
        track = mido.MidiTrack()
        track.append(mido.MetaMessage('track_name', name=['Breathing flute','Harp','Soft strings','Cello','Celesta'][ch]))
        track.append(mido.Message('program_change', channel=ch, program=programs[ch]))
        track.append(mido.Message('control_change', channel=ch, control=10, value=pans[ch]))
        track.append(mido.Message('control_change', channel=ch, control=91, value=28))
        previous = 0
        for tick, event in sorted(events, key=lambda x: (x[0], x[1].type == 'note_on')):
            track.append(event.copy(time=tick - previous))
            previous = tick
        track.append(mido.MetaMessage('end_of_track', time=32 * 3 * PPQ - previous))
        midi.tracks.append(track)
    midi.save(SCORES / f'{name}.mid')
    return midi

def render(midi, font):
    synth = tinysoundfont.Synth(samplerate=RATE)
    sfid = synth.sfload(str(font))
    seconds = 0.0
    cursor = 0
    chunks = []
    for msg in midi:
        seconds += msg.time
        target = round(seconds * RATE)
        if target > cursor:
            chunks.append(np.frombuffer(synth.generate_simple(target - cursor), dtype=np.float32).copy().reshape(-1, 2))
            cursor = target
        if msg.type == 'program_change':
            synth.program_select(msg.channel, sfid, 0, msg.program)
        elif msg.type == 'control_change':
            synth.control_change(msg.channel, msg.control, msg.value)
        elif msg.type == 'note_on':
            synth.noteon(msg.channel, msg.note, msg.velocity)
        elif msg.type == 'note_off':
            synth.noteoff(msg.channel, msg.note)
    # Wrap releases back into the start, so looping retains the room's decay.
    tail = np.frombuffer(synth.generate_simple(RATE * 3), dtype=np.float32).copy().reshape(-1, 2)
    audio = np.concatenate(chunks)
    audio[:len(tail)] += tail
    # Small, diffuse stereo room. Circular delays preserve loop length.
    wet = audio.copy()
    for i, (delay, amount) in enumerate([(.071,.12),(.113,.10),(.179,.08),(.251,.064),(.359,.045),(.487,.032),(.673,.024),(.887,.015)]):
        wet += np.roll(audio[:, ::-1] if i % 2 else audio, round(RATE * delay), axis=0) * amount
    sos = signal.butter(2, 6900, fs=RATE, output='sos')
    wet = signal.sosfilt(sos, wet, axis=0)
    wet -= np.mean(wet, axis=0)
    wet *= .72 / max(.001, np.max(np.abs(wet)))
    # Prevent a waveform discontinuity at the wrap, without a silent fade-out.
    seam = 128
    edge = (wet[0] + wet[-1]) / 2
    fade = np.linspace(0, 1, seam)[:, None]
    wet[:seam] = edge * (1 - fade) + wet[:seam] * fade
    wet[-seam:] = wet[-seam:] * (1 - fade) + edge * fade
    return wet.astype(np.float32)

def wav(path, audio):
    with wave.open(str(path), 'wb') as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes((np.clip(audio, -.98, .98) * 32767).astype('<i2').tobytes())

def encode(path, target):
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-hide_banner', '-loglevel', 'error', '-i', str(path), '-codec:a', 'libmp3lame', '-b:a', '192k', str(target)], check=True)

def effects():
    # Softer tactile effects: felt/mallet tones with filtered transients.
    recipes = {
        'select': (.22, [(0,659,.13),(.055,880,.08)]),
        'launch': (.36, [(0,330,.13),(.09,494,.11),(.18,659,.07)]),
        'bounce': (.16, [(0,740,.11)]),
        'hit': (.16, [(0,220,.09),(.018,330,.05)]),
        'battle': (.55, [(0,294,.12),(.14,440,.11),(.26,587,.08)]),
        'reward': (.78, [(0,587,.12),(.14,740,.10),(.28,880,.09)]),
        'win': (1.2, [(0,587,.12),(.18,740,.11),(.36,880,.09),(.57,1175,.055)]),
        'fail': (.75, [(0,392,.10),(.24,294,.08)]),
    }
    for name, (duration, notes) in recipes.items():
        t = np.arange(round(duration * RATE)) / RATE
        samples = np.zeros_like(t)
        for start, freq, gain in notes:
            local = np.maximum(0, t - start)
            env = (1 - np.exp(-local / .009)) * np.exp(-local / (.12 if name in ['hit','bounce'] else .19)) * (t >= start)
            samples += gain * env * (np.sin(2 * math.pi * freq * local) + .10 * np.sin(2 * math.pi * freq * 2 * local))
        samples[-round(RATE * .04):] *= np.linspace(1, 0, round(RATE * .04))
        wav(ASSETS / f'{name}.wav', np.column_stack((samples, samples)))

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    ASSETS.mkdir(parents=True, exist_ok=True)
    SCORES.mkdir(parents=True, exist_ok=True)
    font = OUT / 'GeneralUser-GS.sf2'
    if not font.exists():
        urllib.request.urlretrieve(FONT_URL, font)
    if hashlib.sha256(font.read_bytes()).hexdigest() != FONT_SHA256:
        raise RuntimeError('SoundFont digest differs from the reviewed build input')
    license_path = SCORES / 'GeneralUser-GS-LICENSE.txt'
    urllib.request.urlretrieve(LICENSE_URL, license_path)
    camp_chords = [
        [38,54,57,61], [35,54,57,62], [31,55,59,62], [33,52,57,61],
        [38,54,57,62], [42,54,57,61], [40,55,59,62], [33,55,57,61],
    ]
    adventure_chords = [
        [43,55,59,62], [40,55,59,64], [36,55,60,64], [43,55,59,62],
        [38,54,57,62], [40,55,59,64], [33,57,60,64], [38,54,57,60],
    ]
    report = {'composition': 'Original Forest Star scores; no film recording, melody or imported MIDI.',
              'soundfontUrl': FONT_URL, 'soundfontSha256': hashlib.sha256(font.read_bytes()).hexdigest(), 'licenseUrl': LICENSE_URL, 'tracks': []}
    for name, melody, bpm, chords in [
        ('sky-camp-v2', CAMP_MELODY, 72, camp_chords),
        ('sky-adventure-v2', ADVENTURE_MELODY, 80, adventure_chords),
    ]:
        midi = score(name, melody, bpm, chords)
        audio = render(midi, font)
        wave_path = OUT / f'{name}.wav'
        wav(wave_path, audio)
        encode(wave_path, ASSETS / f'{name}.mp3')
        preview = audio[12 * RATE:36 * RATE].copy()
        preview[:RATE] *= np.linspace(0, 1, RATE)[:, None]
        preview[-RATE * 2:] *= np.linspace(1, 0, RATE * 2)[:, None]
        preview_path = OUT / f'{name}-preview.wav'
        wav(preview_path, preview)
        encode(preview_path, preview_path.with_suffix('.mp3'))
        metrics = {'name': name, 'seconds': len(audio) / RATE, 'bpm': bpm, 'midiTracks': len(midi.tracks),
                   'noteCount': sum(msg.type == 'note_on' for track in midi.tracks for msg in track),
                   'peakDbfs': round(20 * math.log10(float(np.max(np.abs(audio)))) ,2),
                   'rmsDbfs': round(20 * math.log10(float(np.sqrt(np.mean(audio ** 2)))) ,2),
                   'loopSeam': float(np.max(np.abs(audio[0] - audio[-1]))),
                   'mp3Bytes': (ASSETS / f'{name}.mp3').stat().st_size}
        assert np.isfinite(audio).all() and metrics['peakDbfs'] < -1
        report['tracks'].append(metrics)
        print(metrics, flush=True)
    effects()
    (OUT / 'music-report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')

if __name__ == '__main__':
    main()
