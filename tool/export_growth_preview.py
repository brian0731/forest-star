"""Create GIFs from actual Flutter gameplay captures; no fabricated animation."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
captures = ROOT / 'output/review/growth-v1'
output = ROOT / 'output/preview/growth-v1'
output.mkdir(parents=True, exist_ok=True)
for name, expected in [('pinball', 24), ('evolution', 36)]:
    files = sorted(captures.glob(f'{name}-[0-9][0-9][0-9].png'))
    if len(files) != expected:
        raise RuntimeError(f'Expected {expected} {name} frames, got {len(files)}')
    frames = [Image.open(file).convert('RGB').resize((360, 675), Image.Resampling.LANCZOS)
              for file in files]
    palette = Image.new('RGB', (360 * 6, 675))
    for index in range(6):
        palette.paste(frames[index * (len(frames) - 1) // 5], (360 * index, 0))
    palette = palette.quantize(colors=192)
    indexed = [frame.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG) for frame in frames]
    indexed[0].save(output / f'{name}.gif', save_all=True, append_images=indexed[1:],
                    duration=100, loop=0, disposal=2, optimize=False)
    gif = Image.open(output / f'{name}.gif')
    assert gif.n_frames == expected and gif.info['loop'] == 0
    print(f'{name}: {gif.n_frames} frames, 360x675')
for name in ['pinball-ready', 'companion-growth', 'evolution-012']:
    Image.open(captures / f'{name}.png').save(output / f'{name}.png')
