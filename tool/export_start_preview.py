"""Export the real Flutter start-screen captures as a looping preview GIF."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'output/review/start-v2'
OUTPUT = ROOT / 'output/preview/start-v2'
OUTPUT.mkdir(parents=True, exist_ok=True)
frames = [Image.open(path).convert('RGB') for path in sorted(SOURCE.glob('frame-*.png'))]
if len(frames) != 24:
    raise RuntimeError('Run FOREST_START_CAPTURE=1 flutter test test/start_scene_test.dart first')
palette = frames[0].quantize(colors=256)
indexed = [frame.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG) for frame in frames]
indexed[0].save(OUTPUT / 'start-screen.gif', save_all=True, append_images=indexed[1:],
                duration=70, loop=0, optimize=False, disposal=2)
for source, target in [('start-393-1.0.png', 'start-screen.png'),
                       ('notice-393-1.0.png', 'notice-board.png')]:
    (OUTPUT / target).write_bytes((SOURCE / source).read_bytes())
with Image.open(OUTPUT / 'start-screen.gif') as gif:
    assert gif.n_frames > 1
for path in sorted(OUTPUT.iterdir()):
    print(path.name, path.stat().st_size)
