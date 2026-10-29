"""Export real Flutter captures and the generated location artwork as looping GIFs."""
import math
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--captures', default='output/review/after')
parser.add_argument('--output', default='output/preview/storybook-v2')
args = parser.parse_args()
CAPTURES = ROOT / args.captures
OUTPUT = ROOT / args.output
OUTPUT.mkdir(parents=True, exist_ok=True)
FONT = str(ROOT / 'assets/fonts/NotoSansTC.ttf')
PAGES = [('start', '開始畫面'), ('camp', '森林營地'), ('pinball', '森林彈珠'),
         ('companions', '夥伴小屋'), ('guard', '森林守衛')]


def save_gif(frames, path, duration=100):
    palette = frames[0].convert('RGB').quantize(colors=192)
    indexed = [frame.convert('RGB').quantize(palette=palette,
               dither=Image.Dither.FLOYDSTEINBERG) for frame in frames]
    indexed[0].save(path, save_all=True, append_images=indexed[1:],
                    duration=duration, loop=0, optimize=False, disposal=2)


overview = []
for name, label in PAGES:
    files = sorted(CAPTURES.glob(f'{name}-[0-9][0-9][0-9].png'))
    if len(files) != 24:
        raise RuntimeError(f'Expected 24 captured frames for {name}, got {len(files)}')
    frames = [Image.open(p).convert('RGB').resize((360, 675), Image.Resampling.LANCZOS)
              for p in files]
    save_gif(frames, OUTPUT / f'{name}.gif')
    for frame in frames:
        preview = Image.new('RGB', (300, 598), '#f9f1da')
        preview.paste(frame.resize((300, 562), Image.Resampling.LANCZOS), (0, 36))
        ImageDraw.Draw(preview).text((150, 16), label,
            font=ImageFont.truetype(FONT, 15), fill='#3d573b', anchor='mm')
        overview.append(preview)
save_gif(overview, OUTPUT / 'all-pages.gif')

# These are animated derivatives of the three API-generated location images.
# A soft squash and breathing motion is applied locally, with transparent margins.
for name in ('pinball', 'companions', 'guard'):
    source = Image.open(ROOT / f'assets/camp-{name}-sprite-v1.png').convert('RGBA')
    frames = []
    for index in range(24):
        phase = index * math.tau / 24
        sprite = source.resize((round(332*(1+math.sin(phase)*.012)),
                                round(332*(1-math.sin(phase)*.012))), Image.Resampling.LANCZOS)
        frame = Image.new('RGBA', (360, 360))
        frame.alpha_composite(sprite, ((360-sprite.width)//2,
            round((360-sprite.height)/2+math.sin(phase)*3)))
        # Reserve palette entry 255 for transparency.
        rgb = Image.new('RGB', frame.size, '#eff4de')
        rgb.paste(frame, mask=frame.getchannel('A'))
        quant = rgb.quantize(colors=255)
        mask = frame.getchannel('A').point(lambda a: 255 if a < 100 else 0)
        quant.paste(255, mask=mask)
        quant.info['transparency'] = 255
        frames.append(quant)
    path = OUTPUT / f'location-{name}.gif'
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=100,
        loop=0, disposal=2, transparency=255, optimize=False)

screens = ['00-start', '01-camp', '02-pinball', '03-companions', '04-guard']
contact = Image.new('RGB', (1200, 494), '#f9f1da')
draw = ImageDraw.Draw(contact)
for index, (screen, (_, label)) in enumerate(zip(screens, PAGES)):
    image = Image.open(CAPTURES / f'{screen}.png').convert('RGB')
    contact.paste(image.resize((240, 450), Image.Resampling.LANCZOS), (index*240, 44))
    draw.text((index*240+120, 21), label, font=ImageFont.truetype(FONT,18),
              fill='#3d573b', anchor='mm')
contact.save(OUTPUT / 'all-pages.png')
for path in sorted(OUTPUT.iterdir()):
    if path.suffix == '.gif':
        with Image.open(path) as gif:
            # GIF encoders may merge identical neighbouring frames, preserving duration.
            assert gif.n_frames >= 2 and gif.info.get('loop') == 0
            assert ImageChops.difference(gif.convert('RGB'),
                (gif.seek(1) or gif.convert('RGB'))).getbbox() is not None
    print(path.name, path.stat().st_size)
