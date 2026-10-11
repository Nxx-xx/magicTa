"""Verify approved publication and pre-refinement immutable data; observe concurrent golem separately."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification/phase3/09-refinement/hero'
SOURCE=ROOT/'assets/characters/hero/phase3/source/refine_v06'
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
baseline=read(OUT/'baseline.json')
failures=[]
external_code=[]
for key,digest in baseline['protected'].items():
 if sha(ROOT/key)!=digest:
  if key in ['scripts/ui/phase3_combat_player.gd','scripts/ui/phase3_enemy_player.gd']:
   external_code.append({'path':key,'baseline_sha256':digest,'current_sha256':sha(ROOT/key),'scope':'Changed concurrently by golem refinement; this hero chat did not edit these files. See golem HANDOFF.'})
  else: failures.append('Protected code changed: '+key)
for key,digest in baseline['textures'].items():
 if sha(ROOT/key)!=digest: failures.append('Old PNG changed: '+key)
old=baseline['manifests']['assets/monsters/phase3/manifest.json']
new=read(ROOT/'assets/monsters/phase3/manifest.json')
external=[]
def diff(a,b,at=()):
 if isinstance(a,dict) and isinstance(b,dict):
  for k in a.keys()|b.keys():
   if k not in a or k not in b: yield at+(k,)
   else: yield from diff(a[k],b[k],at+(k,))
 elif a!=b: yield at
for at in diff(old,new):
 if any(segment=='golem' or segment.startswith('golem_') for segment in at) or at in [('status',),('source',)]: external.append('/'.join(at))
 else: failures.append('Unrelated enemy metadata changed: '+'/'.join(at))
approved=read(SOURCE/'visual_review.json')
published=read(ROOT/'assets/characters/hero/phase3/manifest.json')
assert published['status']=='accepted_v06'
for key,a in approved['actions'].items():
 actual=published['actions'][key]
 for field in ['fps','loop','size','anchor','events','pose_holds','source','review']:
  if actual[field]!=a[field]: failures.append('Approved metadata mismatch: '+key+'/'+field)
 for channel in ['frames','effects_frames']:
  assert len(actual[channel])==len(a[channel])
  for target,frame in zip(actual[channel],a[channel]):
   if sha(ROOT/target.removeprefix('res://'))!=frame['sha256']: failures.append('Approved PNG mismatch: '+target)
 if actual['review_sha256']!=sha(SOURCE/'visual_review.json'): failures.append('Review SHA mismatch: '+key)
result={'date':'2026-10-02','failures':failures,'old_pngs_preserved':len(baseline['textures']),'protected_code_preserved':len(baseline['protected'])-len(external_code),'concurrent_code_changes_observed':external_code,'hero_approved_actions':len(approved['actions']),'hero_body_and_fx_hashes_verified':sum(len(a[c]) for a in approved['actions'].values() for c in ['frames','effects_frames']),'concurrent_golem_manifest_changes_observed':external,'scope':'This chat writes hero only. Concurrent golem metadata and two shared presentation code changes are reported separately, not claimed unchanged. All other baseline controls/rules and unrelated enemy metadata plus all old production PNGs are compared to baseline.'}
(OUT/'production-preservation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
raise SystemExit(1 if failures else 0)
