"""Explicit promotion of visually reviewed native rig output. No image editing."""
import json
import shutil
from pathlib import Path
root = Path(__file__).resolve().parents[1]
source = root/'assets/monsters/phase3/source/rig_v03'
review = json.loads((source/'slime_draft_manifest.json').read_text(encoding='utf-8'))
path = root/'assets/monsters/phase3/manifest.json'
manifest = json.loads(path.read_text(encoding='utf-8'))
manifest.update(status='partially_accepted',accepted_entities=sorted(set(manifest.get('accepted_entities',[]))|{'slime'}),production_ready=False,
    source_method='Reviewed native rigs; retained unreviewed draft sheets for other enemies')
for name, action in review['actions'].items():
    assert len(action['frames']) == {'idle':4,'attack':6,'hit':2,'defeat':6}[name]
    assert all(not m['edge_touch'] for m in action['metrics'])
    paths = []
    for i, relative in enumerate(action['frames']):
        target = root/f'assets/monsters/phase3/textures/v03/slime/{name}/{i:02}.png'
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source/relative,target)
        paths.append('res://'+target.relative_to(root).as_posix())
    manifest['actions']['slime_'+name] = {k:action[k] for k in ('fps','loop','events')}
    manifest['actions']['slime_'+name].update(frames=paths,size=[256,256],anchor=[128,224],
        status='accepted',source=review['source'],review='source/rig_v03/REVIEW.md')
path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Published slime: 4 combat actions / 18 timeline frames; other enemies unchanged')
