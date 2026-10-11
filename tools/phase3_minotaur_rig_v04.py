"""Author minotaur v04 articulated draft. Does not paint pixels or publish art.

Raster layers are imagegen originals. Coordinates are fixed source registrations;
two-bone leg contact and weapon release are solved into editable Godot tracks.
"""
import copy
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/monsters/phase3/source/rig_v04'
old = json.loads((OUT.parent/'rig_v02/minotaur_rig.json').read_text())
layers = [copy.deepcopy(x) for x in old['layers'] if x['name'] not in ('near_leg','far_leg','far_arm')]

def add(name, parent, pivot, crop, image_pivot, scale, z, source='minotaur_joints.png'):
    layers.append(dict(name=name,parent=parent,pivot=pivot,crop=crop,image_pivot=image_pivot,scale=scale,z=z,source=source))

# Legs now have independently painted thigh, shin, hoof; no entire-leg hinge.
for side, hip, knee, ankle, row, z in [
    ('near',[342,470],[330,551],[347,631],0,-1),
    ('far',[426,466],[451,540],[460,618],1,-5)]:
    crops = ([[50,10,345,450],[500,10,290,450],[900,145,315,315]] if row == 0
             else [[60,465,320,370],[510,475,285,370],[920,555,295,270]])
    pivots = ([[175,65],[140,70],[170,155]] if row == 0 else [[155,50],[135,50],[150,135]])
    for part, par, point, rect, ip, scale in zip(
        ['thigh','shin','hoof'],['root',side+'_thigh',side+'_shin'],[hip,knee,ankle],crops,pivots,[.34,.29,.38]):
        add(side+'_'+part,par,point,rect,ip,scale,z)
add('far_upper_arm','torso',[462,298],[40,842,365,390],[170,95],.47,-4)
add('far_forearm','far_upper_arm',[493,411],[425,850,375,370],[245,75],.43,-3)
add('open_forearm','upper_arm',[324,438],[860,860,380,370],[265,65],.58,4)
layers.append(dict(name='weapon_grip',parent='forearm',pivot=[219,555],z=4,joint_only=True))
# Weapon is a root child with a solved grip transform; it can be released.
next(x for x in layers if x['name']=='axe')['parent']='root'
base={x['name']:x for x in layers}
v=lambda a,b:[a[0]-b[0],a[1]-b[1]]
def rot(p,d):
    r=math.radians(d)
    return [p[0]*math.cos(r)-p[1]*math.sin(r),p[0]*math.sin(r)+p[1]*math.cos(r)]
def plus(a,b): return [a[0]+b[0],a[1]+b[1]]
def angle(a,b): return math.degrees(math.atan2(b[1]-a[1],b[0]-a[0]))
def world(name,pose):
    if name=='root': return [0,0],0
    layer=base[name]; parent=layer['parent']; pp,pr=world(parent,pose)
    origin=[0,0] if parent=='root' else base[parent]['pivot']
    local=plus(v(layer['pivot'],origin),pose.get(name,{}).get('p',[0,0]))
    return plus(pp,rot(local,pr)),pr+pose.get(name,{}).get('r',0)
def legs(pose,dx,dy,kneel=0):
    contacts={}
    for side in ('near','far'):
        hp=base[side+'_thigh']['pivot']; kp=base[side+'_shin']['pivot']; ap=base[side+'_hoof']['pivot']
        h=plus(hp,[dx,dy]); target=plus(ap,[35*kneel,0]) if side=='near' else ap
        l1=math.dist(hp,kp); l2=math.dist(kp,ap); d=math.dist(h,target)
        distance=min(d,l1+l2-.01)
        along=(l1*l1-l2*l2+distance*distance)/(2*distance)
        height=math.sqrt(max(0,l1*l1-along*along))
        unit=[(target[0]-h[0])/d,(target[1]-h[1])/d]
        k=[h[0]+unit[0]*along-unit[1]*height,h[1]+unit[1]*along+unit[0]*height]
        r1=angle(h,k)-angle(hp,kp)
        r2=angle(k,target)-angle(kp,ap)-r1
        pose[side+'_thigh']={'p':[dx,dy],'r':r1}
        pose[side+'_shin']={'r':r2}
        pose[side+'_hoof']={'r':-r1-r2}
        actual,_=world(side+'_hoof',pose)
        contacts[side]=actual
    return contacts

def pose(dx=0,dy=0,torso=0,head=0,arm=0,fore=0,far=0,rune=0,release=None,kneel=0):
    p={'torso':{'p':[dx,dy],'r':torso},'head':{'r':head},
       'upper_arm':{'r':arm},'forearm':{'r':fore},
       'far_upper_arm':{'r':far},'far_forearm':{'r':-far*.65},'rage_rune':{'a':rune},
       'open_forearm':{'a':0,'r':fore}}
    contacts=legs(p,dx,dy,kneel)
    hand,hand_angle=world('forearm',p)
    grip=plus(hand,rot(v([219,555],base['forearm']['pivot']),hand_angle))
    if release is not None:
        grip,hand_angle=release
        p['forearm']['a']=0
        p['open_forearm']['a']=1
        p['open_forearm']['r']=fore+30*kneel
    else:
        hand_angle += 3
    p['axe']={'p':v(grip,base['axe']['pivot']),'r':hand_angle}
    return p,contacts

actions={}; contact_data={}
def action(name,fps,params,loop=False,events=None):
    results=[pose(**args) for args in params]
    actions[name]=dict(fps=fps,loop=loop,events=events or {},poses=[r[0] for r in results])
    contact_data[name]=[r[1] for r in results]

action('idle',6,[dict(dy=y,head=h,arm=a,far=f) for y,h,a,f in [(0,0,0,0),(-1,-.6,1,-1),(-2,-1,1.5,-2),(-1,-.3,.5,-1),(1,.5,-1,.5),(1,.7,-.5,1)]],True)
action('attack',12,[{},dict(dx=8,dy=9,torso=-3,head=3,arm=27,fore=8,far=-10),
    dict(dx=7,dy=15,torso=-5,head=5,arm=82,fore=25,far=-18),
    dict(dx=5,dy=10,torso=-3,head=2,arm=91,fore=28,far=-20),
    dict(dx=-9,dy=23,torso=-9,head=3,arm=28,fore=-10,far=12),
    dict(dx=-7,dy=18,torso=-6,head=2,arm=10,fore=-12,far=10),
    dict(dx=-3,dy=8,torso=-2,head=1,arm=3,fore=-4,far=4),{}],events={'hit':4})
action('hit',12,[dict(dx=8,dy=12,torso=8,head=9,arm=-8,fore=10,far=-12),dict(dx=4,dy=6,torso=4,head=4,arm=-4,fore=5,far=-6),{}])
action('rage',12,[dict(dy=8,head=5,arm=5,rune=.12),dict(dy=15,torso=-3,head=1,arm=12,fore=4,far=-12,rune=.45),
    dict(dy=9,torso=3,head=-6,arm=20,fore=8,far=-23,rune=.85),
    dict(dy=3,torso=5,head=-10,arm=17,fore=6,far=-18,rune=1),
    dict(dy=2,torso=2,head=-5,arm=8,fore=2,far=-8,rune=.55),dict(head=-1,arm=2,far=-2,rune=.18)])
action('defeat',12,[dict(dx=6,dy=10,torso=6,head=6,arm=-6),dict(dx=3,dy=22,torso=3,head=-5,arm=-9,fore=6),
    dict(dx=-2,dy=35,torso=-3,head=-10,arm=0,fore=-5),
    dict(dx=-5,dy=48,torso=-8,head=-15,arm=8,fore=-8,release=([194,554],-25)),
    dict(dx=-7,dy=65,torso=-12,head=-20,arm=12,fore=-10,far=12,kneel=.15,release=([165,570],0)),
    dict(dx=-8,dy=90,torso=-16,head=-25,arm=17,fore=10,far=20,kneel=.45,release=([150,611],30)),
    dict(dx=-8,dy=108,torso=-19,head=-28,arm=20,fore=25,far=25,kneel=.8,release=([135,680],70)),
    dict(dx=-8,dy=117,torso=-20,head=-30,arm=22,fore=30,far=28,kneel=1,release=([135,680],70)),
    dict(dx=-8,dy=120,torso=-21,head=-31,arm=23,fore=34,far=29,kneel=1,release=([135,680],70)),
    dict(dx=-8,dy=120,torso=-21,head=-31,arm=23,fore=34,far=29,kneel=1,release=([135,680],70))],events={'release':3,'ground':6,'knee_contact':7})
data=dict(version=1,status='draft',entity='minotaur',canvas=768,runtime_size=384,anchor=[384,672],rest_scale=.86,
    source='minotaur_components.png',layers=layers,actions=actions,
    pose_holds={'attack':{'7':0},'defeat':{'9':8}},contacts=contact_data,
    effect_layers=['rage_rune'],effect_actions=['rage'],
    acceptance='Draft: inspect joints, planted hooves, axe release, silhouettes and native playback before explicit publish')
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'minotaur_rig.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'v04 minotaur source: {len(layers)-1} painted layers + weapon grip; 33 frame slots; two intentional holds; no production change')



