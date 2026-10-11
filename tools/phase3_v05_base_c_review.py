"""Create previews/technical evidence. Approval is separately invoked after visual review."""
import argparse,json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
E=ROOT/'build/verification/phase3/08-parallel/base_c'
p=argparse.ArgumentParser();p.add_argument('entity');p.add_argument('--approve',action='store_true');p.add_argument('--notes',default='');a=p.parse_args()
folder=ROOT/'assets/monsters/phase3/source/parallel_v05/battle'/a.entity
manifest=json.loads((folder/(a.entity+'_draft_manifest.json')).read_text(encoding='utf-8'))
manifest['entity']=a.entity;manifest['camera']='battle_left';manifest['map_actions']={};manifest['map_scope']='Independent map camera assigned to map_b; not present in this battle draft.'
(folder/(a.entity+'_draft_manifest.json')).write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
metrics={};review={}
for name,action in manifest['actions'].items():
    frames=[Image.open(folder/f).convert('RGBA') for f in action['frames']]
    combined=[Image.open(folder/f).convert('RGBA') for f in action.get('combined_frames',action['frames'])]
    for speed,label in [(1,'original'),(.25,'quarter')]:
        combined[0].save(E/f'{a.entity}_{name}_{label}.webp',save_all=True,append_images=combined[1:],duration=round(1000/action['fps']/speed),loop=0,lossless=True)
    small=Image.new('RGB',(max(len(frames)*62,310),190),'#23313d');draw=ImageDraw.Draw(small)
    for row,size in enumerate([26,33,47]):
        draw.text((2,row*62),f'{size}px',fill='white')
        for i,im in enumerate(combined):small.paste(im.resize((size,size),Image.Resampling.LANCZOS),(i*62+35,row*62+15),im.resize((size,size),Image.Resampling.LANCZOS))
    small.save(E/f'{a.entity}_{name}_small.png')
    sha=lambda paths:[hashlib.sha256((folder/f).read_bytes()).hexdigest() for f in paths]
    metrics[name]=dict(frame_slots=len(frames),unique_body_hashes=len(set(sha(action['frames']))),edge_touch=any(m['edge_touch'] for m in action['metrics']),rgba=all(im.mode=='RGBA' and im.size==(256,256) for im in frames))
    review[name]=dict(decision='accepted',draft_manifest=a.entity+'_draft_manifest.json',source_action=name,frame_slots=len(frames),pose_holds=action.get('pose_holds',{}),notes=a.notes,frame_sha256=sha(action['frames']))
    if action.get('effects_frames'):review[name]['effects_sha256']=sha(action['effects_frames'])
data=json.loads(json.dumps(manifest))
for action in data['actions'].values():
    for ch in ['frames','effects_frames','combined_frames']:
        if ch in action:action[ch]=[f+'?v='+hashlib.sha256((folder/f).read_bytes()).hexdigest()[:12] for f in action[ch]]
html='''<!doctype html><meta charset="utf-8"><title>__ENTITY__ battle review</title><style>body{background:#182a35;color:#eee;font:16px system-ui;margin:12px}button,input{font:inherit;padding:8px;margin:4px}main{display:flex;flex-wrap:wrap;gap:12px}.card{width:268px}.stage{width:256px;height:256px;position:relative;background:repeating-conic-gradient(#374755 0% 25%,#23313d 0% 50%) 0/16px 16px}.stage img{width:256px}.stage span{position:absolute;top:16px;left:96px;color:#fff;font:bold 22px system-ui;display:__TEXT__;background:#17212c90}.small img{vertical-align:bottom;margin:8px}button:focus{outline:2px solid gold}</style><h2>__ENTITY__ · battle draft / human signoff false</h2><button id="original">原速</button><button id="quarter">0.25倍</button><button id="pause">暂停</button><button id="restart">重播</button><button id="next">逐帧</button><label><input id="fx" type="checkbox" checked>独立特效</label><p id="clock"></p><main></main><script>const data=__DATA__;let t=0,speed=1,playing=true,last=performance.now(),step=0;for(const [name,a] of Object.entries(data.actions)){let c=document.createElement('div');c.className='card';c.innerHTML=`<h3>${name} ${a.frames.length}/${a.fps} FPS</h3><div class="stage"><img data-action="${name}"><span>-19</span></div><div class="small"><img data-action="${name}" width="26"><img data-action="${name}" width="33"><img data-action="${name}" width="47"></div><p id="${name}_label"></p>`;document.querySelector('main').append(c)}function draw(){for(const [n,a] of Object.entries(data.actions)){let i=(Math.floor(t*a.fps)+step)%a.frames.length;document.querySelectorAll(`[data-action="${n}"]`).forEach(im=>im.src=(document.querySelector('#fx').checked&&a.combined_frames?a.combined_frames:a.frames)[i]);document.querySelector('#'+n+'_label').textContent=`帧 ${i} / ${a.frames.length-1} · ${JSON.stringify(a.events)}`;}document.querySelector('#clock').textContent=`${playing?'播放':'暂停'} · ${speed}x · ${t.toFixed(2)}s`;}document.querySelector('#original').onclick=()=>{speed=1;playing=true;t=0;step=0};document.querySelector('#quarter').onclick=()=>{speed=.25;playing=true;t=0;step=0};document.querySelector('#pause').onclick=()=>{playing=!playing;draw()};document.querySelector('#restart').onclick=()=>{t=0;step=0;draw()};document.querySelector('#next').onclick=()=>{if(playing){playing=false;t=0}step++;draw()};document.querySelector('#fx').onchange=draw;function tick(now){if(playing)t+=(now-last)/1000*speed;last=now;draw();requestAnimationFrame(tick)}draw();requestAnimationFrame(tick);</script>'''
html=html.replace(".forEach(im=>im.src=(document.querySelector('#fx').checked&&a.combined_frames?a.combined_frames:a.frames)[i])", ".forEach(im=>{const src=(document.querySelector('#fx').checked&&a.combined_frames?a.combined_frames:a.frames)[i];if(im.getAttribute('src')!==src)im.src=src})")
html=html.replace('draw();requestAnimationFrame(tick);</script>', "const preload=[];for(const a of Object.values(data.actions))for(const c of ['frames','combined_frames'])for(const src of (a[c]||[]))preload.push(new Promise(resolve=>{const im=new Image();im.onload=resolve;im.onerror=resolve;im.src=src}));Promise.all(preload).then(()=>{last=performance.now();draw();requestAnimationFrame(tick)});</script>")
(folder/(a.entity+'_review.html')).write_text(html.replace('__ENTITY__',a.entity).replace('__DATA__',json.dumps(data)).replace('__TEXT__','block' if a.entity=='warden' else 'none'),encoding='utf-8')
(E/(a.entity+'_technical.json')).write_text(json.dumps(metrics,indent=2)+'\n',encoding='utf-8')
if a.approve:
    if not a.notes:raise SystemExit('Explicit actual visual notes required')
    if any(m['edge_touch'] for m in metrics.values()):raise SystemExit('Cannot approve clipped draft')
    r=dict(entity=a.entity,date='2026-10-01',review_method='Agent actual contact sheets, browser original and quarter speed, step frames and 26/33/47px review; not automatic technical approval',human_signoff=False,new_imagegen_originals=2 if (folder/'effects_original.png').exists() else 1,shared_effect_original='effects_original.png reused by both elites' if (folder/'effects_original.png').exists() else None,actions=review)
    (folder/(a.entity+'_publish_review.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(metrics))
