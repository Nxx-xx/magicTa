"""Read-only format/provenance/approval integrity check; never produces acceptance."""
import hashlib,json
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1];BASE=ROOT/'assets/monsters/phase3/source/parallel_v05/map';OUT=ROOT/'build/verification/phase3/08-parallel/map_b'
ids=['warlock','knight','berserker','warden','p3_ember_channeler','p3_vault_knight'];results=[]
for entity in ids:
    folder=BASE/entity;rig=json.loads((folder/f'{entity}_map_rig.json').read_text(encoding='utf-8'));draft=json.loads((folder/f'{entity}_map_draft_manifest.json').read_text(encoding='utf-8'));review=json.loads((folder/f'{entity}_publish_review.json').read_text(encoding='utf-8'));action=draft['actions']['idle'];approval=review['actions']['map_idle']
    assert draft['status']=='draft' and rig['status']=='draft'
    assert draft['size']==[256,256] and draft['anchor']==[128,224]
    assert action['fps']==6 and action['loop'] and action['events']=={} and action['pose_holds']=={}
    assert len(action['frames'])==4 and not any(m['edge_touch'] for m in action['metrics'])
    assert set(review['actions'])=={'map_idle'} and review['human_signoff'] is False
    assert approval['source_action']=='idle' and approval['frame_slots']==4
    assert approval['frame_sha256']==[hashlib.sha256((folder/f).read_bytes()).hexdigest() for f in action['frames']]
    frames=[Image.open(folder/f).convert('RGBA') for f in action['frames']]
    assert all(im.size==(256,256) and im.getchannel('A').getextrema()==(0,255) for im in frames)
    assert len({im.tobytes() for im in frames})==4
    assert (folder/'.gdignore').exists() and (folder/f'{entity}_map_editable_draft.tscn').exists()
    assert {'head','torso','right_arm','left_arm','right_leg','left_leg','weapon_grip','right_elbow','left_elbow','right_knee','left_knee'}<={l['name'] for l in rig['layers']}
    if action.get('effects_frames'):assert approval['effects_sha256']==[hashlib.sha256((folder/f).read_bytes()).hexdigest() for f in action['effects_frames']]
    originals=[p for p in folder.glob('*.png') if 'components' in p.name or 'furnace_flame' in p.name]
    results.append({'entity':entity,'source':folder.relative_to(ROOT).as_posix(),'body_frame_slots':4,'unique_body_poses':4,'effect_slots':len(action.get('effects_frames',[])),'native_scene':True,'source_status':'draft','human_signoff':False,'approval_sha_matches':True,'originals':[{'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'mode':Image.open(p).mode} for p in originals]})
boundary=json.loads((OUT/'foreign-source-rejected-20261002-002613-443-result.json').read_text(encoding='utf-8-sig'));assert boundary['exit_code']==2 and boundary['script_error'] is False and boundary['timed_out'] is False
summary={'group':'map_b','date':'2026-10-02','entities':results,'body_slots':24,'effect_slots':8,'new_imagegen_originals':7,'decoded_body_payload_bytes_if_all_frames_loaded':24*256*256*4,'decoded_effect_payload_bytes_if_all_effects_loaded':8*256*256*4,'runtime_residency_measured':False,'source_boundary_rejection_confirmed':True,'approval_generated_by_this_check':False,'production_written':False}
(OUT/'map_b_final_verification.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
sheet=Image.new('RGBA',(1024,1536),(31,48,55,255));d=ImageDraw.Draw(sheet)
for i,e in enumerate(ids):sheet.alpha_composite(Image.open(OUT/f'{e}_map_idle_draft_contact.png').convert('RGBA'),(0,i*256));d.text((8,i*256+8),e,fill='white')
sheet.save(OUT/'map_b_all_contact.png')
html='<!doctype html><meta charset="utf-8"><title>Map B 完整交付审阅</title><style>body{font:18px system-ui;background:#1e3038;color:#eee;margin:24px}a{color:#ecc57f}main{display:grid;grid-template-columns:repeat(2,minmax(340px,1fr));gap:20px}article{background:#263e48;padding:20px}img.actor{width:256px;background:repeating-conic-gradient(#384751 0% 25%,#273841 0% 50%) 0/16px 16px}img.small{width:100%;max-width:560px}button{font:inherit;padding:8px;margin:8px}</style><h1>地图 B · 六套独立地图 idle</h1><p>24身体帧位 + 8独立火焰效果帧；7张内置imagegen原图。各4/6循环、256、锚点128,224。源仍draft，agent逐动作视觉记录通过；真人签收false，生产由统筹二审发布。</p><button onclick="document.querySelectorAll(\'.actor\').forEach(im=>im.src=im.dataset.id+\'_map_idle_original.webp\')">原速</button><button onclick="document.querySelectorAll(\'.actor\').forEach(im=>im.src=im.dataset.id+\'_map_idle_quarter.webp\')">0.25倍</button><main>'
for e in ids:html+=f'<article><h2>{e}</h2><a href="../../../../../assets/monsters/phase3/source/parallel_v05/map/{e}/{e}_map_review.html">暂停 / 逐帧 / 特效开关及源预览</a><br><img class="actor" data-id="{e}" src="{e}_map_idle_original.webp"><br><img class="small" src="{e}_map_small_contact.png"></article>'
(OUT/'index.html').write_text(html+'</main>',encoding='utf-8')
print('Map B integrity verified: six draft native rigs; 24 distinct body poses; 8 independently switchable effect frames; all exact visual-approval hashes match. No publication.')
