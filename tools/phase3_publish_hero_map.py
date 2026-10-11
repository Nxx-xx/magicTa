"""Package the reviewed map actions. No raster generation or retouching here."""
import json
import argparse
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/characters/hero/phase3/source/rig_v03'
ASSET = ROOT / 'assets/characters/hero/phase3'
review = json.loads((SOURCE / 'review_manifest.json').read_text(encoding='utf-8'))
manifest = json.loads((ASSET / 'manifest.json').read_text(encoding='utf-8'))
actions = {}
parser = argparse.ArgumentParser()
parser.add_argument('--include-combat', action='store_true')
args = parser.parse_args()
for name, action in review['actions'].items():
    if not name.startswith('map_') and not args.include_combat:
        continue
    size = action['size'][0]
    assert all(b[0] >= 4 and b[1] >= 4 and b[2] <= size-4 and b[3] <= size-4 for b in action['bounds']), name
    if name.startswith('map_walk_'):
        contacts = action['foot_contacts_map_px']
        for i in [0, 3]:
            assert all(abs(contacts[i][foot][1]-116) <= 1 for foot in ['right', 'left']), (name, i)
        assert contacts[1]['left'][1] < 115 and contacts[4]['right'][1] < 115, name
    target = ASSET / 'textures/v03' / name
    target.mkdir(parents=True, exist_ok=True)
    frames = []
    for i, source in enumerate(action['frames']):
        destination = target / f'{i:02d}.png'
        shutil.copy2(ROOT / source.removeprefix('res://'), destination)
        frames.append('res://' + destination.relative_to(ROOT).as_posix())
    actions[name] = {k: action[k] for k in ['fps', 'loop', 'size', 'anchor', 'events']}
    actions[name].update(status='accepted', frames=frames,
        source='source/rig_v03/hero_' + (name.rsplit('_', 1)[1] if name.startswith('map_') else 'right') + '_editable.tscn',
        review='source/rig_v03/REVIEW.md')
    if name == 'combat_attack':
        actions[name]['pose_holds'] = {'7': 0}  # Return to authored rest pose.
    elif name == 'combat_victory':
        actions[name]['pose_holds'] = {'4': 3}  # Brief raised-lantern hold.
manifest.update(status='accepted_v03' if args.include_combat else 'map_actions_accepted_combat_pending', actions=actions)
(ASSET / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(f'Published {len(actions)} actions, {sum(len(a["frames"]) for a in actions.values())} timeline frames; combat included={args.include_combat}.')
