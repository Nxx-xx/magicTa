"""Native chain-only evidence preparation and alpha-zone verification; never approves."""
import argparse, json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'assets/monsters/phase3/source/parallel_v05/battle/warden'
evidence=ROOT/'build/verification/phase3/08-parallel/base_c'
p=argparse.ArgumentParser();p.add_argument('--verify',action='store_true');args=p.parse_args()
qa=folder/'qa_chain';qa.mkdir(exist_ok=True);(qa/'.gdignore').touch()
if not args.verify:
    data=json.loads((folder/'warden_rig.json').read_text(encoding='utf-8'))
    data['entity']='warden_chain_mask';data['source']='../components.png';data['effect_layers']=['chain'];data['effect_actions']=list(data['actions'])
    for layer in data['layers']:
        if 'source' in layer:layer['source']='../'+layer['source']
    (qa/'warden_chain_mask_rig.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
else:
    data=json.loads((qa/'warden_chain_mask_draft_manifest.json').read_text(encoding='utf-8'))
    result={'reserved_runtime_text_rect':[80,10,105,53],'source':'native chain-only transparent export','frames':[],'overlap_pixels':0}
    for action,a in data['actions'].items():
        for i,f in enumerate(a['effects_frames']):
            alpha=Image.open(qa/f).convert('RGBA').getchannel('A');mask=alpha.point(lambda x:255 if x>8 else 0)
            overlap=sum(1 for x in mask.crop((80,10,185,63)).getdata() if x)
            result['frames'].append({'action':action,'frame':i,'chain_bounds':mask.getbbox(),'overlap_pixels':overlap})
            result['overlap_pixels']+=overlap
    result['passed']=result['overlap_pixels']==0
    (evidence/'warden_chain_text_zone.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'frames':len(result['frames']),'overlap_pixels':result['overlap_pixels'],'passed':result['passed']}))
