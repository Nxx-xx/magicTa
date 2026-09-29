extends SceneTree
## Technical alpha-preserving canvas normalization only; no generated art is painted here.
const ROOT := "res://assets/monsters/v01/"
const SPECS := {
	"slime": Vector2i(158, 116), "skeleton": Vector2i(180, 204),
	"bat": Vector2i(208, 156), "sentinel": Vector2i(218, 204),
	"knight": Vector2i(204, 212), "warlock": Vector2i(172, 202)
}

func _initialize() -> void:
	var manifest := {}
	var report := {}
	for id in SPECS:
		var source := Image.load_from_file(ROOT + "source/" + id + "_generated.png")
		assert(source != null and not source.is_empty())
		source.convert(Image.FORMAT_RGBA8)
		var min_at := Vector2i(source.get_width(), source.get_height())
		var max_at := Vector2i.ZERO
		for y in source.get_height():
			for x in source.get_width():
				if source.get_pixel(x, y).a > 0.05:
					min_at = min_at.min(Vector2i(x, y))
					max_at = max_at.max(Vector2i(x, y))
		# Generator contains almost invisible alpha specks in otherwise empty margins.
		# Find visible body bounds, retain four source pixels of antialiased fringe.
		var visible := Rect2i(min_at, max_at - min_at + Vector2i.ONE)
		assert(min_at.x > 4 and min_at.y > 4)
		assert(max_at.x < source.get_width() - 5 and max_at.y < source.get_height() - 5)
		var bounds := visible.grow(4)
		print(id, " visible bounds ", visible, " source ", source.get_size())
		var sprite := source.get_region(bounds)
		var limit: Vector2i = SPECS[id]
		var ratio := minf(float(limit.x) / bounds.size.x, float(limit.y) / bounds.size.y)
		var extent := Vector2i(roundi(bounds.size.x * ratio), roundi(bounds.size.y * ratio))
		# Mip-like area averaging retains native alpha; no background keying or edge repaint.
		sprite.resize(extent.x, extent.y, Image.INTERPOLATE_LANCZOS)
		var canvas := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		var baseline := 190 if id == "bat" else 224
		var at := Vector2i((256 - extent.x) / 2, baseline - extent.y)
		canvas.blit_rect(sprite, Rect2i(Vector2i.ZERO, extent), at)
		assert(canvas.save_png(ROOT + "textures/" + id + ".png") == OK)
		var clear := 0
		var partial := 0
		var solid := 0
		for y in 256:
			for x in 256:
				var a := canvas.get_pixel(x, y).a
				if a == 0.0: clear += 1
				elif a == 1.0: solid += 1
				else: partial += 1
				if x == 0 or y == 0 or x == 255 or y == 255: assert(a == 0.0)
		assert(clear > 10000 and partial > 0 and solid > 100)
		manifest[id] = {
			"file": "textures/" + id + ".png", "canvas": [256, 256],
			"ground_anchor": [128, 224], "normalized_ground_anchor": [0.5, 0.875],
			"visible_rect": [at.x, at.y, extent.x, extent.y],
			"hover_lift": 34 if id == "bat" else 0,
			"map_draw": "one square canvas per cell; linear mipmap filtering; no upscaling beyond cell",
			"random_pool_active": id != "warlock"
		}
		report[id] = {
			"source_size": [source.get_width(), source.get_height()],
			"source_alpha_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
			"trim_threshold_alpha": 0.05, "retained_fringe_source_pixels": 4,
			"transparent_pixels": clear, "partial_alpha_pixels": partial, "opaque_pixels": solid,
			"all_canvas_edges_transparent": true, "no_source_clipping": true
		}
	FileAccess.open(ROOT + "asset_manifest.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	FileAccess.open(ROOT + "previews/alpha_report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("MONSTER_PACK_OK six RGBA 256x256 textures; native alpha retained; edges clear")
	quit()
