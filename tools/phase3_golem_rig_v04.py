"""Editable golem articulation and independent map registration. Draft only."""
import copy
import json
import math
from pathlib import Path

root=Path(__file__).resolve().parents[1]
folder=root/'assets/monsters/phase3/source/golem_v04'
layers=[]
# Measured alpha-component rectangles, including a clear gutter. The generated
# pieces cross the nominal atlas grid; slicing equal cells clips parts and grabs
# neighbors. Cropping extracts painted pieces, without repainting their pixels.
rects=[[25,64,220,265],[265,47,238,296],[523,121,229,227],[801,59,182,272],[1023,95,207,244],
       [49,360,190,280],[253,411,219,227],[538,369,184,278],[807,357,152,232],[1014,466,185,170],
       [62,664,176,272],[309,656,145,239],[504,764,218,171],[745,704,227,232],[1004,703,237,228],
       [60,1000,141,185],[287,968,159,246],[541,968,168,245],[769,970,189,239],[1031,1008,196,171]]
absolute_pivots={8:[880,409],9:[1150,578],11:[381,706],12:[641,885],7:[637,416],10:[159,712]}
def add(name,parent,pivot,cell,ip,scale,z):
    col,row=cell%5,cell//5
    absolute=absolute_pivots.get(cell,[round(col*1254/5)+ip[0],round(row*1254/4)+ip[1]])
    x,y,w,h=rects[cell]
    layers.append(dict(name=name,parent=parent,pivot=pivot,crop=rects[cell],image_pivot=[absolute[0]-x,absolute[1]-y],scale=scale,z=z))
add('pelvis','root',[391,467],2,[125,95],.75,-1)
add('torso','root',[391,349],1,[125,195],.82,0)
add('head','torso',[386,240],0,[140,245],.67,4)
layers[-1].update(source='golem_head_left.png',crop=[0,0,1254,1254],image_pivot=[700,1080],scale=.155)
add('far_upper_arm','torso',[463,275],5,[100,65],.66,-4)
add('far_forearm','far_upper_arm',[482,382],6,[165,90],.66,-3)
add('near_upper_arm','torso',[294,278],3,[140,65],.70,1)
add('near_forearm','near_upper_arm',[271,389],4,[165,65],.70,3)
add('far_shoulder','torso',[463,269],14,[125,130],.61,1)
add('near_shoulder','torso',[294,273],13,[140,130],.65,4)
add('core','torso',[352,323],15,[125,158],.34,5)
add('near_plate','torso',[334,342],16,[160,140],.46,6)
add('far_plate','torso',[384,343],17,[95,140],.46,6)
add('armor_rune','torso',[359,333],18,[125,175],.39,7)
add('debris','root',[452,665],19,[125,200],.57,2)
for side,hip,knee,ankle,first,z in [('near',[341,462],[318,551],[310,641],7,2),('far',[433,454],[451,540],[457,625],10,-5)]:
    for part,parent,point,cell,ip,scale in zip(['thigh','shin','foot'],['root',side+'_thigh',side+'_shin'],[hip,knee,ankle],range(first,first+3),[[125,70],[120,65],[170,175]],[.66,.53,.67]):
        add(side+'_'+part,parent,point,cell,ip,.53 if part=='thigh' else scale,z)
base={l['name']:l for l in layers}
def plus(a,b): return [a[0]+b[0],a[1]+b[1]]
def sub(a,b): return [a[0]-b[0],a[1]-b[1]]
def rot(v,degrees):
    t=math.radians(degrees)
    return [v[0]*math.cos(t)-v[1]*math.sin(t),v[0]*math.sin(t)+v[1]*math.cos(t)]
def angle(a,b): return math.degrees(math.atan2(b[1]-a[1],b[0]-a[0]))
def world(name,p):
    if name=='root': return [0,0],0
    l=base[name];parent=l['parent'];pos,r=world(parent,p)
    origin=[0,0] if parent=='root' else base[parent]['pivot']
    return plus(pos,rot(plus(sub(l['pivot'],origin),p.get(name,{}).get('p',[0,0])),r)),r+p.get(name,{}).get('r',0)
def absolute(p,name,target,degrees):
    l=base[name];parent=l['parent'];pos,r=world(parent,p)
    origin=[0,0] if parent=='root' else base[parent]['pivot']
    p.setdefault(name,{})['p']=sub(rot(sub(target,pos),-r),sub(l['pivot'],origin))
    p[name]['r']=degrees-r
def contact_legs(p,dx,dy):
    contacts={}
    for side in ['near','far']:
        hip=base[side+'_thigh']['pivot'];knee=base[side+'_shin']['pivot'];ankle=base[side+'_foot']['pivot']
        h=plus(hip,[dx,dy]);d=math.dist(h,ankle);a=math.dist(hip,knee);b=math.dist(knee,ankle)
        dist=min(d,a+b-.01);along=(a*a-b*b+dist*dist)/(2*dist);height=math.sqrt(max(0,a*a-along*along))
        u=[(ankle[0]-h[0])/d,(ankle[1]-h[1])/d];k=[h[0]+u[0]*along-u[1]*height,h[1]+u[1]*along+u[0]*height]
        r1=angle(h,k)-angle(hip,knee);r2=angle(k,ankle)-angle(knee,ankle)-r1
        p[side+'_thigh']={'p':[dx,dy],'r':r1};p[side+'_shin']={'r':r2};p[side+'_foot']={'r':-r1-r2}
        contacts[side]=world(side+'_foot',p)[0]
    return contacts
def pose(dx=0,dy=0,chest=0,head=0,arm=0,fore=0,far=0,close=0,rune=0,core=1):
    p={'torso':{'p':[dx,dy],'r':chest},'pelvis':{'p':[dx,dy]},'head':{'r':head},
       'near_upper_arm':{'r':arm},'near_forearm':{'r':fore},'far_upper_arm':{'r':far},'far_forearm':{'r':-far*.5},
       'near_plate':{'p':[-28*(1-close),0],'a':close,'r':-20*(1-close)},
       'far_plate':{'p':[28*(1-close),0],'a':close,'r':20*(1-close)},'armor_rune':{'a':rune},'core':{'a':core},'debris':{'a':0}}
    c=contact_legs(p,dx,dy)
    return p,c
actions={};contacts={}
def action(name,fps,params,loop=False,events=None):
    result=[pose(**p) for p in params]
    actions[name]=dict(fps=fps,loop=loop,events=events or {},poses=[p[0] for p in result])
    contacts[name]=[p[1] for p in result]
action('idle',6,[{},dict(dy=-1,head=-.7,arm=1,far=-1),dict(dy=-2,head=-1.2,arm=1.8,far=-2),dict(dy=-1,head=-.3,arm=.7,far=-1),dict(dy=1,head=.5,arm=-.6,far=.6),dict(dy=1,head=.8,arm=-1,far=1)],True)
action('attack',12,[{},dict(dx=4,dy=8,chest=-2,arm=20,fore=8,far=-8),dict(dx=8,dy=15,chest=-4,head=3,arm=50,fore=18,far=-16),
    dict(dx=10,dy=20,chest=-5,head=4,arm=76,fore=22,far=-22),dict(dx=5,dy=13,chest=-2,arm=82,fore=25,far=-23),
    dict(dx=-12,dy=21,chest=-10,head=4,arm=23,fore=-23,far=10),dict(dx=-10,dy=18,chest=-7,arm=5,fore=-25,far=12),
    dict(dx=-6,dy=11,chest=-4,arm=1,fore=-12,far=6),dict(dx=-2,dy=4,chest=-1,arm=.5,fore=-3,far=2),{}],events={'hit':5})
action('hit',12,[dict(dx=8,dy=9,chest=6,head=7,arm=-6,fore=9,far=-8),dict(dx=4,dy=5,chest=3,head=3,arm=-3,fore=4,far=-4),{}])
action('armor',12,[dict(dy=9,chest=-2,arm=5,far=-5,close=.08,rune=.1),dict(dy=14,chest=-3,head=3,arm=10,far=-10,close=.28,rune=.4),
    dict(dy=9,chest=-1,arm=14,fore=8,far=-15,close=.58,rune=.75),dict(dy=4,chest=2,head=-2,arm=10,fore=7,far=-11,close=.85,rune=1),
    dict(dy=1,chest=1,head=-1,arm=5,fore=3,far=-5,close=1,rune=.7),dict(arm=1,far=-1,close=1,rune=.3)],events={'closed':4})
collapse_targets={'pelvis':([480,611],80),'torso':([407,574],70),'head':([315,574],70),
    'near_upper_arm':([250,613],-80),'near_forearm':([219,640],65),'far_upper_arm':([524,610],90),'far_forearm':([567,625],70),
    'near_shoulder':([372,629],100),'far_shoulder':([511,618],-80),'core':([373,619],80),
    'near_plate':([300,633],80),'far_plate':([442,628],-75),'armor_rune':([359,615],0),'debris':([460,660],8),
    'near_thigh':([340,632],80),'near_shin':([430,632],60),'near_foot':([475,648],-25),
    'far_thigh':([483,640],-80),'far_shin':([550,632],-100),'far_foot':([581,647],15)}
death=[]
for index in range(12):
    k=min(index,10)/10
    p,c=pose(dx=3-10*k,dy=55*min(1,k*1.8),chest=8-20*k,head=5-20*k,arm=-4+20*k,fore=12*k,far=18*k,close=.8,core=1-.6*k)
    if index>=3:
        scatter=((min(index,10)-3)/7)**1.3
        snapshot={name:world(name,p) for name in collapse_targets}
        for name,(target,degrees) in collapse_targets.items():
            pos,r=snapshot[name]
            absolute(p,name,[pos[0]+(target[0]-pos[0])*scatter,pos[1]+(target[1]-pos[1])*scatter],r+(degrees-r)*scatter)
        p['core']['a']=max(.08,1-k*1.1);p['debris']['a']=min(1,scatter*2)
    death.append(p)
actions['defeat']=dict(fps=12,loop=False,events={'fracture':3,'core_dark':8,'ground':10},poses=death)
data=dict(version=1,status='draft',entity='golem',canvas=768,runtime_size=384,anchor=[384,672],rest_scale=.90,
    source='golem_components.png',layers=layers,actions=actions,pose_holds={'attack':{'9':0},'defeat':{'11':10}},contacts=contacts,
    effect_layers=['armor_rune'],effect_actions=['armor'],acceptance='Draft: review assembly, independent armor closing, rock-collapse tracks, small silhouettes before publication.')
(folder/'golem_rig.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

# Separate camera: independently generated frontal elevated anatomy.
ml=[]
map_rects=[[77,76,316,317],[485,54,285,379],[900,75,285,315],[72,448,277,310],[515,448,218,326],
           [929,440,200,333],[121,793,211,404],[515,800,186,404],[938,800,188,400]]
map_pivots={6:[221,855],7:[607,868],8:[1030,868]}
def map_layer(name,parent,pivot,cell,ip,scale,z):
    col,row=cell%3,cell//3
    absolute=map_pivots.get(cell,[col*418+ip[0],row*418+ip[1]])
    x,y,w,h=map_rects[cell]
    ml.append(dict(name=name,parent=parent,pivot=pivot,crop=map_rects[cell],image_pivot=[absolute[0]-x,absolute[1]-y],scale=scale,z=z))
map_layer('torso','root',[256,346],1,[208,320],.62,0)
map_layer('head','torso',[256,179],0,[208,325],.42,5)
map_layer('far_arm','torso',[342,213],6,[170,100],.44,-3)
map_layer('near_upper_arm','torso',[171,214],4,[175,80],.40,1)
map_layer('near_forearm','near_upper_arm',[156,290],5,[185,105],.42,3)
map_layer('near_shoulder','torso',[170,211],2,[200,185],.38,4)
map_layer('far_shoulder','torso',[341,211],3,[208,180],.38,2)
map_layer('near_leg','root',[210,341],7,[208,85],.31,-1)
map_layer('far_leg','root',[298,341],8,[208,85],.31,-2)
map_actions={'idle':dict(fps=6,loop=True,events={},poses=[{'torso':{'p':[0,dy]},'head':{'r':h},'near_upper_arm':{'r':a},'near_forearm':{'r':-a*.5},'far_arm':{'r':-a}} for dy,h,a in [(0,0,0),(-1,-.4,.5),(-2,-.7,1),(-1,.3,-.4)]])}
md=dict(version=1,status='draft',entity='golem_map',canvas=512,runtime_size=256,anchor=[256,448],rest_scale=1,source='golem_map_components.png',layers=ml,actions=map_actions,
    acceptance='Independent map camera, stable feet. Review shoulders and closed torso seams.')
(folder/'golem_map_rig.json').write_text(json.dumps(md,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Draft golem: 20 articulated battle parts, five actions/37 slots, independent nine-layer map/4 slots; no production changes.')
