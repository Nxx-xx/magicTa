"""Review exact source/draft SHA, then publish immutable A knight resources separately."""
import argparse, hashlib, json, shutil
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'assets/characters/mysterious_knight/art_polish_a_v03'
OUT = ROOT/'build/verification/art-polish-a'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
parser=argparse.ArgumentParser()
parser.add_argument('--approve-reviewed-draft')
parser.add_argument('--publish',action='store_true')
args=parser.parse_args()
draft=read(BASE/'source/draft_manifest.json')
assert draft['status']=='draft' and draft['fps']==4 and len(draft['frames'])==8
assert draft['anchor']==[128,217.389022827148] and draft['events']=={}
seen=set()
sheet=Image.new('RGB',(1024,650),'#223239'); d=ImageDraw.Draw(sheet)
for i,ref in enumerate(draft['frames']):
 im=Image.open(BASE/ref).convert('RGBA')
 assert im.size==(256,256) and im.getpixel((0,0))[3]==0
 bbox=im.getchannel('A').getbbox(); assert bbox and bbox[0]>4 and bbox[1]>4 and bbox[2]<252 and bbox[3]<252
 digest=hashlib.sha256(im.tobytes()).hexdigest(); assert digest not in seen,('duplicate',i);seen.add(digest)
 sheet.paste(im,(i%4*256,i//4*280),im);d.text((i%4*256+8,i//4*280+255),f'frame {i} / 4 fps',fill='white')
 for j,size in enumerate([26,33,47]):
  small=im.resize((size,size),Image.Resampling.LANCZOS)
  sheet.paste(small,(i*128+6+j*37,586),small)
sheet.save(OUT/'knight_contact.png')
timing_path=OUT/'native/timing.json'
review_path=BASE/'source/visual_review.json'
if args.approve_reviewed_draft:
 assert args.approve_reviewed_draft==sha(BASE/'source/draft_manifest.json'),'stale draft'
 timing=read(timing_path); assert len(timing['samples'])==16
 assert timing['source_sha256']==sha(BASE/'source/art_polish_a_knight_editable.tscn')
 paths=list((BASE/'source').glob('art_polish_a_*'))+[BASE/'source/draft_manifest.json']+[BASE/p for p in draft['frames']]+[BASE/'source/draft/portrait.png']
 review={'approved_for_publish':True,'human_signoff':False,'reviewer':'Codex A visual review','date':'2026-10-03','draft_sha256':args.approve_reviewed_draft,'timing_sha256':sha(timing_path),'files':{p.relative_to(BASE).as_posix():sha(p) for p in paths},'evidence':{'knight_contact.png':sha(OUT/'knight_contact.png')},'scope':'Painted native layers, feet and sword planted, original and quarter speed samples and 26/33/47px contact sheet. Final coordinator/client approval remains separate.'}
 review_path.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print('Explicit visual approval recorded',review['draft_sha256'])
if args.publish:
 review=read(review_path)
 assert review['approved_for_publish'] and review['draft_sha256']==sha(BASE/'source/draft_manifest.json')
 assert review['timing_sha256']==sha(timing_path)
 for p,h in review['files'].items(): assert sha(BASE/p)==h,('changed reviewed file',p)
 dest=BASE/'textures';dest.mkdir(exist_ok=True)
 for src in [BASE/p for p in draft['frames']]+[BASE/'source/draft/portrait.png']:
  target=dest/src.name
  if target.exists(): assert sha(target)==sha(src),'immutable publication'
  else: shutil.copy2(src,target)
 manifest={**draft,'status':'accepted','review_sha256':sha(review_path),'frames':['textures/'+Path(p).name for p in draft['frames']]}
 (BASE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
 print('A knight published into independent textures; old resources preserved')
print('Draft SHA256:',sha(BASE/'source/draft_manifest.json'))
