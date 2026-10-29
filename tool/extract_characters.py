"""Extract the existing character art without regenerating its identity.

The originals stay intact. Runtime PNGs retain soft alpha for fur and ears.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / 'assets/storybook'
OUT = ROOT / 'output/preview/flame-v3'
OUT.mkdir(parents=True, exist_ok=True)
source_sheet = Image.open(ROOT / 'output/imagegen/storybook-v2/friends.png').convert('RGBA')
# The illustration has unequal row heights: splitting at 512 cuts off feet.
columns = [(0, 520), (520, 1000), (1000, 1536)]
rows = [(0, 567), (567, 1024)]
sheet = Image.new('RGB', (1200, 800), '#365743')
report = []
for index in range(6):
    left, right = columns[index % 3]
    top, bottom = rows[index // 3]
    cutout = source_sheet.crop((left, top, right, bottom))
    alpha = np.array(cutout.getchannel('A'))
    # Suppress tiny near-transparent remnants, retaining the antialiased edge.
    alpha[alpha < 8] = 0
    alpha[alpha > 245] = 255
    cutout.putalpha(Image.fromarray(alpha))
    cutout = cutout.crop(cutout.getbbox())
    cutout.thumbnail((488, 488), Image.Resampling.LANCZOS)
    padded = Image.new('RGBA', (512, 512))
    padded.alpha_composite(cutout, ((512-cutout.width)//2, 500-cutout.height))
    cutout = padded
    alpha = np.array(cutout.getchannel('A'))
    cutout.save(ART / f'character-{index}.png', optimize=True)
    assert alpha.min() == 0 and alpha.max() > 250
    assert np.all(alpha[0, :] == 0) and np.all(alpha[-1, :] == 0)
    assert np.all(alpha[:, 0] == 0) and np.all(alpha[:, -1] == 0)
    report.append({'id': index, 'transparent_fraction': float((alpha == 0).mean()),
                   'bounds': cutout.getbbox()})
    tile = Image.new('RGBA', (400, 400), '#365743')
    d = ImageDraw.Draw(tile)
    for y in range(0, 400, 25):
        for x in range(0, 400, 25):
            if (x // 25 + y // 25) % 2:
                d.rectangle((x, y, x+24, y+24), fill='#476a52')
    cutout.thumbnail((380, 380), Image.Resampling.LANCZOS)
    tile.alpha_composite(cutout, ((400-cutout.width)//2, 400-cutout.height))
    sheet.paste(tile.convert('RGB'), ((index % 3)*400, (index // 3)*400))
sheet.save(OUT / 'characters-transparent.png')
(OUT / 'alpha-report.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
