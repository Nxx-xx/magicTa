"""Author base C draft rigs from imagegen component rasters; no publishing."""
import json, math, argparse, shutil
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/monsters/phase3/source/parallel_v05/battle'
EVIDENCE=ROOT/'build/verification/phase3/08-parallel/base_c'
def write(path,data):
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def layer(name,parent,pivot,crop,ip,scale,z,source='components.png',joint=False):
    d=dict(name=name,parent=parent,pivot=pivot,z=z)
    if joint:d['joint_only']=True
    else:d.update(crop=crop,image_pivot=ip,scale=scale,source=source)
    return d
def warlock():
    out=BASE/'warlock';out.mkdir(parents=True,exist_ok=True);(out/'.gdignore').touch()
    layers=[
      layer('skirt','root',[299,325],[850,50,365,365],[185,20],.43,-2),
      layer('torso','root',[299,213],[495,43,257,378],[125,25],.43,0),
      layer('hood','torso',[287,215],[85,65,310,350],[162,292],.43,4),
      layer('far_upper_arm','torso',[330,240],[120,460,205,365],[108,35],.23,-3),
      layer('far_forearm','far_upper_arm',[344,297],[540,450,180,375],[80,40],.25,-2),
      layer('near_upper_arm','torso',[259,237],[145,850,220,365],[85,37],.23,3),
      layer('near_forearm','near_upper_arm',[237,296],[465,850,285,360],[205,40],.26,5),
      layer('staff_grip','far_forearm',[332,359],None,None,None,6,joint=True),
      layer('cast_grip','near_forearm',[190,352],None,None,None,7,joint=True),
      layer('staff','root',[332,359],[985,425,100,410],[49,282],.75,2),
      layer('flame','root',[185,340],[900,850,250,365],[125,255],.25,7),
    ]
    base={x['name']:x for x in layers}
    def rotate(p,r):
        r=math.radians(r);return [p[0]*math.cos(r)-p[1]*math.sin(r),p[0]*math.sin(r)+p[1]*math.cos(r)]
    def world(name,p):
        if name=='root':return [0,0],0
        l=base[name];a,r=world(l['parent'],p);origin=[0,0] if l['parent']=='root' else base[l['parent']]['pivot']
        q=p.get(name,{});d=rotate([l['pivot'][i]-origin[i]+q.get('p',[0,0])[i] for i in range(2)],r)
        return [a[i]+d[i] for i in range(2)],r+q.get('r',0)
    def pose(dy=0,lean=0,head=0,upper=0,fore=0,far=0,fire=.65,release=0):
        p={'torso':{'p':[0,dy],'r':lean},'hood':{'r':head},'skirt':{'r':lean*.12,'p':[0,dy*.02]},
           'near_upper_arm':{'r':upper},'near_forearm':{'r':fore},'far_upper_arm':{'r':far},'far_forearm':{'r':-far*.6}}
        grip,r=world('staff_grip',p);cast,cr=world('cast_grip',p)
        if release:grip=[332-release*88,359+release*104];r=-release*100
        p['staff']={'p':[grip[i]-base['staff']['pivot'][i] for i in range(2)],'r':r}
        p['flame']={'p':[cast[i]-base['flame']['pivot'][i] for i in range(2)],'r':cr*.3,'a':fire}
        return p
    actions={}
    def action(n,fps,args,loop=False,events=None):actions[n]=dict(fps=fps,loop=loop,events=events or {},poses=[pose(**a) for a in args])
    action('idle',6,[{},dict(dy=-1,head=-1,upper=1,fore=1,fire=.72),dict(dy=-2,head=-2,upper=2,fore=2,fire=.8),dict(dy=-1,head=-1,upper=.5,fire=.7)],True)
    action('attack',12,[dict(dy=2,upper=-8,fore=12,fire=.5),dict(dy=5,lean=3,head=-3,upper=20,fore=35,fire=.7),dict(dy=3,lean=-3,head=1,upper=35,fore=40,far=-5,fire=1),dict(dy=2,lean=-7,head=3,upper=58,fore=-5,far=-8,fire=.9),dict(dy=1,lean=-3,upper=25,fore=10,fire=.55),{}],events={'hit':3,'cast':2})
    action('hit',12,[dict(dy=7,lean=9,head=7,upper=-12,fore=8,far=8,fire=.4),dict(dy=2,lean=3,head=2,upper=-3,fore=3,fire=.6)])
    action('defeat',10,[dict(dy=7,lean=5,head=-5,upper=-8,fire=.45),dict(dy=18,lean=3,head=-10,upper=-10,fore=8,fire=.25),dict(dy=35,lean=-5,head=-15,upper=8,fore=10,fire=.1),dict(dy=52,lean=-10,head=-20,upper=18,fore=20,far=12,fire=0,release=.3),dict(dy=65,lean=-14,head=-25,upper=25,fore=25,far=18,fire=0,release=.65),dict(dy=68,lean=-15,head=-26,upper=26,fore=26,far=19,fire=0,release=.7)],events={'release':3,'extinguish':3})
    d=dict(version=1,status='draft',entity='warlock',camera='battle_left',canvas=512,runtime_size=256,anchor=[256,448],rest_scale=.87,source='components.png',layers=layers,actions=actions,pose_holds={},effect_layers=['flame'],effect_actions=list(actions),acceptance='Await actual visual review; not production')
    write(out/'warlock_rig.json',d)
    return out
def elite(entity):
    out=BASE/entity;out.mkdir(parents=True,exist_ok=True);(out/'.gdignore').touch()
    is_warden=entity=='warden'
    head_crop=[65,58,218,285] if is_warden else [60,15,220,323]
    torso_crop=[332,55,285,265] if is_warden else [327,50,293,282]
    waist_crop=[643,88,300,277] if is_warden else [647,65,300,288]
    layers=[
      layer('torso','root',[300,215],torso_crop,[145,35],.4,0),
      layer('helmet','torso',[287,225],head_crop,[129,250 if is_warden else 285],.34,5),
      layer('waist','torso',[300,318],waist_crop,[151,30],.36,3),
      layer('near_upper_arm','torso',[254,249],[78,366,173,270],[89,40],.27,4),
      layer('near_forearm','near_upper_arm',[268,309],[393,371,160,263],[78,38],.27,5),
      layer('far_upper_arm','torso',[345,249],[698,367,190,273],[98,38],.25,-3),
      layer('far_forearm','far_upper_arm',[354,304],[1014,375,153,260],[89,38],.26,-2),
      layer('near_wrist','near_forearm',[275,365],None,None,None,7,joint=True),
      layer('far_wrist','far_forearm',[352,360],None,None,None,1,joint=True),
    ]
    for side,hip,knee,ankle,row,z in [('near',[271,350],[259,398],[255,450],0,1),('far',[332,347],[336,396],[345,447],1,-4)]:
        y=650 if row==0 else 942
        crops=[[79,y,170,278],[385,y,165,278],[635,706 if row==0 else 994,244,210]]
        if is_warden:crops=[[78,y,170,275],[398,y,170,278],[685,705 if row==0 else 992,190,213]]
        for part,parent,pivot,rect,ip,scale in zip(['thigh','shin','boot'],['root',side+'_thigh',side+'_shin'],[hip,knee,ankle],crops,[[83,32],[80,33],[150 if not is_warden else 126,55]],[.27,.25,.21]):
            layers.append(layer(side+'_'+part,parent,pivot,rect,ip,scale,z))
    if is_warden:
        layers += [layer('shield_grip','near_forearm',[258,350],None,None,None,8,joint=True),
          layer('shield','root',[258,350],[994,5,220,365],[140,240],.49,8),
          layer('mace','root',[352,360],[1018,647,168,286],[82,228],.47,1),
          layer('chain','waist',[310,339],[987,983,235,218],[117,30],.22,6),
          layer('chain_left_anchor','waist',[288,339],None,None,None,6,joint=True),
          layer('chain_right_anchor','waist',[334,339],None,None,None,6,joint=True),
          layer('impact_spark','root',[190,305],[425,805,400,410],[210,220],.20,10,'effects_original.png')]
    else:
        layers += [layer('near_pauldron','torso',[254,249],[985,665,248,250],[125,85],.21,6),
          layer('far_pauldron','torso',[345,249],[977,949,245,260],[124,85],.19,-1),
          layer('weapon_grip','near_wrist',[275,365],None,None,None,7,joint=True),
          layer('axe','root',[275,365],[1000,5,210,354],[155,270],.55,7),
          layer('weapon_trail','root',[165,292],[103,20,1110,680],[555,340],.22,10,'effects_original.png')]
    base={x['name']:x for x in layers}
    def rot(p,r):
        r=math.radians(r);return [p[0]*math.cos(r)-p[1]*math.sin(r),p[0]*math.sin(r)+p[1]*math.cos(r)]
    def world(name,p):
        if name=='root':return [0,0],0
        l=base[name];a,r=world(l['parent'],p);o=[0,0] if l['parent']=='root' else base[l['parent']]['pivot'];q=p.get(name,{})
        offset=rot([l['pivot'][i]-o[i]+q.get('p',[0,0])[i] for i in range(2)],r)
        return [a[i]+offset[i] for i in range(2)],r+q.get('r',0)
    def angle(a,b):return math.degrees(math.atan2(b[1]-a[1],b[0]-a[0]))
    def legs(p,dx,dy,kneel):
        contacts={}
        for side in ['near','far']:
            h0=base[side+'_thigh']['pivot'];k0=base[side+'_shin']['pivot'];a0=base[side+'_boot']['pivot']
            h=[h0[0]+dx,h0[1]+dy];target=[a0[0]+(43*kneel if side=='near' else 0),a0[1]]
            l1=math.dist(h0,k0);l2=math.dist(k0,a0);dist=math.dist(h,target);d=min(dist,l1+l2-.01)
            along=(l1*l1-l2*l2+d*d)/(2*d);height=math.sqrt(max(0,l1*l1-along*along));u=[(target[i]-h[i])/dist for i in range(2)]
            sign=1 if side=='far' else -1
            k=[h[0]+u[0]*along+sign*u[1]*height,h[1]+u[1]*along-sign*u[0]*height]
            r1=angle(h,k)-angle(h0,k0);r2=angle(k,target)-angle(k0,a0)-r1
            p[side+'_thigh']={'p':[dx,dy],'r':r1};p[side+'_shin']={'r':r2};p[side+'_boot']={'r':-r1-r2}
            contacts[side]=world(side+'_boot',p)[0]
        return contacts
    def pose(dx=0,dy=0,lean=0,head=0,arm=0,fore=0,far=0,farfore=0,wrist=0,shieldwrist=0,fx=0,release=None,kneel=0):
        p={'torso':{'p':[dx,dy],'r':lean},'helmet':{'r':head},'waist':{'r':-lean*.3},
           'near_upper_arm':{'r':arm},'near_forearm':{'r':fore},'far_upper_arm':{'r':far},'far_forearm':{'r':farfore}}
        contacts=legs(p,dx,dy,kneel)
        weapon='mace' if is_warden else 'axe';joint='far_wrist' if is_warden else 'weapon_grip'
        p[joint]={'r':wrist}
        grip,r=world(joint,p)
        if release is not None:grip,r=release
        p[weapon]={'p':[grip[i]-base[weapon]['pivot'][i] for i in range(2)],'r':r}
        if is_warden:
            sg,sr=world('shield_grip',p);p['shield']={'p':[sg[i]-base['shield']['pivot'][i] for i in range(2)],'r':sr+shieldwrist}
            p['chain']={'r':-lean*.7+arm*.02}
            p['impact_spark']={'a':fx,'r':arm*.15}
        else:p['weapon_trail']={'a':fx,'r':-10+arm*.2}
        return p,contacts
    actions={};contacts={}
    def action(name,fps,args,loop=False,events=None):
        rs=[pose(**x) for x in args];actions[name]=dict(fps=fps,loop=loop,events=events or {},poses=[r[0] for r in rs]);contacts[name]=[r[1] for r in rs]
    action('idle',6,[{},dict(dy=-1,head=-.7,arm=1,far=-1),dict(dy=-2,head=-1.2,arm=2,fore=-1,far=-2),dict(dy=-.7,head=.3,arm=.6,fore=.3,far=-.4)],True)
    if is_warden:
        action('attack',12,[{},dict(dx=3,dy=5,lean=3,head=-2,arm=-8,fore=8,far=-15,farfore=8,wrist=5),
          dict(dx=2,dy=9,lean=2,head=-3,arm=10,fore=-5,far=-20,farfore=10,wrist=15),
          dict(dx=-3,dy=6,lean=-4,head=2,arm=35,fore=-20,far=50,farfore=-15,wrist=-75,shieldwrist=-10),
          dict(dx=-7,dy=8,lean=-7,head=3,arm=48,fore=-25,far=65,farfore=-15,wrist=-100,shieldwrist=-18,fx=.9),
          dict(dx=-4,dy=6,lean=-4,head=1,arm=25,fore=-10,far=32,farfore=-8,wrist=-60,shieldwrist=-8,fx=.35),
          dict(dx=-1,dy=2,lean=-1,arm=8,fore=-4,far=10,farfore=-3,wrist=-12),{}],events={'hit':4,'shield_bash':3})
    else:
        action('attack',12,[{},dict(dx=4,dy=5,lean=3,head=-2,arm=-22,fore=-15,far=-6,wrist=10),
          dict(dx=5,dy=10,lean=4,head=-4,arm=-45,fore=-20,far=-10,wrist=30),
          dict(dx=2,dy=7,lean=1,head=-2,arm=-30,fore=-20,far=-15,wrist=35),
          dict(dx=-7,dy=12,lean=-7,head=3,arm=60,fore=-15,far=10,wrist=-105,fx=.8),
          dict(dx=-4,dy=9,lean=-5,head=2,arm=42,fore=-10,far=8,wrist=-70,fx=.35),
          dict(dx=-2,dy=4,lean=-2,head=1,arm=12,fore=-3,far=3,wrist=-20),{}],events={'hit':4})
    action('hit',12,[dict(dx=5,dy=8,lean=8,head=6,arm=-8,fore=7,far=-10,farfore=6),dict(dx=2,dy=4,lean=4,head=3,arm=-4,fore=3,far=-5,farfore=3),{}])
    release_x=365 if is_warden else 253
    release_r=-85 if is_warden else -90
    args=[dict(dx=3,dy=7,lean=4,head=-4,arm=-8,fore=6),dict(dx=1,dy=15,lean=2,head=-8,arm=-10,fore=8,far=8),
      dict(dx=-2,dy=25,lean=-4,head=-12,arm=2,fore=12,far=12),
      dict(dx=-3,dy=35,lean=-10,head=-16,arm=12,fore=16,far=18,kneel=.2,release=([release_x,392],-30)),
      dict(dx=-5,dy=45,lean=-15,head=-20,arm=20,fore=22,far=22,kneel=.45,release=([release_x-8,420],-55)),
      dict(dx=-5,dy=55,lean=-19,head=-23,arm=24,fore=25,far=25,kneel=.75,release=([release_x-13,446 if is_warden else 400],release_r)),
      dict(dx=-5,dy=60,lean=-22,head=-25,arm=26,fore=27,far=27,kneel=1,release=([release_x-13,446 if is_warden else 400],release_r))]
    args.append(dict(args[-1]));action('defeat',12,args,events={'release':3,'ground':5,'knee_contact':6})
    effects=['impact_spark'] if is_warden else ['weapon_trail']
    d=dict(version=1,status='draft',entity=entity,camera='battle_left',canvas=512,runtime_size=256,anchor=[256,474],rest_scale=.88,source='components.png',layers=layers,actions=actions,pose_holds={'attack':{'7':0},'defeat':{'7':6}},contacts=contacts,effect_layers=effects,effect_actions=['attack'],acceptance='Draft; actual visual review then coordinator release',damage_text_reserved_rect=[160,20,210,105] if is_warden else None)
    write(out/(entity+'_rig.json'),d);return out
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('entity',nargs='?',default='warlock',choices=['warlock','berserker','warden']);args=parser.parse_args()
    print(warlock() if args.entity=='warlock' else elite(args.entity))
