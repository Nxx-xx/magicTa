"""Preserved native articulation, runtime contracts and source provenance."""
import argparse, copy, hashlib, json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/monsters/phase3/source/art_polish_b_v07'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
routes=read(SRC/'art_polish_b_routes.json');checks=0
parser=argparse.ArgumentParser()
parser.add_argument('--production',action='store_true')
args=parser.parse_args()
for old,new in routes.items():
    a=read(ROOT/old.removeprefix('res://'));b=read(ROOT/new.removeprefix('res://'))
    b.pop('art_polish')
    for l in b['layers']:
        l.pop('art_scale',None);l.pop('art_material',None)
    assert a==b,old
    checks+=1
candidate=read(ROOT/'assets/monsters/phase3/art_polish_b_candidate.json')
baseline=read(ROOT/'build/verification/art-polish-b/baseline-manifest.json')
production=read(ROOT/'assets/monsters/phase3/manifest.json')
if args.production:
    review_path=SRC/'art_polish_b_coordinator_review.json'
    review=read(review_path)
    assert review['candidate_sha256']==sha(ROOT/'assets/monsters/phase3/art_polish_b_candidate.json')
    assert review['decision']=='accepted' and review['reviewer_role']=='coordinator' and review['human_signoff'] is False
    expected=copy.deepcopy(baseline)
    inventory=read(SRC/'art_polish_b_review_inventory.json')
    assert set(review['approved_actions'])==set(inventory)
    for key,record in inventory.items():
        action=copy.deepcopy(candidate['actions'][key])
        action.update(status='accepted',publish_review='assets/monsters/phase3/source/art_polish_b_v07/art_polish_b_publish_review.json',coordinator_review=review_path.relative_to(ROOT).as_posix())
        expected['actions'][key]=action
        for channel,hashes in record['channels'].items():
            assert [sha(ROOT/p.removeprefix('res://')) for p in action[channel]]==hashes,(key,channel)
    if any('/art_polish_b_v08/' in a['source'] for a in production['actions'].values()):
        assert read(ROOT/'build/verification/art-polish-b-v08/baseline-manifest.json')==expected,'v08 must start at the exact reviewed v07 publication'
        v08_src=ROOT/'assets/monsters/phase3/source/art_polish_b_v08'
        v08_candidate=read(ROOT/'assets/monsters/phase3/art_polish_b_v08_candidate.json')
        v08_review=read(v08_src/'art_polish_b_coordinator_review.json')
        assert v08_review['candidate_sha256']==sha(ROOT/'assets/monsters/phase3/art_polish_b_v08_candidate.json')
        assert v08_review['decision']=='accepted' and v08_review['human_signoff'] is False
        for key,record in read(v08_src/'art_polish_b_review_inventory.json').items():
            action=copy.deepcopy(v08_candidate['actions'][key])
            action.update(status='accepted',publish_review=(v08_src/'art_polish_b_publish_review.json').relative_to(ROOT).as_posix(),coordinator_review=(v08_src/'art_polish_b_coordinator_review.json').relative_to(ROOT).as_posix())
            expected['actions'][key]=action
            for channel,hashes in record['channels'].items():
                assert [sha(ROOT/p.removeprefix('res://')) for p in action[channel]]==hashes,(key,channel)
    assert production==expected,'Production must exactly match the reviewed replacements and preserve all baseline root fields'
else:
    assert production==baseline
for key,a in candidate['actions'].items():
    if a['status']!='draft':continue
    b=baseline['actions'][key]
    for field in ('fps','loop','events','anchor','size'):assert a[field]==b[field],(key,field)
    assert a.get('pose_holds',{})==b.get('pose_holds',{})
    pixels=[]
    for path in a['frames']:
        with Image.open(ROOT/path.removeprefix('res://')) as im:
            assert im.mode=='RGBA' and list(im.size)==a['size']
            pixels.append(hashlib.sha256(im.tobytes()).hexdigest())
    for i,j in a.get('pose_holds',{}).items():assert pixels[int(i)]==pixels[int(j)],(key,'hold')
    checks+=1
native=list((ROOT/'build/verification/art-polish-b/native').glob('*/timing.json'))
assert len(native)==26
for p in native:
    d=read(p)
    for field in ('draft','rig','scene'):assert sha(ROOT/d[field].removeprefix('res://'))==d[field+'_sha256']
    assert {x['speed'] for x in d['observations']}=={1.0,.25}
    checks+=1
print(f'B contracts: {checks} source/action/native checks passed; '+('exact reviewed production published' if args.production else 'production unchanged'))
