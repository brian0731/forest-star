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
    args = parser.parse_args()
    opener = build_opener(NoRedirect())

    def fetch(path, limit):
        with opener.open(Request(f'https://{HOST}{path}', headers={'Cache-Control': 'no-cache'}), timeout=20) as response:
            if response.status != 200:
                raise ValueError(f'HTTP {response.status}: {path}')
            raw = response.read(limit + 1)
        if len(raw) > limit:
            raise ValueError(f'Oversized response: {path}')
        return raw

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
    captured = {path: catalog_raw}
    total = 0
    for item in catalog['files']:
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9-]*\.(png|webp|jpg|wav|mp3|m4a|json)', item['path']):
            raise ValueError('Invalid filename')
        path = f"/content/{version}/{item['path']}"
        if urlsplit(item['url']).geturl() != f'https://{HOST}{path}':
            raise ValueError('Unexpected file URL')
        raw = fetch(path, min(item['bytes'], 20 * 1024 * 1024))
        if len(raw) != item['bytes'] or hashlib.sha256(raw).hexdigest() != item['sha256']:
            raise ValueError(f"Size or SHA-256 mismatch: {item['path']}")
        captured[path] = raw
        total += len(raw)
        print(f"Verified {item['key']}: {len(raw)} bytes")
    if total != catalog['totalBytes'] or total > 50 * 1024 * 1024:
        raise ValueError('Catalog total mismatch')
    print('Live content enabled:', content['enabled'], '| verified bytes:', total)
    if args.capture:
        captured['/game/update-v1.json'] = (json.dumps(manifest, ensure_ascii=False) + '\n').encode('utf-8')
        for path, raw in captured.items():
            target = args.capture / path.lstrip('/')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
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
