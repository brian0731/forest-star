"""Validate and package the read-only Forest Star update server files."""
import argparse
from datetime import datetime, timezone
import json
import hashlib
from pathlib import Path
import re
import shutil
from urllib.parse import urlsplit
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'server/updates/public'


def validate(path):
    raw = path.read_bytes()
    if len(raw) > 65536:
        raise ValueError('Update manifest must be at most 64 KiB')
    data = json.loads(raw.decode('utf-8'))
    if type(data.get('schemaVersion')) is not int or data['schemaVersion'] != 1:
        raise ValueError('Unsupported schemaVersion')
    if type(data.get('configRevision')) is not int or data['configRevision'] < 1:
        raise ValueError('configRevision must be a positive integer')
    published = datetime.fromisoformat(data['publishedAt'].replace('Z', '+00:00'))
    expiry = datetime.fromisoformat(data['expiresAt'].replace('Z', '+00:00'))
    if published.tzinfo is None or expiry.tzinfo is None or expiry <= published:
        raise ValueError('Dates must have timezone and expiresAt must follow publishedAt')
    now = datetime.now(timezone.utc)
    if published > now or expiry <= now:
        raise ValueError('Manifest is future-dated or expired; update its dates')
    for platform, application_id, host in [
        ('ios', 'com.foreststar.foreststar', 'apps.apple.com'),
        ('android', 'com.foreststar.forest_star', 'play.google.com'),
    ]:
        item = data['platforms'][platform]
        if item['applicationId'] != application_id:
            raise ValueError(f'{platform}: wrong applicationId')
        for key in ['latestBuild', 'minimumBuild']:
            if type(item[key]) is not int or item[key] < 1:
                raise ValueError(f'{platform}: {key} must be a positive integer')
        if item['minimumBuild'] > item['latestBuild']:
            raise ValueError(f'{platform}: minimumBuild exceeds latestBuild')
        if not isinstance(item['latestVersion'], str) or not item['latestVersion']:
            raise ValueError(f'{platform}: latestVersion required')
        if type(item['promptEnabled']) is not bool:
            raise ValueError(f'{platform}: promptEnabled must be boolean')
        value = item['storeUrl']
        if not isinstance(value, str):
            raise ValueError(f'{platform}: storeUrl must be a string')
        if value:
            url = urlsplit(value)
            if (url.scheme != 'https' or url.hostname != host or url.username
                    or url.password or url.port not in (None, 443)):
                raise ValueError(f'{platform}: storeUrl must use https://{host}')
        elif item['promptEnabled']:
            raise ValueError(f'{platform}: fill storeUrl before enabling prompts')
    notice = data['notice']
    if type(notice['enabled']) is not bool or not isinstance(notice['id'], str):
        raise ValueError('Invalid notice enabled/id')
    for key, limit in [('title', 100), ('body', 2000)]:
        for language in ['zh-Hant', 'en', 'yue-HK']:
            value = notice[key][language]
            if not isinstance(value, str) or not value or len(value) > limit:
                raise ValueError(f'Invalid notice {key}/{language}')
    content = data['content']
    if type(content['enabled']) is not bool:
        raise ValueError('content.enabled must be boolean')
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,63}', content['version']):
        raise ValueError('Invalid content version')
    url = urlsplit(content['catalogUrl'])
    if (url.scheme != 'https' or url.netloc != 'star.singtu.hk'
            or url.path != f"/content/{content['version']}/catalog.json"
            or url.query or url.fragment):
        raise ValueError('Invalid catalog URL or content version mismatch')
    for platform in ['ios', 'android']:
        build = content['minimumClientBuild'][platform]
        if type(build) is not int or build < 1:
            raise ValueError('Invalid minimumClientBuild')
    if content['enabled'] and (
            type(content['catalogBytes']) is not int
            or not 1 <= content['catalogBytes'] <= 262144
            or not re.fullmatch(r'[0-9a-f]{64}', content['catalogSha256'])):
        raise ValueError('Enabled content requires valid catalogBytes and catalogSha256')
    return data


def prepare_site(target, version):
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,63}', version):
        raise ValueError('Use lowercase letters, digits and hyphens for content version')
    # Require a fresh output folder: a versioned content path is immutable.
    target.mkdir(parents=True, exist_ok=False)
    shutil.copytree(PUBLIC, target, dirs_exist_ok=True)
    destination = target / 'content' / version
    destination.mkdir(parents=True)
    files = []
    for key, kind, source, filename in [
        ('camp', 'image', ROOT / 'assets/storybook/camp.webp', 'camp.webp'),
        ('board', 'image', ROOT / 'assets/storybook/pinball-board-v2.webp', 'pinball-board.webp'),
        ('camp-music', 'audio', ROOT / 'server/updates/source/legacy-audio/forest_camp.wav', 'forest-camp.wav'),
        ('levels', 'levels', ROOT / 'server/updates/examples/levels-v1.json', 'levels.json'),
    ]:
        if kind == 'levels':
            levels = json.loads(source.read_text(encoding='utf-8'))
            levels['contentVersion'] = version
            data = (json.dumps(levels, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
        else:
            data = source.read_bytes()
        (destination / filename).write_bytes(data)
        files.append({'key': key, 'kind': kind, 'path': filename,
                      'url': f'https://star.singtu.hk/content/{version}/{filename}',
                      'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
    catalog = {'schemaVersion': 1, 'contentVersion': version,
               'totalBytes': sum(item['bytes'] for item in files), 'files': files}
    catalog_data = (json.dumps(catalog, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    (destination / 'catalog.json').write_bytes(catalog_data)
    manifest_path = target / 'game/update-v1.json'
    config = json.loads(manifest_path.read_text(encoding='utf-8'))
    config['content'].update(version=version,
        catalogUrl=f'https://star.singtu.hk/content/{version}/catalog.json',
        catalogBytes=len(catalog_data), catalogSha256=hashlib.sha256(catalog_data).hexdigest())
    manifest_path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    validate(manifest_path)
    print('Prepared image/audio/level catalog; total bytes:', catalog['totalBytes'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, default=PUBLIC / 'game/update-v1.json')
    parser.add_argument('--zip', type=Path, help='Package public files for Cloudflare dashboard upload')
    parser.add_argument('--site', type=Path, help='Create a NEW site folder with real media and a SHA-256 catalog')
    parser.add_argument('--content-version', default='forest-base-v1')
    args = parser.parse_args()
    config = validate(args.manifest)
    print('Valid update manifest; configRevision:', config['configRevision'])
    public = PUBLIC
    if args.site:
        if args.manifest.resolve() != (PUBLIC / 'game/update-v1.json').resolve():
            raise ValueError('--site builds from the default manifest only')
        prepare_site(args.site, args.content_version)
        public = args.site
    if args.zip:
        if args.manifest.resolve() != (PUBLIC / 'game/update-v1.json').resolve():
            raise ValueError('--zip packages the default manifest only')
        args.zip.parent.mkdir(parents=True, exist_ok=True)
        with ZipFile(args.zip, 'w', ZIP_DEFLATED) as archive:
            for path in sorted(public.rglob('*')):
                if path.is_file():
                    archive.write(path, path.relative_to(public).as_posix())
        print('Packaged public server files:', args.zip.resolve())


if __name__ == '__main__':
    main()
