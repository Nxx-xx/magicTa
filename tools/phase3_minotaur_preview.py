"""Build a source-only review page. Does not promote draft frames."""
import hashlib
import json
import argparse
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--entity',default='minotaur',choices=['minotaur','golem'])
parser.add_argument('--source',default='assets/monsters/phase3/source/rig_v04')
args=parser.parse_args()
folder=root/args.source
entity=args.entity
data=json.loads((folder/(entity+'_draft_manifest.json')).read_text(encoding='utf-8'))
map_data=json.loads((folder/(entity+'_map_draft_manifest.json')).read_text(encoding='utf-8'))
slots=sum(len(a['frames']) for a in data['actions'].values())
holds=sum(len(a.get('pose_holds',{})) for a in data['actions'].values())
data['actions']['map_idle']=map_data['actions']['idle']
review_path=folder/(entity+'_publish_review.json')
review=json.loads(review_path.read_text(encoding='utf-8')) if review_path.exists() else {}
approved=all(review.get('actions',{}).get(name,{}).get('frame_sha256')==[hashlib.sha256((folder/f).read_bytes()).hexdigest() for f in action['frames']]
    and (not action.get('effects_frames') or review['actions'][name].get('effects_sha256')==[hashlib.sha256((folder/f).read_bytes()).hexdigest() for f in action['effects_frames']])
    for name,action in data['actions'].items())
# Every rebake may keep the same filename. Bind browser previews to the reviewed
# bytes rather than allowing a previous PNG response to masquerade as this pose.
for action in data['actions'].values():
    for channel in ['frames','effects_frames','combined_frames']:
        if channel in action:
            action[channel]=[f+'?v='+hashlib.sha256((folder/f).read_bytes()).hexdigest()[:12] for f in action[channel]]
html='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>牛头 v04 动作审阅</title>
<style>body{background:#182c34;color:#e7e2cf;font:18px system-ui;margin:24px}button,select,input{font:inherit;margin:6px;padding:8px}#stage{width:384px;height:384px;background:repeating-conic-gradient(#253d47 0% 25%,#34525b 0% 50%) 0/24px 24px;position:relative}#stage:after{content:'';position:absolute;left:0;right:0;top:336px;border-top:1px solid #b4936870}#actor{width:384px}#small img{vertical-align:bottom;margin:20px}code{font:15px monospace}</style>
<h1>牛头 v04 · __STATUS__</h1><p>战斗 33 帧位 / 31 动作内独立姿态；独立地图 4 帧位；2 张新增组件原图。可编辑源保持 draft；运行发布只覆盖显式审阅的动作。真人签收尚未完成。</p>
<select id="action"></select><button id="play">暂停</button><button id="restart">重播</button><button id="next">下一帧</button><select id="speed"><option value="1">原速</option><option value=".25">0.25 倍</option></select>
<label><input id="fx" type="checkbox" checked>独立怒纹</label><p><input id="scrub" type="range" min="0" value="0"><code id="frame"></code></p><div id="stage"><img id="actor"></div><div id="small"><img width="47"><img width="33"><img width="26"></div>
<script>const data=__DATA__,action=document.querySelector('#action'),slider=document.querySelector('#scrub');for(const id in data.actions)action.add(new Option(id,id));let t=0,playing=true,last=performance.now();function draw(){const a=data.actions[action.value];let f=Math.floor(t*a.fps+.00001);f=a.loop?f%a.frames.length:Math.min(f,a.frames.length-1);document.querySelectorAll('img').forEach(im=>im.src=(document.querySelector('#fx').checked && a.combined_frames ? a.combined_frames : a.frames)[f]);slider.max=a.frames.length-1;slider.value=f;document.querySelector('#frame').textContent=`${action.value} ${f+1}/${a.frames.length} · ${a.fps} FPS · ${JSON.stringify(a.events)}`;}action.onchange=()=>{t=0;draw()};document.querySelector('#play').onclick=()=>{playing=!playing;document.querySelector('#play').textContent=playing?'暂停':'播放'};document.querySelector('#restart').onclick=()=>{t=0;draw()};document.querySelector('#next').onclick=()=>{playing=false;t=(Number(slider.value)+1)/data.actions[action.value].fps;draw()};slider.oninput=()=>{playing=false;t=Number(slider.value)/data.actions[action.value].fps;draw()};function tick(now){if(playing)t+=(now-last)/1000*Number(document.querySelector('#speed').value);last=now;draw();requestAnimationFrame(tick)}draw();requestAnimationFrame(tick)</script></html>'''
html=html.replace('牛头 v04','牛头 v04' if entity=='minotaur' else '魔像 v04').replace('战斗 33 帧位 / 31 动作内独立姿态',f'战斗 {slots} 帧位 / {slots-holds} 个非 hold 帧位')
html=html.replace('2 张新增组件原图','2 张新增组件原图' if entity=='minotaur' else '3 张新增组件原图').replace('独立怒纹','独立纹样')
(folder/(entity+'_review.html')).write_text(html.replace('__DATA__',json.dumps(data)).replace('__STATUS__','已审阅发布帧' if approved else 'draft · 待审阅'),encoding='utf-8')
print(folder/(entity+'_review.html'))

