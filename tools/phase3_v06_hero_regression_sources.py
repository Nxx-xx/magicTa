"""Keep legacy regression semantics; isolate their profile and evidence for hero v06."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification/phase3/09-refinement/hero'
items=['phase3_hero_map_test','phase3_animation_test_runner','walking_test_runner','phase3_ui_host_test_runner','phase3_replay_host_capture','phase3_replay_timing_test','phase3_v05_runtime_capture']
records={}
for name in items:
 source=ROOT/'tests'/f'{name}.gd'
 text=source.read_text(encoding='utf-8-sig')
 # Redirect all historic evidence/profile gates to this independent locked group.
 for old in ['phase3/07-completion/','phase3/00-integration/','phase3/06-animation-balance/','phase3/05-animation/','phase3/08-parallel/coordinator/']:
  text=text.replace(old,'phase3/09-refinement/hero/regression/')
 # Guards check the locked wrapper's profile, while output remains in 09-refinement.
 text=text.replace('.contains("phase3/09-refinement/hero/regression/")','.contains("phase3/08-parallel/hero_refine/")')
 text=text.replace('.contains("build/verification/phase3/09-refinement/hero/regression/")','.contains("build/verification/phase3/08-parallel/hero_refine/")')
 text=text.replace('08-parallel\\\\coordinator','08-parallel\\\\hero_refine')
 text=text.replace('08-parallel/coordinator','08-parallel/hero_refine')
 text=text.replace('res://build/verification/walking/frames','res://build/verification/phase3/09-refinement/hero/regression/walking_frames')
 text=text.replace('res://tests/phase3_ui_host_test_runner.gd','res://tools/phase3_v06_hero_regression_phase3_ui_host_test_runner.gd')
 text=text.replace('accepted hero v03 and slime v03','accepted hero v06 and production slime')
 if name=='walking_test_runner':
  text=text.replace('"phase3/07-completion"','"phase3/08-parallel/hero_refine"')
 if name=='phase3_hero_map_test':
  text=text.replace('catalog.cache_bytes == 24*128*128*4,"all four walk cycles decode to 1.5 MiB"','catalog.cache_bytes == 28*128*128*4,"four walk cycles plus four FX-free reduced poses decode to 1.75 MiB"')
 if name=='phase3_v05_runtime_capture':
  text=text.replace('09-refinement/hero/regression/runtime','09-refinement/hero/runtime')
 target=ROOT/'tools'/f'phase3_v06_hero_regression_{name}.gd'
 target.write_text(text,encoding='utf-8')
 records[name]={'original_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'adapted':target.relative_to(ROOT).as_posix(),'changes':'Evidence locations/profile gate; hero map cache assertion includes four separately cached FX-free reduced poses (28 instead of 24 textures). All other legacy assertions retained.' if name=='phase3_hero_map_test' else 'Only evidence locations/profile gate and provenance labels; legacy assertions retained.'}
(OUT/'regression').mkdir(parents=True,exist_ok=True)
(OUT/'regression/source_adaptations.json').write_text(json.dumps(records,indent=2)+'\n',encoding='utf-8')
print('Isolated regression copies:',len(items))
