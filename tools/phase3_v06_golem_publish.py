"""Golem-only explicit hash publication; never touches other accepted metadata."""
import hashlib,json,shutil
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/monsters/phase3/source/golem_v06'
OUT=ROOT/'build/verification/phase3/09-refinement/golem'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def prepare():
    review=read(SRC/'golem_publish_review.json')
    assert review['entity']=='golem' and review['human_signoff'] is False
    for mode,expected in review['native_evidence_sha256'].items():
        timing=OUT/'native'/mode/'timing.json'
        assert hashlib.sha256(timing.read_bytes()).hexdigest()==expected,'Native evidence changed'
        evidence=read(timing)
        for path_key,hash_key in [('draft','draft_sha256'),('rig','rig_sha256'),('scene','scene_sha256')]:
            assert hashlib.sha256((ROOT/evidence[path_key].replace('res://','')).read_bytes()).hexdigest()==evidence[hash_key], 'Changed source requires fresh native review'
    prepared={}
    for name,r in review['actions'].items():
        assert r['decision']=='accepted' and r['human_signoff'] is False
        d=read(SRC/r['draft_manifest']);a=d['actions'][r['source_action']]
        assert len(a['frames'])==r['frame_slots']
        assert all(not m['edge_touch'] for m in a['metrics']),name
        for field in ['fps','loop','events','pose_holds']:assert a.get(field,{})==r.get(field,{}), (name,field)
        for field in ['size','anchor']:
            expected=[256,256] if field=='size' else [128,224]
            assert d[field]==r[field]==expected,(name,field)
        accepted={k:a[k] for k in ['fps','loop','events','pose_holds']}
        accepted.update(size=d['size'],anchor=d['anchor'],status='accepted',source=d['source'],
            review='source/golem_v06/REVIEW.md')
        pixels=[]
        for frame in a['frames']:
            with Image.open(SRC/frame) as image:
                pixels.append(hashlib.sha256(image.convert('RGBA').tobytes()).hexdigest())
        declared={int(k):int(v) for k,v in a.get('pose_holds',{}).items()}
        for index,digest in enumerate(pixels):
            if index in declared:assert digest==pixels[declared[index]],'Declared pose hold changed'
            elif digest in pixels[:index]:raise AssertionError('Undeclared identical body pose: '+name)
        for channel,hash_key in [('frames','frame_sha256'),('effects_frames','effects_sha256')]:
            frames=a.get(channel,[])
            assert [sha(SRC/p) for p in frames]==r[hash_key], f'Changed pixels require fresh visual approval: {name}/{channel}'
            dests=[]
            for i,p in enumerate(frames):
                with Image.open(SRC/p) as image:
                    assert image.size==(256,256) and image.mode=='RGBA'
                target=ROOT/'assets/monsters/phase3/textures/v06/golem'/name/('effects' if channel=='effects_frames' else 'body')/f'{i:02d}.png'
                if target.exists():assert sha(target)==sha(SRC/p),'Refuse overwrite of different existing PNG'
                dests.append((SRC/p,target))
            if frames:accepted[channel]=['res://'+p.relative_to(ROOT).as_posix() for _,p in dests]
            prepared.setdefault(name,{'metadata':accepted,'copies':[]})['copies'].extend(dests)
    assert len(prepared)==26
    return prepared
def publish():
    prepared=prepare()
    path=ROOT/'assets/monsters/phase3/manifest.json';m=read(path)
    other={k:v for k,v in m['actions'].items() if not k.startswith('golem_')}
    roots={k:v for k,v in m.items() if k not in ['actions','golem_stone_armor']}
    for name,entry in prepared.items():
        for src,target in entry['copies']:
            target.parent.mkdir(parents=True,exist_ok=True)
            if not target.exists():shutil.copyfile(src,target)
        m['actions']['golem_'+name]=entry['metadata']
    m['golem_stone_armor']={'includes_base':True,'reachable_enhancements':4,'defense':[14,16,18,20,22],
        'event_increment':2,'stage_count':5,'selection':'sum of committed ordered stone_armor event amounts only',
        'idle_actions':['idle']+[f'idle_armor_{s}' for s in range(1,5)],'human_signoff':False,
        'review':'source/golem_v06/golem_publish_review.json'}
    assert other=={k:v for k,v in m['actions'].items() if not k.startswith('golem_')}
    assert roots=={k:v for k,v in m.items() if k not in ['actions','golem_stone_armor']}
    path.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Published only golem: 26 timelines / 189 body slots / 185 optional FX slots; other root fields and actions preserved')
if __name__=='__main__':publish()
