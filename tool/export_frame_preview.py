"""Export the real revised screens as an overview for visual review."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
output = ROOT / 'output/preview/frames-v1'
output.mkdir(parents=True, exist_ok=True)
preview = Image.new('RGB', (1200, 598), '#f7efd9')
draw = ImageDraw.Draw(preview)
font = ImageFont.truetype(str(ROOT / 'assets/fonts/NotoSansTC.ttf'), 17)
for index, (file, title) in enumerate([
    ('01-camp', '森林營地'), ('02-pinball', '彈珠育成'),
    ('03-companions', '夥伴小屋'), ('04-guard', '森林守衛')]):
    image = Image.open(ROOT / f'output/review/frames/{file}.png').convert('RGB')
    image.save(output / f'{file}.png')
    preview.paste(image.resize((300, 562), Image.Resampling.LANCZOS), (index * 300, 36))
    draw.text((index * 300 + 150, 17), title, font=font, fill='#3b563b', anchor='mm')
preview.save(output / 'frames-overview.png')
print(output / 'frames-overview.png')
