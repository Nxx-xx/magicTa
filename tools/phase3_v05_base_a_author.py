"""Articulate generated raster components; no procedural replacement painting."""
import json, math, copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/monsters/phase3/source/parallel_v05/battle'
EVID=ROOT/'build/verification/phase3/08-parallel/base_a'
EVID.mkdir(parents=True,exist_ok=True)
def write(path,data): path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def skeleton():
    out=BASE/'skeleton'; layers=[]
    def add(n,pa,p,c,ip,s,z): layers.append(dict(name=n,parent=pa,pivot=p,crop=c,image_pivot=ip,scale=s,z=z))
    add('torso','root',[282,288],[370,25,240,285],[125,250],.39,0)
    add('head','torso',[275,209],[35,40,250,275],[170,250],.44,5)
    add('pelvis','root',[282,290],[685,60,235,260],[112,55],.35,2)
    add('near_upper','torso',[250,209],[110,335,120,250],[65,50],.35,6)
    add('near_fore','near_upper',[245,269],[385,335,165,290],[105,46],.30,7)
    add('near_open_fore','near_upper',[245,269],[1030,335,150,275],[51,40],.30,7)
    add('far_upper','torso',[305,213],[725,335,150,240],[54,43],.32,-4)
    add('far_fore','far_upper',[326,267],[1030,335,150,275],[51,40],.29,-3)
    add('shield','far_fore',[337,313],[965,25,260,300],[143,165],.45,4)
    for side,hip,knee,ankle,row,z in [('near',[267,325],[248,378],[259,429],0,1),('far',[297,321],[319,374],[330,421],1,-5)]:
        y=640 if row==0 else 945
        add(side+'_thigh','root',hip,[90,y,165,260],[85,48],.28,z)
        add(side+'_shin',side+'_thigh',knee,[410,y,150,275],[70,45],.27,z)
        add(side+'_foot',side+'_shin',ankle,[660,740 if row==0 else 1040,230,160],[150,45],.31,z)
    layers.append(dict(name='weapon_grip',parent='near_fore',pivot=[233,320],z=8,joint_only=True))
    add('sword','root',[233,320],[1030,625,135,310],[65,256],.54,8)
    add('slash','root',[165,270],[950,930,305,310],[150,150],.48,9)
    base={l['name']:l for l in layers}
    def rot(p,d):
        a=math.radians(d); return [p[0]*math.cos(a)-p[1]*math.sin(a),p[0]*math.sin(a)+p[1]*math.cos(a)]
    def world(n,p):
        if n=='root': return [0,0],0
        l=base[n]; q,r=world(l['parent'],p); origin=[0,0] if l['parent']=='root' else base[l['parent']]['pivot']; t=p.get(n,{})
        v=rot([l['pivot'][i]-origin[i]+t.get('p',[0,0])[i] for i in range(2)],r)
        return [q[i]+v[i] for i in range(2)],r+t.get('r',0)
    def pose(dx=0,dy=0,t=0,h=0,arm=0,fore=0,far=0,fx=0,fall=0,release=None):
        p={'torso':{'p':[dx,dy],'r':t},'pelvis':{'p':[dx,dy]},'head':{'r':h},'near_upper':{'r':arm},'near_fore':{'r':fore,'a':0 if release else 1},'near_open_fore':{'r':fore,'a':1 if release else 0},'far_upper':{'r':far},'far_fore':{'r':-far*.45},'slash':{'a':fx,'r':180}}
        for side in ['near','far']:
            hp=base[side+'_thigh']['pivot']; kp=base[side+'_shin']['pivot']; ap=base[side+'_foot']['pivot']
            target=[ap[0]+(-14 if side=='near' else 10)*fall,ap[1]]; hip=[hp[0]+dx,hp[1]+dy]
            l1=math.dist(hp,kp);l2=math.dist(kp,ap);d=math.dist(hip,target);dist=min(d,l1+l2-.001)
            a=(l1*l1-l2*l2+dist*dist)/(2*dist);b=math.sqrt(max(0,l1*l1-a*a));u=[(target[i]-hip[i])/d for i in range(2)]
            k=[hip[0]+u[0]*a-u[1]*b,hip[1]+u[1]*a+u[0]*b]
            ang=lambda a,b:math.degrees(math.atan2(b[1]-a[1],b[0]-a[0]))
            r1=ang(hip,k)-ang(hp,kp);r2=ang(k,target)-ang(kp,ap)-r1
            p[side+'_thigh']={'p':[dx,dy],'r':r1};p[side+'_shin']={'r':r2};p[side+'_foot']={'r':-r1-r2}
        grip,r=world('weapon_grip',p)
        if release: grip,r=release
        p['sword']={'p':[grip[i]-base['sword']['pivot'][i] for i in range(2)],'r':r-10}
        return p
    actions={}
    def action(n,fps,params,loop=False,events=None): actions[n]=dict(fps=fps,loop=loop,events=events or {},poses=[pose(**p) for p in params])
    action('idle',6,[{},dict(dy=-1.5,h=-1,arm=1,far=-1),dict(dy=-3,h=-2,arm=2,far=-2),dict(dy=-1,h=.5,arm=-.5,far=.5)],True)
    action('attack',12,[{},dict(dx=5,dy=4,t=5,h=-3,arm=50,fore=20,far=-8),dict(dx=3,dy=8,t=7,h=-4,arm=93,fore=25,far=-14),dict(dx=-12,dy=12,t=-10,h=4,arm=-33,fore=-34,far=15,fx=.8),dict(dx=-6,dy=6,t=-5,h=2,arm=-18,fore=-12,far=8,fx=.22),{}],events={'hit':3})
    action('hit',12,[dict(dx=10,dy=8,t=12,h=9,arm=-10,fore=12,far=-15),{}],events={'recoil':0})
    action('defeat',10,[dict(dx=5,dy=8,t=8,h=10,arm=-8),dict(dx=3,dy=23,t=-5,h=-15,arm=8,fore=-7,far=12),dict(dx=-3,dy=44,t=-18,h=-24,arm=14,fore=8,far=25,fall=.4,release=([202,358],-45)),dict(dx=-9,dy=70,t=-27,h=-38,arm=35,fore=25,far=42,fall=.75,release=([165,421],-78)),dict(dx=-12,dy=80,t=-31,h=-45,arm=42,fore=36,far=50,fall=1,release=([150,437],-80)),dict(dx=-12,dy=80,t=-31,h=-45,arm=42,fore=36,far=50,fall=1,release=([150,437],-80))],events={'release':2,'ground':4})
    data=dict(version=1,status='draft',entity='skeleton',view='battle_left',canvas=512,runtime_size=256,anchor=[256,448],rest_scale=.95,source='skeleton_components.png',layers=layers,actions=actions,pose_holds={'attack':{'5':0},'defeat':{'5':4}},effect_layers=['slash'],effect_actions=['attack'])
    write(out/'skeleton_rig.json',data)
if __name__=='__main__':
    skeleton()
    source=(ROOT/'tools/phase3_rig_bake.gd').read_text(encoding='utf8')
    source=source.replace('const OUT := "res://build/verification/phase3/06-animation-balance/"','const OUT := "res://build/verification/phase3/08-parallel/base_a/"')
    source=source.replace('animation.track_set_path(track,NodePath(node_path+":"+property))','animation.track_set_path(track,NodePath(node_path+":"+property))\n\t\t\t\tanimation.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)')
    (ROOT/'tools/phase3_v05_base_a_bake.gd').write_text(source,encoding='utf8')
