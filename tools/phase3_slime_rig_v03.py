"""Edit the native rig's timeline definitions; raster art is supplied by imagegen."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
source = root/'assets/monsters/phase3/source/rig_v03/slime_rig.json'
data = json.loads(source.read_text(encoding='utf-8'))
data['shape_layers']['membrane'] = data['shape_layers']['membrane'][:6]
data['shape_layers']['membrane'][5].update(canvas=[512,512],offset=[0,52])
for i in range(6):
    data['shape_layers']['membrane'].append({'source':'slime_defeat_cleanup.png',
        'crop':[(i%3)*512,(i//3)*512,512,512], 'canvas':[512,512],
        'offset':[0,-16 if i<3 else 42]})
data['actions']['idle']['poses'] = [
    {'membrane':{'shape':0}},
    {'membrane':{'shape':5},'face':{'p':[0,-2]},'core':{'p':[0,-3]}},
    {'membrane':{'shape':0},'face':{'p':[0,1]},'core':{'p':[0,1]}},
    {'membrane':{'shape':5},'face':{'p':[0,1]},'core':{'p':[0,2]}}]
data['actions']['hit']['poses'] = [
    {'membrane':{'shape':1},'face':{'p':[10,35]},'core':{'p':[0,50]}},
    {'membrane':{'shape':0}}]
data['actions']['defeat'] = {'fps':10,'loop':False,'events':{},'poses':[
    {'membrane':{'shape':0 if i == 0 else 6+i},'face':{'p':[0,min(i,2)*22],'a':max(0,1-i*.6)},
     'core':{'p':[0,i*35],'a':max(0,1-i*.6)}} for i in range(6)]}
data['acceptance'] = 'v03 source, inspect baked poses before production promotion'
source.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
