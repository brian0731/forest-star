from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


root = Path(__file__).resolve().parent.parent
background = Image.open(root / "assets" / "forest-star-camp.png").convert("RGB")
meadow = background.crop((0, 560, background.width, background.height))
meadow.save(root / "assets" / "camp-meadow-v1.png")
for name in ("pinball", "companions", "guard"):
    source = root / "output" / "imagegen" / f"camp-{name}-v1.png"
    target = root / "assets" / f"camp-{name}-sprite-v1.png"
    if target.exists():
        continue
    image = Image.open(source).convert("RGBA")
    mask_source = image.copy()
    ImageDraw.floodfill(mask_source, (0, 0), (0, 0, 0, 0), thresh=35)
    alpha = mask_source.getchannel("A").filter(ImageFilter.GaussianBlur(0.6))
    image.putalpha(alpha)
    image.thumbnail((768, 768), Image.Resampling.LANCZOS)
    image.save(target)
    print(target)
