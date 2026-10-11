"""Collect existing final verification results and link reviewable deliveries."""
import html
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/verification/phase3/08-parallel/coordinator'

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def href(path):
    return html.escape(os.path.relpath(path, OUT).replace('\\', '/'), quote=True)

labels = ['v05-final-import', 'v05-imported-production-test', 'v05-imported-runtime-ui', 'phase3_enemy_player_test', 'phase3_hero_map_test-render', 'phase3_ruin_art_test-render', 'phase3_replay_timing_test-render', 'phase3_animation_test_runner-render', 'phase3_ui_host_test_runner-render', 'walking-regression-fixed']
results = {}
for label in labels:
    files = sorted(OUT.glob(label + '-*-result.json'))
    assert files, label
    result = read(files[-1])
    assert result['exit_code'] == 0 and not any(result.get(k) for k in ['script_error', 'engine_error', 'timed_out']), label
    results[label] = files[-1].relative_to(ROOT).as_posix()
preserved = read(OUT / 'production-preservation.json')
assert not preserved['errors']
production = read(OUT / 'production-animation-results.json')
runtime = read(OUT / 'runtime/results.json')
assert production['failures'] == runtime['failures'] == 0
manifest = read(ROOT / 'assets/monsters/phase3/manifest.json')
accepted = {k:v for k,v in manifest['actions'].items() if v['status'] == 'accepted'}
assert len(accepted) == 70 and not manifest['missing_creatures']
report = dict(date='2026-10-02', batch_animation_complete=True, phase3_complete=False, human_signoff=False, accepted_actions=len(accepted), preservation=preserved, production_checks=production['checks'], runtime_checks=runtime['checks'], peak_unique_animation_image_data_bytes=runtime['peak_unique_decoded_animation_bytes'], final_runs=results, remaining=['hero/enemy final art refinement', 'golem five persistent armor idle stages', 'five human novice playtests', 'current Windows/WeChat packages and target-device acceptance'])
(OUT / 'final-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
rows = []
for category in ['battle', 'variants', 'map']:
    base = ROOT / 'assets/monsters/phase3/source/parallel_v05' / category
    for source in sorted(base.iterdir()):
        if not source.is_dir(): continue
        review = source / 'REVIEW.md'
        if not review.is_file(): continue
        matching = [(k,v) for k,v in accepted.items() if v.get('review') == review.relative_to(ROOT / 'assets/monsters/phase3').as_posix()]
        if not matching: continue
        body = sum(len(a['frames']) for _,a in matching)
        fx = sum(len(a.get('effects_frames', [])) for _,a in matching)
        coordinator = ROOT / matching[0][1]['coordinator_review']
        rows.append(f'<tr><td>{html.escape(source.name)}</td><td>{category}</td><td>{len(matching)}</td><td>{body} / {fx}</td><td><a href="{href(review)}">源与限制</a> · <a href="{href(coordinator)}">统筹精确审批</a></td></tr>')
page = f'''<!doctype html><html lang="zh"><meta charset="utf-8"><title>v05动画最终交付核对</title><style>body{{background:#12252e;color:#e6e7df;font:16px system-ui;max-width:1200px;margin:32px auto;padding:16px}}a{{color:#b5d7ed}}table{{border-collapse:collapse;width:100%}}td,th{{border-bottom:1px solid #456;padding:10px;text-align:left}}img{{max-width:100%}}</style><h1>本轮规定动画全部接入 · 2026-10-02</h1><p>七基础战斗、三变体五动作、十一独立地图待机已显式发布。新增54动作、246身体和140特效帧位。生产合计70动作、342身体和152特效帧位。</p><p>导入后1630生产检查、235界面/缓存检查零失败；压力夹具实际image data去重峰值40.69MiB。旧16动作、108纹理及6控制/规则文件保留。</p><p>第三阶段整体仍未完成：公主/魔像精修、真人试玩及目标客户端验收待完成。human_signoff=false；压力夹具为模拟内存战报，不冒充自然账户路线或设备验收。</p><p><a href="../../07-completion/animation-review.html">104条统一动画预览</a> · <a href="{href(ROOT/'docs/phase3/COMPLETION_FOLLOWUP.md')}">完整完成与剩余记录</a> · <a href="final-report.json">最终机器证据</a> · <a href="runtime/results.json">界面与缓存明细</a></p><table><tr><th>实体</th><th>源类别</th><th>动作数</th><th>身体 / 效果帧位</th><th>来源与审批</th></tr>{''.join(rows)}</table><h2>生产界面截图总览</h2><p>独立原始截图链接在runtime目录；此总览已由统筹查看。</p><a href="runtime/ui_contact_540.png"><img src="runtime/ui_contact_540.png" alt="13敌人540宽生产界面"></a><a href="runtime/ui_contact_320.png"><img src="runtime/ui_contact_320.png" alt="13敌人320宽生产界面"></a></html>'''
(OUT / 'index.html').write_text(page, encoding='utf-8')
print(json.dumps({k:report[k] for k in ['batch_animation_complete','phase3_complete','accepted_actions','production_checks','runtime_checks','peak_unique_animation_image_data_bytes']}))
