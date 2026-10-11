"""Coordinator publication gate. Requires separate exact candidate SHA approval.

Usage: python tools/art_polish_b_publish.py --review PATH --publish
Without --publish validates only. Never changes build/current/latest.
"""
import argparse, copy, hashlib, json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/monsters/phase3/source/art_polish_b_v07'
CANDIDATE=ROOT/'assets/monsters/phase3/art_polish_b_candidate.json'
MANIFEST=ROOT/'assets/monsters/phase3/manifest.json'
BASELINE=ROOT/'build/verification/art-polish-b/baseline-manifest.json'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def validate(review_path):
    secondary=read(review_path);worker=read(SRC/'art_polish_b_publish_review.json')
    for r in (worker,secondary):
        assert r['candidate_sha256']==sha(CANDIDATE),'Changed candidate requires fresh review'
        assert r['decision']=='accepted' and r['human_signoff'] is False
        assert r['review_method'] and set(r['approved_actions'])==set(worker['approved_actions'])
    assert secondary['reviewer_role']=='coordinator','Independent coordinator review required'
    current=read(MANIFEST);baseline=read(BASELINE)
    assert current==baseline,'Production changed since B baseline; reconcile before publish'
    candidate=read(CANDIDATE);inventory=read(SRC/'art_polish_b_review_inventory.json')
    for key,r in inventory.items():
        a=candidate['actions'][key];old=baseline['actions'][key]
        for f in ('fps','loop','events','anchor','size'):assert a[f]==old[f],(key,f)
        assert a.get('pose_holds',{})==old.get('pose_holds',{})
        assert len(a['frames'])==len(old['frames'])
        assert sha(ROOT/a['source'].removeprefix('res://'))==r['rig_sha256']
        assert sha(ROOT/r['draft_manifest'])==r['draft_sha256']
        for channel,expected in r['channels'].items():
            paths=[ROOT/p.removeprefix('res://') for p in a[channel]]
            assert [sha(p) for p in paths]==expected,(key,channel,'Changed pixels')
            for p in paths:
                assert p.resolve().is_relative_to((ROOT/'assets/monsters/phase3/textures'/SRC.name).resolve())
                with Image.open(p) as image:assert list(image.size)==a['size'] and image.mode=='RGBA'
    for relative,expected in worker['native_evidence_sha256'].items():
        assert sha(ROOT/relative)==expected
        evidence=read(ROOT/relative)
        for field in ('draft','rig','scene'):
            assert sha(ROOT/evidence[field].removeprefix('res://'))==evidence[field+'_sha256']
    result=copy.deepcopy(current)
    for key in inventory:
        a=copy.deepcopy(candidate['actions'][key]);a['status']='accepted'
        a['publish_review']=(SRC/'art_polish_b_publish_review.json').relative_to(ROOT).as_posix()
        a['coordinator_review']=review_path.relative_to(ROOT).as_posix()
        result['actions'][key]=a
    return result
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--review',type=Path,required=True);parser.add_argument('--publish',action='store_true');args=parser.parse_args()
    result=validate(args.review.resolve())
    if args.publish:MANIFEST.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print('B exact-SHA publication '+('complete' if args.publish else 'validated; no mutation'))
if __name__=='__main__':main()
