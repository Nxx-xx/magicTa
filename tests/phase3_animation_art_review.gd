extends SceneTree
## Deterministic review only: equal-cell slicing, no repaint, mirroring or pose deformation.
const SOURCE := "res://assets/characters/hero/phase3/source/"
const OUTPUT := "res://build/verification/phase3/05-animation/"
const SHEETS := [
	{"file": "walk_four_views_v01_rejected.png", "cols": 6, "rows": 4, "count": 24, "fps": 12},
	{"file": "walk_right_v02_rejected.png", "cols": 6, "rows": 1, "count": 6, "fps": 12},
	{"file": "combat_v01_draft.png", "cols": 4, "rows": 3, "count": 11, "fps": 16}
]

func _initialize() -> void:
	if not "05-animation" in OS.get_environment("APPDATA"):
		push_error("Isolated APPDATA required")
		quit(1)
		return
	var results: Array[Dictionary] = []
	for sheet in SHEETS:
		var source := Image.load_from_file(SOURCE + sheet.file)
		if source == null:
			push_error("Missing source " + sheet.file)
			quit(1)
			return
		var frames: Array[Dictionary] = []
		for index in sheet.count:
			var col: int = index % sheet.cols
			var row: int = index / sheet.cols
			var x0 := int(round(float(col) * source.get_width() / sheet.cols))
			var y0 := int(round(float(row) * source.get_height() / sheet.rows))
			var x1 := int(round(float(col + 1) * source.get_width() / sheet.cols))
			var y1 := int(round(float(row + 1) * source.get_height() / sheet.rows))
			var crop := source.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
			var path: String = sheet.file.get_basename() + "_%02d.png" % index
			crop.save_png(OUTPUT + path)
			var transparent := 0
			var border_alpha := 0
			for y in crop.get_height():
				for x in crop.get_width():
					if crop.get_pixel(x, y).a < 0.01: transparent += 1
					elif x == 0 or y == 0 or x == crop.get_width() - 1 or y == crop.get_height() - 1: border_alpha += 1
			frames.append({"file": path, "index": index, "size": [crop.get_width(), crop.get_height()], "alpha_empty_pixels": transparent, "border_nontransparent_pixels": border_alpha, "sha256": FileAccess.get_sha256(OUTPUT + path)})
		results.append({"file": sheet.file, "size": [source.get_width(), source.get_height()], "sha256": FileAccess.get_sha256(SOURCE + sheet.file), "frames": frames, "fps": sheet.fps, "cols": sheet.cols, "rows": sheet.rows})
	var json := FileAccess.open(OUTPUT + "art_metrics.json", FileAccess.WRITE)
	json.store_string(JSON.stringify(results, "\t"))
	var html := FileAccess.open(OUTPUT + "art_review.html", FileAccess.WRITE)
	html.store_string("""<!doctype html><meta charset="utf-8"><title>Phase 3 · 草稿逐帧审查</title>
<style>body{font:16px system-ui;background:#102330;color:#edf4f3;margin:24px}button,input{font:inherit;padding:8px}section{border:1px solid #527d81;padding:16px;margin:20px 0}.frames{display:flex;flex-wrap:wrap;gap:8px}.cell{background:repeating-conic-gradient(#adc1bf 0 25%,#657977 0 50%) 0/20px 20px}.frame{width:128px;height:128px;object-fit:contain}figure{margin:0}figcaption{font-size:12px}.preview{display:flex;gap:28px;align-items:end;margin:12px 0}.big{width:256px;height:256px;object-fit:contain}.small{object-fit:contain}.warn{color:#ffd09d}</style>
<h1>⑤ 新生成草稿 · 未进入正式 manifest</h1><p class="warn">本页只切分原始图格，保留比例和单元内位置，不重绘、不对齐掩盖漂移、不镜像。播放器并不代表动画验收通过。</p>
<p>四向 v01：腿序重复、图格边界有非透明像素。右向 v02：0/3 接触姿势仍疑似同一近腿领先；拒收。战斗 v01：有独立攻击/受击姿势，但跨格武器、基线与比例尚未通过；草稿。原始 PNG 含真实 alpha；不得根据工具缩略图背景判断为不透明。</p>
<button onclick="playing=!playing">播放 / 暂停</button> <button onclick="tick()">逐帧</button> <label>速度 <input id="speed" type="range" min="0.1" max="1" value="1" step="0.1"></label>
<main id="root"></main><script>const sheets=""")
	html.store_string(JSON.stringify(results))
	html.store_string(""";let playing=true;const groups=[];
for(const s of sheets){const clips=s.rows===4?[[0,6,'下',12],[6,6,'左',12],[12,6,'上',12],[18,6,'右',12]]:s.rows===3?[[0,8,'攻击',16],[8,3,'受击',12]]:[[0,6,'右',12]];
for(const [offset,count,label,fps] of clips){const el=document.createElement('section');el.innerHTML='<h2>'+s.file+' · '+label+'</h2><p>原图 '+s.size.join('×')+' · '+fps+' FPS；图格按原比例缩放。</p>';const previews=document.createElement('div');previews.className='preview';const active=[];
for(const size of [256,47,33,26]){const wrap=document.createElement('div');wrap.textContent=size+'px ';const im=document.createElement('img');im.className='cell';im.style.cssText='display:block;object-fit:contain;width:'+size+'px;height:'+size+'px';wrap.append(im);previews.append(wrap);active.push(im)}el.append(previews);groups.push({s,active,offset,count,fps,index:0,last:0});const row=document.createElement('div');row.className='frames';for(const f of s.frames.slice(offset,offset+count)){const fig=document.createElement('figure');fig.innerHTML='<img class="frame cell" src="'+f.file+'"><figcaption>'+f.index+' · 边界像素 '+f.border_nontransparent_pixels+'</figcaption>';row.append(fig)}el.append(row);root.append(el)}}
function paint(g){for(const im of g.active)im.src=g.s.frames[g.offset+g.index%g.count].file}function tick(){for(const g of groups){g.index++;paint(g)}}
function loop(t){for(const g of groups){if(playing&&t-g.last>1000/(g.fps*Number(speed.value))){g.index++;paint(g);g.last=t}}requestAnimationFrame(loop)}groups.forEach(paint);requestAnimationFrame(loop);</script>""")
	print("Art review exported: 41 raw cells, no accepted animation assets.")
	quit()
