"""Verify exact preservation and encode actual host captures; no asset approval."""
import hashlib,json,shutil
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification/phase3/09-refinement/golem'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
b=read(OUT/'baseline.json');m=read(ROOT/'assets/monsters/phase3/manifest.json')
other={k:v for k,v in b['manifest']['actions'].items() if not k.startswith('golem_')}
assert other=={k:v for k,v in m['actions'].items() if not k.startswith('golem_')}
assert {k:v for k,v in b['manifest'].items() if k not in ['actions','golem_stone_armor']}=={k:v for k,v in m.items() if k not in ['actions','golem_stone_armor']}
checks={p:sha(ROOT/p)==h for p,h in b['hashes'].items()}
# A concurrent authorized hero refinement owns its manifest. Report independently.
hero='assets/characters/hero/phase3/manifest.json'
assert all(v for k,v in checks.items() if k!=hero)
record={'other_enemy_metadata_unchanged':True,'manifest_root_fields_unchanged':True,'all_old_texture_and_protected_code_hashes':checks,
    'concurrent_hero_manifest_unchanged':checks.get(hero),'human_signoff':False}
review=read(ROOT/'assets/monsters/phase3/source/golem_v06/golem_publish_review.json')
published={}
for name,a in review['actions'].items():
    current=m['actions']['golem_'+name]
    for field in ['fps','loop','events','size','anchor','pose_holds']:assert current[field]==a[field],(name,field)
    for channel,key in [('frames','frame_sha256'),('effects_frames','effects_sha256')]:
        assert [sha(ROOT/p.replace('res://','')).lower() for p in current.get(channel,[])]==a[key]
        published.update({p:sha(ROOT/p.replace('res://','')) for p in current.get(channel,[])})
record.update(reviewed_published_frame_sha256=published,all_26_timelines_match_exact_review=True)
(OUT/'preservation.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
for p in (ROOT/'build/verification/phase3/08-parallel/golem_refine').glob('*.log'):shutil.copyfile(p,OUT/p.name)
for p in (ROOT/'build/verification/phase3/08-parallel/golem_refine').glob('*-result.json'):shutil.copyfile(p,OUT/p.name)
host=read(OUT/'host/results.json')
stages=[s['stone_armor_stage'] for s in host['samples']]
assert stages==sorted(stages) and set(stages)==set(range(5)),stages
assert host['checks']>300 and not host['failures']
assert host['boss_peak_cache_bytes']<=8*1024*1024
frames=[Image.open(p).convert('RGBA') for p in sorted((OUT/'host/frames').glob('*.png'))]
frames[0].save(OUT/'host/main-game-replay.webp',save_all=True,append_images=frames[1:],duration=50,loop=0,lossless=True)
grid=Image.new('RGB',(1080,960),'#21323b');draw=ImageDraw.Draw(grid)
indices=[]
for stage in range(5):indices.append(next(i for i,s in enumerate(stages) if s==stage))
indices.append(len(stages)-1)
for i,idx in enumerate(indices):
    im=frames[idx].resize((360,640),Image.Resampling.LANCZOS)
    # Contact evidence preserves UI areas; full originals and animation retained.
    im.thumbnail((360,450),Image.Resampling.LANCZOS)
    grid.paste(im,((i%3)*360,(i//3)*480+25));draw.text(((i%3)*360+4,(i//3)*480+4),f'frame {idx}, stage {stages[idx]}',fill='white')
grid.save(OUT/'host/sequence_contact.png')
print(f'Preserved {len(other)} other enemy actions and {len(checks)} old resource/protected hashes; real host rendered stages 0..4')
