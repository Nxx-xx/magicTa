"""Publish one reviewed v05 delivery, merging only its explicit action keys.

Worker and coordinator approvals both bind the final PNG bytes. This tool does
technical checks; it cannot create an approval or replace visual review.
"""
import argparse
import copy
import hashlib
import json
import os
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/monsters/phase3'
BASE = ['slime', 'skeleton', 'bat', 'sentinel', 'warlock', 'knight', 'berserker', 'warden', 'minotaur', 'golem']
VARIANTS = {'p3_shield_sentinel': 'guard', 'p3_ember_channeler': 'charge', 'p3_vault_knight': 'threat'}
METHOD = 'contact sheets plus native/browser playback; agent visual review'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def confined(folder, relative):
    path = (folder / relative).resolve()
    if not path.is_relative_to(folder.resolve()):
        raise ValueError(f'Path escapes source: {relative}')
    return path


def expect(condition, message):
    if not condition:
        raise ValueError(message)


def timeline(entity, action):
    if action == 'map_idle':
        return 4, 8 if entity == 'bat' else 6, True
    if action in ('guard', 'charge', 'threat'):
        expect(VARIANTS.get(entity) == action, 'Wrong variant mechanism action')
        return 4, 12 if action == 'guard' else 8, False
    elite = entity in ('berserker', 'warden')
    return {'idle': (4, 8 if entity == 'bat' else 6, True),
            'attack': (8 if elite else 6, 12, False),
            'hit': (3 if elite else 2, 12, False),
            'defeat': (8 if elite else 6, 12 if elite else 10, False)}[action]


def validate_delivery(entity, source, coordinator_review, selected=None):
    expect(source.is_relative_to(ASSETS / 'source/parallel_v05'), 'Only parallel_v05 sources can be published here')
    worker_path = source / f'{entity}_publish_review.json'
    worker = read(worker_path)
    coordinator = read(coordinator_review)
    for record in (worker, coordinator):
        expect(record['entity'] == entity and bool(record.get('review_method')), 'Missing explicit visual review method/entity')
        expect(record.get('human_signoff') is False, 'Agent review must retain human_signoff=false')
    expect(coordinator['review_method'] == METHOD, 'Coordinator must actually complete visual playback review')
    actions = selected or list(worker['actions'])
    expect(bool(actions), 'No actions selected')
    if source.parent.name == 'map':
        expect(actions == ['map_idle'], 'Map delivery may publish only map_idle')
    elif source.parent.name == 'battle':
        expect(set(actions) <= {'idle', 'attack', 'hit', 'defeat'}, 'Battle delivery has foreign actions')
    elif source.parent.name == 'variants':
        expect(set(actions) <= {'idle', 'attack', 'hit', 'defeat', VARIANTS[entity]}, 'Variant delivery has foreign actions')
    else:
        raise ValueError('Unknown source category')
    prepared = []
    for action_id in actions:
        approval = worker['actions'][action_id]
        secondary = coordinator['actions'][action_id]
        worker_static_passed = approval['decision'] == 'accepted' or (
            approval['decision'] in ('pending_playback_review', 'pending_motion_review') and
            approval.get('static_visual_decision') in ('accepted', 'passed'))
        expect(worker_static_passed and secondary['decision'] == 'accepted', f'Unapproved {action_id}')
        draft_path = confined(source, approval['draft_manifest'])
        if secondary.get('draft_sha256'):
            expect(sha(draft_path) == secondary['draft_sha256'], f'Draft changed after native capture: {action_id}')
        draft = read(draft_path)
        action = draft['actions'][approval['source_action']]
        count, fps, loop = timeline(entity, action_id)
        expect(len(action['frames']) == approval['frame_slots'] == count, f'Wrong frame count: {action_id}')
        expect(action['fps'] == fps and action['loop'] is loop, f'Wrong timing: {action_id}')
        expect(draft['size'] == [256, 256], f'Wrong dimensions: {action_id}')
        anchor = draft.get('anchor', [])
        expect(len(anchor) == 2 and all(isinstance(v, (int, float)) and 0 <= v <= 256 for v in anchor), f'Invalid explicit anchor: {action_id}')
        if action_id == 'map_idle':
            expect(anchor == [128, 224], 'Map camera must use the fixed (128,224) registration')
        expect(isinstance(action['events'], dict), 'Invalid events')
        if action_id == 'attack':
            expect(isinstance(action['events'].get('hit'), (int, float)), 'Attack must declare contact frame')
        for event, index in action['events'].items():
            expect(isinstance(index, (int, float)) and int(index) == index and 0 <= index < count, f'Invalid event {event}')
        holds = approval.get('pose_holds', {})
        expect(holds == action.get('pose_holds', {}), f'Hold declarations disagree: {action_id}')
        channel_files = {}
        for channel, hash_key in [('frames', 'frame_sha256'), ('effects_frames', 'effects_sha256')]:
            if channel not in action:
                expect(not approval.get(hash_key) and not secondary.get(hash_key), 'Approval references absent channel')
                continue
            files = [confined(source, p) for p in action[channel]]
            expect(len(files) == count, f'Mismatched channel: {action_id}')
            hashes = [sha(p) for p in files]
            expect(hashes == approval[hash_key] == secondary[hash_key], f'Changed frames require new worker/coordinator review: {action_id}/{channel}')
            pixels = []
            for path in files:
                with Image.open(path) as original:
                    expect(original.size == (256, 256) and original.mode == 'RGBA', f'Wrong RGBA dimensions: {path}')
                    alpha = original.getchannel('A')
                    expect(alpha.getextrema()[0] == 0, f'No transparent margin: {path}')
                    bounds = alpha.getbbox()
                    if channel == 'frames':
                        expect(bounds is not None, f'Empty body frame: {path}')
                    if bounds:
                        expect(min(bounds[:2]) >= 4 and max(bounds[2:]) <= 252, f'Clipped/unsafe frame edge: {path}')
                    pixels.append(hashlib.sha256(original.tobytes()).hexdigest())
            if channel == 'frames':
                for index, pixel in enumerate(pixels):
                    if pixel in pixels[:index]:
                        expect(str(index) in holds and pixels[int(holds[str(index)])] == pixel, f'Undeclared repeated pixel pose: {action_id}/{index}')
                for index, origin in holds.items():
                    expect(0 <= int(index) < count and 0 <= int(origin) < count and pixels[int(index)] == pixels[int(origin)], 'Invalid explicit hold')
            channel_files[channel] = files
        prepared.append((action_id, draft, action, holds, channel_files))
    return prepared, worker_path


def update_coverage(manifest):
    def approved(entity, action):
        return manifest['actions'].get(f'{entity}_{action}', {}).get('status') == 'accepted'
    missing_base = [e for e in BASE if not all(approved(e, a) for a in ['idle', 'attack', 'hit', 'defeat'] + (['rage'] if e == 'minotaur' else ['armor'] if e == 'golem' else []))]
    missing_variants = [e for e, extra in VARIANTS.items() if not all(approved(e, a) for a in ['idle', 'attack', 'hit', 'defeat', extra])]
    missing_maps = [e for e in BASE + list(VARIANTS) if not approved(e, 'map_idle')]
    manifest.update(status='partially_accepted', production_ready=False,
                    accepted_entities=sorted({k.rsplit('_', 1)[0] for k, v in manifest['actions'].items() if v.get('status') == 'accepted' and not k.endswith('_map_idle')}),
                    missing_creatures=missing_base + missing_variants,
                    missing_deliverables=([f'{len(missing_base)} remaining base enemy combat sets and their editable rigs'] if missing_base else [])
                    + ([f'{len(missing_variants)} variant attachment/action sets'] if missing_variants else [])
                    + ([f'independent map-camera idle: {", ".join(missing_maps)}'] if missing_maps else [])
                    + ['human motion review and target-device acceptance'],
                    view='combat_and_independent_map',
                    source_method='Reviewed native rigs; worker and coordinator exact-frame hashes gate v05 publication')


def publish(entity, source, coordinator_review, version='v05', selected=None, dry_run=False):
    expect(entity in BASE[0:8] + list(VARIANTS), 'This batch excludes the existing Boss assets')
    expect(re.fullmatch(r'v05(?:_[a-z0-9]+)?', version), 'Use a fresh v05 texture namespace')
    prepared, worker_path = validate_delivery(entity, source, coordinator_review, selected)
    manifest_path = ASSETS / 'manifest.json'
    manifest = read(manifest_path)
    previous_bytes = manifest_path.read_bytes()
    before = copy.deepcopy(manifest['actions'])
    copies = []
    for action_id, draft, action, holds, channels in prepared:
        key = f'{entity}_{action_id}'
        metadata = {k: action[k] for k in ('fps', 'loop', 'events')}
        metadata.update(size=draft['size'], anchor=draft['anchor'], status='accepted', source=draft['source'],
                        review=source.relative_to(ASSETS).as_posix() + '/REVIEW.md', pose_holds=holds,
                        publish_review=worker_path.relative_to(ROOT).as_posix(),
                        coordinator_review=coordinator_review.relative_to(ROOT).as_posix())
        for channel, files in channels.items():
            target_folder = ASSETS / 'textures' / version / entity / action_id
            if channel == 'effects_frames':
                target_folder /= 'effects'
            paths = []
            for index, path in enumerate(files):
                target = target_folder / f'{index:02}.png'
                if target.exists():
                    expect(sha(target) == sha(path), f'Refusing to overwrite published bytes: {target}; use a fresh version')
                copies.append((path, target))
                paths.append('res://' + target.relative_to(ROOT).as_posix())
            metadata[channel] = paths
        if before.get(key, {}).get('status') == 'accepted':
            expect(before[key] == metadata, f'Refusing to replace an accepted action: {key}')
        manifest['actions'][key] = metadata
    update_coverage(manifest)
    changed = {f'{entity}_{entry[0]}' for entry in prepared}
    expect(all(manifest['actions'][k] == v for k, v in before.items() if k not in changed), 'Foreign action metadata changed')
    if dry_run:
        return {'dry_run': True, 'actions': sorted(changed), 'frames': len(copies)}
    for path, target in copies:
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            temporary = target.with_suffix('.png.pending')
            temporary.write_bytes(path.read_bytes())
            os.replace(temporary, target)
    expect(manifest_path.read_bytes() == previous_bytes, 'Manifest changed during publication; retry serially')
    temporary_manifest = manifest_path.with_suffix('.json.pending')
    temporary_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    os.replace(temporary_manifest, manifest_path)
    return {'dry_run': False, 'actions': sorted(changed), 'frames': len(copies)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--entity', required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--coordinator-review', required=True)
    parser.add_argument('--version', default='v05')
    parser.add_argument('--actions', nargs='+')
    parser.add_argument('--dry-run', action='store_true')
    options = parser.parse_args()
    print(json.dumps(publish(options.entity, (ROOT / options.source).resolve(),
                             (ROOT / options.coordinator_review).resolve(), options.version,
                             options.actions, options.dry_run), ensure_ascii=False))
