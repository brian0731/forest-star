"""Build a server-only media snapshot; no Flutter assets or website HTML copied.

python tool/prepare_sky_guard_update.py --site <NEW directory> --zip <NEW zip>
Pass --base-manifest <JSON> to use an inspected manifest instead of fetching it.
"""
from pathlib import Path
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
import shutil
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = 'forest-sky-guard-v2'
MEDIA = ROOT / 'server/updates/media' / VERSION
HOST = 'https://star.singtu.hk'
EFFECTS = ('select', 'launch', 'bounce', 'reward', 'battle', 'hit', 'win', 'fail')


def encode(data):
    return (json.dumps(data, ensure_ascii=False, indent=2) + '\n').encode('utf-8')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def catalog():
    sources = [
        ('camp', 'image', 'camp.webp'),
        ('field-level2', 'image', 'field-level2.webp'),
        ('levels', 'levels', 'levels.json'),
        *[(f'field-level{n}', 'image', f'guard-stage-{n}.webp') for n in range(3, 11)],
        *[(f'{s}-music-v2', 'audio', f'sky-{s}-v2.mp3') for s in ('camp', 'adventure')],
        *[(f'sfx-{s}-v2', 'audio', f'{s}.wav') for s in EFFECTS],
    ]
    files = []
    for key, kind, filename in sources:
        data = (MEDIA / filename).read_bytes()
        if kind == 'levels':
            assert json.loads(data)['contentVersion'] == VERSION
        assert 0 < len(data) <= 128 * 1024 * 1024
        files.append(dict(key=key, kind=kind, path=filename, bytes=len(data),
                          sha256=digest(data), url=f'{HOST}/content/{VERSION}/{filename}'))
    return dict(schemaVersion=1, contentVersion=VERSION,
                totalBytes=sum(f['bytes'] for f in files), files=files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--site', type=Path)
    parser.add_argument('--zip', type=Path)
    parser.add_argument('--base-manifest', type=Path)
    parser.add_argument('--catalog-only', action='store_true')
    args = parser.parse_args()
    data = catalog()
    catalog_bytes = encode(data)
    (MEDIA / 'catalog.json').write_bytes(catalog_bytes)
    if args.catalog_only:
        print(f'{len(data["files"])} files, {data["totalBytes"]:,} bytes')
        return
    if args.site is None:
        parser.error('--site is required unless --catalog-only is used')
    if args.site.exists() or (args.zip and args.zip.exists()):
        parser.error('Use a NEW site directory / ZIP; published versions are immutable')
    if args.base_manifest:
        base = json.loads(args.base_manifest.read_bytes())
    else:
        with urllib.request.urlopen(f'{HOST}/game/update-v1.json', timeout=20) as response:
            base = json.loads(response.read(256 * 1024))
    assert base['schemaVersion'] == 1
    assert base['platforms']['ios']['applicationId'] == 'com.foreststar.foreststar'
    assert base['platforms']['android']['applicationId'] == 'com.foreststar.forest_star'
    now = datetime.now(timezone.utc).replace(microsecond=0)
    base.update(configRevision=base['configRevision'] + 1,
                publishedAt=now.isoformat().replace('+00:00', 'Z'),
                expiresAt=(now + timedelta(days=90)).isoformat().replace('+00:00', 'Z'))
    base['content'] = dict(enabled=True, version=VERSION,
                           minimumClientBuild=dict(ios=23, android=23),
                           catalogUrl=f'{HOST}/content/{VERSION}/catalog.json',
                           catalogBytes=len(catalog_bytes), catalogSha256=digest(catalog_bytes))
    base['notice'] = dict(
        id=VERSION, enabled=True,
        title={'zh-Hant': '天空冒險與八大秘境', 'en': 'Sky adventure and eight new worlds',
               'yue-HK': '天空冒險與八大秘境'},
        body={'zh-Hant': '下載原創長笛、豎琴及弦樂配樂、柔和音效與守衛第 3–10 關場景。下載後可離線使用；營地及第 2 關內容繼續保留。',
              'en': 'Download original flute, harp and strings music, softer sounds and guard stages 3–10. Play offline after downloading; camp and stage 2 content are included.',
              'yue-HK': '下載原創長笛、豎琴同弦樂配樂、柔和音效及守衛第 3–10 關場景。下載後可離線玩，營地同第 2 關內容繼續保留。'})
    destination = args.site / 'content' / VERSION
    destination.mkdir(parents=True)
    for entry in data['files']:
        shutil.copyfile(MEDIA / entry['path'], destination / entry['path'])
    (destination / 'catalog.json').write_bytes(catalog_bytes)
    game = args.site / 'game'
    game.mkdir()
    (game / 'update-v1.json').write_bytes(encode(base))
    # Keep editable MIDI and the upstream instrument license outside public media.
    shutil.copytree(ROOT / 'server/updates/source/sky-v2', args.site / 'maintainer-sources')
    shutil.copyfile(ROOT / 'docs/SERVER_SKY_GUARD_UPDATE.zh-TW.md', args.site / 'SETUP.zh-TW.md')
    report = dict(contentVersion=VERSION, minimumClientBuild=23,
                  files=len(data['files']), totalBytes=data['totalBytes'],
                  catalogSha256=digest(catalog_bytes), publishedAt=base['publishedAt'],
                  expiresAt=base['expiresAt'], deployed=False)
    (args.site / 'package-info.json').write_bytes(encode(report))
    if args.zip:
        args.zip.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.zip, 'w', zipfile.ZIP_DEFLATED) as archive:
            for file in sorted(args.site.rglob('*')):
                if file.is_file():
                    archive.write(file, file.relative_to(args.site).as_posix())
        report.update(zip=str(args.zip.resolve()), zipBytes=args.zip.stat().st_size,
                      zipSha256=digest(args.zip.read_bytes()))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
