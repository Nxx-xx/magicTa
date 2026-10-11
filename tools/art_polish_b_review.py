"""Build local review UI; --accept records the agent's completed visual review."""
import argparse,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification/art-polish-b'
SRC=ROOT/'assets/monsters/phase3/source/art_polish_b_v07'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--accept',action='store_true');args=parser.parse_args()
    candidate=ROOT/'assets/monsters/phase3/art_polish_b_candidate.json';new=read(candidate);old=read(OUT/'baseline-manifest.json')
    data={k:{'before':old['actions'][k],'after':a} for k,a in new['actions'].items() if a['status']=='draft'}
    page='''<!doctype html><meta charset="utf-8"><title>B enemy polish review</title>
<style>body{background:#18252d;color:#dfded1;font:16px system-ui;max-width:1100px;margin:24px auto}button,select{padding:10px;background:#263942;color:#eee;border:1px solid #6b7777}figure{display:inline-block;margin:12px}.actor{position:relative;width:256px;height:256px}.actor img{position:absolute;inset:0;width:100%;height:100%}aside{display:flex;gap:20px;align-items:end}a{color:#e5c282}</style>
<h1>B 组：13 敌人原生部件精修候选</h1><p>正式清单未发布；旧 / v07。所有动作事件与时序保留。静态逐帧＋native 定时采样复核，非真人签收。</p>
<select id="action"></select><button onclick="speed=1">原速</button><button onclick="speed=.25">0.25 倍</button><button onclick="paused=!paused">暂停</button><button onclick="paused=true;frame++">下一帧</button><button onclick="frame=0;t=0">重播</button><label><input id="fx" type="checkbox" checked>效果</label><label><input id="reduced" type="checkbox">稳态</label><p id="info"></p><div id="view"></div><aside id="small"></aside>
<p><a href="after/ui_contact_320.png">320 实际回放</a> · <a href="after/ui_contact_390.png">390 实际回放</a> · <a href="after/ui_contact_540.png">540 实际回放</a> · <a href="battle_comparison.png">战斗对比</a> · <a href="map_comparison.png">地图对比</a></p>
<script>const data=DATA;let speed=1,paused=false,frame=0,t=0,last=performance.now();const select=document.querySelector('#action');for(const k of Object.keys(data)){const o=document.createElement('option');o.textContent=k;select.append(o)}select.value='warlock_attack';select.onchange=()=>{t=0;frame=0};function src(p){return '../../../'+p.replace('res://','')}function render(now){if(!paused)t+=(now-last)/1000*speed;last=now;let entry=data[select.value],a=entry.after,i=document.querySelector('#reduced').checked?0:paused?frame%a.frames.length:Math.floor(t*a.fps)%a.frames.length;document.querySelector('#info').textContent=select.value+' — '+i+'/'+(a.frames.length-1)+' · '+a.fps+' FPS · events '+JSON.stringify(a.events);document.querySelector('#view').innerHTML=['before','after'].map(k=>{let x=entry[k];return '<figure><figcaption>'+k+'</figcaption><div class="actor"><img src="'+src(x.frames[i])+'">'+(document.querySelector('#fx').checked&&x.effects_frames&&!document.querySelector('#reduced').checked?'<img src="'+src(x.effects_frames[i])+'">':'')+'</div></figure>'}).join('');document.querySelector('#small').innerHTML=[26,33,47].map(n=>'<span>'+n+'px <img width="'+n+'" height="'+n+'" src="'+src(a.frames[i])+'"></span>').join('');requestAnimationFrame(render)}requestAnimationFrame(render);</script>'''
    (OUT/'review.html').write_text(page.replace('DATA',json.dumps(data,ensure_ascii=False)),encoding='utf8')
    if args.accept:
        native={p.relative_to(ROOT).as_posix():sha(p) for p in (OUT/'native').glob('*/timing.json')}
        assert len(native)==26
        review={'decision':'accepted','reviewer_role':'producer_b','human_signoff':False,'candidate_sha256':sha(candidate),'review_method':'Agent inspected every exact-frame action sheet, all 90 native original/quarter-speed action sample rows, 26/33/47px comparisons and actual 320/390/540 runtime/map captures. Timed sampling is not continuous video perception or human signoff.','approved_actions':sorted(data),'native_evidence_sha256':native,'remaining':'Independent coordinator exact-SHA publication, combined export and target client/device acceptance.'}
        (SRC/'art_polish_b_publish_review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print('Review HTML written'+('; explicit producer visual approval recorded' if args.accept else '; no approval written'))
if __name__=='__main__':main()
