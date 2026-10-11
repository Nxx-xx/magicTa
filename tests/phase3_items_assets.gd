extends SceneTree
## Deterministic raster export of the repo-native vector icons; no editor import.
const Items = preload("res://scripts/core/phase3_items.gd")
const ROOT := "res://assets/items/phase3/"
const EVIDENCE := "res://build/verification/phase3/01-items/"

func _initialize() -> void:
	for folder in ["masters", "icons"]:
		DirAccess.make_dir_recursive_absolute(ROOT + folder)
	var sheet := Image.create(960, 392, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("182638"))
	var light := Image.create(960, 392, false, Image.FORMAT_RGBA8)
	light.fill(Color("e9e1d1"))
	var records: Array = []
	for index in Items.UNIQUE_IDS.size():
		var id: String = Items.UNIQUE_IDS[index]
		var source := ROOT + "source/" + id + ".svg"
		var master := Image.new()
		if master.load_svg_from_string(FileAccess.get_file_as_string(source)) != OK:
			push_error("SVG export failed: " + id)
			quit(1)
			return
		master.convert(Image.FORMAT_RGBA8)
		var bounds := master.get_used_rect()
		if bounds.position.x < 30 or bounds.position.y < 30 or bounds.end.x > 226 or bounds.end.y > 226:
			push_error("Unsafe icon margin: " + id)
			quit(1)
			return
		master.save_png(ROOT + "masters/" + id + "_256.png")
		var icon := master.duplicate()
		icon.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		icon.save_png(ROOT + "icons/" + id + ".png")
		var small := master.duplicate()
		small.resize(32, 32, Image.INTERPOLATE_LANCZOS)
		for canvas in [sheet, light]:
			canvas.blend_rect(icon, Rect2i(0, 0, 128, 128), Vector2i(index * 160 + 16, 16))
			canvas.blend_rect(small, Rect2i(0, 0, 32, 32), Vector2i(index * 160 + 64, 160))
			var zoom := small.duplicate()
			zoom.resize(128, 128, Image.INTERPOLATE_NEAREST)
			canvas.blend_rect(zoom, Rect2i(0, 0, 128, 128), Vector2i(index * 160 + 16, 224))
		records.append({"id": id, "master_size": [256, 256], "icon_size": [128, 128],
			"rgba": master.get_format() == Image.FORMAT_RGBA8, "transparent": master.get_pixel(0, 0).a == 0,
			"bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
			"source_sha256": FileAccess.get_sha256(source),
			"master_sha256": FileAccess.get_sha256(ROOT + "masters/" + id + "_256.png"),
			"icon_sha256": FileAccess.get_sha256(ROOT + "icons/" + id + ".png")})
	sheet.save_png(EVIDENCE + "icons-dark.png")
	light.save_png(EVIDENCE + "icons-light.png")
	var report := FileAccess.open(ROOT + "manifest.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"version": 1, "source": "Original repo-native SVG by Codex, 2026-10-01", "assets": records}, "  "))
	print("Phase3 icons: 6 vector sources exported; RGBA and 12% margins checked")
	quit()
