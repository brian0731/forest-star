"""Extract the twenty original APIXGo pets, preserving soft alpha at the edges."""
from pathlib import Path
import json
import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'output/imagegen/pets-v1'
DEST = ROOT / 'assets/pets'
PREVIEW = ROOT / 'output/preview/pets-v1'
DEST.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)
names = ['花刺蝟','蜜果熊','櫻角鹿','暮羽鴞','橡果松鼠','雪團企鵝','珊瑚螈','葉隱龍',
         '楓尾熊貓','日葵犬','雲朵象','桃貝海豹','荷葉蛙','星翼蝠','鈴絨羊駝','霜角鯨',
         '青鱗穿山甲','莓尾貂','桃羽紅鶴','晶芽幼龍']
overview = Image.new('RGB', (1200, 1072), '#edf2e0')
draw = ImageDraw.Draw(overview)
font = ImageFont.truetype(str(ROOT/'assets/fonts/NotoSansTC.ttf'), 18)
report = []
for sheet_index in range(5):
    sheet = Image.open(SOURCE/f'sheet-{sheet_index}.png').convert('RGBA')
    for cell in range(4):
        box = (cell%2*sheet.width//2, cell//2*sheet.height//2,
               (cell%2+1)*sheet.width//2, (cell//2+1)*sheet.height//2)
        cut = sheet.crop(box)
        arr = np.asarray(cut).copy()
        rgb = arr[:,:,:3].astype(float)
        candidate = (arr[:,:,3] == 0) | ((rgb.min(axis=2)>243)&(rgb.max(axis=2)-rgb.min(axis=2)<12))
        labels,_ = ndimage.label(candidate)
        border = np.unique(np.concatenate([labels[0],labels[-1],labels[:,0],labels[:,-1]]))
        background = np.isin(labels,border[border!=0])
        alpha = arr[:,:,3].astype(float)/255
        alpha[background] = 0
        # Remove isolated matte noise while retaining the main character's detail.
        parts,count = ndimage.label(alpha>.05)
        for part in range(1,count+1):
            if np.count_nonzero(parts==part)<45:
                alpha[parts==part]=0
        distance,nearest = ndimage.distance_transform_edt(alpha<.5,return_indices=True)
        foreground = rgb[tuple(nearest)]
        edge = (distance<=2)&(alpha<.5)&(arr[:,:,3]>0)
        coverage = np.linalg.norm(255-rgb,axis=2)/np.maximum(np.linalg.norm(255-foreground,axis=2),1)
        alpha[edge]=np.clip(coverage[edge],0,1)
        rgb[edge]=foreground[edge]
        arr[:,:,:3]=np.clip(rgb,0,255).astype('uint8')
        arr[:,:,3]=(alpha*255).astype('uint8')
        cut=Image.fromarray(arr)
        bounds=cut.getchannel('A').point(lambda a:255 if a>8 else 0).getbbox()
        if bounds is None: raise RuntimeError(f'Empty pet: {sheet_index}/{cell}')
        cut=cut.crop(bounds)
        cut.thumbnail((480,480),Image.Resampling.LANCZOS)
        sprite=Image.new('RGBA',(512,512))
        sprite.alpha_composite(cut,((512-cut.width)//2,500-cut.height))
        index=sheet_index*4+cell
        sprite.save(DEST/f'character-{index+6}.png',optimize=True)
        a=np.asarray(sprite.getchannel('A'))
        assert a[0].max()==a[-1].max()==a[:,0].max()==a[:,-1].max()==0
        report.append({'id':index+6,'name':names[index],'bounds':sprite.getbbox(),
                       'transparentFraction':float((a==0).mean())})
        tile=Image.new('RGBA',(240,240),'#426348')
        td=ImageDraw.Draw(tile)
        for y in range(0,240,20):
            for x in range(0,240,20):
                if (x//20+y//20)%2: td.rectangle((x,y,x+19,y+19),fill='#4b7051')
        preview=sprite.resize((220,220),Image.Resampling.LANCZOS)
        tile.alpha_composite(preview,(10,10))
        x=index%5*240; y=index//5*268
        overview.paste(tile.convert('RGB'),(x,y))
        draw.text((x+120,y+252),names[index],font=font,fill='#35563c',anchor='mm')
overview.save(PREVIEW/'new-pets.png')
(PREVIEW/'alpha-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
prompts='# Twenty new pet sprites\n\nAPIXGo openai group; `gpt-image-2.5-flare`; imagegen fallback CLI edit mode. Existing companions used only as a style reference.\n\n'
for index in range(5):
    prompts+=f'## Sheet {index+1}\n\n'+(SOURCE/f'prompt-{index}.txt').read_text(encoding='utf-8')+'\n\n'
prompts+='Post-processing: split 2×2 quadrants, remove connected near-white matte, preserve cream fur and alpha edges, crop and pad each full-body sprite to 512×512. Runtime assets: `assets/pets/character-6.png` through `character-25.png`.\n'
(ROOT/'docs/PET_ART_PROMPTS.md').write_text(prompts,encoding='utf-8')
print(f'Prepared {len(report)} transparent pets and {PREVIEW / "new-pets.png"}')
