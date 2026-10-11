"""Follow-up dark-material/identity refinement; immutable v07 and exact-SHA gate."""
import argparse, copy, hashlib, json, shutil
from pathlib import Path
import art_polish_b_stage as stage
import art_polish_b_sheets as sheets
import art_polish_b_publish as publish

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/monsters/phase3/source/art_polish_b_v08'
OUT=ROOT/'build/verification/art-polish-b-v08'
CANDIDATE=ROOT/'assets/monsters/phase3/art_polish_b_v08_candidate.json'
ENTITIES={'warlock','p3_ember_channeler','warden','knight','p3_vault_knight','berserker'}
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,d): p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def prepare():
    baseline=OUT/'baseline-manifest.json'
    if baseline.exists(): raise RuntimeError('Existing v08 baseline is immutable; use a new revision')
    OUT.mkdir(parents=True,exist_ok=True);SRC.mkdir(parents=True,exist_ok=True);(SRC/'.gdignore').touch()
    shutil.copy2(ROOT/'assets/monsters/phase3/manifest.json',baseline)
    routes={}
    for source in sorted({a['source'] for a in read(baseline)['actions'].values()}):
        origin=ROOT/source.removeprefix('res://');d=read(origin)
        entity=d['entity'].removesuffix('_map');is_map=d['entity'].endswith('_map')
        if entity not in ENTITIES:continue
        dest=SRC/entity/('map' if is_map else 'battle');dest.mkdir(parents=True,exist_ok=True)
        refs={d['source']}|{l['source'] for l in d['layers'] if 'source' in l}
        for shapes in d.get('shape_layers',{}).values():refs.update(s['source'] for s in shapes)
        for ref in refs:
            target=dest/ref;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(origin.parent/ref,target)
        effects=set(d.get('effect_layers',[]));changed=[]
        for l in d['layers']:
            n=l['name']
            if l.get('joint_only') or n in effects:continue
            if entity in ('warlock','p3_ember_channeler'):
                cloth=n in ('hood','head','torso','skirt','cape','near_upper_arm','near_forearm','far_upper_arm','far_forearm','right_arm','left_arm')
                if cloth:
                    # Lift cloth locally; retain warmer metal trim and a darker hood cavity.
                    lift=(.047 if is_map else .115)
                    if n in ('hood','head'):lift=.04 if is_map else .083
                    l['art_material']={'shadow_lift':lift,'cool_mix':.055}
                    if not is_map and n in ('torso','skirt'):l['art_scale']=[1.18 if n=='torso' else 1.12,1.0]
                    if is_map and n=='head':l['art_scale']=[1.06,1.0]
                    changed.append(n)
                if n in ('staff','weapon','furnace_collar','furnace_ring','trident_head'):
                    l['art_material']={'shadow_lift':.035,'cool_mix':.015};changed.append(n)
            else:
                if n in ('sword','axe','weapon','mace','chain','key_crown','ornament'):
                    l['art_material']={'shadow_lift':.025,'cool_mix':.025};changed.append(n)
                elif n not in ('shadow','impact_spark','weapon_trail','sword_arc','threat_glint'):
                    lift=.038 if is_map else (.085 if entity=='warden' else .055)
                    if n in ('cape','cape_upper','cape_lower','tabard','waist'):lift*=.8
                    l['art_material']={'shadow_lift':lift,'cool_mix':.075};changed.append(n)
                    if not is_map:
                        if n=='torso':l['art_scale']=[1.25 if entity=='warden' else 1.16,1.0]
                        if n in ('head','helmet'):l['art_scale']=[1.16,1.0]
                        if n=='waist':l['art_scale']=[1.18,1.0]
                        if 'upper_arm' in n or 'forearm' in n:l['art_scale']=[1.10,1.0]
        d['art_polish']={'baseline_source':source,'description':'v08 local dark-cloth/steel separation and shared head/chest identity; all bone pivots, parents, contact paths, actions, events, alpha and z preserved. Map remains an independent short-proportion camera.','changed_components':changed,'human_signoff':False}
        target=dest/origin.name;write(target,d);routes[source]='res://'+target.relative_to(ROOT).as_posix()
    write(SRC/'art_polish_b_routes.json',routes)
    print('Prepared',len(routes),'new sources; v07 assets/approvals untouched')

def contracts(production=False):
    for old,new in read(SRC/'art_polish_b_routes.json').items():
        a=read(ROOT/old.removeprefix('res://'));b=read(ROOT/new.removeprefix('res://'))
        for d in (a,b):
            d.pop('art_polish',None)
            for l in d['layers']:l.pop('art_scale',None);l.pop('art_material',None)
        assert a==b,old
    candidate=read(CANDIDATE);baseline=read(OUT/'baseline-manifest.json');inventory=read(SRC/'art_polish_b_review_inventory.json')
    for k,rec in inventory.items():
        a=candidate['actions'][k];b=baseline['actions'][k]
        for field in ('fps','loop','events','anchor','size','pose_holds'):assert a.get(field)==b.get(field),(k,field)
        for channel,hashes in rec['channels'].items():
            assert len(a[channel])==len(b[channel])
            assert [sha(ROOT/p.removeprefix('res://')) for p in a[channel]]==hashes
    if production:
        expected=copy.deepcopy(baseline)
        for k in inventory:
            a=copy.deepcopy(candidate['actions'][k]);a.update(status='accepted',publish_review=(SRC/'art_polish_b_publish_review.json').relative_to(ROOT).as_posix(),coordinator_review=(SRC/'art_polish_b_coordinator_review.json').relative_to(ROOT).as_posix())
            expected['actions'][k]=a
        assert read(ROOT/'assets/monsters/phase3/manifest.json')==expected
        for name in ('art_polish_b_publish_review.json','art_polish_b_coordinator_review.json'):
            r=read(SRC/name)
            assert r['candidate_sha256']==sha(CANDIDATE) and r['decision']=='accepted' and r['human_signoff'] is False
        print('Production exactly matches reviewed v08 plus preserved v07 actions/root metadata')
    print('v08 contracts:',len(inventory),'actions; original bone/action contracts preserved')

def main():
    p=argparse.ArgumentParser();p.add_argument('command',choices=['prepare','stage','sheets','contracts','production-contracts','validate','publish']);args=p.parse_args()
    if args.command=='prepare':return prepare()
    if args.command=='stage':
        stage.SRC=SRC;stage.OUT=OUT;stage.CANDIDATE=CANDIDATE;stage.run()
        inventory=read(SRC/'art_polish_b_review_inventory.json')
        paths=sorted({p for record in inventory.values() for c in ('frames','effects_frames') for p in record['baseline'].get(c,[])})
        write(SRC/'retired_runtime_frames.json',{'requires_reference_audit':True,'paths':paths})
        return
    if args.command=='sheets':
        sheets.SRC=SRC;sheets.OUT=OUT;return sheets.run()
    if args.command=='contracts':return contracts()
    if args.command=='production-contracts':return contracts(True)
    publish.SRC=SRC;publish.CANDIDATE=CANDIDATE;publish.BASELINE=OUT/'baseline-manifest.json'
    result=publish.validate(SRC/'art_polish_b_coordinator_review.json')
    if args.command=='publish':write(publish.MANIFEST,result)
    print('v08 exact-SHA gate:',args.command)
if __name__=='__main__':main()
