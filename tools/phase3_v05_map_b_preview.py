"""Package source-only contact/small-size/playback evidence. Never approves assets."""
import argparse,hashlib,json,copy
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]; BASE=ROOT/'assets/monsters/phase3/source/parallel_v05/map'; EVID=ROOT/'build/verification/phase3/08-parallel/map_b'
p=argparse.ArgumentParser();p.add_argument('entity',choices=['warlock','knight','berserker','warden','p3_ember_channeler','p3_vault_knight']);args=p.parse_args();entity=args.entity;folder=BASE/entity
manifest=json.loads((folder/f'{entity}_map_draft_manifest.json').read_text(encoding='utf-8'));action=copy.deepcopy(manifest['actions']['idle'])
frames=[Image.open(folder/f).convert('RGBA') for f in action['frames']]
combined=[Image.open(folder/f).convert('RGBA') for f in action.get('combined_frames',action['frames'])]
for speed,duration in [('original',167),('quarter',667)]:combined[0].save(EVID/f'{entity}_map_idle_{speed}.webp',save_all=True,append_images=combined[1:],duration=duration,loop=0,lossless=True)
sheet=Image.new('RGBA',(560,220),(31,48,55,255));draw=ImageDraw.Draw(sheet)
for row,size in enumerate([26,33,47]):
    draw.text((8,row*70+12),f'{size}px',fill='white')
    for i,frame in enumerate(combined):
        small=frame.resize((size,size),Image.Resampling.LANCZOS);sheet.alpha_composite(small,(90+i*110,row*70+10));draw.text((90+i*110,row*70+size+14),str(i),fill='white')
sheet.save(EVID/f'{entity}_map_small_contact.png')
for channel in ['frames','effects_frames','combined_frames']:
    if channel in action: action[channel]=[f+'?v='+hashlib.sha256((folder/f).read_bytes()).hexdigest()[:12] for f in action[channel]]
html='''<!doctype html><meta charset="utf-8"><title>__ID__ map B review</title><style>body{font:17px system-ui;background:#1e3038;color:#eee;margin:20px}button,select,input{padding:9px;margin:5px;font:inherit}.stage{width:384px;height:384px;background:repeating-conic-gradient(#384751 0% 25%,#273841 0% 50%) 0/24px 24px}#actor{width:384px}#small img{margin:20px;vertical-align:bottom}#contact{width:960px;max-width:95vw}#frame{font-family:monospace}</style><h1>__ID__ · 独立地图 idle DRAFT</h1><p>4帧 / 6FPS / loop / 256 / anchor128,224 / 真人签收false</p><button id="play">暂停</button><button id="restart">重播</button><button id="next">下一帧</button><select id="speed"><option value="1">原速</option><option value=".25">0.25 倍</option></select><label><input id="fx" type="checkbox" checked>独立特效</label><p><input id="scrub" type="range" min="0" max="3" value="0"><span id="frame"></span></p><div class="stage"><img id="actor"></div><div id="small"><img width="26"><img width="33"><img width="47"></div><h2>逐帧</h2><img id="contact" src="__CONTACT__"><script>const a=__DATA__;let t=0,playing=true,last=performance.now();function draw(){let f=Math.floor(t*a.fps+.00001)%a.frames.length;document.querySelectorAll('#actor,#small img').forEach(im=>im.src=(document.querySelector('#fx').checked&&a.combined_frames?a.combined_frames:a.frames)[f]);document.querySelector('#scrub').value=f;document.querySelector('#frame').textContent=`map_idle frame ${f} / 3`;window.reviewFrame=f}document.querySelector('#play').onclick=()=>{playing=!playing;document.querySelector('#play').textContent=playing?'暂停':'播放'};document.querySelector('#restart').onclick=()=>{t=0;draw()};document.querySelector('#next').onclick=()=>{playing=false;t=(Number(document.querySelector('#scrub').value)+1)%4/6;draw()};document.querySelector('#scrub').oninput=e=>{playing=false;t=Number(e.target.value)/6;draw()};document.querySelector('#fx').onchange=draw;function tick(now){if(playing)t+=(now-last)/1000*Number(document.querySelector('#speed').value);last=now;draw();requestAnimationFrame(tick)}draw();requestAnimationFrame(tick)</script>'''
contact='../../../../../../../build/verification/phase3/08-parallel/map_b/'+entity+'_map_idle_draft_contact.png'
(folder/f'{entity}_map_review.html').write_text(html.replace('__ID__',entity).replace('__DATA__',json.dumps(action)).replace('__CONTACT__',contact),encoding='utf-8')
summary={'entity':entity,'dimensions':[list(im.size) for im in frames],'body_unique_pixel_poses':len({im.tobytes() for im in frames}),'body_sha256':[hashlib.sha256((folder/f).read_bytes()).hexdigest() for f in manifest['actions']['idle']['frames']],'edge_touches':[m['edge_touch'] for m in action['metrics']],'human_signoff':False,'approval_written':False}
(EVID/f'{entity}_format_check.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8');print(summary)
