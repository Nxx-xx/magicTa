"""Verify local tower-polish release integrity without claiming client/device validation."""
import hashlib
import json
from pathlib import Path
import zipfile
from build_wechat import TOTAL_PACKAGE_BUDGET_BYTES, MAIN_PACKAGE_BUDGET_BYTES

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/verification/tower-polish'

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

latest = read(ROOT / 'build/wechat-tower-final-latest.json')
report = read(latest['report'])
project = Path(latest['project'])
stage = Path(latest['source'])
for relative, expected in report['files'].items():
    path = project / relative
    assert path.stat().st_size == expected['bytes'], relative
    assert sha(path) == expected['sha256'], relative
assert sum(v['bytes'] for v in report['files'].values()) == report['total_bytes']
assert report['total_bytes'] <= TOTAL_PACKAGE_BUDGET_BYTES
assert report['main_bytes'] <= MAIN_PACKAGE_BUDGET_BYTES
for archive in (project / 'engine/godot.zip', Path(latest['archive'])):
    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None, str(archive)
with zipfile.ZipFile(project / 'engine/godot.zip') as package:
    paths = set(package.namelist())
    assert 'assets/environment/tower_v02/gateway.png.import' in paths
    assert 'scripts/ui/tower_environment.gd' in paths
    assert not any(p.startswith(('tests/', 'tools/')) for p in paths)
for relative in ('scripts/ui/grid_board.gd', 'scripts/ui/tower_environment.gd',
                 'assets/environment/tower_v02/gateway.png',
                 'assets/characters/hero/phase3/manifest.json',
                 'assets/monsters/phase3/manifest.json',
                 'assets/environment/ruins/phase3/runtime_v02.json'):
    assert sha(ROOT / relative) == sha(stage / relative), relative
preserved = read(OUT / 'preserved-before.json')
for item in preserved:
    assert sha(ROOT / item['path']) == item['sha256'].lower(), item['path']
audit = read(OUT / 'package-audit.json')
for relative, digest in audit['manifest_sha256'].items():
    assert sha(ROOT / relative) == digest, relative
staging = read(OUT / 'staging/results.json')
assert len(staging) == 4 and all(r['exit_code'] == 0 and not r['failed'] and not r['unexpected_errors'] for r in staging)
summary = {
    'project': str(project), 'build_id': report['build_id'],
    'report_files_verified': len(report['files']), 'zip_crc': 'passed',
    'total_bytes': report['total_bytes'], 'main_bytes': report['main_bytes'],
    'headroom_bytes': TOTAL_PACKAGE_BUDGET_BYTES - report['total_bytes'],
    'package_budget': {'total_bytes': TOTAL_PACKAGE_BUDGET_BYTES,
                       'main_bytes': MAIN_PACKAGE_BUDGET_BYTES},
    'preserved_core_and_animation_files': len(preserved),
    'preserved_production_manifests': len(audit['manifest_sha256']),
    'production_pngs': report['asset_exclusions']['export_verification'],
    'staging_tests': staging,
    'scope': 'Godot desktop and isolated 4.6.1 export resources; WeChat DevTools/device not verified',
}
(OUT / 'package-verification.json').write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps({k: v for k, v in summary.items() if k != 'staging_tests'}, indent=2))
