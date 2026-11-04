"""Prepare APIXGo four-lane art; preserve lane anchors when fitting the field."""
from pathlib import Path
import argparse
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'output/imagegen/guard-stages-v1'
THEMES = {
    3: ('竹溪晴谷', 'sunlit bamboo valley, jade bamboo leaves, a narrow sparkling creek winding ONLY between the roads, tiny blue flowers and smooth river stones'),
    4: ('楓葉山徑', 'golden autumn maple valley, copper and red maple leaves, soft amber light, little mushrooms and warm mossy stones'),
    5: ('霜雪松林', 'gentle snowy pine forest, powder snow on blue-green pine boughs, frosted shrubs, icy blue shadows, four clear pale sandy snow trails'),
    6: ('水晶幽谷', 'magical crystal grotto garden, luminous turquoise and lavender crystals, purple moss and tiny glowing fungi, four clear muted violet stone trails'),
    7: ('金沙綠洲', 'sunny desert oasis garden, small palm fronds and turquoise pools ONLY between roads, succulent plants, golden dunes and four clear sandy trails'),
    8: ('熔光花園', 'friendly fantasy volcanic garden at twilight, smooth dark basalt, glowing amber cracks ONLY between roads, red-orange flowers, four clear warm grey stone trails, no scary scenery'),
    9: ('雲海浮島', 'dreamy floating sky garden, white fluffy clouds ONLY between roads, tiny floating rock islands and blue flowers, four clear pale ivory stone trails with continuous walkable surfaces'),
    10: ('星穹聖域', 'enchanted midnight star sanctuary, deep indigo grass, small moonlit ancient stones and silver flowers, softly glowing cyan star crystals, four clear moonlit lavender stone trails'),
}

def prompts():
    RAW.mkdir(parents=True, exist_ok=True)
    entries = []
    for stage, (name, description) in THEMES.items():
        prompt = f'''Use case: style-transfer / game environment background.
Input reference role: composition and painterly style reference, NOT an image to keep unchanged.
Create a completely new environment for level {stage}: {description}.
Match the supplied image's polished cute hand-painted storybook mobile game style, soft volumetric shading and top-down view.
CRITICAL COMPOSITION: exactly FOUR straight parallel HORIZONTAL roads from the left edge to the right edge. Road center y positions are 14.4%, 36.3%, 61.0%, 85.7% of image height. Each road is about 7% of image height. Preserve these positions exactly. No vertical paths, no perspective convergence, no curving roads. All four roads are unobstructed flat walking surfaces. Landscape decorations stay entirely between roads and at upper/lower edges. Rich unique scenery, restrained detail on the roads for readable combat.
Output a single square full-bleed opaque game background. No text, no labels, no borders, no UI, no buttons, no characters, no animals, no castles, no water flowing across roads. This is a scene illustration, not a screenshot.
'''
        path = RAW / f'stage-{stage}.txt'
        path.write_text(prompt, encoding='utf-8')
        entries.append({'stage': stage, 'name': name, 'prompt': prompt})
    (RAW / 'prompts.json').write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding='utf-8')
    doc = '# 守衛第 3–10 關場景提示詞\n\nAPIXGo openai 分組；`gpt-image-2.5-flare`；imagegen fallback CLI `edit`；1024 × 1024。\n\n參考圖：`output/imagegen/guard-horizontal-v1/guard.png`，僅參考畫風及四路位置。\n'
    for entry in entries:
        doc += f"\n## {entry['stage']} · {entry['name']}\n\n```text\n{entry['prompt']}```\n"
    (ROOT / 'docs/GUARD_STAGE_ART_PROMPTS.md').write_text(doc, encoding='utf-8')

def prepare():
    tiles = []
    font = ImageFont.truetype('C:/Windows/Fonts/msjh.ttc', 22)
    # Each source can override anchors after visual review, as fractions of height.
    overrides = json.loads((RAW / 'anchors.json').read_text()) if (RAW / 'anchors.json').exists() else {}
    for stage, (name, _) in THEMES.items():
        source = Image.open(RAW / f'stage-{stage}.png').convert('RGB')
        anchors = overrides.get(str(stage), [0, .144, .363, .610, .857, 1])
        sy = [round(v * source.height) for v in anchors]
        ty = [0, 92, 278, 464, 650, 766]
        fitted = Image.new('RGB', (804, 766))
        for start, end, top, bottom in zip(sy, sy[1:], ty, ty[1:]):
            strip = source.crop((0, start, source.width, end)).resize((804, bottom - top), Image.Resampling.LANCZOS)
            fitted.paste(strip, (0, top))
        target = ROOT / f'server/updates/media/forest-sky-guard-v2/guard-stage-{stage}.webp'
        target.parent.mkdir(parents=True, exist_ok=True)
        fitted.save(target, quality=91, method=6)
        tile = Image.new('RGB', (402, 424), '#182d37')
        tile.paste(fitted.resize((402, 383), Image.Resampling.LANCZOS), (0, 41))
        ImageDraw.Draw(tile).text((12, 7), f'{stage:02d}  {name}', font=font, fill='white')
        tiles.append(tile)
    sheet = Image.new('RGB', (402 * 4, 424 * 2))
    for i, tile in enumerate(tiles):
        sheet.paste(tile, (i % 4 * 402, i // 4 * 424))
    out = ROOT / 'output/preview/guard-stages-v1'
    out.mkdir(parents=True, exist_ok=True)
    sheet.save(out / 'contact-sheet.jpg', quality=93)
    print(out / 'contact-sheet.jpg')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--prompts', action='store_true')
    args = parser.parse_args()
    prompts() if args.prompts else prepare()
