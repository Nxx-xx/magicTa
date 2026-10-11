"""Produce review media and metadata checks; never writes approval decisions."""
import base64, hashlib, json
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/monsters/phase3/source/parallel_v05/variants'
OUT=ROOT/'build/verification/phase3/08-parallel/variants'
IDS=['p3_shield_sentinel','p3_ember_channeler','p3_vault_knight']
OUT.mkdir(parents=True,exist_ok=True)
all_data=[]; checks=[]
for id in IDS:
 folder=SRC/id;mp=folder/(id+'_draft_manifest.json')
 if not mp.exists():continue
 m=json.loads(mp.read_text(encoding='utf8'));m['entity']=id;m['scene']='battle';m['camera']='three-quarter facing left';m['human_signoff']=False
 mp.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
 entity=[]
 entity_contact=Image.new('RGB',(1080,len(m['actions'])*210),'#202e3a');contact_draw=ImageDraw.Draw(entity_contact)
 for name,a in m['actions'].items():
  key=id+'_'+name;frames=[Image.open(folder/p).convert('RGBA') for p in a.get('combined_frames',a['frames'])]
  row=list(m['actions']).index(name);contact_draw.text((5,row*210+2),name,fill='white')
  for i,f in enumerate(frames):
   q=f.resize((180,180),Image.Resampling.LANCZOS);entity_contact.paste(q,(i*180,row*210+20),q);contact_draw.text((i*180+5,row*210+195),str(i),fill='white')
  thumb=Image.new('RGB',(len(frames)*128,222),'#202e3a');dr=ImageDraw.Draw(thumb)
  for i,f in enumerate(frames):
   thumb.paste(f.resize((128,128),Image.Resampling.LANCZOS),(i*128,18),f.resize((128,128),Image.Resampling.LANCZOS))
   dr.text((i*128+4,2),str(i),fill='white')
   for j,size in enumerate([26,33,47]):
    q=f.resize((size,size),Image.Resampling.LANCZOS);thumb.paste(q,(i*128+j*40,165),q)
  thumb.save(OUT/(key+'_small_contact.png'))
  for label,speed in [('original',1),('quarter',.25)]:
   frames[0].save(OUT/(key+'_'+label+'.webp'),save_all=True,append_images=frames[1:],duration=round(1000/a['fps']/speed),loop=0,lossless=True)
  urls=lambda paths:['data:image/png;base64,'+base64.b64encode((folder/p).read_bytes()).decode('ascii') for p in paths]
  entity.append(dict(key=key,label=name,fps=a['fps'],loop=a['loop'],body=urls(a['frames']),combined=urls(a.get('combined_frames',a['frames']))))
  hashes=[hashlib.sha256((folder/p).read_bytes()).hexdigest() for p in a['frames']]
  duplicate=[i for i,h in enumerate(hashes) if h in hashes[:i] and str(i) not in a.get('pose_holds',{})]
  checks.append(dict(entity=id,action=name,frame_count=len(frames),fps=a['fps'],loop=a['loop'],events=a['events'],pose_holds=a.get('pose_holds',{}),edge_touch=any(x['edge_touch'] for x in a['metrics']),undeclared_duplicates=duplicate,rgba_all=all(Image.open(folder/p).mode=='RGBA' for p in a['frames'])))
 entity_contact.save(OUT/(id+'_all_actions_contact.png'))
 all_data.append(dict(id=id,actions=entity))
html='''<!doctype html><meta charset="utf-8"><title>Variants draft review</title><style>body{background:#14212b;color:#eee;font:14px Arial;margin:10px}button{padding:9px;margin:3px}header{position:sticky;top:0;background:#14212b;z-index:2}article{display:flex;gap:10px}section{width:210px;background:#243442;padding:4px}img{background:repeating-conic-gradient(#304453 0% 25%,#20303e 0% 50%) 0/16px 16px}h2{margin:6px 0}h3{margin:2px}p{margin:4px}</style><header><h2>Variants DRAFT — agent review; human signoff false</h2><button id="normal" onclick="speed=1;paused=false">原速</button><button id="quarter" onclick="speed=.25;paused=false">0.25倍</button><button id="pause" onclick="paused=!paused">暂停</button><button id="step" onclick="paused=true;tick++">逐帧</button><button id="reset" onclick="paused=true;t=0;tick=0">帧0</button><button id="effects" onclick="effects=!effects">特效开关</button><span id="state"></span></header><main></main><script>'''
html+='const data='+json.dumps(all_data)+';let speed=1,paused=false,effects=true,t=0,tick=0,last=performance.now();'
html+='''for(const e of data){let h=document.createElement('h2');h.textContent=e.id;document.querySelector('main').append(h);let row=document.createElement('article');for(const a of e.actions){let s=document.createElement('section');s.innerHTML=`<h3>${a.label} ${a.body.length}/${a.fps}</h3><img id="${a.key}" width="200"><p><img id="${a.key}_26" width="26"><img id="${a.key}_33" width="33"><img id="${a.key}_47" width="47"> <span id="${a.key}_frame"></span></p>`;row.append(s)}document.querySelector('main').append(row)}function run(now){if(!paused)t+=(now-last)/1000*speed;last=now;for(const e of data)for(const a of e.actions){let i=(Math.floor(t*a.fps)+tick)%a.body.length,src=(effects?a.combined:a.body)[i];for(const suffix of ['','_26','_33','_47'])document.getElementById(a.key+suffix).src=src;document.getElementById(a.key+'_frame').textContent='frame '+i}document.getElementById('state').textContent=(paused?'paused ':'playing ')+speed+'x / effects '+effects;requestAnimationFrame(run)}requestAnimationFrame(run)</script>'''
(OUT/'variants_review.html').write_text(html,encoding='utf8')
(OUT/'variants_technical_checks.json').write_text(json.dumps(checks,indent=2),encoding='utf8')
print('Review media:',len(checks),'actions; failures:',[x for x in checks if x['edge_touch'] or x['undeclared_duplicates'] or not x['rgba_all']]);print('No approvals created.')
