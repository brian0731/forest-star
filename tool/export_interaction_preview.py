"""Export recorded Flutter interactions; no generated or simulated UI frames."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT = Path(__file__).resolve().parent.parent
captures = ROOT / 'output/review/interaction-v1'
output = ROOT / 'output/preview/interaction-v1'
output.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype(str(ROOT / 'assets/fonts/NotoSansTC.ttf'), 17)
panels = []
for name, title, samples in [('navigation', '按壓、獎勵與夥伴招呼', [7, 13, 20, 36]),
                             ('pinball', '瞄準、出手與得分', [12, 26, 50, 118]),
                             ('guard', '四路出擊與命中回饋', [8, 33, 60, 89])]:
    paths = sorted(captures.glob(f'{name}-*.png'))
    frames = [Image.open(path).convert('RGB').resize((360, 675), Image.Resampling.LANCZOS) for path in paths]
    # Learn one palette from representative frames, preserving UI colours when
    # a navigation recording crosses from outdoor to indoor scenes.
    palette_sheet = Image.new('RGB', (360 * 4, 675))
    for i in range(4): palette_sheet.paste(frames[round(i * (len(frames)-1) / 3)], (i * 360, 0))
    palette = palette_sheet.quantize(colors=240)
    indexed = [frame.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG) for frame in frames]
    indexed[0].save(output / f'{name}.gif', save_all=True, append_images=indexed[1:],
                    duration=80, loop=0, disposal=2, optimize=False)
    assert ImageChops.difference(frames[0], frames[len(frames)//2]).getbbox() is not None
    panel = Image.new('RGB', (960, 488), '#fff7e2')
    ImageDraw.Draw(panel).text((480, 18), title, font=font, fill='#426b48', anchor='mm')
    for i, sample in enumerate(samples):
        original = Image.open(paths[min(sample, len(paths)-1)]).convert('RGB')
        original.resize((240, 450), Image.Resampling.LANCZOS).save(output / f'{name}-sample-{i}.png')
        panel.paste(original.resize((240,450), Image.Resampling.LANCZOS), (i * 240, 38))
    panels.append(panel)
    print(name, len(frames), (output / f'{name}.gif').stat().st_size)
contact = Image.new('RGB', (960, 488*3), '#fff7e2')
for i, panel in enumerate(panels): contact.paste(panel, (0, i*488))
contact.save(output / 'interaction-contact.png')
