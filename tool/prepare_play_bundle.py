"""Preserve signed AAB contents, order JAR metadata first and check native ELF alignment."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import struct
import zipfile

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--input', type=Path, default=ROOT / 'build/app/outputs/bundle/release/app-release.aab')
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
if args.input.resolve() == args.output.resolve():
    raise SystemExit('Input and output must be different paths.')
args.output.parent.mkdir(parents=True, exist_ok=True)

def jar_order(info):
    name = info.filename.upper()
    if name == 'META-INF/MANIFEST.MF':
        return (0, name)
    if name.startswith('META-INF/') and name.endswith(('.SF', '.RSA', '.DSA', '.EC')):
        return (1, name)
    return (2, info.filename)

with zipfile.ZipFile(args.input) as source:
    if source.testzip() is not None:
        raise SystemExit('Source ZIP integrity failed.')
    if any(name.endswith(('.jks', '.keystore', '.key-password', 'key.properties')) for name in source.namelist()):
        raise SystemExit('Signing secrets must not be packaged.')
    with zipfile.ZipFile(args.output, 'w') as output:
        for info in sorted(source.infolist(), key=jar_order):
            output.writestr(copy.copy(info), source.read(info.filename))
    # Reopen only after closing the writer to verify its final central directory.
    with zipfile.ZipFile(args.output) as output:
        assert output.testzip() is None
        assert set(source.namelist()) == set(output.namelist())
        assert all(source.read(name) == output.read(name) for name in source.namelist())

checks = []
with zipfile.ZipFile(args.output) as bundle:
    for name in bundle.namelist():
        if not name.startswith(('base/lib/arm64-v8a/', 'base/lib/x86_64/')) or not name.endswith('.so'):
            continue
        data = bundle.read(name)
        assert data[:5] == b'\x7fELF\x02', name
        endian = '<' if data[5] == 1 else '>'
        offset = struct.unpack_from(endian + 'Q', data, 32)[0]
        size, count = struct.unpack_from(endian + 'HH', data, 54)
        alignments = []
        for index in range(count):
            header = offset + index * size
            if struct.unpack_from(endian + 'I', data, header)[0] == 1:
                alignments.append(struct.unpack_from(endian + 'Q', data, header + 48)[0])
        assert alignments and all(value >= 16384 for value in alignments), (name, alignments)
        checks.append({'library': name, 'load_alignments': alignments})
assert checks, 'No 64-bit native libraries found'
digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
args.output.with_suffix('.aab.sha256').write_text(f'{digest}  {args.output.name}\n', encoding='ascii')
args.output.with_suffix('.aab.verification.json').write_text(json.dumps({
    'file': args.output.name, 'bytes': args.output.stat().st_size, 'sha256': digest,
    'signed_entry_contents_preserved': True, 'native_libraries': checks,
    'note': 'Also verify with jarsigner and bundletool before submission.'
}, indent=2), encoding='utf-8')
print(args.output)
print(f'All {len(checks)} 64-bit libraries pass 16 KB ELF alignment; JAR entry bytes preserved.')
