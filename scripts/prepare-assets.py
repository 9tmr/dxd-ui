"""Optimize existing media only. Optional authoring dependency: Pillow 12.3.0."""
from pathlib import Path
import json
from PIL import Image, ImageOps
ROOT = Path(__file__).resolve().parents[1]
SIZE = (400, 224)
manifest = {}
def save(im, name):
    path = ROOT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    im.quantize(colors=128).save(path, optimize=True)
    return name
def still(key, filename, crop=None):
    with Image.open(ROOT / 'assets/source' / filename) as im:
        if crop: im = im.crop(crop)
        im = ImageOps.fit(im.convert('RGB'), SIZE, Image.Resampling.LANCZOS, centering=(0.5, 0))
        name = save(im, f'assets/characters/{key}-ui.png')
    manifest[key] = {'width':400,'height':224,'frames':[{'file':name,'duration':1}]}
def animation(key, filename, crop=None):
    frames, boundaries, total = [], [], 0
    with Image.open(ROOT / 'assets/source' / filename) as gif:
        for index in range(gif.n_frames):
            gif.seek(index)
            im = gif.convert('RGB')
            if crop: im = im.crop(crop)
            frames.append(ImageOps.fit(im, SIZE, Image.Resampling.LANCZOS, centering=(0.5,0)))
            total += max(20, gif.info.get('duration',100))
            boundaries.append(total)
    count = max(1, int(total/1000*12))
    output = []
    for index in range(count):
        source_index = next(i for i,end in enumerate(boundaries) if end > index*total/count)
        name = save(frames[source_index], f'assets/animations/{key}/{index:02d}.png')
        output.append({'file':name,'duration':total/count/1000})
    manifest[key] = {'width':400,'height':224,'frames':output}
    for suffix,index in [('still',0),('end',len(frames)-1)]:
        name = save(frames[index], f'assets/characters/{key}-{suffix}.png')
        manifest[key+'_'+suffix] = {'width':400,'height':224,'frames':[{'file':name,'duration':1}]}
def sprite(key):
    # Crop/extract the existing sprite. Original poster and attribution retained.
    # No character pixels are painted or reconstructed.
    with Image.open(ROOT / f'assets/source/{key}-pixel.png') as original:
        im = original.convert('RGBA').crop((0,0,745,984))
    pixels=im.load()
    colors=[(255,224,5),(231,0,21),(172,204,7),(230,82,152)]
    for y in range(im.height):
        for x in range(im.width):
            r,g,b,a=pixels[x,y]
            neutral=94<r<245 and max(r,g,b)-min(r,g,b)<5
            colored=any(max(abs(r-c[0]),abs(g-c[1]),abs(b-c[2]))<5 for c in colors)
            if neutral or colored or (x<153 and y>=928): pixels[x,y]=(r,g,b,0)
    # Flood only exterior neutral poster regions; retain interior wing/clothing pixels.
    seen=set(); queue=[(xx,0) for xx in range(im.width)]+[(xx,im.height-1) for xx in range(im.width)]+[(0,yy) for yy in range(im.height)]+[(im.width-1,yy) for yy in range(im.height)]
    while queue:
        xx,yy=queue.pop()
        if (xx,yy) in seen: continue
        seen.add((xx,yy)); r,g,b,a=pixels[xx,yy]
        if a==0 or (20<r<245 and max(r,g,b)-min(r,g,b)<5):
            pixels[xx,yy]=(r,g,b,0)
            for nx,ny in ((xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)):
                if 0<=nx<im.width and 0<=ny<im.height and (nx,ny) not in seen: queue.append((nx,ny))
    im=im.crop(im.getbbox())
    im.thumbnail((150,180),Image.Resampling.NEAREST)
    # Discard isolated background speckles after nearest-neighbor resizing.
    mask=im.getchannel('A'); seen=set(); components=[]
    for yy in range(im.height):
        for xx in range(im.width):
            if (xx,yy) in seen or mask.getpixel((xx,yy))<128: continue
            group=[]; queue=[(xx,yy)]; seen.add((xx,yy))
            while queue:
                u,v=queue.pop(); group.append((u,v))
                for nx,ny in ((u-1,v),(u+1,v),(u,v-1),(u,v+1)):
                    if 0<=nx<im.width and 0<=ny<im.height and (nx,ny) not in seen and mask.getpixel((nx,ny))>=128:
                        seen.add((nx,ny));queue.append((nx,ny))
            components.append(group)
    keep=set(max(components,key=len)); alpha=Image.new('L',im.size)
    for xy in keep: alpha.putpixel(xy,255)
    im.putalpha(alpha)
    name=save(im,f'assets/characters/{key}-sprite.png')
    manifest[key+'_pixel']={'width':im.width,'height':im.height,'frames':[{'file':name,'duration':1}]}
still('akeno','akeno-uniform.jpg')
still('akeno_evening','akeno-evening.jpg')
still('akeno_sky','akeno-sky.jpg',(0,0,736,480))
animation('rias','rias.gif')
animation('akeno_motion','akeno.gif',(115,0,360,140))
sprite('rias')
sprite('akeno')
(ROOT/'assets/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(f'Prepared {len(manifest)} media entries from existing artwork.')
