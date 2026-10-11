"""Offline review packaging, technical evidence only. Never approves output."""
import json,hashlib,sys
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
entity=sys.argv[1]
OUT=ROOT/'assets/monsters/phase3/source/parallel_v05/battle'/entity
EVID=ROOT/'build/verification/phase3/08-parallel/base_a'
m=json.loads((OUT/f'{entity}_draft_manifest.json').read_text(encoding='utf8'))
report={};js={}
for action,a in m['actions'].items():
    ims=[Image.open(OUT/p).convert('RGBA') for p in a['frames']]
    js[action]=dict(a)
    report[action]={'frames':len(ims),'fps':a['fps'],'loop':a['loop'],'hashes':[hashlib.sha256((OUT/p).read_bytes()).hexdigest() for p in a['frames']], 'edge_touch':any(t['edge_touch'] for t in a['metrics'])}
    for speed in [1,.25]:
        ims[0].save(EVID/f'{entity}_{action}_{speed}x.webp',save_all=True,append_images=ims[1:],duration=round(1000/a['fps']/speed),loop=0,lossless=True)
    canvas=Image.new('RGB',(max(660,len(ims)*100),240),'#293440'); d=ImageDraw.Draw(canvas)
    for row,size in enumerate([26,33,47]):
        d.text((3,row*75+4),f'{size}px',fill='white')
        for i,im in enumerate(ims):
            small=im.resize((size,size),Image.Resampling.LANCZOS); canvas.paste(small,(65+i*90,row*75+20),small);d.text((65+i*90,row*75+4),str(i),fill='white')
    canvas.save(EVID/f'{entity}_{action}_small.png')
(EVID/f'{entity}_technical.json').write_text(json.dumps(report,indent=2),encoding='utf8')
html='''<!doctype html><meta charset="utf-8"><title>ENTITY battle review</title><style>body{font:16px sans-serif;color:#eee;background:#182330}button,select{padding:10px;margin:4px}section{display:inline-block;vertical-align:top;width:310px}img{background:repeating-conic-gradient(#394957 0% 25%,#253341 0% 50%) 0/16px 16px}canvas{display:none}</style><h1>ENTITY · battle draft</h1><p>18 frame slots, 512 master → 256 RGBA; fixed anchor (128,224); human signoff false.</p><button onclick="speed=1;paused=false">1x</button><button onclick="speed=.25;paused=false">0.25x</button><button onclick="paused=!paused">Pause</button><button onclick="paused=true;step++">Next frame</button><label><input type="checkbox" id="fx" checked>Effects</label><p id="info"></p>'''.replace('ENTITY',entity)
for act in js:
    html+=f'<section><h2>{act}</h2><img id="{act}" width="256"><p>' + ''.join(f'<img id="{act}_{s}" width="{s}">' for s in [26,33,47])+f'</p><output id="{act}_frame"></output></section>'
html+='''<script>const data=DATA;let speed=1,paused=false,step=0,t=0,last=performance.now();function loop(now){if(!paused)t+=(now-last)/1000*speed;last=now;for(const [act,a] of Object.entries(data)){let i=(Math.floor(t*a.fps)+step)%a.frames.length;let frames=document.getElementById('fx').checked&&a.combined_frames?a.combined_frames:a.frames;for(const suffix of ['', '_26','_33','_47'])document.getElementById(act+suffix).src=frames[i];document.getElementById(act+'_frame').textContent=`${i} / ${a.frames.length-1} · ${a.fps} FPS · loop ${a.loop}`;}document.getElementById('info').textContent=`${speed}x · ${paused?'paused':'playing'} · t=${t.toFixed(2)}`;requestAnimationFrame(loop)}requestAnimationFrame(loop)</script>'''.replace('DATA',json.dumps(js))
(OUT/f'{entity}_review.html').write_text(html,encoding='utf8')
print(json.dumps(report))
