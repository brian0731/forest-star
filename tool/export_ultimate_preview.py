"""Export actual Flutter test frames, not mockups, as a GIF and a sound demo."""
from pathlib import Path
import subprocess
import wave
import numpy as np
from PIL import Image
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
FRAMES = ROOT / 'output/review/ultimate-v1'
OUT = ROOT / 'output/preview/ultimate-v1'
KINDS = ['nature', 'water', 'fire', 'earth', 'lightning', 'moon']

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new('RGB', (960, 1200))
    for i, kind in enumerate(KINDS):
        image = Image.open(FRAMES / f'{kind}-14.png').convert('RGB')
        sheet.paste(image.resize((320, 600), Image.Resampling.LANCZOS), (i % 3 * 320, i // 3 * 600))
    sheet.save(OUT / 'six-spells.jpg', quality=94)
    frames = [Image.open(path).convert('RGB').resize((384, 720), Image.Resampling.LANCZOS) for path in sorted(FRAMES.glob('fire-*.png'))]
    palette = frames[7].quantize(colors=192)
    frames = [frame.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG) for frame in frames]
    frames[0].save(OUT / 'fire-ultimate.gif', save_all=True, append_images=frames[1:], loop=0, duration=200, disposal=2)
    video_frames = [FRAMES / 'battle-ready.png'] * 5
    for kind in KINDS:
        video_frames.extend(sorted(FRAMES.glob(f'{kind}-*.png')))
    video_frames.extend([FRAMES / 'battle-used.png'] * 5)
    silent = OUT / 'six-spells-silent.mp4'
    writer = imageio_ffmpeg.write_frames(str(silent), (480, 900), fps=5, codec='libx264', pix_fmt_in='rgb24', pix_fmt_out='yuv420p', macro_block_size=2, output_params=['-crf', '19', '-movflags', '+faststart'])
    writer.send(None)
    for path in video_frames:
        writer.send(np.asarray(Image.open(path).convert('RGB')))
    writer.close()
    rate = 44100
    audio = np.zeros((round(len(video_frames) / 5 * rate), 2), dtype=np.float32)
    for i, kind in enumerate(KINDS):
        start = 1 + i * 3.4
        for effect, delay, gain in [('magicCharge', 0, .42), ('magicImpact', 1.25, .52)]:
            with wave.open(str(ROOT / f'assets/audio/{effect}.wav')) as stream:
                samples = np.frombuffer(stream.readframes(stream.getnframes()), dtype='<i2').reshape(-1, 2).astype(np.float32) / 32768
            offset = round((start + delay) * rate)
            audio[offset:offset + len(samples)] += samples * gain
    soundtrack = OUT / 'demo-sounds.wav'
    with wave.open(str(soundtrack), 'wb') as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(rate)
        stream.writeframes((np.clip(audio, -.95, .95) * 32767).astype('<i2').tobytes())
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-hide_banner', '-loglevel', 'error', '-i', str(silent), '-i', str(soundtrack), '-c:v', 'copy', '-c:a', 'aac', '-b:a', '160k', '-shortest', '-movflags', '+faststart', str(OUT / 'six-spells-demo.mp4')], check=True)
    silent.unlink()
    print(OUT / 'six-spells-demo.mp4')
    print(OUT / 'fire-ultimate.gif')

if __name__ == '__main__':
    main()
