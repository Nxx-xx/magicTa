"""Encode existing review/capture pixels and audit distinct poses; no painting."""
import hashlib
import json
import argparse
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--entity',default='minotaur',choices=['minotaur','golem'])
args=parser.parse_args()
source=root/('assets/monsters/phase3/source/rig_v04' if args.entity=='minotaur' else 'assets/monsters/phase3/source/golem_v04')
out=root/f'build/verification/phase3/07-completion/{args.entity}-host'
audit={}
for entity in [args.entity,args.entity+'_map']:
    draft=json.loads((source/(entity+'_draft_manifest.json')).read_text(encoding='utf-8'))
    for name,action in draft['actions'].items():
        paths=action.get('combined_frames',action['frames'])
        images=[Image.open(source/p).convert('RGBA') for p in paths]
        hashes=[hashlib.sha256(im.tobytes()).hexdigest() for im in images]
        audit[entity+'_'+name]={'slots':len(images),'unique_action_poses':len(set(hashes)),
            'pose_holds':action.get('pose_holds',{}),'edge_touch':any(m['edge_touch'] for m in action['metrics'])}
        images[0].save(out/(entity+'_'+name+'.webp'),save_all=True,append_images=images[1:],
            duration=round(1000/action['fps']),lossless=True,loop=0 if action['loop'] else 1)
capture=json.loads((out/'results.json').read_text(encoding='utf-8'))
captures=[out/'frames'/f'{index:03}.png' for index in range(capture['frame_count'])]
images=[Image.open(p).convert('RGB') for p in captures]
images[0].save(out/'main-game-replay.webp',save_all=True,append_images=images[1:],duration=50,lossless=True,loop=0)
(out/'pose-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'Encoded {len(captures)} actual host frames and six transparent action previews; wrote pose audit.')
