"""Audit this work's actual compressed payload; never charge concurrent art changes to NPCs."""
import hashlib
import io
import json
import re
import sys
import zipfile
from pathlib import Path
from build_wechat import TOTAL_PACKAGE_BUDGET_BYTES, MAIN_PACKAGE_BUDGET_BYTES

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/verification/npc-polish'
BASE = ROOT / 'build/wechat-runs/20261004-134105-179524'
RUN = Path(sys.argv[1])
if not RUN.is_absolute(): RUN = ROOT / RUN
REPORT = json.loads((RUN / 'build-report.json').read_text(encoding='utf-8'))
PROJECT = ROOT / 'build/wechat-npc-polish'

rows = []
with zipfile.ZipFile(BASE / 'TowerRealm-WeChat.zip') as outer:
    base_zip = outer.read('engine/godot.zip')
    before = zipfile.ZipFile(io.BytesIO(base_zip))
with zipfile.ZipFile(PROJECT / 'engine/godot.zip') as after:
    assert after.testzip() is None
    for path in [
        'assets/characters/camp_death/death.png',
        'assets/characters/candlelight_merchant/textures/idle.png',
        'assets/characters/candlelight_merchant/textures/conversation.png',
    ]:
        for archive, key in [(before, 'before'), (after, 'after')]:
            sizes = {}
            if path + '.import' in archive.namelist():
                remap = re.search(r'^path="res://([^"]+)"', archive.read(path + '.import').decode(), re.M).group(1)
                sizes = {'payload': archive.getinfo(remap).compress_size,
                         'remap': archive.getinfo(path + '.import').compress_size,
                         'payload_sha256': hashlib.sha256(archive.read(remap)).hexdigest()}
            if key == 'before': row = {'path': path, 'before': sizes}
            else: row['after'] = sizes
        row['delta'] = sum(row['after'].get(k, 0)-row['before'].get(k, 0) for k in ['payload','remap'])
        if path.endswith(('death.png','idle.png')):
            assert row['before']['payload_sha256'] == row['after']['payload_sha256'], path
        rows.append(row)
    for path in ['scripts/ui/camp_death_art.gd','scripts/ui/npc_portrait.gd','scripts/ui/npc_portrait.gdshader']:
        assert after.read(path) == (ROOT/path).read_bytes(), path
        old = before.getinfo(path).compress_size if path in before.namelist() else 0
        new = after.getinfo(path).compress_size
        rows.append({'path':path,'before_bytes':old,'after_bytes':new,'delta':new-old})
    # Verify that shared-script changes contain ONLY our two local edits before
    # attributing their actual ZIP-entry delta. Concurrent changes must never
    # silently become part of this work's accounting.
    replacements = {
        'scripts/ui/camp_board.gd': (
            '\tDeathArt.draw(self,death_rect(),idle_seconds,reduce_motion)',
            '\tdraw_texture_rect(DeathArt.TEXTURE,death_rect(),false,Color("cbdedc"))'),
        'scripts/ui/map_screen.gd': (
            '\t\tvar portrait = preload("res://scripts/ui/npc_portrait.gd").merchant(settings,get_viewport_rect().size.y < 640)',
            '\n'.join(['\t\tvar portrait := TextureRect.new()', '\t\tportrait.name = "MerchantPortrait"',
                       '\t\tportrait.texture = RuntimeArt.entity_texture(entity)',
                       '\t\tportrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE',
                       '\t\tportrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED',
                       '\t\tportrait.custom_minimum_size = Vector2(56, 56)',
                       '\t\tportrait.mouse_filter = Control.MOUSE_FILTER_IGNORE']))
    }
    for path, (new, old) in replacements.items():
        data = after.read(path)
        text = data.decode()
        assert text.count(new) == 1, path
        newline = '\r\n' if '\r\n' in text else '\n'
        inverse = text.replace(new, old.replace('\n',newline)).encode()
        assert inverse == before.read(path), 'Unrelated shared-script changes require separate accounting: '+path
        rows.append({'path':path,'method':'actual ZIP delta; inverse NPC edit equals baseline bytes exactly',
                     'before_bytes':before.getinfo(path).compress_size,'after_bytes':after.getinfo(path).compress_size,
                     'delta':after.getinfo(path).compress_size-before.getinfo(path).compress_size})
    assert not any('/source/' in n and ('camp_death/' in n or 'candlelight_merchant/' in n) for n in after.namelist())
    assert not any(n.startswith(('tests/','tools/')) for n in after.namelist())
    # Both shared scripts' independent edits are preserved in the exported snapshot.
    integration_patch_applied = '.portrait(ui.settings)' in after.read('scripts/ui/campaign_panels.gd').decode()
    old_panel = before.read('scripts/ui/campaign_panels.gd')
    new_panel = after.read('scripts/ui/campaign_panels.gd')
    baseline_total = json.loads((BASE/'build-report.json').read_text())['total_bytes']
for path, record in REPORT['files'].items():
    data = (PROJECT/path).read_bytes()
    assert len(data) == record['bytes'] and hashlib.sha256(data).hexdigest() == record['sha256'], path
with zipfile.ZipFile(RUN/'TowerRealm-WeChat.zip') as outer:
    assert outer.testzip() is None
delta = sum(r['delta'] for r in rows)
assert REPORT['total_bytes'] <= TOTAL_PACKAGE_BUDGET_BYTES
assert REPORT['main_bytes'] <= MAIN_PACKAGE_BUDGET_BYTES
result = {'build_id':REPORT['build_id'],'report':str(RUN/'build-report.json'),
          'budget_source':'tools/build_wechat.py current constants; reevaluated per user instruction',
          'configured_total_budget_bytes':TOTAL_PACKAGE_BUDGET_BYTES,
          'configured_main_budget_bytes':MAIN_PACKAGE_BUDGET_BYTES,
          'configured_total_headroom_bytes':TOTAL_PACKAGE_BUDGET_BYTES-REPORT['total_bytes'],
          'configured_main_headroom_bytes':MAIN_PACKAGE_BUDGET_BYTES-REPORT['main_bytes'],
          'configured_budget_pass':True,'configured_npc_specific_budget':None,
          'original_npc_reference_bytes':32768,
          'npc_compressed_delta_bytes':delta,'remaining_against_original_reference_bytes':32768-delta,
          'entries':rows,'total_snapshot_bytes':REPORT['total_bytes'],'main_snapshot_bytes':REPORT['main_bytes'],
          'overall_snapshot_change_bytes':REPORT['total_bytes']-baseline_total,
          'overall_change_is_not_npc_attribution':True,
          'verified_file_hashes':len(REPORT['files']),'both_zip_crc':'passed',
          'original_death_and_idle_payload_unchanged':True,'source_and_tests_not_exported':True,
          'death_dialogue_patch_applied':integration_patch_applied,
          'campaign_panels_unchanged_in_this_snapshot':old_panel==new_panel,
          'devtools_upload':False,'device_validation':False}
(OUT/'package-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')

# Clean harness mounts only the actual runtime ZIP: no source resource fallback.
harness = OUT/'packed-runtime'
harness.mkdir(exist_ok=True)
(harness/'project.godot').write_text('config_version=5\n[application]\nconfig/name="NPC packed review"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
code = (ROOT/'tests/npc_polish_capture.gd').read_text(encoding='utf-8')
code = code.replace('const Screen = preload("res://scripts/ui/map_screen.gd")','var Screen')
code = code.replace('const Core = preload("res://scripts/core/campaign_engine.gd")','var Core')
code = code.replace('preload(', 'load(')
code = code.replace('"res://build/verification/npc-polish/before/"',json.dumps((OUT/'packed/after').as_posix()+'/'))
code = code.replace('func _initialize() -> void:', 'func _initialize() -> void:\n\tassert(ProjectSettings.load_resource_pack('+json.dumps((PROJECT/'engine/godot.zip').as_posix())+'))\n\tScreen = load("res://scripts/ui/map_screen.gd")\n\tCore = load("res://scripts/core/campaign_engine.gd")')
(harness/'verify.gd').write_text(code,encoding='utf-8')
(OUT/'baseline-godot.zip').write_bytes(base_zip)
baseline_code = code.replace((PROJECT/'engine/godot.zip').as_posix(),(OUT/'baseline-godot.zip').as_posix())
baseline_code = baseline_code.replace((OUT/'packed/after').as_posix(),(OUT/'baseline-packed/after').as_posix())
(harness/'baseline.gd').write_text(baseline_code,encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k!='entries'},ensure_ascii=False,indent=2))
