"""Measure this task from actual ZIP compressed entries, and isolate exported resources."""
import hashlib
import argparse
import importlib.util
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--run', default='20261004-135330-025700')
parser.add_argument('--project', default='wechat-ruins-polish')
parser.add_argument('--output', default='build/verification/ruins-polish')
args = parser.parse_args()
OUT = ROOT / args.output
OUT.mkdir(parents=True, exist_ok=True)
PREFIX = 'assets/environment/ruins/phase3/'
OLD_RUN = ROOT / 'build/wechat-runs/20261004-134105-179524'
NEW_RUN = ROOT / 'build/wechat-runs' / args.run
OLD_PROJECT = ROOT / 'build/wechat-art-audit'
NEW_PROJECT = ROOT / 'build' / args.project
spec = importlib.util.spec_from_file_location('ruins_budget_build', ROOT / 'tools/build_wechat.py')
build_config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build_config)

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def scope(package):
    manifest = json.loads(package.read(PREFIX+'runtime_v02.json'))
    paths = set()
    def walk(value):
        if isinstance(value, str) and value.endswith('.png') and value.startswith('res://'):
            paths.add(value.removeprefix('res://'))
        elif isinstance(value, dict):
            for child in value.values(): walk(child)
        elif isinstance(value, list):
            for child in value: walk(child)
    walk(manifest)
    entries = set()
    for path in paths:
        sidecar = path+'.import'
        entries.add(sidecar)
        targets = re.findall(r'path="res://([^"]+)"',package.read(sidecar).decode())
        assert targets
        entries.update(targets)
    textures = {n: package.getinfo(n).compress_size for n in sorted(entries)}
    entries.update([PREFIX+'runtime_v02.json','scripts/ui/phase3_ruin_art.gd'])
    all_entries = {n: package.getinfo(n).compress_size for n in sorted(entries)}
    return manifest, paths, textures, all_entries

old_report, new_report = read(OLD_RUN/'build-report.json'), read(NEW_RUN/'build-report.json')
budget = {'total_bytes':build_config.TOTAL_PACKAGE_BUDGET_BYTES, 'main_bytes':build_config.MAIN_PACKAGE_BUDGET_BYTES}
for project, report in [(OLD_PROJECT,old_report),(NEW_PROJECT,new_report)]:
    assert sha(project/'engine/godot.zip') == report['files']['engine/godot.zip']['sha256']
for path, entry in new_report['files'].items():
    assert (NEW_PROJECT/path).stat().st_size == entry['bytes']
    assert sha(NEW_PROJECT/path) == entry['sha256']
assert sum(x['bytes'] for x in new_report['files'].values()) == new_report['total_bytes']
with zipfile.ZipFile(NEW_RUN/'TowerRealm-WeChat.zip') as z:
    assert z.testzip() is None
with zipfile.ZipFile(OLD_PROJECT/'engine/godot.zip') as old, zipfile.ZipFile(NEW_PROJECT/'engine/godot.zip') as new:
    assert old.testzip() is None and new.testzip() is None
    om, op, ot, oe = scope(old)
    nm, np, nt, ne = scope(new)
    assert len(op) == 75 and len(np) == 78
    for rid in om['ruins']:
        assert om['ruins'][rid]['actions'] == nm['ruins'][rid]['actions']
    assert not any(n.startswith(PREFIX+'source/') for n in new.namelist())
    assert not any(n.startswith(('tools/ruins_polish','tests/')) for n in new.namelist())
    # Verify exact retired painted payloads did not survive under historical imports.
    old_hashes = {hashlib.sha256(old.read(n)).hexdigest() for n in ot if n.endswith('.ctex')}
    duplicate_payloads = [n for n in new.namelist() if n.endswith('.ctex') and hashlib.sha256(new.read(n)).hexdigest() in old_hashes]
    assert not duplicate_payloads, duplicate_payloads
    packed = OUT/'packed-runtime'
    packed.mkdir(exist_ok=True)
    for n in ne:
        p = packed/n
        p.parent.mkdir(parents=True,exist_ok=True)
        p.write_bytes(new.read(n))
    (packed/'project.godot').write_text('config_version=5\n[application]\nconfig/name="RuinsPackedVerification"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    result = {
        'baseline_report':str(OLD_RUN/'build-report.json'), 'new_report':str(NEW_RUN/'build-report.json'),
        'old_texture_and_remap_compressed_bytes':sum(ot.values()), 'new_texture_and_remap_compressed_bytes':sum(nt.values()),
        'texture_delta_bytes':sum(nt.values())-sum(ot.values()),
        'reader_old_compressed_bytes':oe['scripts/ui/phase3_ruin_art.gd'], 'reader_new_compressed_bytes':ne['scripts/ui/phase3_ruin_art.gd'],
        'task_total_delta_including_reader_manifest_bytes':sum(ne.values())-sum(oe.values()),
        'initial_task_net_budget_bytes_historical':0, 'meets_initial_task_net_budget':sum(ne.values())<=sum(oe.values()),
        'whole_snapshot_total_bytes':new_report['total_bytes'], 'whole_snapshot_main_bytes':new_report['main_bytes'],
        'whole_snapshot_delta_bytes_not_task_attribution':new_report['total_bytes']-old_report['total_bytes'],
        'current_budget_from_config':budget,
        'export_recorded_budget':new_report.get('package_budget'),
        'current_total_budget_headroom_bytes':budget['total_bytes']-new_report['total_bytes'],
        'current_main_budget_headroom_bytes':budget['main_bytes']-new_report['main_bytes'],
        'current_total_and_main_budget_pass':new_report['total_bytes']<=budget['total_bytes'] and new_report['main_bytes']<=budget['main_bytes'],
        'historical_20_MiB_headroom_bytes':20*1024*1024-new_report['total_bytes'],
        'historical_20_MiB_pass':new_report['total_bytes'] <= 20*1024*1024,
        'production_png_paths':len(np), 'timelines':15, 'frame_slots':75, 'bases':3,
        'all_report_sha256_and_both_zip_crc':'passed', 'retired_painted_payload_duplicates':duplicate_payloads,
        'source_exported':False, 'scope':'isolated local export; no WeChat upload, DevTools or physical device verification',
        'old_entries':oe, 'new_entries':ne,
    }
    assert result['current_total_and_main_budget_pass']
    (OUT/'package-audit.json').write_text(json.dumps(result,indent=2,ensure_ascii=False))
    print(json.dumps({k:v for k,v in result.items() if not k.endswith('_entries')},indent=2,ensure_ascii=False))
