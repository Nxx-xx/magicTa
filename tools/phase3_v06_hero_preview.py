"""Compose draft/body/FX/playback evidence without retouching source pixels."""
import json, html
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/characters/hero/phase3/source/refine_v06'
OUT=ROOT/'build/verification/phase3/09-refinement/hero'
data=json.loads((SOURCE/'draft_manifest.json').read_text(encoding='utf-8'))
def path(ref): return ROOT/ref.removeprefix('res://')
def compose(groups,target,cell=196):
 cols=max(len(g[1]) for g in groups)
 sheet=Image.new('RGB',(cols*cell,len(groups)*(cell+25)),'#27333d')
 draw=ImageDraw.Draw(sheet)
 for row,(name,frames) in enumerate(groups):
  for col,ref in enumerate(frames):
   pic=Image.open(path(ref)).convert('RGBA');pic.thumbnail((cell,cell))
   sheet.paste(pic,(col*cell+(cell-pic.width)//2,row*(cell+25)),pic)
   draw.text((col*cell+3,row*(cell+25)+cell+2),f'{name} #{col}',fill='white')
 sheet.save(target)
OUT.mkdir(parents=True,exist_ok=True)
for scope in ['map','combat']:
 groups=[(k,a['frames']) for k,a in data['actions'].items() if k.startswith(scope+'_')]
 if not groups: continue
 compose(groups,OUT/f'{scope}_contact.png')
 compose([(k,data['actions'][k]['effects_frames']) for k,_ in groups],OUT/f'{scope}_effects.png')
 small=Image.new('RGB',(8*78+170,len(groups)*152),'#27333d');draw=ImageDraw.Draw(small)
 for row,(name,frames) in enumerate(groups):
  for i,size in enumerate([26,33,47]):
   draw.text((3,row*152+i*50),f'{name} {size}px',fill='white')
   for col,ref in enumerate(frames):
    pic=Image.open(path(ref)).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
    small.paste(pic,(170+col*78,row*152+i*50),pic)
 small.save(OUT/f'{scope}_small.png')
for name,action in data['actions'].items():
 compose([(name,action['frames'])],OUT/f'{name}_contact.png',256)
frames_data={}
for name,action in data['actions'].items():
 frames_data[name]={k:v for k,v in action.items() if k in ['fps','loop','size','anchor','events','pose_holds']}
 for channel in ['frames','effects_frames']:
  frames_data[name][channel]=['../../../../../'+path(p).relative_to(ROOT).as_posix() for p in action[channel]]
page='''<!doctype html><meta charset="utf-8"><title>公主 v06 精修审阅</title>
<style>body{background:#17242d;color:#eef1ee;font:16px system-ui;margin:24px}button,select,input{font:inherit;margin:6px}canvas{background:repeating-conic-gradient(#273640 0% 25%,#30404b 0% 50%) 50%/24px 24px;border:1px solid #769288}label{margin-right:12px}</style>
<h1>公主 v06 · 已发布帧审阅</h1><p>18 动作 / 91 帧位。独立身体、灯光与剑光；原速、0.25 倍、逐帧；human_signoff=false。</p>
<select id="action"></select><select id="speed"><option value="1">原速 1×</option><option value=".25">慢速 0.25×</option></select>
<button id="play">暂停 / 播放</button><button id="step">下一帧</button><input id="frame" type="range" min="0" value="0"><label><input type="checkbox" id="fx" checked>独立效果</label><label><input type="checkbox" id="reduced">减动效</label><p id="info"></p>
<canvas id="view" width="384" height="384"></canvas><p>实际 26 / 33 / 47px</p><canvas id="s26" width="26" height="26"></canvas> <canvas id="s33" width="33" height="33"></canvas> <canvas id="s47" width="47" height="47"></canvas>
<script>const data=DATA;const action=document.querySelector('#action'),slider=document.querySelector('#frame');let playing=true,elapsed=0,last=0,images={};for(const name in data){let o=new Option(name,name);action.add(o);images[name]={};for(const key of ['frames','effects_frames'])images[name][key]=data[name][key].map(url=>{let i=new Image;i.src=url;return i})}
function select(){elapsed=0;slider.max=data[action.value].frames.length-1;slider.value=0}action.onchange=select;select();document.querySelector('#play').onclick=()=>playing=!playing;slider.oninput=()=>{playing=false;elapsed=Number(slider.value)/data[action.value].fps};document.querySelector('#step').onclick=()=>{playing=false;slider.value=(Number(slider.value)+1)%data[action.value].frames.length;elapsed=Number(slider.value)/data[action.value].fps};
function draw(t){let dt=last?(t-last)/1000:0;last=t;const a=data[action.value];if(playing)elapsed+=dt*Number(document.querySelector('#speed').value);let n=Math.floor(elapsed*a.fps);if(a.loop)n%=a.frames.length;else n=Math.min(n,a.frames.length-1);if(document.querySelector('#reduced').checked)n=0;slider.value=n;for(const id of ['view','s26','s33','s47']){const c=document.querySelector('#'+id),ctx=c.getContext('2d');ctx.clearRect(0,0,c.width,c.height);let body=images[action.value].frames[n],fx=images[action.value].effects_frames[n];if(body.complete)ctx.drawImage(body,0,0,c.width,c.height);if(document.querySelector('#fx').checked&&!document.querySelector('#reduced').checked&&fx.complete)ctx.drawImage(fx,0,0,c.width,c.height)}document.querySelector('#info').textContent=`${action.value} 帧 ${n}/${a.frames.length-1} · ${a.fps} FPS · anchor ${a.anchor} · ${JSON.stringify(a.events)}`;requestAnimationFrame(draw)}requestAnimationFrame(draw);</script>'''
(OUT/'hero_review.html').write_text(page.replace('DATA',json.dumps(frames_data,ensure_ascii=False)),encoding='utf-8')
if (OUT/'native/timing.json').exists():
 timing=json.loads((OUT/'native/timing.json').read_text(encoding='utf-8'))
 for speed in [1,.25]:
  for scope in ['map','combat']:
   groups=[]
   for name in data['actions']:
    obs=[o for o in timing['observations'] if o['action']==name and o['speed']==speed]
    if name.startswith(scope+'_') and obs: groups.append((name,[o['path'] for o in obs]))
   if groups: compose(groups,OUT/f'native/{scope}_{speed}x_contact.png')
   if scope=='map':
    for direction in ['right','down','up','left']:
     subset=[g for g in groups if g[0].endswith('_'+direction)]
     if subset: compose(subset,OUT/f'native/map_{direction}_{speed}x_contact.png')
print('Draft sheets and interactive preview:',OUT)
