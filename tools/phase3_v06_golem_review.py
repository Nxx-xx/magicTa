"""Build review artifacts without granting approval. --record binds visual decisions."""
import argparse, hashlib, json, shutil
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/monsters/phase3/source/golem_v06'
OUT=ROOT/'build/verification/phase3/09-refinement/golem'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def actions():
    d=read(SRC/'golem_draft_manifest.json')
    m=read(SRC/'golem_map_draft_manifest.json')
    result={n:(a,d,'golem_draft_manifest.json',n) for n,a in d['actions'].items()}
    result['map_idle']=(m['actions']['idle'],m,'golem_map_draft_manifest.json','idle')
    return result
def sheet(items,dest,cell=96):
    canvas=Image.new('RGB',(12*cell,len(items)*(cell+20)), '#21323b');draw=ImageDraw.Draw(canvas)
    for row,(name,a) in enumerate(items):
        draw.text((4,row*(cell+20)+2),name,fill='#eee6cf')
        for i,p in enumerate(a.get('combined_frames',a['frames'])):
            im=Image.open(SRC/p).convert('RGBA');im.thumbnail((cell,cell),Image.Resampling.LANCZOS)
            canvas.paste(im,(i*cell,row*(cell+20)+20),im)
    canvas.save(dest)
def build():
    all_actions=actions()
    for tier in range(5):
        suffix='' if tier==0 else f'_armor_{tier}'
        sheet([(n,all_actions[n+suffix][0]) for n in ['idle','attack','hit','armor','defeat']],OUT/f'tier_{tier}_all_frames.png')
    sheet([('map_idle',all_actions['map_idle'][0])],OUT/'map_all_frames.png',128)
    small=Image.new('RGB',(650,280),'#21323b');draw=ImageDraw.Draw(small)
    for tier in range(5):
        name='idle' if tier==0 else f'idle_armor_{tier}'
        a=all_actions[name][0]
        draw.text((tier*130+4,5),f'DEF {14+tier*2}',fill='white')
        for row,size in enumerate([26,33,47]):
            im=Image.open(SRC/a['frames'][0]).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
            small.paste(im,(tier*130+30,row*80+25),im);draw.text((tier*130+4,row*80+35),str(size),fill='white')
    small.save(OUT/'five_tiers_effects_off_small.png')
    for tier in range(5):
        suffix='' if tier==0 else f'_armor_{tier}'
        miniature=Image.new('RGB',(564,1005),'#21323b');draw=ImageDraw.Draw(miniature)
        for scale_index,size in enumerate([26,33,47]):
            for action_index,name in enumerate(['idle','attack','hit','armor','defeat']):
                row=scale_index*5+action_index
                draw.text((2,row*67+2),f'{name} {size}px / body, FX off',fill='white')
                for index,path in enumerate(all_actions[name+suffix][0]['frames']):
                    im=Image.open(SRC/path).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
                    miniature.paste(im,(index*47+(47-size)//2,row*67+20),im)
        miniature.save(OUT/f'tier_{tier}_all_frames_26_33_47.png')
    map_small=Image.new('RGB',(564,201),'#21323b');draw=ImageDraw.Draw(map_small)
    for row,size in enumerate([26,33,47]):
        draw.text((2,row*67+2),f'map idle {size}px',fill='white')
        for index,path in enumerate(all_actions['map_idle'][0]['frames']):
            im=Image.open(SRC/path).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
            map_small.paste(im,(index*47+(47-size)//2,row*67+20),im)
    map_small.save(OUT/'map_all_frames_26_33_47.png')
    # Standalone preview uses exact hash query strings to defeat stale browser PNGs.
    data={n:{**a,'frames':[p+'?sha='+sha(SRC/p)[:12] for p in a['frames']],
        'combined_frames':[p+'?sha='+sha(SRC/p)[:12] for p in a.get('combined_frames',a['frames'])]} for n,(a,*_) in all_actions.items()}
    html='''<!doctype html><meta charset="utf-8"><title>魔像 v06</title><style>body{font:18px system-ui;background:#21323b;color:#eee6cf;margin:24px}button,select{font:inherit;padding:8px;margin:5px}#large{width:384px;height:384px}img{background:repeating-conic-gradient(#273e47 0% 25%,#34505b 0% 50%) 0/24px 24px}#small img{margin:12px}</style>
<h1>魔像 v06 · 五档含基础态</h1><p>防御14/16/18/20/22；实体胸领/肩甲/臂箍独立。两张新原图、189身体帧位，非189张新原画。human_signoff=false。</p>
<select id="action"></select><button id="play">暂停/播放</button><button id="restart">重播</button><button id="next">逐帧</button><select id="speed"><option value="1">原速</option><option value=".25">0.25倍</option></select><label><input id="fx" type="checkbox" checked>独立效果</label><p><input id="scrub" type="range"><span id="info"></span></p><img id="large"><div id="small"><img width="26"><img width="33"><img width="47"></div>
<script>const data=DATA;let t=0,playing=true,last=performance.now();const sel=document.querySelector('#action'),s=document.querySelector('#scrub');for(const id in data)sel.add(new Option(id,id));function draw(){const a=data[sel.value];let f=Math.floor(t*a.fps+.00001);f=a.loop?f%a.frames.length:Math.min(f,a.frames.length-1);for(const im of document.querySelectorAll('img'))im.src=(document.querySelector('#fx').checked?a.combined_frames:a.frames)[f];s.max=a.frames.length-1;s.value=f;document.querySelector('#info').textContent=`${sel.value} ${f+1}/${a.frames.length} ${a.fps}FPS`;}sel.onchange=()=>{t=0;draw()};document.querySelector('#play').onclick=()=>playing=!playing;document.querySelector('#restart').onclick=()=>{t=0;draw()};document.querySelector('#next').onclick=()=>{playing=false;t=((Number(s.value)+1)%data[sel.value].frames.length)/data[sel.value].fps;draw()};s.oninput=()=>{playing=false;t=Number(s.value)/data[sel.value].fps;draw()};document.querySelector('#fx').onchange=draw;function tick(now){if(playing)t+=(now-last)/1000*Number(document.querySelector('#speed').value);last=now;draw();requestAnimationFrame(tick)}draw();requestAnimationFrame(tick)</script>'''
    (SRC/'golem_review.html').write_text(html.replace('DATA',json.dumps(data)),encoding='utf-8')
    for p in (ROOT/'build/verification/phase3/08-parallel/golem_refine').glob('*draft_contact.png'):shutil.copyfile(p,OUT/p.name)
    # Ordered actual timed captures, one image per native action/speed, all samples.
    for mode in ['battle','map']:
        timing=OUT/'native'/mode/'timing.json'
        if not timing.exists():continue
        native=read(timing);groups={}
        for sample in native['observations']:groups.setdefault((sample['action'],sample['speed']),[]).append(sample)
        for (name,speed),samples in groups.items():
            canvas=Image.new('RGB',(len(samples)*96,116),'#21323b');draw=ImageDraw.Draw(canvas)
            for i,sample in enumerate(samples):
                im=Image.open(ROOT/sample['path'].replace('res://','')).convert('RGBA').resize((96,96),Image.Resampling.LANCZOS)
                canvas.paste(im,(i*96,20),im);draw.text((i*96,1),f'{sample["animation_seconds"]:.2f}s',fill='white')
            canvas.save(OUT/'native'/mode/f'{name}_{speed}_ordered.png')
        if mode=='battle':
            for tier in range(5):
                suffix='' if tier==0 else f'_armor_{tier}'
                grid=Image.new('RGB',(1152,1160),'#21323b')
                row=0
                for speed in [1.0,.25]:
                    for name in ['idle','attack','hit','armor','defeat']:
                        piece=Image.open(OUT/'native'/mode/f'{name+suffix}_{speed}_ordered.png')
                        grid.paste(piece,(0,row*116));row+=1
                grid.save(OUT/f'tier_{tier}_native_both_speeds.png')
    print('Review sheets and hash-bound playback page written; no approvals')
def record():
    all_actions=actions()
    assert (OUT/'native/battle/timing.json').exists() and (OUT/'native/map/timing.json').exists()
    review={'entity':'golem','date':'2026-10-02','human_signoff':False,
        'review_method':'all frame sheets, effects-off 26/33/47 silhouettes and actual native timed original/.25 samples; agent visual review',
        'actions':{}}
    for name,(a,d,draft,key) in all_actions.items():
        review['actions'][name]={'decision':'accepted','draft_manifest':draft,'source_action':key,
            'frame_slots':len(a['frames']),'frame_sha256':[sha(SRC/p) for p in a['frames']],
            'effects_sha256':[sha(SRC/p) for p in a.get('effects_frames',[])],
            'fps':a['fps'],'loop':a['loop'],'events':a['events'],'size':d['size'],'anchor':d['anchor'],
            'pose_holds':a.get('pose_holds',{}),'human_signoff':False}
    review['native_evidence_sha256']={mode:sha(OUT/'native'/mode/'timing.json') for mode in ['battle','map']}
    (SRC/'golem_publish_review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Explicit reviewed hashes recorded; no publication')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--record',action='store_true');args=p.parse_args()
    record() if args.record else build()
