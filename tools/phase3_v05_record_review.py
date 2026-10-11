"""Record a coordinator decision AFTER actual visual inspection, never during bake."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True)
    parser.add_argument('--entity', required=True)
    parser.add_argument('--evidence', required=True, help='Already inspected coordinator/native directory')
    parser.add_argument('--notes', required=True)
    parser.add_argument('--confirm-visual-review', required=True, action='store_true')
    options = parser.parse_args()
    source = (ROOT/options.source).resolve()
    evidence = (ROOT/options.evidence).resolve()
    assert source.is_relative_to(ROOT/'assets/monsters/phase3/source/parallel_v05')
    assert evidence.is_relative_to(ROOT/'build/verification/phase3/08-parallel/coordinator/native')
    worker = json.loads((source/f'{options.entity}_publish_review.json').read_text(encoding='utf-8-sig'))
    timing = json.loads((evidence/'timing.json').read_text(encoding='utf-8-sig'))
    for kind in ['draft', 'rig', 'scene']:
        assert hashlib.sha256((ROOT/timing[kind].removeprefix('res://')).read_bytes()).hexdigest() == timing[kind+'_sha256'], f'Native capture source changed: {kind}'
    record = copy.deepcopy(worker)
    record.update(date='2026-10-02', reviewer='coordinator', review_method='contact sheets plus native/browser playback; agent visual review',
                  human_signoff=False, approved_for_publish=True, playback_review_complete=True,
                  review_scope='Final authored body/effect and 26/33/47px contact sheets plus timed actual AnimationPlayer source playback at 1x/.25. Ordered sampled images inspected; no continuous video perception or human signoff claimed.', notes=options.notes)
    record['evidence'] = {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in evidence.glob('*.png')}
    record['evidence'][str((evidence/'timing.json').relative_to(ROOT).as_posix())] = hashlib.sha256((evidence/'timing.json').read_bytes()).hexdigest()
    for action in record['actions'].values():
        action['decision']='accepted'
        action['coordinator_notes']=options.notes
        action['draft_sha256']=timing['draft_sha256']
    category=source.parent.name
    output=ROOT/f'build/verification/phase3/08-parallel/coordinator/reviews/{options.entity}_{category}.json'
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(output)
