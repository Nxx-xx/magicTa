"""Audit published approval/evidence and gather existing locked run logs; no new approval."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/verification/phase3/09-refinement/hero'
SOURCE = ROOT / 'assets/characters/hero/phase3/source/refine_v06'

def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def local(ref):
    return ROOT / ref.removeprefix('res://')

review = read(SOURCE / 'visual_review.json')
assert review['approved_for_publish'] and not review['human_signoff']
assert digest(SOURCE / 'draft_manifest.json') == review['draft_sha256']
assert digest(OUT / 'native/timing.json') == review['native_timing_sha256']
timing = read(OUT / 'native/timing.json')
assert digest(ROOT / 'tools/phase3_v06_hero_bake.gd') == timing['author_sha256']
assert digest(ROOT / 'tools/phase3_v06_hero_playback.gd') == timing['capture_sha256']
for p, sha in review['scenes'].items():
    assert digest(local(p)) == sha, p
for p, sha in review['evidence'].items():
    assert digest(ROOT / p) == sha, p
published = read(ROOT / 'assets/characters/hero/phase3/manifest.json')
for action, approved in review['actions'].items():
    actual = published['actions'][action]
    assert actual['review_sha256'] == digest(SOURCE / 'visual_review.json')
    for field in ['frames', 'effects_frames']:
        assert len(actual[field]) == len(approved[field])
        for p, frame in zip(actual[field], approved[field]):
            assert digest(local(frame['path'])) == frame['sha256']
            assert digest(local(p)) == frame['sha256']

logs = OUT / 'locked-logs'
logs.mkdir(exist_ok=True)
origin = ROOT / 'build/verification/phase3/08-parallel/hero_refine'
for p in origin.iterdir():
    if p.is_file() and p.suffix in ['.json', '.log']:
        shutil.copy2(p, logs / p.name)

labels = ['v06-production-import', 'v06-specific-test',
          'v06-phase3_hero_map_test-final', 'v06-phase3_animation_test_runner-final',
          'v06-walking_test_runner-final', 'v06-phase3_replay_timing_test-final',
          'v06-phase3_ui_host_test_runner-final', 'v06-phase3_replay_host_capture-final',
          'v06-phase3_v05_runtime_capture-final', 'v06-real-main-held-walk-final',
          'v06-action-ui']
runs = []
for label in labels:
    matches = sorted(origin.glob(label + '-*-result.json'))
    p = matches[-1]
    result = read(p)
    assert result['exit_code'] == 0 and not any(result[k] for k in ['script_error', 'engine_error', 'timed_out']), label
    runs.append({'label': label, 'result': (logs / p.name).relative_to(ROOT).as_posix(), 'arguments': result['arguments']})
summary = {'date': '2026-10-02', 'draft_sha256': review['draft_sha256'],
           'visual_review_sha256': digest(SOURCE / 'visual_review.json'),
           'approved_actions': len(review['actions']), 'approved_body_plus_fx_pngs': 182,
           'native_timed_observations': len(timing['observations']),
           'approved_evidence_hashes_verified': len(review['evidence']),
           'final_locked_runs': runs,
           'scope': 'Existing reviewed assets and final locked logs audited; no approval or runtime publication performed by this script.'}
(OUT / 'delivery-audit.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Delivery audit passed:', len(runs), 'locked runs;', summary['approved_evidence_hashes_verified'], 'reviewed evidence hashes')
print('Visual review SHA256:', summary['visual_review_sha256'])
