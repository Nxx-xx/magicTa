"""Measure only owned entries against the supplied integrated package baseline."""
from pathlib import Path
import ast, hashlib, io, json, re, zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/verification/story-expressions'
BASE = ROOT / 'build/wechat-runs/20261004-134105-179524'
PACKAGE = ROOT / 'build/wechat-story-expressions'
# Read the current shared policy without modifying/importing the build tool.
budget_tree = ast.parse((ROOT/'tools/build_wechat.py').read_text(encoding='utf-8-sig'))
budgets = {}
for node in budget_tree.body:
    if isinstance(node, ast.Assign):
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id in ['TOTAL_PACKAGE_BUDGET_BYTES','MAIN_PACKAGE_BUDGET_BYTES']:
                budgets[target.id] = eval(compile(ast.Expression(node.value),'<budget>','eval'),{'__builtins__':{}})
assert len(budgets) == 2
outer = zipfile.ZipFile(BASE / 'TowerRealm-WeChat.zip')
assert outer.testzip() is None
before = zipfile.ZipFile(io.BytesIO(outer.read('engine/godot.zip')))
after = zipfile.ZipFile(PACKAGE / 'engine/godot.zip')
assert before.testzip() is None and after.testzip() is None
base_report = json.loads((BASE / 'build-report.json').read_text())
# Match the exact output package hash rather than attributing another run.
digest = hashlib.sha256((PACKAGE / 'engine/godot.zip').read_bytes()).hexdigest()
reports = []
for p in (ROOT / 'build/wechat-runs').glob('*/build-report.json'):
    d = json.loads(p.read_text())
    if d.get('files', {}).get('engine/godot.zip', {}).get('sha256') == digest:
        reports.append((p, d))
assert reports
report_path, report = sorted(reports)[-1]
for name, entry in report['files'].items():
    data = (PACKAGE / name).read_bytes()
    assert len(data) == entry['bytes'] and hashlib.sha256(data).hexdigest() == entry['sha256'], name
assert zipfile.ZipFile(report_path.parent / 'TowerRealm-WeChat.zip').testzip() is None

entries = set()
for name in after.namelist():
    if name.startswith('assets/story/expressions/textures/') and name.endswith('.png.import'):
        entries.add(name)
        remap = after.read(name).decode()
        target = re.search(r'^path="res://([^"]+)"', remap, re.M).group(1)
        assert target in after.namelist()
        entries.add(target)
scripts = ['scripts/ui/story_expression_art.gd','scripts/ui/campaign_panels.gd','scripts/ui/story_intro_stage.gd']
entries.update(scripts)
rows = []
for name in sorted(entries):
    old = before.getinfo(name).compress_size if name in before.namelist() else 0
    new = after.getinfo(name).compress_size
    rows.append({'entry': name, 'baseline_compressed': old, 'final_compressed': new, 'delta': new-old})
delta = sum(r['delta'] for r in rows)
assert len([n for n in entries if n.endswith('.ctex')]) == 5
assert not any('assets/story/expressions/source/' in n for n in after.namelist())
assert after.read('data/story.json') == before.read('data/story.json')
for name in ['hero_dialogue_neutral_v01.png','prince_dialogue.png','demon_dialogue.png','prince_monster_reveal_v01.png']:
    for n in before.namelist():
        if n.startswith('.godot/imported/'+name+'-'):
            assert before.read(n) == after.read(n), n
for rel in ['data/story.json'] + scripts:
    assert after.read(rel) == (ROOT/rel).read_bytes(), 'Export snapshot differs: '+rel
new_entries = [n for n in entries if n not in before.namelist()]
# Standard local and central ZIP headers; reported separately from compressed payloads.
headers = sum(76 + 2*len(n.encode()) for n in new_entries)
assert delta <= 65536
result = {
    'baseline_report': str(BASE/'build-report.json'), 'final_report': str(report_path),
    'package': str(PACKAGE), 'baseline_total_bytes': base_report['total_bytes'],
    'snapshot_total_bytes': report['total_bytes'], 'snapshot_main_bytes': report['main_bytes'],
    'snapshot_change_all_tasks_bytes': report['total_bytes']-base_report['total_bytes'],
    'owned_compressed_entry_delta_bytes': delta, 'owned_new_zip_headers_bytes': headers,
    'owned_delta_including_new_headers_bytes': delta+headers,
    'owned_budget_bytes':65536,'owned_budget_remaining_bytes':65536-delta,
    'current_total_budget_bytes':budgets['TOTAL_PACKAGE_BUDGET_BYTES'],
    'current_main_budget_bytes':budgets['MAIN_PACKAGE_BUDGET_BYTES'],
    'current_total_budget_remaining_bytes':budgets['TOTAL_PACKAGE_BUDGET_BYTES']-report['total_bytes'],
    'current_main_budget_remaining_bytes':budgets['MAIN_PACKAGE_BUDGET_BYTES']-report['main_bytes'],
    'current_config_pass': report['total_bytes'] <= budgets['TOTAL_PACKAGE_BUDGET_BYTES'] and report['main_bytes'] <= budgets['MAIN_PACKAGE_BUDGET_BYTES'],
    'export_report_budget':report.get('package_budget'),
    'historical_20mib_reference_remaining_bytes':20*1024*1024-report['total_bytes'],
    'not_a_confirmed_appid_platform_limit':True,
    'checks': {'five_remaps_and_payloads':True,'source_masters_not_exported':True,
               'three_neutral_textures_and_reveal_unchanged':True,'story_json_identical_to_baseline':True,
               'both_zip_layers_crc':True,'package_file_sizes_sha256':True},
    'entries': rows,
    'validation': {'desktop_phone_viewports':True,
                   'wechat_pack_native_runtime': 'PACKED STORY EXPRESSIONS 68 checks, 0 failures' in (OUT/'packed.log').read_text() if (OUT/'packed.log').exists() else False,
                   'devtools':False,'device':False}
}
(OUT/'package-audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ['entries','checks']},indent=2))
