"""Extract the four generated illustrations without cutting ears or alpha edges."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
source = Image.open(ROOT / 'output/imagegen/navigation-v1/navigation-atlas.png').convert('RGBA')
pixels = np.asarray(source).copy()
labels, _ = ndimage.label(pixels[:, :, 3] > 32)
sizes = np.bincount(labels.ravel())
components = sorted(range(1, len(sizes)), key=lambda i: sizes[i], reverse=True)[:4]
components.sort(key=lambda i: (round(ndimage.center_of_mass(labels == i)[0] / source.height),
                               ndimage.center_of_mass(labels == i)[1]))
# Assign the original low-alpha feathering to its nearest illustration, rather
# than imposing quadrant crops that could cut the rabbit's protruding ears.
distance, nearest = ndimage.distance_transform_edt(labels == 0, return_indices=True)
nearest_labels = labels[tuple(nearest)]
manifest = []
for index, component in enumerate(components):
    isolated = pixels.copy()
    isolated[:, :, 3] = np.where((nearest_labels == component) & (distance <= 12),
                                 pixels[:, :, 3], 0)
    cutout = Image.fromarray(isolated)
    bounds = cutout.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    cutout = cutout.crop(bounds)
    cutout.thumbnail((296, 276), Image.Resampling.LANCZOS)
    result = Image.new('RGBA', (320, 300))
    result.alpha_composite(cutout, ((320 - cutout.width)//2, (300-cutout.height)//2))
    target = ROOT / f'assets/storybook/navigation-{index}-v1.png'
    result.save(target)
    manifest.append({'index': index, 'label': ['彈珠', '夥伴', '守衛', '營地'][index],
                     'source_bounds': bounds, 'asset': str(target.relative_to(ROOT))})
    print(target.name, bounds)
(ROOT / 'output/imagegen/navigation-v1/assets.json').write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
