"""Map B source registration. Crops imagegen originals; does not draw raster art."""
import argparse, json
from collections import deque
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/monsters/phase3/source/parallel_v05/map'
parser=argparse.ArgumentParser(); parser.add_argument('entity',choices=['warlock','knight','berserker','warden','p3_ember_channeler','p3_vault_knight']); opts=parser.parse_args()
entity=opts.entity; out=BASE/entity
source=out/f'{entity}_map_components.png'
im=Image.open(source).convert('RGBA'); W,H=im.size
names=['head','torso','cape','right_arm','left_arm','weapon','right_leg','left_leg','ornament']
if entity=='knight': names=['head','torso','cape','right_arm','weapon','left_arm','right_leg','left_leg','ornament']
rects=[(0,0,1/3,1/3),(1/3,0,2/3,1/3),(2/3,0,1,1/3),(0,1/3,1/3,2/3),(1/3,1/3,2/3,2/3),(2/3,1/3-.015,1,2/3+.014),(0,2/3,1/3,1),(1/3,2/3,2/3,1),(2/3,2/3+.015,1,1)]
crops={}
# Full-image connected bounds avoid nominal-grid truncation of model-generated parts.
mask=bytearray(1 if a>24 else 0 for a in im.getchannel('A').tobytes())
components=[]
for start in range(W*H):
    if not mask[start]:continue
    queue=deque([start]);mask[start]=0;count=0;x0=W;y0=H;x1=y1=0
    while queue:
        index=queue.popleft(); y,x=divmod(index,W);count+=1
        x0=min(x0,x);y0=min(y0,y);x1=max(x1,x);y1=max(y1,y)
        for ny in range(max(0,y-1),min(H,y+2)):
            for nx in range(max(0,x-1),min(W,x+2)):
                ni=ny*W+nx
                if mask[ni]:mask[ni]=0;queue.append(ni)
    if count>1000:components.append((count,[x0,y0,x1-x0+1,y1-y0+1]))
for name,rect in zip(names,rects):
    cx=(rect[0]+rect[2])/2*W;cy=(rect[1]+rect[3])/2*H
    eligible=[c for c in components if abs(c[1][0]+c[1][2]/2-cx)<W*.24 and abs(c[1][1]+c[1][3]/2-cy)<H*.24]
    assert eligible,name
    chosen=min(eligible,key=lambda c:(c[1][0]+c[1][2]/2-cx)**2+(c[1][1]+c[1][3]/2-cy)**2)
    crops[name]=chosen[1];components.remove(chosen)

layers=[]
def add(name,parent,pivot,target_width,z,ip=(.5,.1)):
    crop=crops[name]; scale=target_width/crop[2]
    layers.append(dict(name=name,parent=parent,pivot=pivot,crop=crop,image_pivot=[crop[2]*ip[0],crop[3]*ip[1]],scale=scale,z=z))
def joint(name,parent,pivot): layers.append(dict(name=name,parent=parent,pivot=pivot,z=0,joint_only=True))

mage=entity in ('warlock','p3_ember_channeler')
# Coordinates live in fixed 512 master; feet remain at y448.
legwidth=58 if mage else 71
for side,x in [('right',215),('left',297)]:
    name=side+'_leg'; crop=crops[name]; scale=(448-338)/crop[3]
    layers.append(dict(name=name,parent='root',pivot=[x,338],crop=crop,image_pivot=[crop[2]*.5,0],scale=scale,z=-4))
    joint(side+'_hip',name,[x,338]); joint(side+'_knee',name,[x,387]); joint(side+'_ankle',name,[x,433])
heavy=entity in ('berserker','warden')
add('cape','root',[256,218],168,-5,(.5,.06))
add('torso','root',[256,350],228 if mage else 224 if heavy else 182,0,(.5,.90))
add('head','torso',[256,201 if mage else 225 if heavy else 195],142 if mage else 130,4,(.5,.86))
add('right_arm','torso',[174,235 if mage else 202],67 if mage else 69,2,(.5,.07))
add('left_arm','torso',[338,235 if mage else 202],99 if mage else 69,1,(.26 if mage else .5,.08))
joint('right_elbow','right_arm',[175,275]); joint('right_wrist','right_arm',[174,349 if mage else 337]);joint('weapon_grip','right_wrist',[174,352 if mage else 340])
joint('left_elbow','left_arm',[338,258]);joint('left_wrist','left_arm',[357 if mage else 338,299 if mage else 315]);joint('left_grip','left_wrist',[357 if mage else 338,299 if mage else 319])
add('weapon','weapon_grip',[174,352 if mage else 340],40 if mage else 118 if entity=='berserker' else 75 if entity=='warden' else 45,5 if entity=='berserker' else 3,(.5,.63 if mage else .73 if entity in ('berserker','warden') else .23))
if entity=='berserker':add('ornament','torso',[174,218],72,3,(.5,.45))
else:add('ornament','left_grip',[357 if mage else 342,281 if mage else 318],48 if mage else 106,5,(.5,.76 if mage else .35))
if entity=='p3_ember_channeler':
    accessory=Image.open(out/'p3_ember_channeler_map_furnace_flame.png').convert('RGBA');aw,ah=accessory.size
    def extra_bounds(rect):
        region=accessory.crop(rect);bb=region.getchannel('A').point(lambda a:255 if a>24 else 0).getbbox();return [rect[0]+bb[0],rect[1]+bb[1],bb[2]-bb[0],bb[3]-bb[1]]
    ring=extra_bounds((0,0,round(aw*.7),ah));flame=extra_bounds((round(aw*.71),0,aw,ah))
    metal=next(l for l in layers if l['name']=='ornament');metal.update(source='p3_ember_channeler_map_furnace_flame.png',crop=ring,pivot=[385,293],image_pivot=[ring[2]*.5,ring[3]*.85],scale=79/ring[2])
    weapon=next(l for l in layers if l['name']=='weapon');weapon['scale']=83/weapon['crop'][2]
    layers.append(dict(name='furnace_flame',parent='ornament',pivot=[385,268],crop=flame,source='p3_ember_channeler_map_furnace_flame.png',image_pivot=[flame[2]*.5,flame[3]*.7],scale=33/flame[2],z=6))
poses=[]
for i,(dy,head,ar,al,cp) in enumerate([(0,0,0,0,0),(-1.4,-.6,.65,-.65,.5),(-2.3,-1.1,1.1,-1.0,.9),(-.7,.4,-.4,.35,-.3)]):
    p={'torso':{'p':[0,dy]},'head':{'r':head},'right_arm':{'r':ar},'left_arm':{'r':al},'cape':{'r':cp}}
    if entity=='warlock':p['ornament']={'r':[0,3,-2,-4][i],'a':[.87,1,.92,.78][i]}
    if entity=='p3_ember_channeler':p['ornament']={'r':[0,.5,1,-.3][i]};p['furnace_flame']={'r':[0,3,-2,-4][i],'a':[.8,1,.91,.7][i]}
    if entity in ('berserker','warden'):p['weapon']={'r':[-18,-17.35,-16.9,-18.4][i]}
    poses.append(p)
data=dict(version=1,status='draft',entity=entity+'_map',canvas=512,runtime_size=256,anchor=[256,448],rest_scale=1.0,source=source.name,layers=layers,actions={'idle':dict(fps=6,loop=True,poses=poses,events={})},pose_holds={},contacts={'idle':[{'right_foot':[215,448],'left_foot':[297,448]} for _ in poses]},acceptance='Independent elevated FRONT map original. Fixed root and planted feet. Agent visual review required; production publish belongs to coordinator.')
if entity=='warlock': data.update(effect_layers=['ornament'],effect_actions=['idle'])
if entity=='p3_ember_channeler': data.update(effect_layers=['furnace_flame'],effect_actions=['idle'])
(out/f'{entity}_map_rig.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(out/'registration.json').write_text(json.dumps({'original_size':[W,H],'crops':crops,'handedness':'right weapon = image left','camera':'front elevated orthographic'},indent=2)+'\n',encoding='utf-8')
print(entity, 'registered',len(layers),'nodes /',sum(not l.get('joint_only',False) for l in layers),'painted parts')
