"""Author editable cutout joints/timelines. Raster art is imagegen; no painting here.
JSON is the editable source; Godot packs named cropped layers and native animations.
All output stays DRAFT until visual/art acceptance; this script never edits manifests.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def layer(name, parent, pivot, crop, image_pivot, scale=1, z=0):
    return dict(name=name,parent=parent,pivot=pivot,crop=crop,image_pivot=image_pivot,scale=scale,z=z)

def save(folder, name, canvas, anchor, layers, actions):
    path=ROOT/folder
    path.mkdir(parents=True,exist_ok=True)
    data=dict(version=1,status='draft',entity=name,canvas=canvas,runtime_size=canvas//2,
              anchor=anchor,rest_scale=.8 if name in ('hero','minotaur') else 1,
              source='components_boot_fix_draft.png' if name=='hero' else ('minotaur_components_joint_fix_draft.png' if name=='minotaur' else name+'_components_draft.png'),
              layers=layers,actions=actions,
              acceptance='NOT ACCEPTED: articulated source prototype, not production animation')
    if name=='slime':
        data['shape_layers']={'membrane':[{'source':'slime_shapes_cleanup_draft.png','crop':[(i%3)*512,(i//3)*512,512,512]} for i in range(6)]}
        # Explicit atlas extraction rectangles, not per-frame body recentering.
        data['shape_layers']['membrane'][3]['crop']=[0,512,536,512]
        data['shape_layers']['membrane'][4].update(crop=[536,512,488,512],canvas=[512,512],offset=[24,0])
    (path/(name+'_rig.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')

def action(fps, poses, loop=False, hit=None):
    return dict(fps=fps,loop=loop,poses=poses,events={} if hit is None else {'hit':hit})

# Pivots are canvas-space rest coordinates; parent links form the actual joint tree.
hero=[
layer('cape_back','root',[364,280],[650,0,310,395],[150,60],.9,-8),
layer('left_thigh','root',[355,470],[60,960,220,260],[100,35],.62,-5),
layer('left_boot','left_thigh',[355,564],[365,960,220,280],[100,25],.52,-5),
layer('left_upper_arm','torso',[380,310],[1030,415,190,260],[65,55],.7,-4),
layer('left_forearm','left_upper_arm',[410,380],[65,700,210,250],[140,30],.7,-3),
layer('lantern','left_forearm',[370,492],[410,700,160,260],[75,35],.55,-3),
layer('right_thigh','root',[392,470],[690,690,230,255],[110,35],.64,-2),
layer('right_boot','right_thigh',[392,565],[1020,685,220,275],[92,25],.53,-2),
layer('torso','root',[384,470],[400,40,230,350],[130,290],.78,0),
layer('head','torso',[398,275],[15,10,310,365],[190,310],.72,3),
layer('right_upper_arm','torso',[377,320],[80,410,185,250],[92,65],.7,4),
layer('right_forearm','right_upper_arm',[358,420],[390,415,225,255],[60,50],.7,5),
layer('sword','right_forearm',[447,528],[660,405,310,290],[82,73],.72,4),
layer('cape_front','torso',[370,290],[1020,70,225,285],[100,40],.68,6),
]
# Angles rotate independent limbs, not the flattened original sprite. Root never moves.
hero_actions={
'idle':action(6,[{}, {'head':{'r':-1},'lantern':{'r':2}}, {'head':{'r':0},'lantern':{'r':0}}, {'head':{'r':1},'lantern':{'r':-2}}],True),
'attack':action(16,[{}, {'right_upper_arm':{'r':-28},'right_forearm':{'r':-25}}, {'right_upper_arm':{'r':-65},'right_forearm':{'r':-38},'sword':{'r':-15}}, {'right_upper_arm':{'r':-80},'right_forearm':{'r':15},'sword':{'r':-10}}, {'right_upper_arm':{'r':-65},'right_forearm':{'r':22}}, {'right_upper_arm':{'r':-30},'right_forearm':{'r':10}}, {'right_upper_arm':{'r':-10}}, {}],hit=3),
'hit':action(12,[{'torso':{'r':-5},'head':{'r':-4}}, {'torso':{'r':-3}}, {}]),
}
save('assets/characters/hero/phase3/source/rig_v02','hero',768,[384,696],hero,hero_actions)

slime=[layer('membrane','root',[256,448],[20,120,665,545],[256,480],.8,0),
layer('core','membrane',[260,320],[150,750,390,370],[195,185],.35,-1),
layer('face','membrane',[230,335],[820,340,290,190],[140,100],.55,2)]
# Layer articulation experiment only: not accepted body animation. No whole-sprite scaling.
slime_actions={'idle':action(6,[{}, {'core':{'p':[0,-3]},'face':{'p':[0,-1]}}, {'core':{'p':[0,-1]}}, {'core':{'p':[0,2]},'face':{'p':[0,1]}}],True),
'hit':action(12,[{'face':{'r':-8,'p':[6,2]},'core':{'p':[9,3]}},{}]),
'attack':action(12,[{'membrane':{'shape':0}}, {'membrane':{'shape':1},'face':{'p':[10,35]},'core':{'p':[0,60]}}, {'membrane':{'shape':2},'face':{'p':[-20,-12]}}, {'membrane':{'shape':3},'face':{'p':[-75,-65]},'core':{'p':[45,-20]}}, {'membrane':{'shape':4},'face':{'p':[-35,-60]},'core':{'p':[20,15]}}, {'membrane':{'shape':5}}],hit=3)}
save('assets/monsters/phase3/source/rig_v02','slime',512,[256,448],slime,slime_actions)

mino=[layer('far_leg','root',[420,470],[500,810,310,435],[145,45],.53,-4),
layer('far_arm','torso',[462,298],[915,465,315,375],[118,70],.55,-3),
layer('near_leg','root',[333,470],[40,810,300,430],[180,45],.55,-2),
layer('torso','root',[384,478],[420,0,420,495],[208,365],.76,0),
layer('head','torso',[365,278],[10,0,400,425],[235,330],.61,2),
layer('upper_arm','torso',[307,315],[70,470,340,345],[160,90],.59,3),
layer('forearm','upper_arm',[324,438],[440,498,350,312],[265,37],.58,4),
layer('axe','forearm',[219,555],[840,0,405,460],[235,170],.55,3),
layer('rage_rune','torso',[378,386],[830,840,410,400],[210,200],.23,5)]
mino_actions={'idle':action(6,[{}, {'head':{'r':-1}}, {'head':{'r':-2}}, {'head':{'r':-1}}, {}, {'head':{'r':1}}],True),
'attack':action(12,[{}, {'upper_arm':{'r':25}}, {'upper_arm':{'r':65},'forearm':{'r':30}}, {'upper_arm':{'r':90},'forearm':{'r':35}}, {'upper_arm':{'r':-35},'forearm':{'r':-15}}, {'upper_arm':{'r':-25}}, {'upper_arm':{'r':-10}}, {}],hit=4),
'hit':action(12,[{'torso':{'r':5},'head':{'r':8}}, {'torso':{'r':2}}, {}]),
'rage':action(12,[{'rage_rune':{'a':.2}}, {'rage_rune':{'a':.5},'head':{'r':-3}}, {'rage_rune':{'a':1},'head':{'r':-6}}, {'rage_rune':{'a':.7},'head':{'r':-4}}, {'rage_rune':{'a':.3},'head':{'r':-1}}, {}])}
save('assets/monsters/phase3/source/rig_v02','minotaur',768,[384,672],mino,mino_actions)
print('Wrote three editable draft rig JSON sources; no production manifests changed.')
