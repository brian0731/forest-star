"""Prepare the approved APIXGo title art as project assets with clean alpha."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'output/imagegen/start-adventure-v1'
OUTPUT=ROOT/'assets/start'
OUTPUT.mkdir(parents=True,exist_ok=True)
im=Image.open(SOURCE/'button.png').convert('RGBA')
pixels=np.asarray(im).copy()
rgb=pixels[:,:,:3].astype(np.float32)
candidate=(pixels[:,:,3]==0)|((rgb.min(axis=2)>230)&((rgb.max(axis=2)-rgb.min(axis=2))<26))
labels,_=ndimage.label(candidate)
edge_labels=np.unique(np.concatenate([labels[0],labels[-1],labels[:,0],labels[:,-1]]))
edge_labels=edge_labels[edge_labels!=0]
background=np.isin(labels,edge_labels)
alpha=pixels[:,:,3].astype(np.float32)/255
alpha[background]=0
solid=alpha>.5
distance,nearest=ndimage.distance_transform_edt(~solid,return_indices=True)
foreground=rgb[tuple(nearest)]
# Recover anti-aliased edge coverage from the original white matte.
edge=(distance<=2)&(~solid)&(pixels[:,:,3]>0)
denominator=np.linalg.norm(255-foreground,axis=2)
coverage=np.divide(np.linalg.norm(255-rgb,axis=2),np.maximum(denominator,1))
alpha[edge]=np.clip(coverage[edge],0,1)
rgb[edge]=foreground[edge]
pixels[:,:,:3]=np.clip(rgb,0,255).astype(np.uint8)
pixels[:,:,3]=(alpha*255).astype(np.uint8)
result=Image.fromarray(pixels)
box=result.getchannel('A').point(lambda x:255 if x>8 else 0).getbbox()
result=result.crop((max(0,box[0]-5),max(0,box[1]-5),min(im.width,box[2]+5),min(im.height,box[3]+5)))
result.thumbnail((1050,320),Image.Resampling.LANCZOS)
result.save(OUTPUT/'adventure-button-v1.png',optimize=True)
Image.open(SOURCE/'background.png').convert('RGB').save(OUTPUT/'forest-stage-v1.webp',quality=91,method=6)
prompt='# Start-screen art prompts\n\nGenerated through APIXGo openai group, model `gpt-image-2.5-flare`, with the imagegen skill CLI.\n\n'
for name in ['prompt','background-prompt']:
    prompt+='## '+name+'\n\n'+(SOURCE/(name+'.txt')).read_text(encoding='utf-8')+'\n'
prompt+='\nPost-processing: remove the connected white matte from the generated button, preserve the coloured silhouette and alpha edges, crop transparent margins, retain text as a native Flutter overlay. Background converted to WebP.\n'
(ROOT/'docs/START_SCREEN_ART_PROMPTS.md').write_text(prompt,encoding='utf-8')
print(json.dumps({'buttonSize':result.size,'alphaRange':result.getchannel('A').getextrema(),
    'button':str(OUTPUT/'adventure-button-v1.png'),'background':str(OUTPUT/'forest-stage-v1.webp')}))
