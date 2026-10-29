from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
source = ROOT / 'output/imagegen/storybook-v2'
target = ROOT / 'assets/storybook'
target.mkdir(parents=True, exist_ok=True)
for name in ('camp', 'companions', 'guard'):
    image = Image.open(source / f'{name}.png').convert('RGB')
    image.thumbnail((1024, 1536), Image.Resampling.LANCZOS)
    image.save(target / f'{name}.webp', quality=92)
import runpy
runpy.run_path(str(ROOT / 'tool/prepare_pinball_board.py'))
runpy.run_path(str(ROOT / 'tool/extract_characters.py'))
print(f'Prepared backgrounds, board and six portraits in {target}')
