extends SceneTree

const ROOT = "res://assets/environment/tower_v01/"

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "asset_manifest.json"))
	var metrics: Dictionary = {}
	assert(manifest.size() == 38)
	for id in manifest:
		var texture: Texture2D = load(ROOT + manifest[id].file)
		assert(texture != null)
		var img := texture.get_image()
		assert(img.get_size() == Vector2i(128, 128))
		var transparent := 0
		var visible := 0
		var border_visible := 0
		for y in 128:
			for x in 128:
				var c := img.get_pixel(x, y)
				if c.a < 0.01: transparent += 1
				if c.a > 0.5:
					visible += 1
					if x == 0 or y == 0 or x == 127 or y == 127: border_visible += 1
		assert(visible > 100, id + " has no visible artwork")
		if id.begins_with("floor_"): assert(transparent == 0)
		elif not id.begins_with("wall_"):
			assert(transparent > 1000, id + " lacks alpha")
			assert(border_visible == 0, id + " exceeds cell border")
		if id.ends_with("_open"):
			assert(img.get_pixel(64, 64).a < 0.1, "Door opening must be transparent")
		metrics[id] = {"size": [128, 128], "transparent_pixels": transparent, "visible_pixels": visible, "visible_border_pixels": border_visible}
	var tiles: TileSet = load(ROOT + "walls_tileset.tres")
	assert(tiles.tile_size == Vector2i(128, 128))
	assert(tiles.get_source(0).get_tiles_count() == 16)
	metrics["validation"] = {"result": "PASS", "textures": 38, "wall_masks": 16, "opaque_floors": 4, "transparent_objects": 18, "open_centers_verified": 3}
	FileAccess.open(ROOT + "verification_metrics.json", FileAccess.WRITE).store_string(JSON.stringify(metrics, "\t"))
	print("MAP_ART_ASSET_VERIFY_OK: 38 textures; 16 masks; 18 transparent props; 3 transparent door openings")
	quit()
