"""Extract the four APIXGo sprites, retaining the source PNG's native alpha."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
source = Image.open(ROOT / 'output/imagegen/marbles-v1/marbles-atlas.png').convert('RGBA')
if source.getchannel('A').getextrema()[0] != 0:
    raise RuntimeError('Atlas must have transparent margins; inspect before importing.')
preview = Image.new('RGB', (1000, 300), '#f3eddd')
draw = ImageDraw.Draw(preview)
font = ImageFont.truetype(str(ROOT / 'assets/fonts/NotoSansTC.ttf'), 18)
for index, title in enumerate(['綠葉 · 1 碰 / 6 分', '藍水 · 2 碰 / 14 分', '紫星 · 3 碰 / 24 分', '金色 · 發射彈珠']):
    col, row = index % 2, index // 2
    sprite = source.crop((col * source.width // 2, row * source.height // 2,
                         (col + 1) * source.width // 2, (row + 1) * source.height // 2))
    bounds = sprite.getchannel('A').point(lambda value: 255 if value > 24 else 0).getbbox()
    sprite = sprite.crop(bounds)
    sprite.thumbnail((240, 240), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (256, 256))
    canvas.alpha_composite(sprite, ((256 - sprite.width) // 2, (256 - sprite.height) // 2))
    canvas.save(ROOT / f'assets/storybook/marble-{index}.png')
    preview.paste(canvas.resize((220, 220)), (index * 250 + 15, 5), canvas.resize((220, 220)))
    draw.text((index * 250 + 125, 260), title, fill='#365640', font=font, anchor='mm')
preview.save(ROOT / 'output/imagegen/marbles-v1/marbles-preview.png')
print('Prepared four RGBA sprites and preview.')
