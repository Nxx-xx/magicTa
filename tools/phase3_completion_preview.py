"""Build a local interactive index of reviewed frames; never edits image pixels."""
import json
import os
import hashlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root/'build/verification/phase3/07-completion/animation-review.html'
out.parent.mkdir(parents=True,exist_ok=True)
entries = []
counts = {'hero': 0, 'enemy_combat': 0, 'enemy_map': 0, 'ruins': 0}
def add(label, action):
    channels={}
    for channel in ['frames','effects_frames']:
        urls=[]
        for frame in action.get(channel,[]):
            path=root/frame.removeprefix('res://')
            assert path.is_file(),path
            urls.append(os.path.relpath(path,out.parent).replace('\\','/')+'?v='+hashlib.sha256(path.read_bytes()).hexdigest()[:12])
        channels[channel]=urls
    entries.append(dict(label=label,**channels,fps=action['fps'],loop=action['loop']))
for key, action in json.loads((root/'assets/characters/hero/phase3/manifest.json').read_text(encoding='utf-8'))['actions'].items():
    add('公主 · '+key,action)
    counts['hero'] += len(action['frames'])
for key, action in json.loads((root/'assets/monsters/phase3/manifest.json').read_text(encoding='utf-8'))['actions'].items():
    if action['status'] == 'accepted':
        add('敌人 · '+key,action)
        counts['enemy_map' if key.endswith('_map_idle') else 'enemy_combat'] += len(action['frames'])
for key, ruin in json.loads((root/'assets/environment/ruins/phase3/runtime_v02.json').read_text(encoding='utf-8'))['ruins'].items():
    for name, action in ruin['actions'].items():
        add('遗迹 · '+key+' / '+name,action)
        counts['ruins'] += len(action['frames'])
add('回溯标记 · 弱呼吸',dict(frames=['res://assets/ui/phase3/return_marker_0.svg','res://assets/ui/phase3/return_marker_1.svg'],fps=2,loop=True))
html = '''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>第三阶段 · 已接入动画检查</title><style>
body{font:16px system-ui;background:#12252e;color:#e6e7df;margin:24px;max-width:1100px}h1{font-size:26px}button,select{font:inherit;padding:8px;margin:4px;background:#26414c;color:inherit;border:1px solid #61797d;border-radius:6px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(265px,1fr));gap:16px}article{background:#1b333c;padding:12px;border-radius:12px}h2{font-size:14px;overflow-wrap:anywhere}.stage{position:relative;height:270px;display:flex;align-items:end;justify-content:center;background:repeating-conic-gradient(#172d35 0% 25%,#213a42 0% 50%) 50%/24px 24px}.stage img{object-fit:contain;max-height:256px}.stage .effect{position:absolute;bottom:0;left:50%;transform:translateX(-50%)}small{color:#aec3c8}header{position:sticky;top:0;background:#12252ef5;padding:8px 0;z-index:1}
</style><h1>第三阶段 · 已接入动画检查</h1><p>公主 91 帧位、史莱姆/牛头/魔像战斗 88 帧位及两种独立地图 8 帧位、三遗迹 75 帧位与两态回溯标记。帧位不是新原画数量；其他怪物仍未完成。</p><header><button id="toggle">暂停</button><button id="step">下一帧</button><button id="reset">重播</button><label>速度 <select id="speed"><option value="1">原速</option><option value=".25">0.25 倍</option></select></label><label>显示尺寸 <select id="size"><option>128</option><option>256</option><option>47</option><option>33</option><option>26</option></select></label><label><input id="effects" type="checkbox" checked>独立纹样</label><small>非循环动作停在末帧。缩小检查只缩放显示，不修改资源。</small></header><main></main><script>
const entries=__DATA__;let playing=true,clock=0,last=performance.now(),manual=0;
const cards=entries.map(e=>{const a=document.createElement('article'),h=document.createElement('h2'),s=document.createElement('div'),im=document.createElement('img'),label=document.createElement('small');h.textContent=e.label;s.className='stage';im.alt=e.label;im.width=128;const effect=document.createElement("img");effect.className="effect";effect.width=128;s.append(im,effect);a.append(h,s,label);document.querySelector('main').append(a);return {...e,im,effect,label};});
function draw(){cards.forEach(e=>{let f=Math.floor(clock*e.fps)+manual;f=e.loop?f%e.frames.length:Math.min(f,e.frames.length-1);e.im.src=e.frames[f];e.effect.hidden=!e.effects_frames.length||!document.querySelector("#effects").checked;if(e.effects_frames.length)e.effect.src=e.effects_frames[f];e.label.textContent=`${f+1} / ${e.frames.length} · ${e.fps} FPS · ${e.loop?'循环':'单次'}`;});}
document.querySelector('#toggle').onclick=()=>{playing=!playing;document.querySelector('#toggle').textContent=playing?'暂停':'播放';};document.querySelector('#step').onclick=()=>{playing=false;document.querySelector('#toggle').textContent='播放';manual++;draw();};document.querySelector('#reset').onclick=()=>{clock=manual=0;draw();};document.querySelector('#size').onchange=e=>cards.forEach(c=>{c.im.width=c.effect.width=Number(e.target.value)});function tick(t){if(playing)clock+=(t-last)/1000*Number(document.querySelector('#speed').value);last=t;draw();requestAnimationFrame(tick);}draw();requestAnimationFrame(tick);
</script></html>'''
summary = f"公主 {counts['hero']} 帧位、敌人战斗 {counts['enemy_combat']} 帧位和独立地图 {counts['enemy_map']} 帧位、遗迹 {counts['ruins']} 帧位及两态回溯标记。帧位不是新原画数量。此页展示已显式发布资源，真人美术签收和目标设备验收仍未完成。"
old_summary = '公主 91 帧位、史莱姆/牛头/魔像战斗 88 帧位及两种独立地图 8 帧位、三遗迹 75 帧位与两态回溯标记。帧位不是新原画数量；其他怪物仍未完成。'
out.write_text(html.replace(old_summary,summary).replace('__DATA__',json.dumps(entries,ensure_ascii=False)),encoding='utf-8')
print(f'Review: {len(entries)} timelines -> {out}')

