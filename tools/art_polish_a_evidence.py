"""Compose existing source/runtime evidence; never edit production pixel assets."""
from pathlib import Path
import hashlib,json,zipfile,io,re
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification/art-polish-a';OUT.mkdir(parents=True,exist_ok=True)
BASE=ROOT/'assets/characters/mysterious_knight/art_polish_a_v03'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def contact(paths,dest,cell=(128,160),columns=8):
 sheet=Image.new('RGB',(columns*cell[0],((len(paths)+columns-1)//columns)*cell[1]),'#233138')
 draw=ImageDraw.Draw(sheet)
 for i,p in enumerate(paths):
  im=Image.open(p).convert('RGBA');im.thumbnail((cell[0],cell[1]-22),Image.Resampling.LANCZOS)
  x=i%columns*cell[0];y=i//columns*cell[1]
  sheet.paste(im,(x+(cell[0]-im.width)//2,y),im)
  draw.text((x+4,y+cell[1]-18),p.stem,fill='white')
 sheet.save(dest)
native=sorted((OUT/'native').glob('knight*.png'))
if native: contact(native,OUT/'native_contact.png',(192,215))
hero=json.loads((ROOT/'assets/characters/hero/phase3/manifest.json').read_text())
for kind in ['map','combat']:
 actions=[(k,v) for k,v in hero['actions'].items() if k.startswith(kind)]
 sheet=Image.new('RGB',(1024,len(actions)*158),'#233138');draw=ImageDraw.Draw(sheet)
 for row,(name,action) in enumerate(actions):
  draw.text((8,row*158+2),name,fill='#e0c68e')
  for i,p in enumerate(action['frames']):
   im=Image.open(ROOT/p.removeprefix('res://')).convert('RGBA');im.thumbnail((124,128),Image.Resampling.LANCZOS)
   sheet.paste(im,(i*128,row*158+22),im)
 sheet.save(OUT/f'hero_{kind}_contact.png')
for width in [320,390,540]:
 paths=[OUT/f'{stage}/near_{width}.png' for stage in ['before','after']]
 if all(p.exists() for p in paths):
  images=[Image.open(p).convert('RGB') for p in paths]
  sheet=Image.new('RGB',(width*2,max(i.height for i in images)+24),'#15242b');draw=ImageDraw.Draw(sheet)
  for x,(im,label) in enumerate(zip(images,['BEFORE','AFTER'])):
   draw.text((x*width+8,5),label,fill='white');sheet.paste(im,(x*width,24))
  sheet.save(OUT/f'comparison_{width}.png')
baseline=json.loads((OUT/'preserved-baseline.json').read_text())
preservation={'files':len(baseline),'mismatches':[p for p,h in baseline.items() if sha(ROOT/p)!=h]}
(OUT/'preservation.json').write_text(json.dumps(preservation,indent=2))
new=list((BASE/'textures').glob('*.png'));old=list((ROOT/'assets/characters/mysterious_knight/textures').glob('*.png'))
def zip_bytes(paths):
 mem=io.BytesIO()
 with zipfile.ZipFile(mem,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for p in paths:z.write(p,p.name)
 return len(mem.getvalue())
if new:
 budget={'scope':'PNG and desktop imported ctex DEFLATE estimate; not final WeChat export size','new_png_bytes':sum(p.stat().st_size for p in new),'new_png_zip_bytes':zip_bytes(new),'old_png_zip_bytes':zip_bytes(old),'replacement_delta_bytes':zip_bytes(new)-zip_bytes(old),'new_paths':[p.relative_to(ROOT).as_posix() for p in new]}
 for kind,folder in [('new',BASE/'textures'),('old',ROOT/'assets/characters/mysterious_knight/textures')]:
  payloads=[]
  for sidecar in folder.glob('*.png.import'):
   found=re.search(r'^path="res://([^"]+)"',sidecar.read_text(encoding='utf-8-sig'),re.M)
   if found:payloads.append(ROOT/found[1])
  if payloads:budget['desktop_imported_'+kind]={'count':len(payloads),'raw_bytes':sum(p.stat().st_size for p in payloads),'zip_bytes':zip_bytes(payloads)}
 if 'desktop_imported_new' in budget and 'desktop_imported_old' in budget:
  budget['desktop_imported_replacement_delta']=budget['desktop_imported_new']['zip_bytes']-budget['desktop_imported_old']['zip_bytes']
 (OUT/'asset-budget.json').write_text(json.dumps(budget,indent=2))
print('Evidence sheets and preserved-source hashes updated',preservation)
