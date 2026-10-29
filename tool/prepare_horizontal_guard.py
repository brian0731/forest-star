"""Align the generated road centres to the four logical gameplay lanes."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
source = Image.open(ROOT / 'output/imagegen/guard-horizontal-v1/guard.png').convert('RGB')
width, height = 804, 766
# Observed path centres in the reviewed 1254px generation. Keep all scenery,
# adjusting each grass/road span continuously to match BattleLayout at 2x.
source_y = [0, 180, 455, 765, 1075, source.height]
target_y = [0, 92, 278, 464, 650, height]
result = Image.new('RGB', (width, height))
for index in range(len(source_y) - 1):
    tile = source.crop((0, source_y[index], source.width, source_y[index + 1]))
    tile = tile.resize((width, target_y[index + 1] - target_y[index]), Image.Resampling.LANCZOS)
    result.paste(tile, (0, target_y[index]))
target = ROOT / 'assets/storybook/guard-horizontal-v1.webp'
result.save(target, quality=95)
print(target, result.size)
