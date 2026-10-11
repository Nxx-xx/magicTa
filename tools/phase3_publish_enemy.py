"""Explicit publication of action-by-action reviewed enemy sources.

Review approval is a separate checked-in record bound to exact frame hashes.
The bake tool never writes it, and changed frames cannot inherit approval.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

root=Path(__file__).resolve().parents[1]
args=argparse.ArgumentParser()
args.add_argument('--entity',required=True)
args.add_argument('--source',required=True)
opts=args.parse_args()
source=(root/opts.source).resolve()
assert source.is_relative_to(root/'assets/monsters/phase3/source')
review=json.loads((source/(opts.entity+'_publish_review.json')).read_text(encoding='utf-8'))
assert review['entity']==opts.entity and review['review_method']=='contact sheets plus native/browser playback; agent visual review'
manifest_path=root/'assets/monsters/phase3/manifest.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
prepared=[]
for action_id, approval in review['actions'].items():
    assert approval['decision']=='accepted',action_id
    draft=json.loads((source/approval['draft_manifest']).read_text(encoding='utf-8'))
    action=draft['actions'][approval['source_action']]
    actual=[hashlib.sha256((source/p).read_bytes()).hexdigest() for p in action['frames']]
    assert actual==approval['frame_sha256'],'Changed frames require a new visual review: '+action_id
    assert all(not m['edge_touch'] for m in action['metrics']),action_id
    assert len(actual)==approval['frame_slots'],action_id
    if action.get('effects_frames'):
        effect_hashes=[hashlib.sha256((source/p).read_bytes()).hexdigest() for p in action['effects_frames']]
        assert effect_hashes==approval['effects_sha256'],'Changed effect frames require review: '+action_id
    prepared.append((action_id,draft,action))
for action_id,draft,action in prepared:
    paths=[]
    for index,relative in enumerate(action['frames']):
        target=root/f'assets/monsters/phase3/textures/v04/{opts.entity}/{action_id}/{index:02}.png'
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source/relative,target)
        paths.append('res://'+target.relative_to(root).as_posix())
    manifest['actions'][opts.entity+'_'+action_id]={k:action[k] for k in ('fps','loop','events')}
    manifest['actions'][opts.entity+'_'+action_id].update(frames=paths,size=draft['size'],anchor=draft['anchor'],status='accepted',
        source=draft['source'],review=source.relative_to(root/'assets/monsters/phase3').as_posix()+'/REVIEW.md',
        pose_holds=review['actions'][action_id].get('pose_holds',{}))
    if action.get('effects_frames'):
        paths=[]
        for index,relative in enumerate(action['effects_frames']):
            target=root/f'assets/monsters/phase3/textures/v04/{opts.entity}/{action_id}/effects/{index:02}.png'
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(source/relative,target)
            paths.append('res://'+target.relative_to(root).as_posix())
        manifest['actions'][opts.entity+'_'+action_id]['effects_frames']=paths
accepted=set(manifest.get('accepted_entities',[]));accepted.add(opts.entity)
base_ids=['slime','skeleton','bat','sentinel','warlock','knight','berserker','warden','minotaur','golem']
def approved(entity,action):
    return manifest['actions'].get(entity+'_'+action,{}).get('status')=='accepted'
missing_base=[entity for entity in base_ids if not all(approved(entity,a) for a in
    ['idle','attack','hit','defeat']+(['rage'] if entity=='minotaur' else ['armor'] if entity=='golem' else []))]
missing_maps=[entity for entity in base_ids if not approved(entity,'map_idle')]
missing_variants=[entity for entity,extra in [('p3_shield_sentinel','guard'),('p3_ember_channeler','charge'),('p3_vault_knight','threat')]
    if not all(approved(entity,a) for a in ['idle','attack','hit','defeat',extra])]
manifest.update(status='partially_accepted',accepted_entities=sorted(accepted),production_ready=False,
    source_method='Reviewed native rigs; all unreviewed sheets remain draft; exact reviewed-frame hashes gate publication',
    view='combat_and_independent_map_partial',
    missing_creatures=missing_base+missing_variants,
    missing_deliverables=[f'{len(missing_base)} remaining base enemy combat sets and their editable rigs',
        f'{len(missing_variants)} variant attachment/action sets',f'independent map-camera idle: {", ".join(missing_maps)}',
        'human motion review and target-device acceptance'])
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'Published {opts.entity}: {len(prepared)} reviewed actions / {sum(len(a[2]["frames"]) for a in prepared)} frame slots')
