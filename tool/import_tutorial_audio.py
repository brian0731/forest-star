"""Import a completed TopMediai tutorial run without submitting generation.

Pass the local forest-completed.json emitted by the generation session. URLs
are account-scoped; do not commit the report or include its URLs in source.
"""
import argparse
import json
from pathlib import Path
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = {'zh': 'zh-TW', 'en': 'en-US', 'yue': 'yue-HK'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    args = parser.parse_args()
    entries = json.loads(args.report.read_text(encoding='utf-8'))
    expected = {(language, lesson) for language in LANGUAGES for lesson in range(1, 11)}
    actual = {(entry['lang'], entry['lesson']) for entry in entries}
    if actual != expected or len(entries) != len(expected):
        raise ValueError('Expected exactly 30 completed tutorial audio results')
    for entry in entries:
        result = entry['result']
        if result.get('status') != 'completed' or result.get('delivery_error'):
            raise ValueError('Incomplete or undeliverable generation')
        artifacts = result.get('artifacts', [])
        if len(artifacts) != 1 or artifacts[0].get('mime_type') != 'audio/mpeg':
            raise ValueError('Expected one MP3 per lesson')
        url = urllib.parse.urlsplit(artifacts[0]['url'])
        if url.scheme != 'https' or url.hostname != 'files.topmediai.com' or url.username or url.password:
            raise ValueError('Untrusted audio origin')
        target = ROOT / 'assets/tutorial' / LANGUAGES[entry['lang']] / f"{entry['lesson']}.mp3"
        target.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(artifacts[0]['url'], timeout=60) as response:
            data = response.read(5 * 1024 * 1024 + 1)
        if not data or len(data) > 5 * 1024 * 1024:
            raise ValueError('Invalid audio length')
        if target.exists() and target.read_bytes() != data:
            raise FileExistsError(f'Refusing to replace {target}')
        target.write_bytes(data)
        print(f"{entry['lang']} {entry['lesson']}: {len(data)} bytes")


if __name__ == '__main__':
    main()
