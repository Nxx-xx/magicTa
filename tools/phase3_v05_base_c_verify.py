"""Read-only final handoff validation, no automatic acceptance/publishing."""
import json,hashlib,math
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
B=ROOT/'assets/monsters/phase3/source/parallel_v05/battle'
E=ROOT/'build/verification/phase3/08-parallel/base_c'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
expected={'warlock':{'idle':(4,6),'attack':(6,12),'hit':(2,12),'defeat':(6,10)},'berserker':{'idle':(4,6),'attack':(8,12),'hit':(3,12),'defeat':(8,12)},'warden':{'idle':(4,6),'attack':(8,12),'hit':(3,12),'defeat':(8,12)}}
result={'checks':0,'failures':[],'entities':{},'body_frame_slots':0,'effect_frame_slots':0,'unique_imagegen_original_hashes':[]}
def check(ok,label):
    result['checks']+=1
    if not ok:result['failures'].append(label)
originals=set()
for entity,spec in expected.items():
    folder=B/entity;manifest=json.loads((folder/(entity+'_draft_manifest.json')).read_text(encoding='utf-8'));rig=json.loads((folder/(entity+'_rig.json')).read_text(encoding='utf-8'));review=json.loads((folder/(entity+'_publish_review.json')).read_text(encoding='utf-8'))
    info={'body_slots':0,'effect_slots':0,'declared_holds':0,'source_sha256':sha(folder/(entity+'_rig.json')),'editable_scene_sha256':sha(folder/(entity+'_editable_draft.tscn')),'review_sha256':sha(folder/(entity+'_publish_review.json')),'actions':{}}
    check(manifest['status']=='draft',entity+' source status');check(review['human_signoff'] is False,entity+' human signoff');check((folder/'.gdignore').exists(),entity+' import isolation');check(set(manifest['actions'])==set(spec),entity+' action set')
    original_hash=sha(folder/'components.png');originals.add(original_hash);info['component_original_sha256']=original_hash
    original=Image.open(folder/'components.png');check(original.mode=='RGBA' and original.getchannel('A').getextrema()[0]==0,entity+' original alpha')
    if (folder/'effects_original.png').exists():originals.add(sha(folder/'effects_original.png'));info['effect_original_sha256']=sha(folder/'effects_original.png')
    for name,(count,fps) in spec.items():
        a=manifest['actions'][name];r=review['actions'][name]
        check(len(a['frames'])==count and a['fps']==fps,entity+'/'+name+' spec');check(a['loop']==(name=='idle'),entity+'/'+name+' loop');check(all(isinstance(v,(int,float)) and v==int(v) and 0<=v<count for v in a['events'].values()),entity+'/'+name+' events');check(r['decision']=='accepted',entity+'/'+name+' manual decision')
        hashes=[sha(folder/f) for f in a['frames']];check(hashes==r['frame_sha256'],entity+'/'+name+' final body hashes')
        for frame,path in enumerate(a['frames']):
            im=Image.open(folder/path);check(im.mode=='RGBA' and im.size==(256,256),entity+'/'+name+f' frame{frame} format');bounds=im.getchannel('A').getbbox();check(bounds and bounds[0]>=4 and bounds[1]>=4 and bounds[2]<=252 and bounds[3]<=252,entity+'/'+name+f' frame{frame} alpha bounds')
        holds=a.get('pose_holds',{});check(holds==r['pose_holds'],entity+'/'+name+' holds approval')
        for target,source in holds.items():check(hashes[int(target)]==hashes[int(source)],entity+'/'+name+f' hold{target}')
        for i,h in enumerate(hashes):
            if h in hashes[:i]:check(str(i) in holds,entity+'/'+name+f' undeclared duplicate{i}')
        if a.get('effects_frames'):
            check([sha(folder/f) for f in a['effects_frames']]==r['effects_sha256'],entity+'/'+name+' effect hashes');check(len(a['effects_frames'])==count,entity+'/'+name+' effect slots')
        info['body_slots']+=count;info['effect_slots']+=len(a.get('effects_frames',[]));info['declared_holds']+=len(holds)
        info['actions'][name]={'slots':count,'fps':fps,'unique_body_poses':len(set(hashes)),'holds':holds}
    result['entities'][entity]=info;result['body_frame_slots']+=info['body_slots'];result['effect_frame_slots']+=info['effect_slots']
zone=json.loads((E/'warden_chain_text_zone.json').read_text(encoding='utf-8'));check(zone['passed'] and zone['overlap_pixels']==0 and len(zone['frames'])==23,'warden chain/text')
result['unique_imagegen_original_hashes']=sorted(originals);result['production_candidate_rgba_image_data_bytes']=(result['body_frame_slots']+result['effect_frame_slots'])*256*256*4;result['passed']=not result['failures']
(E/'final-handoff-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'checks':result['checks'],'failures':result['failures'],'body_slots':result['body_frame_slots'],'effect_slots':result['effect_frame_slots'],'unique_generated_originals':len(originals),'candidate_rgba_bytes':result['production_candidate_rgba_image_data_bytes']}))
raise SystemExit(0 if result['passed'] else 1)
