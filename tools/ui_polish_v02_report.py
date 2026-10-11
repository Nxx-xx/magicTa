"""Generate an evidence gallery and scoped source diff; no production writes."""
from pathlib import Path
import difflib
import hashlib
import html
import json
import zlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/verification/ui-polish-v02'
EXISTING = ['scripts/ui/main_menu.gd', 'scripts/ui/map_screen.gd',
            'scripts/ui/paged_catalog.gd', 'scripts/ui/compact_screens.gd',
            'scripts/ui/action_choices.gd']
SNAPSHOTS = EXISTING + ['assets/ui/art_polish_d_v01/art_polish_d_theme.tres',
                       'scripts/ui/art_polish_d_frame.gd']
NEW = ['scripts/ui/ui_polish_surface.gd', 'assets/ui/ui_polish_v02/ui_polish_theme.tres']

def baseline(path):
    text = (OUT / 'baseline' / Path(path).name).read_text(encoding='utf-8-sig')
    for source in SNAPSHOTS:
        text = text.replace('res://build/verification/ui-polish-v02/baseline/' + Path(source).name,
                            'res://' + source)
    return text.rstrip() + '\n'

diff = []
delta = 0
files = []
for path in EXISTING + NEW:
    current = (ROOT / path).read_bytes()
    after = current.decode('utf-8-sig').replace('\r\n', '\n').rstrip() + '\n'
    before = baseline(path) if path in EXISTING else ''
    diff.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                   fromfile='before/' + path, tofile='after/' + path))
    delta += len(zlib.compress(after.encode(), 9)) - (len(zlib.compress(before.encode(), 9)) if before else 0)
    files.append({'path': path, 'bytes': len(current), 'sha256': hashlib.sha256(current).hexdigest()})
(OUT / 'ui-only.patch').write_text(''.join(diff), encoding='utf-8')
results = []
for path in sorted((ROOT / 'build/verification/phase3/08-parallel/ui-polish-v02').glob('*result.json')):
    results.append(json.loads(path.read_text(encoding='utf-8-sig')))
(OUT / 'review.json').write_text(json.dumps({'files': files, 'source_zlib_delta_bytes': delta,
    'new_raster_bytes': 0, 'export_measured': False, 'runs': results}, ensure_ascii=False, indent=2), encoding='utf-8')

names = {'menu': '主菜单', 'shop': '商店', 'shop_detail': '商品详情',
         'inventory': '空行囊', 'inventory_full': '满行囊', 'guide': '探索指引',
         'settings': '设置', 'confirmation': '长文本确认', 'hud': '底部工具栏'}
parts = ['''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>塔境 · 界面精修 v02</title>
<style>body{margin:0;background:#071317;color:#dfe5df;font:15px system-ui}main{max-width:1180px;margin:auto;padding:36px 24px}h1{color:#d9bd83;font-weight:500}p{color:#9db1b4;line-height:1.8}nav{display:flex;gap:12px;position:sticky;top:0;background:#071317ee;padding:16px 0;z-index:2}button{cursor:pointer;background:#122a31;color:#dfe5df;border:1px solid #345057;padding:12px 22px;border-radius:3px}button.active{background:#b49860;color:#071317}section{margin:32px 0 56px}h2{font-size:20px;font-weight:500;color:#c9b486}.pair{display:flex;gap:24px;align-items:flex-start;flex-wrap:wrap}figure{margin:0;flex:1;min-width:260px;max-width:540px}img{display:block;width:100%;height:auto;border-radius:4px}figcaption{padding:12px 0;color:#91a5a9}a{color:#dcc28f}.size{display:none}.size.active{display:block}</style>
<main><h1>塔境 · 界面精修 v02</h1><p>2026-10-04 · Godot 实际页面 · 左侧修改前，右侧修改后。三档手机宽度采用同一种 seed 42 测试夹具；商店与满行囊为注入样本，非通关记录。人物、塔内及物品素材由其他工作提供。</p>
<nav>''']
for width in (320, 390, 540):
    parts.append(f'<button class="{"active" if width == 390 else ""}" onclick="choose({width},this)">{width}px</button>')
parts.append('</nav>')
for width in (320, 390, 540):
    parts.append(f'<div class="size {"active" if width == 390 else ""}" id="w{width}">')
    for key, name in names.items():
        parts.append(f'<section><h2>{name}</h2><div class="pair">')
        for version, title in [('before', '修改前'), ('after', '修改后')]:
            source = f'{version}/{key}_{width}.png'
            if (OUT / source).exists():
                parts.append(f'<figure><figcaption>{title} · {width}px</figcaption><a href="{source}"><img loading="lazy" src="{source}" alt="{html.escape(name)} {title}"></a></figure>')
        parts.append('</div></section>')
    parts.append('</div>')
parts.append('''<p>可操作入口：tools/ui_polish_v02_verify.ps1 -Play；商店样板追加 -Screen shop，行囊样板追加 -Screen inventory。存档隔离，未导出或发布微信包。</p></main>
<script>function choose(w,b){document.querySelectorAll('.size,nav button').forEach(e=>e.classList.remove('active'));document.getElementById('w'+w).classList.add('active');b.classList.add('active')}</script></html>''')
(OUT / 'review.html').write_text(''.join(parts), encoding='utf-8')
print(f'UI source zlib estimate: {delta} bytes; {len(results)} logged runs; gallery {OUT / "review.html"}')
