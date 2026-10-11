"""Read-only snapshot of production and protected controls before hero refinement."""
import hashlib, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/verification/phase3/09-refinement/hero'
SOURCE = ROOT/'assets/characters/hero/phase3/source/refine_v06'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE/'.gdignore').touch()
protected = ['scripts/ui/hero_walk.gd','scripts/ui/floating_joystick.gd',
 'scripts/core/combat.gd','scripts/core/phase3_combat.gd','scripts/core/rewards.gd',
 'scripts/core/campaign_save.gd','scripts/core/save_store.gd','scripts/core/phase3_progress.gd',
 'scripts/ui/phase3_combat_player.gd','scripts/ui/phase3_enemy_player.gd',
 'scripts/ui/phase3_enemy_map_art.gd']
manifests = ['assets/characters/hero/phase3/manifest.json','assets/monsters/phase3/manifest.json']
snapshot = {'date':'2026-10-02','protected':{},'manifests':{},'textures':{}}
for p in protected:
 snapshot['protected'][p] = hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
for p in manifests:
 data=json.loads((ROOT/p).read_text(encoding='utf-8-sig'))
 snapshot['manifests'][p]=data
for group in ['assets/characters/hero/phase3/textures','assets/monsters/phase3/textures']:
 for p in (ROOT/group).rglob('*.png'):
  snapshot['textures'][p.relative_to(ROOT).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
target=OUT/'baseline.json'
assert not target.exists(), 'Preserve first snapshot'
target.write_text(json.dumps(snapshot,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Baseline:',len(snapshot['textures']),'old PNG hashes;',len(protected),'protected code hashes')
