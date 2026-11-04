"""Build the >200 MiB level 2 server test site from generated art and original MP3.

Large media stays outside Git. The output never overwrites an existing content version.
"""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import shutil
from zipfile import ZipFile, ZIP_STORED
from PIL import Image
from prepare_update_server import validate

ROOT = Path(__file__).resolve().parents[1]
VERSION = 'forest-level2-v1'


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def prepare_art():
    destination = ROOT / 'server/updates/examples/level2'
    destination.mkdir(parents=True, exist_ok=True)
    generated = ROOT / 'output/imagegen/level2-v1'
    Image.open(generated / 'camp.png').convert('RGB').save(destination / 'camp.webp', quality=93, method=6)
    field = Image.open(generated / 'field.png').convert('RGB').resize((1024,1024), Image.Resampling.LANCZOS)
    # Align painted lane centres with BattleLayout.laneY, not approximate AI placement.
    source = [0,170,410,650,894,1024]
    target = [0,123,372,621,869,1024]
    mesh = [((0,target[i],1024,target[i+1]),
             (0,source[i],0,source[i+1],1024,source[i+1],1024,source[i])) for i in range(5)]
    field = field.transform((1024,1024), Image.Transform.MESH, mesh, Image.Resampling.BICUBIC)
    field.resize((804,766), Image.Resampling.LANCZOS).save(destination / 'field.webp', quality=95, method=6)
    prompt = '# Level 2 generated art\n\nAPIXGo openai group; model `gpt-image-2.5-flare`, via the imagegen skill CLI.\n\n'
    for name in ['field','camp']:
        prompt += f'## {name}\n\n' + (generated / f'{name}-prompt.txt').read_text(encoding='utf-8') + '\n'
    prompt += '\nField post-processing: piecewise vertical remap to match the four fixed gameplay lane centres; WebP 804 × 766. Camp: WebP 1024 × 1536.\n'
    (destination / 'ART_PROMPTS.md').write_text(prompt, encoding='utf-8')
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--site', type=Path, default=ROOT / 'output/server/forest-level2-v1')
    parser.add_argument('--zip', type=Path, default=ROOT.parents[1] / 'Builds/Server/forest-star-level2-200mb.zip')
    args = parser.parse_args()
    if args.site.exists(): raise FileExistsError(args.site)
    art = prepare_art()
    music = ROOT / 'output/audio/level2-v1'
    sources = [
        ('camp','image', art / 'camp.webp','camp.webp'),
        ('field-level2','image', art / 'field.webp','field-level2.webp'),
        ('camp-music','audio',music / 'firefly-camp-extended.mp3','firefly-camp.mp3'),
        ('adventure-music','audio',music / 'firefly-adventure-extended.mp3','firefly-adventure.mp3'),
        ('levels','levels',ROOT / 'server/updates/examples/levels-v2.json','levels.json'),
    ]
    for _,_,source,_ in sources:
        if not source.is_file(): raise FileNotFoundError(source)
    shutil.copytree(ROOT / 'server/updates/public', args.site)
    folder = args.site / 'content' / VERSION
    folder.mkdir(parents=True)
    files = []
    for key,kind,source,name in sources:
        target = folder / name
        shutil.copyfile(source, target)
        files.append({'key':key,'kind':kind,'path':name,'bytes':target.stat().st_size,
            'sha256':sha(target),'url':f'https://star.singtu.hk/content/{VERSION}/{name}'})
    total = sum(item['bytes'] for item in files)
    if total <= 200 * 1024 * 1024: raise ValueError('Test package must exceed 200 MiB')
    catalog = {'schemaVersion':1,'contentVersion':VERSION,'totalBytes':total,'files':files}
    catalog_path = folder / 'catalog.json'
    catalog_path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n', encoding='utf-8')
    manifest_path = args.site / 'game/update-v1.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    now = datetime.now(timezone.utc)
    manifest.update(configRevision=3, publishedAt=now.strftime('%Y-%m-%dT%H:%M:%SZ'),
                    expiresAt=(now+timedelta(days=30)).strftime('%Y-%m-%dT%H:%M:%SZ'))
    manifest['content'].update(enabled=True,version=VERSION,minimumClientBuild={'ios':21,'android':21},
        catalogUrl=f'https://star.singtu.hk/content/{VERSION}/catalog.json',
        catalogBytes=catalog_path.stat().st_size,catalogSha256=sha(catalog_path))
    manifest['notice'].update(enabled=True,id='firefly-level2-200mb-v1',
        title={'zh-Hant':'螢光秘林更新測試','en':'Firefly woodland update test','yue-HK':'螢光秘林更新測試'},
        body={'zh-Hant':'新增第 2 關螢光秘林、晚間營地圖片及兩首原創 MP3。此測試包超過 200 MB，建議使用 Wi-Fi。第 1 關通關後即可挑戰第 2 關。',
              'en':'Level 2, twilight camp art and two original MP3 soundtracks. This test download exceeds 200 MB; Wi-Fi is recommended. Clear level 1 to reach level 2.',
              'yue-HK':'新增第 2 關螢光秘林、晚間營地圖片同兩首原創 MP3。測試包超過 200 MB，建議用 Wi-Fi。過第 1 關後就可以挑戰第 2 關。'})
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n', encoding='utf-8')
    validate(manifest_path)
    args.zip.parent.mkdir(parents=True,exist_ok=True)
    with ZipFile(args.zip,'w',ZIP_STORED) as archive:
        for path in sorted(args.site.rglob('*')):
            if path.is_file(): archive.write(path,path.relative_to(args.site).as_posix())
    report = {'version':VERSION,'minimumClientBuild':21,'bytes':total,'MiB':round(total/1024**2,2),
              'files':len(files),'zipBytes':args.zip.stat().st_size,'zipSha256':sha(args.zip),
              'site':str(args.site.resolve()),'zip':str(args.zip.resolve())}
    (args.zip.parent / 'level2-package-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n', encoding='utf-8')
    shutil.copyfile(manifest_path,args.zip.parent / 'update-v1-level2-build21.json')
    print(json.dumps(report,ensure_ascii=False,indent=2))


if __name__ == '__main__': main()
