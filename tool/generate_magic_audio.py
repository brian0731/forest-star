"""Original short magical charge/impact sounds; no external recordings."""
from pathlib import Path
import math
import wave
import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100

def write(name, audio):
    audio -= np.mean(audio)
    audio *= .68 / np.max(np.abs(audio))
    edge = round(RATE * .025)
    audio[:edge] *= np.linspace(0, 1, edge)
    audio[-edge:] *= np.linspace(1, 0, edge)
    stereo = np.column_stack([audio, .94 * audio + .06 * np.roll(audio, 293)])
    with wave.open(str(ROOT / f'assets/audio/{name}.wav'), 'wb') as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes((stereo * 32767).astype('<i2').tobytes())

def main():
    rng = np.random.default_rng(20261104)
    t = np.arange(round(RATE * 1.18)) / RATE
    wind = sosfilt(butter(2, [180, 2200], btype='bandpass', fs=RATE, output='sos'), rng.standard_normal(len(t)))
    env = np.sin(np.pi * t / 1.18) ** 1.3
    charge = .13 * wind * env
    for i, pitch in enumerate([50, 57, 62, 66, 69, 74]):
        local = np.maximum(0, t - i * .12)
        tone_env = (1 - np.exp(-local / .035)) * np.exp(-local / .33)
        freq = 440 * 2 ** ((pitch - 69) / 12)
        charge += .065 * tone_env * np.sin(2 * math.pi * freq * local)
    charge += .025 * env * np.sin(2 * math.pi * (160 * t + 160 * t ** 2))
    write('magicCharge', charge)
    t = np.arange(round(RATE * 1.6)) / RATE
    noise = sosfilt(butter(2, 1700, fs=RATE, output='sos'), rng.standard_normal(len(t)))
    impact = .14 * noise * np.exp(-t * 7) * (1 - np.exp(-t / .008))
    impact += .18 * np.sin(2 * math.pi * (58 * t - 12 * t ** 2)) * np.exp(-t * 4) * (1 - np.exp(-t / .006))
    for i, pitch in enumerate([50, 62, 66, 69, 74]):
        freq = 440 * 2 ** ((pitch - 69) / 12)
        impact += .04 * np.sin(2 * math.pi * freq * t) * np.exp(-t * (2.8 + i * .2)) * (1 - np.exp(-t / .012))
    write('magicImpact', impact)
    print('Wrote magicCharge.wav (1.18s) and magicImpact.wav (1.60s)')

if __name__ == '__main__':
    main()
