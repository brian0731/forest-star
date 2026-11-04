"""Verify the live update package; optionally capture it and prepare activation JSON.

This only reads the public website. It never deploys or changes server files.
"""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import re
from urllib.request import Request, build_opener, HTTPRedirectHandler
from urllib.parse import urlsplit

HOST = 'star.singtu.hk'


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, help='Save verified responses for local integration tests')
    parser.add_argument('--enable-manifest', type=Path, help='Write an activation manifest locally; does not deploy')
    parser.add_argument('--local-catalog', type=Path, help='Verify uploaded media against a local catalog before activating its manifest')
    args = parser.parse_args()
    if args.local_catalog and (args.capture or args.enable_manifest):
        parser.error('--local-catalog cannot be combined with capture/enable-manifest')
    opener = build_opener(NoRedirect())

    def fetch(path, limit, *, target=None, expected_size=None, expected_hash=None, media=False):
        digest = hashlib.sha256()
        count, pieces = 0, []
        if target:
            target.parent.mkdir(parents=True, exist_ok=True)
        sink = target.open('wb') if target else None
        try:
            with opener.open(Request(f'https://{HOST}{path}', headers={'Cache-Control': 'no-cache'}), timeout=30) as response:
                if response.status != 200: raise ValueError(f'HTTP {response.status}: {path}')
                while chunk := response.read(256 * 1024):
                    count += len(chunk)
                    if count > limit: raise ValueError(f'Oversized response: {path}')
                    digest.update(chunk)
                    if sink: sink.write(chunk)
                    if not media: pieces.append(chunk)
            if expected_size is not None and count != expected_size: raise ValueError(f'Size mismatch: {path}')
            if expected_hash is not None and digest.hexdigest() != expected_hash: raise ValueError(f'SHA-256 mismatch: {path}')
            return b''.join(pieces)
        finally:
            if sink: sink.close()

    if args.local_catalog:
        catalog_raw = args.local_catalog.read_bytes()
        if len(catalog_raw) > 262144: raise ValueError('Oversized local catalog')
        version = json.loads(catalog_raw.decode('utf-8'))['contentVersion']
        manifest = None
        content = {'version':version,'enabled':False,
                   'catalogUrl':f'https://{HOST}/content/{version}/catalog.json',
                   'catalogBytes':len(catalog_raw),'catalogSha256':hashlib.sha256(catalog_raw).hexdigest()}
    else:
        manifest = json.loads(fetch('/game/update-v1.json', 65536).decode('utf-8'))
        content = manifest['content']
    version = content['version']
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,63}', version):
        raise ValueError('Invalid content version')
    path = f'/content/{version}/catalog.json'
    if content['catalogUrl'] != f'https://{HOST}{path}':
        raise ValueError('Unexpected catalog URL')
    catalog_raw = fetch(path, 262144)
    if (len(catalog_raw) != content['catalogBytes'] or
            hashlib.sha256(catalog_raw).hexdigest() != content['catalogSha256']):
        raise ValueError('Catalog size or SHA-256 mismatch')
    catalog = json.loads(catalog_raw.decode('utf-8'))
    if catalog['schemaVersion'] != 1 or catalog['contentVersion'] != version:
        raise ValueError('Unexpected catalog schema/version')
    if args.capture:
        target = args.capture / path.lstrip('/')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(catalog_raw)
    total = 0
    for item in catalog['files']:
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9-]*\.(png|webp|jpg|wav|mp3|m4a|json)', item['path']):
            raise ValueError('Invalid filename')
        path = f"/content/{version}/{item['path']}"
        if urlsplit(item['url']).geturl() != f'https://{HOST}{path}':
            raise ValueError('Unexpected file URL')
        fetch(path, min(item['bytes'], 128 * 1024 * 1024), media=True,
              target=args.capture / path.lstrip('/') if args.capture else None,
              expected_size=item['bytes'], expected_hash=item['sha256'])
        total += item['bytes']
        print(f"Verified {item['key']}: {item['bytes']} bytes")
    if total != catalog['totalBytes'] or total > 512 * 1024 * 1024:
        raise ValueError('Catalog total mismatch')
    print('Catalog verified before activation' if args.local_catalog else f"Live content enabled: {content['enabled']}", '| verified bytes:', total)
    if args.capture:
        target = args.capture / 'game/update-v1.json'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(manifest, ensure_ascii=False)+'\n', encoding='utf-8')
        print('Captured verified responses:', args.capture)
    if args.enable_manifest:
        now = datetime.now(timezone.utc)
        manifest['configRevision'] += 1
        manifest['publishedAt'] = now.strftime('%Y-%m-%dT%H:%M:%SZ')
        manifest['expiresAt'] = (now + timedelta(days=30)).strftime('%Y-%m-%dT%H:%M:%SZ')
        manifest['content']['enabled'] = True
        args.enable_manifest.parent.mkdir(parents=True, exist_ok=True)
        args.enable_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print('Prepared activation JSON (not deployed):', args.enable_manifest)


if __name__ == '__main__':
    main()
