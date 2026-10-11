"""Prepare contact/playback/hash evidence. This tool NEVER creates approvals."""
import argparse, hashlib, json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/monsters/phase3/source/parallel_v05/map'
OUT=ROOT/'build/verification/phase3/08-parallel/map_a'

def evidence(entity):
    folder=BASE/entity
    manifest_path=folder/f'{entity}_map_draft_manifest.json'
    data=json.loads(manifest_path.read_text(encoding='utf-8'))
    action=data['actions']['idle']
    frames=[Image.open(folder/p).convert('RGBA') for p in action['frames']]
    fps=action['fps']
    hashes=[hashlib.sha256((folder/p).read_bytes()).hexdigest() for p in action['frames']]
    effects_hashes=[hashlib.sha256((folder/p).read_bytes()).hexdigest() for p in action.get('effects_frames',[])]
    combined_hashes=[hashlib.sha256((folder/p).read_bytes()).hexdigest() for p in action.get('combined_frames',[])]
    for speed,duration in [('original',round(1000/fps)),('quarter',round(4000/fps))]:
        frames[0].save(OUT/f'{entity}_map_idle_{speed}.webp',save_all=True,
                       append_images=frames[1:],duration=duration,loop=0,lossless=True)
    contact=Image.new('RGB',(1040,416),(24,34,44))
    draw=ImageDraw.Draw(contact)
    for i,frame in enumerate(frames):
        contact.paste(frame,(i*260,24),frame)
        draw.text((i*260+12,4),f'{entity} map idle {i}',fill='white')
        x=i*260+32
        for size in [26,33,47]:
            small=frame.resize((size,size),Image.Resampling.LANCZOS)
            contact.paste(small,(x,310),small)
            draw.text((x,366),f'{size}px',fill='white')
            x+=size+24
    contact.save(OUT/f'{entity}_map_idle_visual_contact.png')
    checks=[]
    for i,frame in enumerate(frames):
        alpha=frame.getchannel('A')
        checks.append(dict(frame=i,size=frame.size,alpha_extrema=alpha.getextrema(),
                           opaque_bounds=alpha.point(lambda a:255 if a>128 else 0).getbbox()))
    candidate=dict(entity=entity,action='map_idle',source_action='idle',frame_slots=4,
                   fps=fps,loop=action['loop'],size=data['size'],anchor=data['anchor'],
                   events=action['events'],pose_holds=action.get('pose_holds',{}),
                   frame_sha256=hashes,checks=checks,
                   effects_sha256=effects_hashes,combined_sha256=combined_hashes,
                   unique_pixel_poses=len(set(hashlib.sha256(f.tobytes()).hexdigest() for f in frames)),
                   decoded_image_bytes=sum(f.width*f.height*4 for f in frames),
                   decision='requires_separate_visual_review')
    (OUT/f'{entity}_technical_candidate.json').write_text(json.dumps(candidate,indent=2)+'\n',encoding='utf-8')
    html='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>Map idle draft review</title>
<style>body{background:#18222c;color:#eee;font:16px sans-serif;margin:20px}button,select,label{padding:10px;margin:4px} .stack{display:inline-block;position:relative;background:repeating-conic-gradient(#35424c 0% 25%,#25303a 0% 50%) 0/12px 12px;margin:10px}.stack img{position:absolute;inset:0;width:100%;height:100%}#contact{max-width:100%;background:#18222c}</style>
<h1>ENTITY / map_idle — draft</h1><p>独立轻俯视正面地图视角，4帧 FPS FPS，256×256，锚点(128,224)。真人签收 false。</p>
<button id="original">原速</button><button id="quarter">0.25倍</button><button id="pause">暂停/播放</button><button id="step">逐帧</button><button id="reset">帧0</button>
<label>逐帧编号 <select id="frame"><option>0</option><option>1</option><option>2</option><option>3</option></select></label>
<label><input id="effects" type="checkbox">独立效果</label><p id="status"></p><div id="stacks"></div><p>每帧身体及26/33/47px联系图：</p><img id="contact" src="CONTACT">
<script>const a=DATA;let speed=1,paused=false,t=0,last=performance.now(),frame=0;
const sizes=[384,47,33,26],stacks=document.getElementById('stacks');
for(const size of sizes){const p=document.createElement('div');p.className='stack';p.style.width=p.style.height=size+'px';p.innerHTML='<img class="body"><img class="effect">';stacks.appendChild(p)}
document.getElementById('original').onclick=()=>{speed=1;paused=false};document.getElementById('quarter').onclick=()=>{speed=.25;paused=false};document.getElementById('pause').onclick=()=>paused=!paused;
function choose(i){paused=true;t=i/a.fps;frame=i;paint()}document.getElementById('step').onclick=()=>choose((frame+1)%4);document.getElementById('reset').onclick=()=>choose(0);document.getElementById('frame').onchange=e=>choose(+e.target.value);
function paint(){document.getElementById('frame').value=String(frame);document.getElementById('status').textContent='帧 '+frame+' / 4，'+(paused?'暂停':speed+'×播放');for(const p of document.querySelectorAll('.stack')){p.querySelector('.body').src=a.frames[frame];const fx=p.querySelector('.effect');fx.style.display=document.getElementById('effects').checked&&a.effects.length?'block':'none';if(a.effects.length)fx.src=a.effects[frame]}}
document.getElementById('effects').disabled=!a.effects.length;document.getElementById('effects').onchange=paint;
function tick(now){if(!paused)t+=(now-last)/1000*speed;last=now;frame=Math.floor(t*a.fps)%4;paint();requestAnimationFrame(tick)}requestAnimationFrame(tick);</script></html>'''
    contact_relative='../../../../../../../build/verification/phase3/08-parallel/map_a/'+entity+'_map_idle_visual_contact.png'
    html=html.replace('ENTITY',entity).replace('FPS FPS',f'{int(fps)} FPS').replace('CONTACT',contact_relative).replace('DATA',json.dumps(dict(fps=fps,frames=action['frames'],effects=action.get('effects_frames',[]))))
    (folder/f'{entity}_map_review.html').write_text(html,encoding='utf-8')
    print(json.dumps(candidate))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('entity');evidence(parser.parse_args().entity)
