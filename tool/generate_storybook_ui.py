"""Generate style-matched project art through the user's approved APIXGo API."""
import argparse
import base64
import concurrent.futures
import ctypes
import io
import json
from pathlib import Path
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'output' / 'imagegen' / 'storybook-v2'
STYLE = (
    'Use case: illustration-story. Reference image 1 is the STYLE REFERENCE only. '
    'Match its cozy hand-painted forest fantasy illustration exactly: soft painterly edges, '
    'warm sunlight, fresh moss green and pale blue, creamy highlights, textured wood and '
    'flowers, charming round animals with soft fur. Original mobile game art. '
    'No typography, text, letters, numbers, logos, watermarks, UI buttons, or frames around the whole image. '
)
JOBS = {
    'camp': ('1024x1536', 'Full-bleed portrait forest village glade. Slightly elevated view of a '
        'sunny grassy clearing surrounded by tall trees, little flowers and distant misty mountains '
        'under a blue sky in the upper fifth. Three empty little meadow plots connected by a '
        'winding footpath: upper left, middle right, lower center. Leave those plots clear for '
        'separate small buildings to be placed later. No buildings, no animals. Lush foliage '
        'at the outer edges, uncluttered grassy center. Warm inviting home base.'),
    'pinball': ('1024x1024', 'A single EMPTY magical woodland pinball playfield seen perfectly '
        'straight-on. Rectangle wooden rounded frame occupies most of the square, with small '
        'mint leaves, a few flowers at the outer corners and tiny gold studs on its rim. '
        'The inner play area is uniform warm light ivory with a very faint pale green gradient. '
        'Completely EMPTY central board, no pegs, no balls, no machines, no animals, no text. '
        'Keep decoration outside the central playfield. Entire frame visible.'),
    'companions': ('1024x1536', 'Full-bleed portrait cozy woodland companion cottage interior. '
        'Soft golden daylight through an arched window, mossy green wooden beams, flowers '
        'and tiny shelves on the far outer edges. Warm cream plaster and pale wood, with a '
        'quiet soft-focus open center for a character collection interface. No furniture '
        'or animals in the central 85 percent. Inviting picture-book atmosphere, green '
        'foliage visible through upper windows. No panels or interface drawn into the art.'),
    'guard': ('1024x1536', 'Full-bleed portrait woodland defense battlefield viewed from above '
        'at a slight angle. A bright grassy clearing with THREE subtle vertical sandy lanes '
        'at 20, 50 and 80 percent of image width, all running from near top to near bottom. '
        'Tall trees, flowers, ferns and rocks frame only the outer edges. No characters, '
        'no buildings, no UI, no labels, no weapons. Center remains clear for gameplay. '
        'Warm midday sunlight, storybook forest, gentle shadows, readable paths.'),
    'friends': ('1536x1024', 'A clean sprite atlas on pure flat white background, six separate '
        'full-body cute chibi forest companions in an exact 3 column by 2 row grid. '
        'Each fits fully within its own equal cell with a white margin, no cell borders. '
        'Top left: pale green fluffy bunny with a small sprout on its head. Top middle: '
        'round blue otter with cream cheeks. Top right: orange fox with cream belly and '
        'fluffy white-tipped tail. Bottom left: adorable moss-green turtle with a leafy shell. '
        'Bottom middle: tiny round golden yellow fluffy bird with small wings. Bottom right: '
        'lavender sleepy cat with a little crescent decoration. Face forward, big kind glossy '
        'eyes, soft fur, rounded silhouettes, harmonious proportions. Match the animals '
        'in the reference. No extra animals, props, lettering or text. All six isolated.'),
}


def api_key():
    import os
    key = os.environ.get('APIXGO_IMAGE_API_KEY')
    if not key:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, 'Environment') as env:
            key = winreg.QueryValueEx(env, 'APIXGO_IMAGE_API_KEY')[0]
    if not key:
        raise RuntimeError('APIXGO_IMAGE_API_KEY is not configured')
    return key


def generate(name):
    size, subject = JOBS[name]
    path = OUTPUT / f'{name}.png'
    if path.exists():
        print(f'Using existing {name}', flush=True)
        return
    prompt = STYLE + subject
    boundary = 'ForestStar' + uuid.uuid4().hex
    data = io.BytesIO()
    fields = dict(model='gpt-image-2.5-flare', prompt=prompt, size=size,
                  quality='high', response_format='b64_json', n='1')
    for key, value in fields.items():
        data.write(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode())
    data.write(f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="style-reference.png"\r\nContent-Type: image/png\r\n\r\n'.encode())
    data.write((ROOT / 'assets' / 'forest-star-start.png').read_bytes())
    data.write(f'\r\n--{boundary}--\r\n'.encode())
    request = urllib.request.Request('https://img.apixgo.com/v1/images/edits', data=data.getvalue(),
        headers={'Authorization': 'Bearer ' + api_key(),
                 'Content-Type': 'multipart/form-data; boundary=' + boundary})
    print(f'Generating {name} with start-screen reference...', flush=True)
    try:
        with urllib.request.urlopen(request, timeout=240) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError(f'{name}: image API returned HTTP {error.code}') from None
    item = result['data'][0]
    if item.get('b64_json'):
        image = base64.b64decode(item['b64_json'])
    elif item.get('url'):
        with urllib.request.urlopen(item['url'], timeout=120) as response:
            image = response.read()
    else:
        raise RuntimeError(f'{name}: API returned no image')
    path.write_bytes(image)
    (OUTPUT / f'{name}-prompt.txt').write_text(prompt, encoding='utf-8')
    print(f'Saved {path}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--jobs', nargs='+', default=list(JOBS), choices=JOBS)
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(generate, args.jobs))
