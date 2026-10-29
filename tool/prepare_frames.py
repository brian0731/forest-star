"""Split the generated frame atlas, retaining alpha and cleaning detached specks."""
from collections import deque
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
source = Image.open(ROOT / 'output/imagegen/frames-v1/frames-atlas.png').convert('RGBA')
if source.getchannel('A').getextrema()[0] != 0:
    raise RuntimeError('Expected native transparent margins. Inspect the atlas first.')
for index, name in enumerate(['paper', 'green', 'cream', 'selected']):
    col, row = index % 2, index // 2
    tile = source.crop((col * source.width // 2, row * source.height // 2,
                        (col + 1) * source.width // 2, (row + 1) * source.height // 2))
    pixels = np.array(tile)
    mask = pixels[:, :, 3] > 16
    height, width = mask.shape
    # The centre is opaque panel paper. Retain only its connected silhouette.
    keep = np.zeros_like(mask)
    queue = deque([(height // 2, width // 2)])
    keep[height // 2, width // 2] = True
    while queue:
        y, x = queue.popleft()
        for ny, nx in [(y-1, x), (y+1, x), (y, x-1), (y, x+1)]:
            if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not keep[ny, nx]:
                keep[ny, nx] = True
                queue.append((ny, nx))
    # Preserve antialiased edge pixels immediately around the retained shape.
    support = keep.copy()
    support[1:] |= keep[:-1]
    support[:-1] |= keep[1:]
    support[:, 1:] |= keep[:, :-1]
    support[:, :-1] |= keep[:, 1:]
    pixels[:, :, 3][~support] = 0
    tile = Image.fromarray(pixels)
    tile = tile.crop(tile.getchannel('A').getbbox()).resize((512, 512), Image.Resampling.LANCZOS)
    target = ROOT / f'assets/storybook/frame-{name}-v1.png'
    tile.save(target)
    print(target.name, tile.size)
