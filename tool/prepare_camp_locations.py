from pathlib import Path
import argparse

import numpy as np
from scipy import ndimage
from PIL import Image


root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description="Remove the white matte from camp locations.")
parser.add_argument("--only", choices=("pinball", "companions", "guard"))
parser.add_argument("--force", action="store_true", help="Rebuild an existing runtime sprite.")
args = parser.parse_args()
if args.only is None:
    background = Image.open(root / "assets" / "forest-star-camp.png").convert("RGB")
    meadow = background.crop((0, 560, background.width, background.height))
    meadow.save(root / "assets" / "camp-meadow-v1.png")

# Openings in this specific 1254-square guard illustration. These are background,
# unlike the light-coloured flowers, lanterns and squirrel fur. Normalized seeds
# also work if the same original illustration is exported at a different size.
guard_openings = [(360, 407), (265, 420), (205, 425), (214, 448),
                  (850, 465), (975, 460), (600, 590), (969, 660), (991, 695)]
for name in ((args.only,) if args.only else ("pinball", "companions", "guard")):
    source = root / "output" / "imagegen" / f"camp-{name}-v1.png"
    target = root / "assets" / f"camp-{name}-sprite-v1.png"
    if target.exists() and not args.force:
        continue
    image = Image.open(source).convert("RGBA")
    pixels = np.asarray(image).copy()
    rgb = pixels[:, :, :3].astype(np.float32)
    near_white = (rgb.min(axis=2) > 230) & (np.ptp(rgb, axis=2) < 26)
    labels, _ = ndimage.label(near_white | (pixels[:, :, 3] == 0))
    selected = set(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    if name == "guard":
        for x, y in guard_openings:
            label = labels[round(y / 1254 * image.height), round(x / 1254 * image.width)]
            if label == 0:
                raise RuntimeError("Guard opening does not match the expected original illustration")
            selected.add(label)
    selected.discard(0)
    background = np.isin(labels, list(selected))
    alpha = pixels[:, :, 3].astype(np.float32) / 255
    alpha[background] = 0
    # Recover edge coverage and colour from the original matte. Blurring an
    # alpha-only mask leaves white RGB in partially transparent outline pixels.
    distance, nearest = ndimage.distance_transform_edt(background, return_indices=True)
    foreground = rgb[tuple(nearest)]
    edge = background & (distance <= 2) & (pixels[:, :, 3] > 0)
    colour_distance = np.linalg.norm(255 - foreground, axis=2)
    coverage = np.linalg.norm(255 - rgb, axis=2) / np.maximum(colour_distance, 1)
    alpha[edge] = np.clip(coverage[edge], 0, 1)
    rgb[edge] = foreground[edge]
    pixels[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    pixels[:, :, 3] = np.round(alpha * 255).astype(np.uint8)
    image = Image.fromarray(pixels)
    image.thumbnail((768, 768), Image.Resampling.LANCZOS)
    image.save(target, optimize=True)
    print(target)
