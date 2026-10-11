"""Build review media and technical evidence; never approves a visual action."""
import json,hashlib,copy
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
EVIDENCE=ROOT/'build/verification/phase3/08-parallel/base_b'
for entity in ('sentinel','knight'):
 folder=ROOT/'assets/monsters/phase3/source/parallel_v05/battle'/entity
 manifest=json.loads((folder/(entity+'_draft_manifest.json')).read_text(encoding='utf8'))
 manifest.update(entity=entity,view='battle_left',master_size=[512,512],human_signoff=False)
 (folder/(entity+'_draft_manifest.json')).write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
 small=Image.new('RGB',(1000,460),'#213440');d=ImageDraw.Draw(small)
 technical={'entity':entity,'actions':{},'native_scene_exists':(folder/(entity+'_editable_draft.tscn')).exists()}
 for ai,(name,a) in enumerate(manifest['actions'].items()):
  paths=a.get('combined_frames',a['frames']);frames=[Image.open(folder/p).convert('RGBA') for p in paths]
  body=[Image.open(folder/p).convert('RGBA') for p in a['frames']]
  for speed in (1,.25):
   duration=round(1000/a['fps']/speed)
   frames[0].save(EVIDENCE/f'{entity}_{name}_{speed}x.webp',save_all=True,append_images=frames[1:],duration=duration,loop=0,lossless=True)
  d.text((8,ai*115+5),f'{entity} {name}: 47 / 33 / 26 px',fill='white')
  for fi,im in enumerate(body):
   x=210+fi*125
   for size,offset in ((47,20),(33,72),(26,107)):
    thumb=im.resize((size,size),Image.Resampling.LANCZOS);small.paste(thumb,(x+offset-20,ai*115+40+(47-size)),thumb)
  hashes=[hashlib.sha256((folder/p).read_bytes()).hexdigest() for p in a['frames']]
  pixel_hashes=[hashlib.sha256(im.tobytes()).hexdigest() for im in body]
  technical['actions'][name]={'frame_sha256':hashes,'pixel_unique':len(set(pixel_hashes)),'frame_slots':len(body),'size':list(body[0].size),'edge_touch':any(m['edge_touch'] for m in a['metrics']),'pose_holds':a.get('pose_holds',{}),'effects_sha256':[hashlib.sha256((folder/p).read_bytes()).hexdigest() for p in a.get('effects_frames',[])]}
 small.save(EVIDENCE/f'{entity}_small_sizes.png')
 (EVIDENCE/f'{entity}_technical.json').write_text(json.dumps(technical,indent=2)+'\n',encoding='utf8')
 data=copy.deepcopy(manifest)
 for a in data['actions'].values():
  for key in ('frames','combined_frames','effects_frames'):
   if key in a:a[key]=[p+'?v='+hashlib.sha256((folder/p).read_bytes()).hexdigest()[:12] for p in a[key]]
 html='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>__ENTITY__ 动作审阅</title><style>body{background:#213440;color:#eee;font:18px system-ui;margin:24px}button,select,input{font:inherit;padding:8px;margin:6px}#stage{width:384px;height:384px;background:repeating-conic-gradient(#344854 0% 25%,#26353f 0% 50%) 0/24px 24px}#stage img{width:384px}#small img{margin:16px;vertical-align:bottom}code{font:16px monospace}</style><h1>__ENTITY__ · draft</h1><p>战斗朝左 · 512母版→256运行帧 · anchor(128,224) · 18帧位 · 真人签收 false</p><select id="action"></select><button id="play">暂停</button><button id="restart">重播</button><button id="next">下一帧</button><select id="speed"><option value="1">原速</option><option value=".25">0.25倍</option></select><label><input type="checkbox" id="fx" checked>独立效果</label><p><input type="range" id="scrub" min="0" value="0"><code id="frame"></code></p><div id="stage"><img></div><div id="small"><img width="47"><img width="33"><img width="26"></div><script>const data=__DATA__,action=document.querySelector('#action'),slider=document.querySelector('#scrub');for(const id in data.actions)action.add(new Option(id,id));let t=0,playing=true,last=performance.now();function draw(){const a=data.actions[action.value];let f=Math.floor(t*a.fps+.00001);f=a.loop?f%a.frames.length:Math.min(f,a.frames.length-1);document.querySelectorAll('img').forEach(im=>im.src=(document.querySelector('#fx').checked&&a.combined_frames?a.combined_frames:a.frames)[f]);slider.max=a.frames.length-1;slider.value=f;document.querySelector('#frame').textContent=`${action.value} ${f+1}/${a.frames.length} · ${a.fps} FPS · ${JSON.stringify(a.events)}`;}action.onchange=()=>{t=0;draw()};document.querySelector('#play').onclick=()=>{playing=!playing;document.querySelector('#play').textContent=playing?'暂停':'播放'};document.querySelector('#restart').onclick=()=>{t=0;playing=true;draw()};document.querySelector('#next').onclick=()=>{playing=false;t=((Number(slider.value)+1)%data.actions[action.value].frames.length)/data.actions[action.value].fps;draw()};slider.oninput=()=>{playing=false;t=Number(slider.value)/data.actions[action.value].fps;draw()};document.querySelector('#fx').onchange=draw;function tick(now){if(playing)t+=(now-last)/1000*Number(document.querySelector('#speed').value);last=now;draw();requestAnimationFrame(tick)}draw();requestAnimationFrame(tick)</script></html>'''
 (folder/(entity+'_review.html')).write_text(html.replace('__ENTITY__',entity).replace('__DATA__',json.dumps(data)),encoding='utf8')
 print(entity,technical)
