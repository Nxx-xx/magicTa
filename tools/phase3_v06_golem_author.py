"""Non-destructive golem refinement; native independent parts, draft only."""
import copy, json, math, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT/'assets/monsters/phase3/source/golem_v04'
OUT = ROOT/'assets/monsters/phase3/source/golem_v06'

def save(name, obj):
    (OUT/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def author():
    d=json.loads((OLD/'golem_rig.json').read_text(encoding='utf-8'))
    # User-requested 512 master -> 256 runtime. Preserve normalized foot anchor.
    factor=2/3
    d.update(canvas=512,runtime_size=256,anchor=[256,448],status='draft')
    for l in d['layers']:
        l['pivot']=[v*factor for v in l['pivot']]
        l['scale']*=factor
    for a in d['actions'].values():
        for p in a['poses']:
            for state in p.values():
                if 'p' in state: state['p']=[v*factor for v in state['p']]
    for frames in d['contacts'].values():
        for contact in frames:
            for side in contact: contact[side]=[v*factor for v in contact[side]]
    # Actual alpha bounds measured from the generated attachment atlas.
    parts=json.loads((OUT/'attachment_bounds.json').read_text(encoding='utf-8'))
    specs=[('near_cap','near_shoulder',[196,180],.20,8),
           ('far_cap','far_shoulder',[308.667,177],.20,7),
           ('chest_collar','torso',[234.667,215.333],.19,8),
           ('stone_cuff','near_forearm',[180,282],.12,8)]
    for (name,parent,pivot,scale,z),rect in zip(specs,parts):
        d['layers'].append(dict(name=name,parent=parent,pivot=pivot,crop=rect,
            source='golem_armor_attachments.png',image_pivot=[rect[2]/2,rect[3]*.52],scale=scale,z=z))
    d['layers'][-2]['image_pivot']=[237,251]
    if (OUT/'golem_dark_flame.png').exists():
        from PIL import Image
        w,h=Image.open(OUT/'golem_dark_flame.png').size
        d['layers'].append(dict(name='dark_flame',parent='torso',pivot=[234.667,215.333],
            source='golem_dark_flame.png',crop=[0,0,w,h],image_pivot=[w/2,h/2],scale=96/w,z=9))
        d['effect_layers'].append('dark_flame')
    # Explicit wrist/fist grip points belong to the articulated forearms.
    for side,pivot in [('near',[170,307]),('far',[321,303])]:
        d['layers'].append(dict(name=side+'_fist_grip',parent=side+'_forearm',pivot=pivot,joint_only=True,z=0))
    original=copy.deepcopy(d['actions']); d['actions']={}; holds={}
    # Shoulder windup, elbow release, and asymmetric recovery. Feet remain IK fixed.
    for i,p in enumerate(original['attack']['poses']):
        p['near_shoulder']={'r':[0,-1,-2,-4,-3,3,2,1,.4,0][i]}
        p['far_shoulder']={'r':[0,.5,1,2,2,-1,-.7,-.4,0,0][i]}
        p['near_upper_arm']['r']=[0,20,50,85,87,23,-8,-3,.5,0][i]
        p['near_forearm']['r']=[0,8,18,22,15,-23,-17,-9,-3,0][i]
    original['hit']['poses'][0]['head']['r']=11
    original['hit']['poses'][1]['head']['r']=4
    names=['idle','attack','hit','armor','defeat']
    for tier in range(5):
        for name in names:
            key=name if tier==0 else f'{name}_armor_{tier}'
            a=copy.deepcopy(original[name])
            for i,p in enumerate(a['poses']):
                collapsed=name=='defeat' and i>=3
                # Plates are physical body layers, never optional glow.
                close=1.0 if tier<4 else .42
                if name=='armor': close=(.68,.80,.93,1,1,1)[i] if tier<4 else (.75,.66,.55,.45,.42,.42)[i]
                if not collapsed:
                    p['near_plate']={'a':1,'p':[-18.667*(1-close),0],'r':-20*(1-close)}
                    p['far_plate']={'a':1,'p':[18.667*(1-close),0],'r':20*(1-close)}
                growth=1 if name!='armor' else (.72,.78,.86,.95,1,1)[i]
                for part,threshold in [('chest_collar',1),('near_cap',2),('far_cap',2),('stone_cuff',3)]:
                    p[part]={'a':1 if tier>=threshold else 0,'p':[0,-(tier-threshold)*1.5*growth]}
                if name=='defeat':
                    p['chest_collar']['a']*=max(0,1-(i-7)/3)
                    # Attachments remain parented to their separately falling rocks.
                p['armor_rune']['a']=0 if tier==0 else (.16+.09*tier)*(1+.12*math.sin(i*math.pi/3))
                p['dark_flame']={'a':(.44 if tier==3 else .60 if tier==4 else 0)*(1+.12*math.sin(i*math.pi/3))}
                if name=='armor': p['armor_rune']['a']=(.12,.35,.65,.85,.55,.25)[i]
                if name=='defeat': p['armor_rune']['a']*=max(0,1-i/8)
                if name=='defeat': p['dark_flame']['a']*=max(0,1-i/5)
                # Core gets exposed at final reachable stage, without tint-only tiers.
                if tier==4 and not collapsed: p['core']['p']=[-1,-2]
            d['actions'][key]=a
            if name in d.get('pose_holds',{}): holds[key]=copy.deepcopy(d['pose_holds'][name])
    d['pose_holds']=holds
    d['effect_actions']=list(d['actions'])
    d['stone_armor_design']={'includes_base':True,'defense':[14,16,18,20,22],
        'reachable_enhancements':4,'event_increment':2,'maximum_hp':250,
        'physical_layers':['near_plate','far_plate','chest_collar','near_cap','far_cap','stone_cuff'],
        'selection':'committed stone_armor amount sum only; never infer from HP or note'}
    d['acceptance']='Draft v06, independent painted attachments and physical persistent armor. Human signoff pending.'
    save('golem_rig.json',d)
    m=json.loads((OLD/'golem_map_rig.json').read_text(encoding='utf-8'))
    m['actions']['idle']['poses']=[{'torso':{'p':[0,y]},'head':{'r':h},'near_upper_arm':{'r':a},'near_forearm':{'r':-a*.6},'far_arm':{'r':-a*.7},'near_shoulder':{'r':a*.3},'far_shoulder':{'r':-a*.2}} for y,h,a in [(0,0,0),(-2,-.6,1),(-3,-1,1.5),(-1,.3,-.5)]]
    save('golem_map_rig.json',m)
    print('Draft only: 5 reachable body tiers x 37 battle slots, 4 independent map slots')

if __name__=='__main__': author()
