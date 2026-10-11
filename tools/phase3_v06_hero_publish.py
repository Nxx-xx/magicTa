"""Explicit visual review SHA record and separate immutable hero-only publication."""
import argparse,hashlib,json,shutil
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/characters/hero/phase3/source/refine_v06'
OUT=ROOT/'build/verification/phase3/09-refinement/hero'
ASSET=ROOT/'assets/characters/hero/phase3'
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def local(ref): return ROOT/ref.removeprefix('res://')
def checked():
 draft=read(SOURCE/'draft_manifest.json')
 assert draft['status']=='draft' and draft['mirrored'] is False
 assert len(draft['actions'])==18
 for name,a in draft['actions'].items():
  count,fps,loop=({'idle':(4,6,True),'walk':(6,12,True),'interact':(4,10,False)}[name.split('_')[1]] if name.startswith('map_') else {'idle':(6,6,True),'attack':(8,16,False),'guard':(4,12,False),'hit':(3,12,False),'victory':(8,12,False),'defeat':(6,10,False)}[name.split('_')[1]])
  assert (len(a['frames']),a['fps'],a['loop'])==(count,fps,loop),name
  assert len(a['effects_frames'])==count
  size=128 if name.startswith('map_') else 384
  assert a['size']==[size,size] and a['anchor']==[size//2,116 if size==128 else 348]
  assert a['events']==({'hit':3} if name=='combat_attack' else {})
  seen={}
  for i,p in enumerate(a['frames']):
   image=Image.open(local(p)).convert('RGBA')
   assert image.size==(size,size)
   bbox=image.getchannel('A').getbbox()
   assert bbox and bbox[0]>=4 and bbox[1]>=4 and bbox[2]<=size-4 and bbox[3]<=size-4,(name,i,bbox)
   pixels=hashlib.sha256(image.tobytes()).hexdigest()
   assert pixels not in seen,(name,'undeclared duplicate',i,seen.get(pixels))
   seen[pixels]=i
   effect=Image.open(local(a['effects_frames'][i])).convert('RGBA')
   assert effect.size==image.size
   assert all(e['sword_error']<.001 and e['lamp_error']<.001 for e in a['grip_errors_source_px'])
  if name.startswith('map_walk_'):
   contacts=a['foot_contacts_map_px']
   assert all(abs(contacts[i][foot][1]-116)<=1 for i in [0,3] for foot in ['right','left']),name
   assert contacts[1]['left'][1]<115 and contacts[4]['right'][1]<115,name
 return draft
parser=argparse.ArgumentParser()
parser.add_argument('--approve-reviewed-draft',metavar='EXACT_SHA256')
parser.add_argument('--publish',action='store_true')
args=parser.parse_args()
draft=checked()
review_path=SOURCE/'visual_review.json'
if args.approve_reviewed_draft:
 assert args.approve_reviewed_draft==sha(SOURCE/'draft_manifest.json'),'Stale draft approval'
 timing=read(OUT/'native/timing.json')
 assert timing['draft_sha256']==args.approve_reviewed_draft
 assert timing['author_sha256']==sha(ROOT/'tools/phase3_v06_hero_bake.gd')
 assert timing['capture_sha256']==sha(ROOT/'tools/phase3_v06_hero_playback.gd')
 assert len(timing['observations'])==182
 for p,digest in timing['scenes'].items(): assert sha(local(p))==digest
 approved={'date':'2026-10-02','reviewer':'Codex visual inspection in hero refinement chat','human_signoff':False,'approved_for_publish':True,'draft_sha256':args.approve_reviewed_draft,'native_timing_sha256':sha(OUT/'native/timing.json'),'scenes':timing['scenes'],'scope':'Final body/effect contact sheets, 26/33/47px, actual timed AnimationPlayer samples at 1x and 0.25x inspected. No continuous-video perception, human playtest or device acceptance claimed.','actions':{}}
 for name,a in draft['actions'].items():
  approved['actions'][name]={k:a[k] for k in ['fps','loop','size','anchor','events','pose_holds','source','review']}
  approved['actions'][name]['frames']=[{'path':p,'sha256':sha(local(p))} for p in a['frames']]
  approved['actions'][name]['effects_frames']=[{'path':p,'sha256':sha(local(p))} for p in a['effects_frames']]
 approved['evidence']={}
 for p in list(OUT.glob('*contact.png'))+list(OUT.glob('*effects.png'))+list(OUT.glob('*small.png'))+list((OUT/'native').glob('*contact.png')):
  approved['evidence'][p.relative_to(ROOT).as_posix()]=sha(p)
 review_path.write_text(json.dumps(approved,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print('Explicit reviewed SHA recorded:',approved['draft_sha256'])
if args.publish:
 approved=read(review_path)
 assert approved['approved_for_publish'] is True and approved['human_signoff'] is False
 assert approved['draft_sha256']==sha(SOURCE/'draft_manifest.json')
 assert approved['native_timing_sha256']==sha(OUT/'native/timing.json')
 for p,digest in approved['scenes'].items(): assert sha(local(p))==digest
 manifest=read(ASSET/'manifest.json')
 before=manifest.copy()
 for name,a in draft['actions'].items():
  entry=manifest['actions'].get(name,{}).copy()
  entry.update({k:a[k] for k in ['fps','loop','size','anchor','events','pose_holds','source','review']})
  entry.update(status='accepted',review_sha256=sha(review_path))
  for field in ['frames','effects_frames']:
   entry[field]=[]
   for i,frame in enumerate(approved['actions'][name][field]):
    source=local(frame['path']);assert sha(source)==frame['sha256'],'Changed approved frame'
    dest=ASSET/'textures/v06'/name/('effects' if field=='effects_frames' else 'body')/f'{i:02d}.png'
    dest.parent.mkdir(parents=True,exist_ok=True)
    if dest.exists(): assert sha(dest)==frame['sha256'],'Refusing different bytes in published v06'
    else: shutil.copy2(source,dest)
    entry[field].append('res://'+dest.relative_to(ROOT).as_posix())
  manifest['actions'][name]=entry
 manifest['status']='accepted_v06'
 manifest['source']='source/refine_v06/REVIEW.md'
 temporary=ASSET/'manifest.v06.tmp'
 temporary.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 temporary.replace(ASSET/'manifest.json')
 print('Hero-only publication: 18 accepted actions; 91 body + 91 optional FX frame positions; old PNGs retained')
if not args.publish and not args.approve_reviewed_draft: print('Draft structure/pixels/contacts/grips valid; SHA',sha(SOURCE/'draft_manifest.json'))
