"""Encode existing captured frames; does not paint, modify or promote artwork."""
from pathlib import Path
from PIL import Image
import json,hashlib
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification/phase3/06-animation-balance'
captures=sorted((OUT/'host-frames').glob('*.png'))
images=[Image.open(p).convert('RGB') for p in captures]
images[0].save(OUT/'main-game-replay.gif',save_all=True,append_images=images[1:],duration=100,loop=0)
sources=[ROOT/'assets/characters/hero/phase3/source/rig_v02/hero_rig.json',ROOT/'assets/monsters/phase3/source/rig_v02/slime_rig.json',ROOT/'assets/monsters/phase3/source/rig_v02/minotaur_rig.json']
audit=[]
for source in sources:
    rig=json.loads(source.read_text(encoding='utf-8'))
    manifest=json.loads(source.with_name(rig['entity']+'_draft_manifest.json').read_text(encoding='utf-8'))
    entity=dict(entity=rig['entity'],status='draft',layers=len(rig['layers']),actions={})
    all_hashes=set()
    for action,spec in manifest['actions'].items():
        frames=[Image.open(source.parent/p).convert('RGBA') for p in spec['frames']]
        hashes=[hashlib.sha256(im.tobytes()).hexdigest() for im in frames]
        all_hashes.update(hashes)
        entity['actions'][action]=dict(frame_slots=len(frames),unique_raster_poses=len(set(hashes)),
          fully_transparent_pixels=[im.getchannel('A').tobytes().count(0) for im in frames],
          accepted=False)
        # Animated WebP preserves transparency and original pose pixels.
        frames[0].save(OUT/(rig['entity']+'_'+action+'_draft.webp'),save_all=True,append_images=frames[1:],duration=round(1000/spec['fps']),lossless=True,loop=0)
    entity['unique_raster_poses_across_actions']=len(all_hashes)
    audit.append(entity)
(OUT/'draft-frame-audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
print('Encoded real gameplay GIF and draft-only animated WebP previews; wrote distinct-pose audit.')
