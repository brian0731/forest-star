"""Export Play listing art from the game's existing illustration assets."""

from pathlib import Path
import json

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parents[1]
DEST = WORKSPACE / 'Builds' / 'GooglePlay'
DEST.mkdir(parents=True, exist_ok=True)
SCALE = 2


def font(size, weight=700):
    result = ImageFont.truetype(str(ROOT / 'assets/fonts/NotoSansTC.ttf'), size * SCALE)
    result.set_variation_by_axes([weight])
    return result


def place_character(canvas, index, left, baseline, height):
    image = Image.open(ROOT / f'assets/storybook/character-{index}.png').convert('RGBA')
    image = image.crop(image.getbbox())
    image = image.resize((round(image.width * height / image.height * SCALE), height * SCALE), Image.Resampling.LANCZOS)
    x, y = left * SCALE, baseline * SCALE - image.height
    shadow = Image.new('RGBA', canvas.size)
    draw = ImageDraw.Draw(shadow)
    draw.ellipse((x + image.width * .08, baseline * SCALE - 14 * SCALE,
                  x + image.width * .92, baseline * SCALE + 7 * SCALE), fill=(37, 65, 28, 65))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8 * SCALE)))
    canvas.alpha_composite(image, (x, y))


icon = Image.open(WORKSPACE / 'output/imagegen/forest-star-icon.png').convert('RGB')
icon.resize((512, 512), Image.Resampling.LANCZOS).save(DEST / 'forest-star-icon-512.png', optimize=True)

# A landscape crop keeps the forest geometry intact without stretching it.
background = Image.open(ROOT / 'assets/storybook/camp.webp').convert('RGBA')
background = background.crop((0, 420, 1024, 920))
canvas = background.resize((1024 * SCALE, 500 * SCALE), Image.Resampling.LANCZOS)
wash = Image.new('RGBA', canvas.size)
draw = ImageDraw.Draw(wash)
for x in range(canvas.width):
    opacity = round(235 * max(0, min(1, (650 - x / SCALE) / 220)))
    draw.line((x, 0, x, canvas.height), fill=(255, 249, 222, opacity))
canvas.alpha_composite(wash)

place_character(canvas, 1, 510, 415, 205)
place_character(canvas, 2, 786, 413, 220)
place_character(canvas, 0, 620, 430, 275)

draw = ImageDraw.Draw(canvas)
draw.text((70 * SCALE, 124 * SCALE), '歡迎來到森林營地', font=font(22, 600), fill='#527857')
draw.text((65 * SCALE, 163 * SCALE), '森星小隊', font=font(90, 900), fill='#2C553D',
          stroke_width=2 * SCALE, stroke_fill='#FFF9DE')
draw.line((73 * SCALE, 290 * SCALE, 134 * SCALE, 290 * SCALE), fill='#B6934D', width=3 * SCALE)
draw.text((71 * SCALE, 310 * SCALE), '彈珠冒險・夥伴養成', font=font(26, 650), fill='#436847')

feature = canvas.convert('RGB').resize((1024, 500), Image.Resampling.LANCZOS)
feature.save(DEST / 'forest-star-feature-1024x500.png', optimize=True)

report = []
for name, size, limit in [
    ('forest-star-icon-512.png', (512, 512), 1_000_000),
    ('forest-star-feature-1024x500.png', (1024, 500), 15_000_000),
]:
    path = DEST / name
    with Image.open(path) as image:
        image.load()
        assert image.size == size
        assert image.format == 'PNG' and image.mode == 'RGB'
    assert path.stat().st_size < limit
    report.append({'file': name, 'width': size[0], 'height': size[1],
                   'bytes': path.stat().st_size, 'format': 'PNG', 'mode': 'RGB'})
(DEST / 'art-verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))
