"""Export actual Flame camp captures as a full view and a closer walking view."""
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
captures = ROOT / 'output/review/camp-patrol-v1'
output = ROOT / 'output/preview/camp-patrol-v1'
output.mkdir(parents=True, exist_ok=True)
paths = sorted(captures.glob('camp-*.png'))
assert len(paths) == 160
for name, crop, size in [('camp-guards', None, (360, 675)),
                          ('walking-detail', (26, 446, 460, 771), (434, 325))]:
    frames = []
    for path in paths:
        image = Image.open(path).convert('RGB')
        if crop: image = image.crop(crop)
        frames.append(image.resize(size, Image.Resampling.LANCZOS))
    palette = frames[0].quantize(colors=224)
    indexed = [frame.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG)
               for frame in frames]
    indexed[0].save(output / f'{name}.gif', save_all=True, append_images=indexed[1:],
        duration=100, loop=0, disposal=1, optimize=True)
    assert ImageChops.difference(frames[0], frames[60]).getbbox() is not None
    print(name, len(frames), (output / f'{name}.gif').stat().st_size)
Image.open(paths[35]).save(output / 'camp-guards.png')
