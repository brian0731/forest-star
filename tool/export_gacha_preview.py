"""Export actual Flutter captures and an allowlisted VPS service package."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'output/review/gacha-v1'
OUTPUT = ROOT / 'output/preview/gacha-v1'
OUTPUT.mkdir(parents=True, exist_ok=True)
frames = [Image.open(path).convert('RGB') for path in sorted(SOURCE.glob('spin-*.png'))]
if len(frames) != 24:
    raise RuntimeError('Run FOREST_GACHA_CAPTURE=1 flutter test test/gacha_page_test.dart first')
# Include the final reveal instead of ending at the spinning machine.
result = Image.open(SOURCE / 'result-393-1.0.png').convert('RGB')
frames.append(result)
palette = frames[0].quantize(colors=256)
indexed = [frame.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG) for frame in frames]
indexed[0].save(OUTPUT / 'gacha.gif', save_all=True, append_images=indexed[1:],
                duration=[90] * 24 + [2200], loop=0, optimize=False, disposal=2)
for name, source in [('gacha.png', 'gacha-393-1.0.png'), ('new-pet.png', 'result-393-1.0.png')]:
    (OUTPUT / name).write_bytes((SOURCE / source).read_bytes())
(OUTPUT / 'new-pets.png').write_bytes((ROOT / 'output/preview/pets-v1/new-pets.png').read_bytes())

delivery = ROOT.parents[1] / 'Builds/Server'
delivery.mkdir(parents=True, exist_ok=True)
service = ROOT / 'server/gacha'
# Explicit allowlist excludes node_modules, .env, private keys and databases.
files = [service / name for name in ['package.json', 'package-lock.json', 'Dockerfile',
          '.dockerignore', '.env.example', 'compose.yaml', 'nginx-location.conf']]
files += sorted((service / 'src').glob('*.mjs'))
files += sorted((service / 'test').glob('*.mjs'))
archive = delivery / 'forest-star-gacha-server.zip'
with ZipFile(archive, 'w', ZIP_DEFLATED) as bundle:
    for path in files:
        bundle.write(path, Path('forest-star-gacha') / path.relative_to(service))
    bundle.write(ROOT / 'docs/GACHA_IAP_SETUP.zh-TW.md', 'GACHA_IAP_SETUP.zh-TW.md')
    bundle.write(ROOT / 'server/updates/public/privacy-policy.html', 'public/privacy-policy.html')
with ZipFile(archive) as bundle:
    assert bundle.testzip() is None
    assert not any('node_modules/' in name or '/secrets/' in name or name.endswith('.sqlite') for name in bundle.namelist())
(delivery / 'GACHA_IAP_SETUP.zh-TW.md').write_bytes((ROOT / 'docs/GACHA_IAP_SETUP.zh-TW.md').read_bytes())
for path in sorted(OUTPUT.iterdir()):
    print(path.name, path.stat().st_size)
print(archive, archive.stat().st_size)
