"""Reconstruct the original failed warlock bake for preserved failure evidence only."""
import json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'assets/monsters/phase3/source/parallel_v05/battle/warlock'
data=json.loads((folder/'warlock_rig.json').read_text(encoding='utf-8'))
out=folder/'rejected_initial_reconstruction';out.mkdir(exist_ok=True);(out/'.gdignore').touch()
data['entity']='warlock_rejected';data['source']='../components.png';data['acceptance']='REJECTED reconstruction of initial clipping; not publishable'
base={x['name']:x for x in data['layers']}
base['skirt']['parent']='torso';base['staff_grip']['pivot']=[325,332];base['staff']['pivot']=[325,332];base['staff']['z']=-1
for l in data['layers']:
    if 'source' in l:l['source']='../'+l['source']
def rot(p,r):
    r=math.radians(r);return [p[0]*math.cos(r)-p[1]*math.sin(r),p[0]*math.sin(r)+p[1]*math.cos(r)]
def world(name,p):
    if name=='root':return [0,0],0
    l=base[name];a,r=world(l['parent'],p);o=[0,0] if l['parent']=='root' else base[l['parent']]['pivot'];q=p.get(name,{})
    v=rot([l['pivot'][i]-o[i]+q.get('p',[0,0])[i] for i in range(2)],r)
    return [a[i]+v[i] for i in range(2)],r+q.get('r',0)
for name,action in data['actions'].items():
    for i,p in enumerate(action['poses']):
        p['skirt']={'r':-p['torso']['r']*.65}
        grip,r=world('staff_grip',p)
        if name=='defeat' and i>=3:
            release=[.3,.65,.7][i-3];grip=[325+release*25,332+release*90];r=release*45
        p['staff']={'p':[grip[0]-325,grip[1]-332],'r':r}
(out/'warlock_rejected_rig.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(out/'REJECTED.md').write_text('Explicit reconstruction of initial failed source after its output had been overwritten by the correction. Preserves the original incorrect skirt parent and staff release parameters. Never approved or production referenced. Original failed bake log/metrics remain in base_c evidence.\n',encoding='utf-8')
print(out)
