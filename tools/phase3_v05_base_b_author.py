"""Articulate imagegen components; no pixel painting, no production publishing."""
import json, math, copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/monsters/phase3/source/parallel_v05/battle'
def addv(a,b): return [a[0]+b[0],a[1]+b[1]]
def sub(a,b): return [a[0]-b[0],a[1]-b[1]]
def rot(p,d):
 t=math.radians(d);return [p[0]*math.cos(t)-p[1]*math.sin(t),p[0]*math.sin(t)+p[1]*math.cos(t)]
def angle(a,b):return math.degrees(math.atan2(b[1]-a[1],b[0]-a[0]))
def author(entity):
 layers=[]
 def layer(name,parent,pivot,rect,ip,scale,z):layers.append(dict(name=name,parent=parent,pivot=pivot,crop=rect,image_pivot=ip,scale=scale,z=z))
 def joint(name,parent,pivot):layers.append(dict(name=name,parent=parent,pivot=pivot,z=0,joint_only=True))
 if entity=='sentinel':
  rects=[[43,73,236,240],[330,48,291,303],[655,120,270,215],[998,8,222,361],[65,374,201,239],[348,374,238,269],[699,377,201,248],[995,387,216,265],[48,634,215,283],[390,644,169,291],[651,743,269,195],[1007,655,208,269],[88,945,174,283],[335,1038,277,191],[712,990,175,212],[986,966,226,245]]
  def L(n,p,xy,i,ip,s,z):layer(n,p,xy,rects[i],ip,s,z)
  L('torso','root',[270,256],1,[143,190],.53,0)
  L('pelvis','torso',[275,325],2,[135,75],.43,-1)
  L('head','torso',[255,188],0,[135,207],.42,5)
  L('near_upper_arm','torso',[207,205],4,[112,49],.39,2)
  L('near_forearm','near_upper_arm',[202,269],5,[190,39],.39,3)
  L('far_upper_arm','torso',[333,206],6,[91,45],.37,-4)
  L('far_forearm','far_upper_arm',[351,265],7,[174,44],.36,-3)
  joint('shield_grip','far_forearm',[321,327])
  L('shield','shield_grip',[321,327],3,[78,174],.48,7)
  L('core','torso',[255,249],14,[88,104],.18,6)
  L('core_aura','core',[255,249],15,[109,120],.23,8)
  for side,hip,knee,ankle,cells,z in [('near',[239,333],[225,380],[229,423],[8,9,10],1),('far',[303,327],[321,373],[326,417],[11,12,13],-3)]:
   L(side+'_thigh','root',hip,cells[0],[146 if side=='near' else 65,55],.27,z)
   L(side+'_shin',side+'_thigh',knee,cells[1],[83 if side=='near' else 59,51],.25,z)
   L(side+'_foot',side+'_shin',ankle,cells[2],[175,68],.30,z+1)
  effect='core_aura'
 else:
  rects=[[91,70,190,245],[368,24,248,300],[704,42,200,269],[1003,72,174,246],[68,342,229,285],[382,399,207,219],[716,316,142,350],[996,334,192,326],[107,667,160,265],[389,662,166,278],[692,677,182,263],[1005,662,181,280],[45,955,270,282],[386,965,245,277],[712,937,168,306],[940,967,296,239]]
  def L(n,p,xy,i,ip,s,z):layer(n,p,xy,rects[i],ip,s,z)
  L('torso','root',[280,265],1,[126,223],.48,1)
  L('head','torso',[278,175],0,[107,215],.37,5)
  L('cape_upper','torso',[303,178],12,[77,55],.40,-5)
  L('cape_lower','cape_upper',[330,260],13,[48,25],.45,-6)
  joint('cape_joint','cape_upper',[330,260])
  L('tabard','torso',[270,288],14,[74,35],.34,3)
  L('near_upper_arm','torso',[226,190],2,[112,69],.33,4)
  L('near_forearm','near_upper_arm',[211,245],3,[112,46],.34,5)
  joint('weapon_grip','near_forearm',[186,303])
  L('sword','weapon_grip',[186,303],6,[69,280],.45,4)
  L('far_upper_arm','torso',[326,191],4,[84,67],.31,-2)
  L('far_forearm','far_upper_arm',[350,249],5,[53,56],.32,-1)
  joint('shield_grip','far_forearm',[380,292])
  L('shield','shield_grip',[380,292],7,[89,143],.40,7)
  L('sword_arc','root',[152,253],15,[146,117],.50,9)
  for side,hip,knee,ankle,cells,z in [('near',[250,304],[246,365],[237,435],[8,9],0),('far',[302,307],[314,365],[308,435],[10,11],-3)]:
   L(side+'_thigh','root',hip,cells[0],[75,30],.31,z)
   L(side+'_shin',side+'_thigh',knee,cells[1],[95,49],.34,z)
   joint(side+'_ankle',side+'_shin',ankle)
  effect='sword_arc'
 base={l['name']:l for l in layers}
 def world(n,p):
  if n=='root':return [0,0],0
  l=base[n];pp,pr=world(l['parent'],p);origin=[0,0] if l['parent']=='root' else base[l['parent']]['pivot'];q=p.get(n,{})
  return addv(pp,rot(addv(sub(l['pivot'],origin),q.get('p',[0,0])),pr)),pr+q.get('r',0)
 def absolute(p,n,target,degrees):
  l=base[n];pp,pr=world(l['parent'],p);origin=[0,0] if l['parent']=='root' else base[l['parent']]['pivot']
  p.setdefault(n,{})['p']=sub(rot(sub(target,pp),-pr),sub(l['pivot'],origin));p[n]['r']=degrees-pr
 def pose(dx=0,dy=0,chest=0,head=0,arm=0,fore=0,far=0,cloth=0,fx=0):
  p={'torso':{'p':[dx,dy],'r':chest},'head':{'r':head},'near_upper_arm':{'r':arm},'near_forearm':{'r':fore},'far_upper_arm':{'r':far},'far_forearm':{'r':-far*.6},effect:{'a':fx}}
  if entity=='knight':p.update(sword={'r':-34},cape_upper={'r':cloth},cape_lower={'r':cloth*.7},tabard={'r':cloth*.4})
  contacts={}
  for side in ('near','far'):
   hp=base[side+'_thigh']['pivot'];kp=base[side+'_shin']['pivot'];end=side+('_foot' if entity=='sentinel' else '_ankle');ap=base[end]['pivot'];h=addv(hp,[dx,dy]);a=math.dist(hp,kp);b=math.dist(kp,ap);d=math.dist(h,ap);dist=min(d,a+b-.01);along=(a*a-b*b+dist*dist)/(2*dist);height=math.sqrt(max(0,a*a-along*along));u=[(ap[0]-h[0])/d,(ap[1]-h[1])/d];k=[h[0]+u[0]*along-u[1]*height,h[1]+u[1]*along+u[0]*height];r1=angle(h,k)-angle(hp,kp);r2=angle(k,ap)-angle(kp,ap)-r1
   p[side+'_thigh']={'p':[dx,dy],'r':r1};p[side+'_shin']={'r':r2}
   if entity=='sentinel':p[end]={'r':-r1-r2}
   contacts[side]=world(end,p)[0]
  return p,contacts
 actions={};contacts={}
 def action(n,fps,params,loop=False,events=None):
  results=[pose(**k) for k in params];actions[n]=dict(fps=fps,loop=loop,events=events or {},poses=[r[0] for r in results]);contacts[n]=[r[1] for r in results]
 action('idle',6,[{},dict(dy=-1,head=-.8,arm=1,far=-1,cloth=1),dict(dy=-2,head=-1.2,arm=2,far=-2,cloth=2),dict(dy=-.6,head=.3,arm=-.6,far=.5,cloth=-.5)],True)
 if entity=='sentinel':
  attack=[{},dict(dx=6,dy=8,chest=-4,head=3,arm=-24,fore=-15,far=-10),dict(dx=9,dy=13,chest=-7,head=5,arm=-35,fore=-22,far=-15),dict(dx=-13,dy=12,chest=-10,head=4,arm=68,fore=10,far=14,fx=.7),dict(dx=-5,dy=6,chest=-4,arm=25,fore=7,far=6),{}]
 else:
  attack=[{},dict(dx=3,dy=5,chest=3,head=-2,arm=-80,fore=-30,cloth=6),dict(dx=5,dy=8,chest=5,head=-3,arm=-118,fore=-24,cloth=10),dict(dx=-14,dy=13,chest=-12,head=5,arm=42,fore=-12,far=8,cloth=-15,fx=.8),dict(dx=-6,dy=7,chest=-5,arm=20,fore=-4,cloth=-8),{}]
 action('attack',12,attack,events={'hit':3})
 if entity=='knight':
  for i,wrist in enumerate([-34,100,158,-93,-65,-34]):actions['attack']['poses'][i]['sword']['r']=wrist
 action('hit',12,[dict(dx=8,dy=7,chest=9,head=7,arm=-12,fore=10,far=-12,cloth=12),dict(dx=2,dy=2,chest=2,head=1,arm=-3,far=-2,cloth=4)],events={'recoil':0})
 death=[]
 for i in range(6):
  k=i/5;p,c=pose(dx=4-8*k,dy=60*k,chest=7-30*k,head=5+20*k,arm=12*k,fore=25*k,far=24*k,cloth=20*k)
  if entity=='sentinel' and i>=2:
   scatter=(i-2)/3;targets={'head':([203,396],-35),'torso':([286,389],25),'pelvis':([320,414],20),'near_upper_arm':([196,402],-70),'near_forearm':([162,416],65),'far_upper_arm':([359,398],45),'far_forearm':([364,426],65),'shield':([380,415],55),'near_thigh':([244,413],50),'near_shin':([273,427],65),'far_thigh':([320,411],-55),'far_shin':([355,427],-65)}
   snapshots={n:world(n,p) for n in targets}
   for n,(target,a) in targets.items():
    pos,r=snapshots[n];absolute(p,n,[pos[j]+(target[j]-pos[j])*scatter for j in range(2)],r+(a-r)*scatter)
   p['core']={'a':1-.85*k}
  elif entity=='knight' and i>=2:
   # Detached weapon has an explicit release track relative to grip, never a jump of hands.
   absolute(p,'sword',[168-10*(i-2),325+34*(i-2)],-55-12*(i-2))
  death.append(p)
 actions['defeat']=dict(fps=10,loop=False,events={'fracture' if entity=='sentinel' else 'release':2,'ground':5},poses=death)
 data=dict(version=1,status='draft',entity=entity,view='battle_left',canvas=512,runtime_size=256,anchor=[256,448],rest_scale=.93,source=entity+'_components.png',layers=layers,actions=actions,contacts=contacts,pose_holds={'attack':{'5':0}},effect_layers=[effect],effect_actions=['attack'],acceptance='Draft only; agent visual review and exact frame hash approval separate from bake; human_signoff false.')
 (BASE/entity/(entity+'_rig.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
 print(entity,len(layers),'layers; 18 frame slots')
for entity in ('sentinel','knight'):author(entity)
