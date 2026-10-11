"""Rebuild review-only contact sheets, animation viewers and source-size audit."""
from pathlib import Path
from PIL import Image, ImageDraw
import hashlib
import html
import json
import zlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/verification/battle-polish'

def contact(paths, destination, columns=4, thumb=(195,350)):
    paths = list(paths)
    if not paths:
        return
    width, height = thumb
    sheet = Image.new('RGB', (width*columns, (height+25)*((len(paths)+columns-1)//columns)), '#111d25')
    draw = ImageDraw.Draw(sheet)
    for i,path in enumerate(paths):
        image = Image.open(path).convert('RGB')
        image.thumbnail(thumb)
        x,y = i%columns*width,i//columns*(height+25)
        sheet.paste(image,(x,y))
        draw.text((x+4,y+height+3),path.stem,fill='#eac888')
    sheet.save(destination,quality=90)

for width in (320,390,540):
    contact(sorted(p for p in (OUT/'mobile').glob(f'*_{width}.png') if 'reduced' not in p.name),OUT/f'contact_{width}.jpg',5)
    contact(sorted((OUT/'mobile').glob(f'*_reduced_{width}.png')),OUT/f'reduced_contact_{width}.jpg',5)

sequences = []
for name,folder in [('slime','host-slime/host-frames'),('minotaur','host-minotaur/frames'),('golem','host-golem/frames')]:
    paths = sorted((OUT/folder).glob('*.png'))
    sequences.append((f'Public campaign {name}',paths,100 if name=='slime' else 50,OUT/f'host-{name}'))
for folder in sorted((OUT/'timed').glob('*')):
    if folder.is_dir():
        sequences.append((f'Timed fixture {folder.name}',sorted(folder.glob('*.png')),70,folder))
blocks=[]
for name,paths,duration,folder in sequences:
    if not paths: continue
    delays=[duration]*len(paths)
    if (folder/'timing.json').exists():
        samples=json.loads((folder/'timing.json').read_text(encoding='utf-8'))['samples']
        delays=[max(1,round((b['wall_seconds']-a['wall_seconds'])*1000)) for a,b in zip(samples,samples[1:])]
        delays.append(delays[-1] if delays else duration)
    images=[Image.open(p).convert('RGB') for p in paths]
    images[0].save(folder/'replay.webp',save_all=True,append_images=images[1:],duration=delays,loop=0,quality=85)
    picks=[paths[round(i*(len(paths)-1)/11)] for i in range(12)]
    contact(picks,folder/'contact.jpg',4)
    files=[p.relative_to(OUT).as_posix() for p in paths]
    blocks.append({'name':name,'frames':files,'duration':duration,'delays':delays,'contact':(folder/'contact.jpg').relative_to(OUT).as_posix()})

payload=json.dumps(blocks)
page='''<!doctype html><meta charset="utf-8"><title>Moonlit battle stages v02</title>
<style>body{margin:28px;background:#101d25;color:#e7d1a8;font:16px system-ui}button,select,input{font:inherit;margin:6px}img{max-width:100%;max-height:76vh}section{display:flex;gap:18px;flex-wrap:wrap}.note{max-width:900px;color:#bbcbcd}figure{margin:0}</style>
<h1>月夜战斗舞台 v02 / 实拍审阅</h1><p class="note">公开路线首战、牛头、魔像为已保存战报实拍；Timed fixture 为模拟战报的真实 Godot 定时渲染。滑杆逐帧，0.25× 复核。不是微信或真人签收；原速/慢速实际时间见各目录 timing.json。</p>
<select id="seq"></select><button id="play">暂停</button><select id="speed"><option value="1">1×</option><option value=".25">0.25×</option></select><button id="prev">上一帧</button><button id="next">下一帧</button><input id="frame" type="range" min="0" value="0"><span id="label"></span>
<section><img id="shot"><img id="sheet"></section><h2>同尺寸前 / 后</h2><section><figure><figcaption>改前 390</figcaption><img src="../art-polish-c/after/slime_390.png"></figure><figure><figcaption>改后 390</figcaption><img src="mobile/slime_390.png"></figure></section><h2>13 敌 / 三尺寸</h2>'''
page+=''.join(f'<a href="contact_{w}.jpg">{w}px 全图联系表</a> · <a href="reduced_contact_{w}.jpg">减动效 {w}px</a><br>' for w in (320,390,540))
page+='''<script>const data=PAYLOAD;let selected=0,index=0,playing=true,last=0;const seq=document.querySelector('#seq'),frame=document.querySelector('#frame'),shot=document.querySelector('#shot');data.forEach((s,i)=>seq.add(new Option(s.name,i)));function draw(){const s=data[selected];index=Math.max(0,Math.min(index,s.frames.length-1));shot.src=s.frames[index];frame.max=s.frames.length-1;frame.value=index;document.querySelector('#label').textContent=`${index+1} / ${s.frames.length}`;document.querySelector('#sheet').src=s.contact;}seq.onchange=()=>{selected=+seq.value;index=0;draw()};frame.oninput=()=>{playing=false;index=+frame.value;draw()};document.querySelector('#play').onclick=()=>{playing=!playing;document.querySelector('#play').textContent=playing?'暂停':'播放'};document.querySelector('#prev').onclick=()=>{playing=false;index--;draw()};document.querySelector('#next').onclick=()=>{playing=false;index++;draw()};function tick(t){if(playing&&t-last>data[selected].delays[index]/+document.querySelector('#speed').value){index=(index+1)%data[selected].frames.length;draw();last=t}requestAnimationFrame(tick)}draw();requestAnimationFrame(tick);</script>'''.replace('PAYLOAD',payload)
(OUT/'review.html').write_text(page,encoding='utf-8')
paths=[ROOT/'scripts/ui/art_polish_c_stage.gd',ROOT/'scripts/ui/phase3_combat_player.gd',ROOT/'scripts/ui/combat_presentation.gd']
audit={'scope':'Source size estimate only. New painted stages are separately measured in package-audit.json; not a whole-build before/after comparison.','files':[{ 'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'zlib_bytes':len(zlib.compress(p.read_bytes(),9)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths]}
(OUT/'source-audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
contact([OUT/'mobile'/f'{n}_390.png' for n in ['slime','skeleton','minotaur']],OUT/'three-stages.jpg',3,(390,700))
print('Battle v02 review rebuilt')
