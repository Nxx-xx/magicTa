"""Audit published coverage, exact source/review bytes, and protected baseline."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/verification/phase3/08-parallel/coordinator'

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

if __name__ == '__main__':
    baseline = read(OUT / 'baseline.json')
    manifest = read(ROOT / 'assets/monsters/phase3/manifest.json')
    errors = []
    def check(ok, label):
        if not ok:
            errors.append(label)
    for key, metadata in baseline['accepted_actions'].items():
        check(manifest['actions'].get(key) == metadata, 'Protected accepted metadata changed: ' + key)
    frame_key = next(k for k in baseline if k not in ['accepted_actions', 'preserved_controls_and_rules'])
    for path, expected in baseline[frame_key].items():
        check(sha(ROOT / path.removeprefix('res://')) == expected, 'Protected texture changed: ' + path)
    for path, expected in baseline['preserved_controls_and_rules'].items():
        check(sha(ROOT / path) == expected, 'Protected control/rule changed: ' + path)
    base = ['slime', 'skeleton', 'bat', 'sentinel', 'warlock', 'knight', 'berserker', 'warden', 'minotaur', 'golem']
    specials = {'p3_shield_sentinel': 'guard', 'p3_ember_channeler': 'charge', 'p3_vault_knight': 'threat'}
    slots = effects = new_slots = new_effects = 0
    for entity in base + list(specials):
        names = ['idle', 'attack', 'hit', 'defeat', 'map_idle']
        if entity in specials: names.append(specials[entity])
        if entity == 'minotaur': names.append('rage')
        if entity == 'golem': names.append('armor')
        for name in names:
            key = f'{entity}_{name}'
            action = manifest['actions'].get(key, {})
            check(action.get('status') == 'accepted', 'Missing accepted action: ' + key)
            if not action: continue
            slots += len(action['frames'])
            effects += len(action.get('effects_frames', []))
            if key in baseline['accepted_actions']: continue
            new_slots += len(action['frames'])
            new_effects += len(action.get('effects_frames', []))
            coordinator = read(ROOT / action['coordinator_review'])
            worker = read(ROOT / action['publish_review'])
            check(coordinator['human_signoff'] is False and worker['human_signoff'] is False, 'False human signoff missing: ' + key)
            for channel in ['frames', 'effects_frames']:
                if not action.get(channel): continue
                actual = [sha(ROOT / path.removeprefix('res://')) for path in action[channel]]
                review_channel = 'frame_sha256' if channel == 'frames' else 'effects_sha256'
                check(actual == coordinator['actions'][name][review_channel], 'Coordinator texture hashes differ: ' + key + '/' + channel)
                check(actual == worker['actions'][name][review_channel], 'Worker texture hashes differ: ' + key + '/' + channel)
    result = dict(errors=errors, protected_actions=len(baseline['accepted_actions']), protected_texture_paths=len(baseline[frame_key]), protected_controls_rules=len(baseline['preserved_controls_and_rules']), accepted_body_slots=slots, accepted_effect_slots=effects, added_body_slots=new_slots, added_effect_slots=new_effects, missing_creatures=manifest.get('missing_creatures'), scope='Byte preservation and exact publication checks, not visual/human/device signoff')
    (OUT / 'production-preservation.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(bool(errors))
