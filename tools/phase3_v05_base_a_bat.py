import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/monsters/phase3/source/parallel_v05/battle/bat'
layers=[]
def add(n,pa,p,c,ip,s,z): layers.append(dict(name=n,parent=pa,pivot=p,crop=c,image_pivot=ip,scale=s,z=z))
add('body','root',[273,298],[480,155,325,300],[160,148],.29,2)
add('head','body',[250,271],[105,50,305,390],[150,295],.27,5)
add('near_wing','body',[255,280],[855,85,380,355],[317,233],.23,1)
add('near_tip','near_wing',[201,237],[15,480,400,350],[372,163],.29,0)
add('far_wing','body',[298,277],[455,480,370,355],[57,218],.21,-3)
add('far_tip','far_wing',[348,237],[855,480,380,355],[40,159],.26,-4)
add('talons','body',[278,339],[120,920,220,250],[110,70],.19,3)
add('shadow','root',[270,448],[465,920,365,300],[182,150],.37,-8)
add('swoosh','root',[158,285],[865,880,385,330],[190,165],.48,6)
layers.extend([dict(name='near_wrist',parent='near_wing',pivot=[201,237],joint_only=True,z=0),dict(name='far_wrist',parent='far_wing',pivot=[348,237],joint_only=True,z=-4)])
def pose(dx=0,dy=0,b=0,h=0,n=0,f=0,nt=0,ft=0,feet=0,fx=0,shadow=.35,fold=0):
    return {'body':{'p':[dx,dy],'r':b},'head':{'r':h},'near_wing':{'r':n,'p':[0,-22*fold]},'far_wing':{'r':f,'p':[0,-22*fold]},'near_tip':{'r':nt},'far_tip':{'r':ft},'talons':{'r':feet},'swoosh':{'a':fx,'r':180},'shadow':{'a':shadow}}
actions={}
def action(n,fps,args,loop=False,events=None): actions[n]=dict(fps=fps,loop=loop,events=events or {},poses=[pose(**x) for x in args])
action('idle',8,[dict(n=22,f=-20,nt=10,ft=-9),dict(dy=-6,h=-2,n=48,f=-44,nt=22,ft=-20,feet=5),dict(dy=-2,h=1,n=-32,f=30,nt=-8,ft=6,feet=-3),dict(dy=5,h=2,n=-12,f=10,nt=3,ft=-3,feet=-5)],True)
action('attack',12,[dict(n=22,f=-20,nt=10,ft=-9),dict(dx=9,dy=-8,b=8,h=-6,n=55,f=-50,nt=24,ft=-18,feet=12),dict(dx=-13,dy=-2,b=-9,h=3,n=-30,f=32,nt=-8,ft=8),dict(dx=-38,dy=14,b=-18,h=-4,n=-48,f=45,nt=12,ft=-12,feet=22,fx=.7),dict(dx=-15,dy=6,b=-6,h=1,n=5,f=-4,nt=10,ft=-8,fx=.2),dict(n=22,f=-20,nt=10,ft=-9)],events={'hit':3})
action('hit',12,[dict(dx=16,dy=8,b=18,h=12,n=-25,f=8,nt=30,ft=-30,feet=-20),dict(n=22,f=-20,nt=10,ft=-9)],events={'recoil':0})
action('defeat',10,[dict(dx=5,dy=10,b=12,h=10,n=-30,f=35,nt=22,ft=-20),dict(dx=8,dy=32,b=18,h=8,n=-46,f=50,nt=0,ft=5,feet=-12),dict(dx=3,dy=65,b=-9,h=-10,n=-65,f=72,nt=-25,ft=40,feet=-30,fold=.3),dict(dx=-4,dy=90,b=-32,h=-20,n=-82,f=92,nt=-80,ft=130,feet=-45,fold=.7),dict(dx=-7,dy=112,b=-45,h=-28,n=-90,f=100,nt=-95,ft=160,feet=-55,fold=1),dict(dx=-7,dy=112,b=-45,h=-28,n=-90,f=100,nt=-95,ft=160,feet=-55,fold=1)],events={'ground':3,'settle':4})
d=dict(version=1,status='draft',entity='bat',view='battle_left',canvas=512,runtime_size=256,anchor=[256,448],rest_scale=.93,source='bat_components.png',layers=layers,actions=actions,pose_holds={'attack':{'5':0},'defeat':{'5':4}},effect_layers=['swoosh'],effect_actions=['attack'])
(OUT/'bat_rig.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf8')
