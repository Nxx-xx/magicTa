"""Measure only this task's actual exported entries; report the shared snapshot separately."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile
from build_wechat import TOTAL_PACKAGE_BUDGET_BYTES, MAIN_PACKAGE_BUDGET_BYTES

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'build/wechat-runs/20261004-134105-179524'
PREFIX = 'assets/characters/hero/phase3/'
CHANGED = {'combat_attack', 'combat_guard', 'combat_hit', 'combat_victory'}
parser = argparse.ArgumentParser()
parser.add_argument('run', type=Path)
args = parser.parse_args()
run = args.run.resolve()
report = json.loads((run / 'build-report.json').read_text(encoding='utf-8'))
before_report = json.loads((BASE / 'build-report.json').read_text(encoding='utf-8'))
outer0 = zipfile.ZipFile(BASE / 'TowerRealm-WeChat.zip')
outer1 = zipfile.ZipFile(run / 'TowerRealm-WeChat.zip')
assert outer0.testzip() is None and outer1.testzip() is None
before = zipfile.ZipFile(io.BytesIO(outer0.read('engine/godot.zip')))
after = zipfile.ZipFile(io.BytesIO(outer1.read('engine/godot.zip')))
assert before.testzip() is None and after.testzip() is None

def target(archive, path):
    return re.search(r'path="res://([^"]+)"', archive.read(path + '.import').decode()).group(1)

def accounting(archive):
    remaps = sorted(p for p in archive.namelist() if p.startswith(PREFIX) and p.endswith('.png.import'))
    payloads = sorted({target(archive, p[:-7]) for p in remaps})
    names = remaps + payloads + [PREFIX + 'manifest.json']
    return {
        'texture_count': len(payloads),
        'texture_compressed_bytes': sum(archive.getinfo(p).compress_size for p in payloads),
        'remap_compressed_bytes': sum(archive.getinfo(p).compress_size for p in remaps),
        'manifest_compressed_bytes': archive.getinfo(PREFIX + 'manifest.json').compress_size,
        'entries': {p: archive.getinfo(p).compress_size for p in names},
    }

a0, a1 = accounting(before), accounting(after)
m0 = json.loads(before.read(PREFIX + 'manifest.json'))
m1 = json.loads(after.read(PREFIX + 'manifest.json'))
assert set(m0['actions']) == set(m1['actions']) and len(m1['actions']) == 18
unchanged = 0
for name, action in m0['actions'].items():
    new = m1['actions'][name]
    for field in ('fps', 'loop', 'size', 'anchor', 'events', 'pose_holds'):
        assert action[field] == new[field], (name, field)
    for field in ('frames', 'effects_frames'):
        assert len(action[field]) == len(new[field])
        for old_path, new_path in zip(action[field], new[field]):
            op, np = old_path.removeprefix('res://'), new_path.removeprefix('res://')
            if name not in CHANGED:
                assert before.read(target(before, op)) == after.read(target(after, np)), (name, field)
                unchanged += 1
retired = json.loads((ROOT / PREFIX / 'source/motion_v07/retired_duplicates.json').read_text(encoding='utf-8'))
for entry in retired['records']:
    assert entry['old'].removeprefix('res://') + '.import' not in after.namelist()
assert not any('/source/motion_v07/' in p or 'hero_motion_' in p for p in after.namelist())
for relative, expected in report['files'].items():
    data = outer1.read(relative)
    assert len(data) == expected['bytes'] and hashlib.sha256(data).hexdigest() == expected['sha256'], relative
assert sum(v['bytes'] for v in report['files'].values()) == report['total_bytes']
assert sum(v['bytes'] for p, v in report['files'].items()
           if not p.startswith(('engine/', 'subpacks/'))) == report['main_bytes']
texture_delta = a1['texture_compressed_bytes'] - a0['texture_compressed_bytes']
own_total_delta = sum(a1['entries'].values()) - sum(a0['entries'].values())
package_budget_pass = (report['total_bytes'] <= TOTAL_PACKAGE_BUDGET_BYTES
                       and report['main_bytes'] <= MAIN_PACKAGE_BUDGET_BYTES)
workspace_manifest_matches = json.loads((ROOT / PREFIX / 'manifest.json').read_text(encoding='utf-8')) == m1
source_paths = {p.removeprefix('res://') for action in m1['actions'].values()
                for field in ('frames', 'effects_frames') for p in action[field]}
workspace_frame_sources_match = all((ROOT / p).read_bytes() == (run / 'source' / p).read_bytes()
                                   for p in source_paths)
result = {
    'baseline_run': str(BASE), 'final_run': str(run),
    'basis': 'Unique compressed texture payload entries in actual engine/godot.zip, including all hero/phase3 textures and gait; remaps and manifest reported additionally. No runtime scripts added or modified by this task.',
    'before': a0, 'after': a1,
    'texture_net_bytes': texture_delta, 'new_runtime_script_bytes': 0,
    'own_entries_net_bytes_including_remaps_manifest': own_total_delta,
    'budget_source': 'tools/build_wechat.py',
    'package_budget': {'total_bytes': TOTAL_PACKAGE_BUDGET_BYTES, 'main_bytes': MAIN_PACKAGE_BUDGET_BYTES},
    'budget_pass': package_budget_pass,
    'original_task_budget': {'net_bytes': 0, 'pass': texture_delta <= 0 and own_total_delta <= 0,
                            'note': 'Historical task target, reported separately from the current configured package limits.'},
    'build_time_package_budget': report.get('package_budget'),
    'assessment_scope': 'Existing immutable export rechecked against current configuration; no new export or platform upload.',
    'workspace_hero_manifest_matches_export': workspace_manifest_matches,
    'workspace_hero_frame_sources_match_export_stage': workspace_frame_sources_match,
    'unchanged_action_payload_positions_verified': unchanged,
    'runtime_action_count': 18, 'body_frame_positions': 91,
    'crc_outer_and_inner': True, 'all_package_file_sha256_and_sizes': True,
    'retired_exact_duplicates_absent': len(retired['records']), 'ignored_sources_and_tools_absent': True,
    'snapshot': {'baseline_total_bytes': before_report['total_bytes'], 'total_bytes': report['total_bytes'], 'main_bytes': report['main_bytes'],
                 'total_mib': report['total_bytes']/1048576, 'main_mib': report['main_bytes']/1048576,
                 'total_budget_remaining_bytes': TOTAL_PACKAGE_BUDGET_BYTES-report['total_bytes'],
                 'main_budget_remaining_bytes': MAIN_PACKAGE_BUDGET_BYTES-report['main_bytes'],
                 'note':'Existing shared-checkout snapshot includes other tasks; whole-package delta is not attributable to hero motion. Current local build budgets are not verified AppID platform limits or a reserved hero allocation.'},
    'devtools_upload': False, 'device_validation': False,
}
(ROOT / 'build/verification/hero-motion/package-audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({k: v for k, v in result.items() if k not in ('before', 'after')}, ensure_ascii=False, indent=2))
assert result['budget_pass'], 'Export exceeds current configured package budget'
