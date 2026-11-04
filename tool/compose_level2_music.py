"""Original evolving stereo game music, synthesized locally and encoded as real MP3.

No third-party melodies, recordings, sample libraries, silence padding or fake bytes.
The deliberately long 48-minute editions exercise the >200 MiB update pipeline.
"""
import argparse
import json
import math
from pathlib import Path
import subprocess
import numpy as np
import imageio_ffmpeg

RATE = 22050
ROOT = Path(__file__).resolve().parents[1]
CHORDS = [[50,57,62,66], [47,54,59,62], [43,50,55,59], [45,52,57,61],
          [54,57,61,64], [47,54,57,62], [43,50,57,62], [45,52,57,64]]
MOTIFS = [[0,4,7,11,9,7,4,2], [7,9,11,14,11,7,4,2],
          [4,7,9,7,4,2,0,2], [0,2,4,7,4,2,-1,0],
          [11,9,7,4,7,9,14,11], [7,4,2,0,2,4,7,9]]


def phrase(index, theme, seconds=12):
    """A self-contained eight-bar phrase with evolving harmony and orchestration."""
    count = int(seconds * RATE)
    mix = np.zeros((count, 2), dtype=np.float32)
    beat = seconds / 24
    movement = index // 16
    transpose = [0, 0, 5, 0, -2, 0, 7, 0][movement % 8]
    motif = MOTIFS[(index // 2 + (3 if theme == 'adventure' else 0)) % len(MOTIFS)]
    lead_pan = .35 + .2 * math.sin(index * .7)
    stats = {'notes': 0}

    def add(start, length, pitch, instrument, gain, pan):
        duration = min(length, seconds - start)
        if duration <= 0: return
        t = np.arange(int(duration * RATE), dtype=np.float32) / RATE
        freq = 440 * 2 ** ((pitch + transpose - 69) / 12)
        phase = 2 * np.pi * freq * t
        if instrument == 'bell':
            signal = np.sin(phase) * np.exp(-t / .7) + .19 * np.sin(phase * 2.01) * np.exp(-t / .25)
            envelope = np.minimum(t / .008, 1)
        elif instrument == 'flute':
            signal = np.sin(phase + .018 * np.sin(2 * np.pi * 4.6 * t)) + .13 * np.sin(phase * 2)
            envelope = np.minimum(t / .06, 1) * np.minimum((duration - t) / .1, 1)
        elif instrument == 'pad':
            signal = np.sin(phase) + .09 * np.sin(phase * 2) + .07 * np.sin(phase * 1.003)
            envelope = np.minimum(t / .28, 1) * np.minimum((duration - t) / .28, 1)
        elif instrument == 'bass':
            signal = np.sin(phase) + .12 * np.sin(phase * 2)
            envelope = np.minimum(t / .018, 1) * np.exp(-t / .65) * np.minimum((duration-t)/.04, 1)
        else:
            signal = np.sin(phase) + .21 * np.sin(phase * 2) + .07 * np.sin(phase * 3)
            envelope = np.minimum(t / .006, 1) * np.exp(-t / .25)
        wave = (signal * envelope * gain).astype(np.float32)
        a = int(start * RATE)
        b = min(a + len(wave), count)
        mix[a:b, 0] += wave[:b-a] * math.cos(pan * np.pi / 2)
        mix[a:b, 1] += wave[:b-a] * math.sin(pan * np.pi / 2)
        stats['notes'] += 1

    for bar in range(8):
        start = bar * 3 * beat
        chord = CHORDS[(index + bar) % len(CHORDS)]
        for step in range(6):
            pitch = chord[[0,1,2,3,2,1][step]] + 12
            add(start + step * beat / 2, .62, pitch, 'harp', .09 if theme == 'camp' else .11, .25)
        add(start, 2.8 * beat, chord[0]-12, 'bass', .10, .5)
        for p, pitch in enumerate(chord[1:]):
            add(start, 2.95 * beat, pitch, 'pad', .033, .6+p*.12)
        if bar % 2 == 0 or theme == 'adventure':
            for step in range(3):
                pitch = 74 + motif[(bar * 2 + step + index % 3) % len(motif)]
                lead = 'bell' if (index // 4) % 3 != 1 else 'flute'
                add(start + step * beat, beat * .92, pitch, lead, .14, lead_pan)
        if theme == 'adventure':
            # Soft pitched wooden percussion, synthesized rather than sampled.
            for step in range(3):
                add(start + step * beat, .12, 38 + step % 2 * 7, 'harp', .075, .6)
        elif bar in (3,7):
            add(start + beat, .8, 86 + motif[(index+bar)%8] % 5, 'bell', .045, .8)
    dry = mix.copy()
    for delay, level in [(.101,.12),(.211,.08),(.337,.04)]:
        n = int(delay * RATE)
        mix[n:] += dry[:-n, ::-1] * level
    # Soft limiting and tiny edge fades avoid hard phrase-boundary clicks.
    mix = np.tanh(mix * 1.35) * .85
    fade = min(int(.035 * RATE), count // 2)
    mix[:fade] *= np.linspace(0,1,fade)[:,None]
    mix[-fade:] *= np.linspace(1,0,fade)[:,None]
    return mix.astype('<f4'), stats['notes']


def render(theme, output, minutes):
    target = output / f'firefly-{theme}-extended.mp3'
    if target.exists():
        raise FileExistsError(target)
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    command = [ffmpeg, '-hide_banner', '-loglevel', 'error', '-f', 'f32le', '-ar', str(RATE),
               '-ac', '2', '-i', 'pipe:0', '-c:a', 'libmp3lame', '-b:a', '320k', '-ar', '44100',
               '-metadata', f'title=Forest Star - Firefly {theme.title()} - Original Extended Test Edition',
               '-metadata', 'artist=Forest Star', '-metadata',
               'comment=Original procedural composition and additive synthesis; no third-party samples.', str(target)]
    proc = subprocess.Popen(command, stdin=subprocess.PIPE)
    phrases = math.ceil(minutes * 60 / 12)
    peak, energy, samples, note_count = 0., 0., 0, 0
    try:
        for i in range(phrases):
            audio, notes = phrase(i, theme)
            if i == phrases - 1:
                remaining = round(minutes * 60 * RATE) - i * 12 * RATE
                audio = audio[:remaining]
            proc.stdin.write(audio.tobytes())
            peak = max(peak, float(np.max(np.abs(audio))))
            energy += float(np.sum(audio.astype(np.float64)**2))
            samples += audio.size
            note_count += notes
            if i % 40 == 0: print(f'{theme}: {i*12//60}/{minutes} minutes rendered', flush=True)
        proc.stdin.close()
        if proc.wait() != 0: raise RuntimeError('MP3 encoding failed')
    finally:
        if proc.poll() is None: proc.kill()
    preview = output / f'firefly-{theme}-preview.mp3'
    subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-i',str(target),'-t','24',
                    '-af','afade=t=out:st=21:d=3','-b:a','192k',str(preview)], check=True)
    report = {'theme':theme, 'minutes':minutes, 'seconds':minutes*60,
              'bitrate':320000,'sampleRate':44100,'channels':2,'phrases':phrases,
              'notes':note_count,'bytes':target.stat().st_size,'peak':peak,
              'rms':math.sqrt(energy / samples),'clipped':peak >= 1,
              'source':'Original procedural composition and additive synthesis, no external samples'}
    (output / f'{theme}-composition.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--theme', choices=['camp','adventure'], required=True)
    parser.add_argument('--minutes', type=int, default=48)
    parser.add_argument('--output', type=Path, default=ROOT / 'output/audio/level2-v1')
    args = parser.parse_args()
    if not 1 <= args.minutes <= 48: raise ValueError('minutes must be 1..48')
    args.output.mkdir(parents=True, exist_ok=True)
    render(args.theme, args.output, args.minutes)
