"""Independent elevated map-camera assembly; feet and root stay fixed."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'assets/monsters/phase3/source/rig_v04'
def layer(name,parent,pivot,crop,ip,scale,z):
    return dict(name=name,parent=parent,pivot=pivot,crop=crop,image_pivot=ip,scale=scale,z=z)
layers=[
    layer('far_leg','root',[300,340],[510,850,300,375],[108,60],.30,-5),
    layer('near_leg','root',[205,340],[80,840,330,375],[190,65],.31,-3),
    layer('far_arm','torso',[325,195],[940,490,280,420],[110,75],.38,-2),
    layer('torso','root',[256,350],[430,30,400,470],[200,450],.62,0),
    layer('head','torso',[253,130],[10,20,390,390],[205,310],.40,2),
    # Torso contains map-camera pauldrons; the cropped arm starts below them.
    layer('near_upper_arm','torso',[155,190],[170,650,180,145],[50,20],.37,1),
    layer('near_forearm','near_upper_arm',[176,255],[500,530,240,310],[70,70],.35,3),
    layer('axe','near_forearm',[179.5,319.75],[890,35,350,465],[180,205],.32,2),
]
poses=[{}, {'head':{'r':-.7},'near_upper_arm':{'r':.5},'near_forearm':{'r':-.5},'far_arm':{'r':-.5}},
       {'head':{'r':-1.2},'near_upper_arm':{'r':.8},'near_forearm':{'r':-.8},'far_arm':{'r':-.8}},
       {'head':{'r':.5},'near_upper_arm':{'r':-.4},'near_forearm':{'r':.4},'far_arm':{'r':.4}}]
data=dict(version=1,status='draft',entity='minotaur_map',canvas=512,runtime_size=256,anchor=[256,448],rest_scale=.88,
          source='minotaur_map_components.png',layers=layers,actions={'idle':dict(fps=6,loop=True,poses=poses,events={})},
          acceptance='Independent front/elevated map camera; inspect at 26/33/47 px before publishing')
(out/'minotaur_map_rig.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
print('Authored independent minotaur map source: 8 layers, 4 idle frame slots')
