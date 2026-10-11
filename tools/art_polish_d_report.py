"""D-owned source delta and review gallery. No image processing or export."""
from pathlib import Path
import difflib
import hashlib
import html
import json
import zlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/verification/art-polish-d"
RUNTIME = ["scripts/ui/map_screen.gd", "scripts/ui/main_menu.gd",
           "scripts/ui/story_intro_stage.gd", "scripts/ui/paged_catalog.gd",
           "scripts/ui/item_icon.gd", "scripts/ui/action_icon.gd",
           "scripts/ui/art_polish_d_frame.gd",
           "assets/ui/art_polish_d_v01/art_polish_d_theme.tres"]
patch, delta = [], 0
for file in RUNTIME:
    current = (ROOT / file).read_bytes()
    old_path = OUT / "baseline" / Path(file).name
    previous = old_path.read_bytes() if old_path.exists() else b""
    if file.endswith("paged_catalog.gd"):
        # This file's two-line pre-edit state is reconstructed explicitly.
        previous = current.decode().replace('\t\tbutton.theme_type_variation = "CatalogButton"\n', "").replace('12, Color("b7c6ca")', '11, Color("a8bcbf")').encode()
    delta += len(zlib.compress(current, 9)) - (len(zlib.compress(previous, 9)) if previous else 0)
    patch.extend(difflib.unified_diff(previous.decode().splitlines(True), current.decode().splitlines(True), fromfile=file+".before-D", tofile=file))
(OUT / "owned-changes.patch").write_text("".join(patch), encoding="utf-8")
report = {
    "version": "art_polish_d_v01", "status": "agent_reviewed", "human_signoff": False,
    "runtime": [{"path": f, "sha256": hashlib.sha256((ROOT/f).read_bytes()).hexdigest(), "bytes": (ROOT/f).stat().st_size} for f in RUNTIME],
    "baseline_captures": len(list((OUT/"before").glob("*.png"))),
    "final_captures": len(list((OUT/"after").glob("*.png"))),
    "sizes": [[320,640],[390,700],[540,960]],
    "source_deflate_estimate_bytes": delta,
    "estimate_limit": "Independent zlib source estimate, not actual WeChat ZIP delta. Old theme remains retained.",
    "new_raster_assets": 0, "wechat_export_performed": False, "device_verified": False,
    "review_notes": "Menu/HUD/guide/settings/shop/detail/inventory/confirmation/story inspected at phone widths. All 14 authored intro lines fit at all three sizes. Presentation only; shop is an explicit seeded visual fixture, not a natural playthrough."
}
(OUT/"art_polish_d_review.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
(OUT/"package-estimate.json").write_text(json.dumps({k: report[k] for k in ["source_deflate_estimate_bytes","estimate_limit","new_raster_assets","wechat_export_performed"]}, ensure_ascii=False, indent=2), encoding="utf-8")
parts = ['<!doctype html><meta charset="utf-8"><title>MagicTa D UI review</title><style>body{background:#0b151c;color:#e4e9e8;font:16px system-ui;margin:24px}a{color:#dfbf80}.row{display:flex;gap:20px;align-items:flex-start;flex-wrap:wrap}figure{margin:12px 0}img{max-width:320px;height:auto;border:1px solid #786c50}h2{margin-top:48px}</style><h1>D 组 UI 精修 · 实际 Godot 截图</h1><p>320 / 390 / 540 · seed 42 · 隔离存档；商店为明确视觉夹具。地图包含其他组共享制作进展。点击原图查看实际像素。</p>']
for name in ["menu","hud","hud_motion","guide","camp","settings","inventory","shop","shop_detail","confirmation","story","story_portrait","story_line7","story_line13"]:
    parts.append("<h2>"+html.escape(name)+"</h2><div class=row>")
    for width in [320,390,540]:
        for phase in ["before","after"]:
            f = f"{phase}/{name}_{width}.png"
            if not (OUT/f).exists(): continue
            parts.append(f'<figure><figcaption>{phase} · {width}</figcaption><a href="{f}"><img loading="lazy" src="{f}"></a></figure>')
    parts.append("</div>")
(OUT/"art_polish_d_review.html").write_text("".join(parts), encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
