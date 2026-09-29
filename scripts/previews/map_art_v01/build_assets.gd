extends SceneTree

const ROOT = "res://assets/environment/tower_v01/"
const SIZE = 128
var manifest: Dictionary = {}

func _initialize() -> void:
	var terrain := Image.load_from_file(ROOT + "source/terrain_generated.png")
	var doors := Image.load_from_file(ROOT + "source/doors_generated.png")
	var props := Image.load_from_file(ROOT + "source/props_generated.png")
	var wall_master := Image.load_from_file(ROOT + "source/wall_master_generated.png")
	wall_master.convert(Image.FORMAT_RGBA8)
	for index in 4:
		var tile := terrain.get_region(Rect2i(4 + index * 314, 5, 302, 296))
		tile.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		# Edge clamp is a deterministic tile packing step; artwork is generated.
		tile.convert(Image.FORMAT_RGBA8)
		for y in SIZE:
			for x in SIZE:
				var c := tile.get_pixel(x, y)
				c.a = 1.0
				tile.set_pixel(x, y, c)
		_save("floor_%d" % index, tile)
	var face := wall_master.get_region(Rect2i(4, 618, 1244, 622))
	face.resize(128, 49, Image.INTERPOLATE_LANCZOS)
	var cap := wall_master.get_region(Rect2i(5, 4, 614, 606))
	cap.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	var atlas := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	for mask in 16:
		var tile := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		# NESW bit mask: all visible faces remain strictly inside the blocking cell.
		tile.blit_rect(cap, Rect2i(0, 0, 128, 128), Vector2i.ZERO)
		if not mask & 4:
			tile.blit_rect(face, Rect2i(0, 0, 128, 49), Vector2i(0, 79))
		for y in SIZE:
			for x in SIZE:
				var c := tile.get_pixel(x, y)
				c.a = 1.0
				if (not mask & 1 and y < 5) or (not mask & 8 and x < 5):
					c = c.lightened(0.13)
				if (not mask & 2 and x > 114) or (not mask & 8 and x < 10) or (not mask & 4 and y > 123):
					c = c.darkened(0.48)
				# Tiny transparent outer corners prevent a boxed silhouette on isolated ends.
				if (x < 2 or x > 125) and (y < 2 or y > 125) and mask != 15:
					c.a = 0.0
				tile.set_pixel(x, y, c)
		_save("wall_%02d" % mask, tile)
		atlas.blit_rect(tile, Rect2i(0, 0, 128, 128), Vector2i(mask % 4, mask / 4) * 128)

	atlas.save_png(ROOT + "textures/walls_atlas.png")
	for row in 2:
		for col in 3:
			var name := "door_%s_%s" % [["copper", "silver", "gold"][col], "closed" if row == 0 else "open"]
			var source := doors.get_region(Rect2i(col * 512, row * 512, 512, 512))
			_pack(name, source, 116)
	var names := ["key_copper", "key_silver", "key_gold", "chest", "potion", "stairs_up", "stairs_down", "torch", "banner", "rubble", "coins", "pillar"]
	for index in names.size():
		# Generated third row starts early; use inspected gutters instead of nominal thirds.
		var y0: int = [0, 341, 660][index / 4]
		var y1: int = [341, 660, 1024][index / 4]
		var source := props.get_region(Rect2i((index % 4) * 384, y0, 384, y1 - y0))
		_pack(names[index], source, 108 if index in [3, 5, 6] else 96)
	var resource := "[gd_resource type=\"TileSet\" load_steps=3 format=3]\n\n[ext_resource type=\"Texture2D\" path=\"res://assets/environment/tower_v01/textures/walls_atlas.png\" id=\"1\"]\n\n[sub_resource type=\"TileSetAtlasSource\" id=\"Atlas\"]\ntexture = ExtResource(\"1\")\ntexture_region_size = Vector2i(128, 128)\n"
	for mask in 16:
		resource += "%d:%d/0 = 0\n" % [mask % 4, mask / 4]
	resource += "\n[resource]\ntile_size = Vector2i(128, 128)\nsources/0 = SubResource(\"Atlas\")\n"
	FileAccess.open(ROOT + "walls_tileset.tres", FileAccess.WRITE).store_string(resource)
	FileAccess.open(ROOT + "asset_manifest.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	print("MAP_ART_ASSETS_OK: ", manifest.size(), " textures; 16 wall masks")
	quit()

func _pack(name: String, source: Image, extent: int) -> void:
	# Ignore vanishing generated halo only for determining trim bounds; retain original alpha.
	var bounds := Rect2i()
	var found := false
	for y in source.get_height():
		for x in source.get_width():
			if source.get_pixel(x, y).a > 0.45:
				if not found:
					bounds = Rect2i(x, y, 1, 1)
					found = true
				else:
					bounds = bounds.expand(Vector2i(x, y))
	bounds = bounds.grow(3).intersection(Rect2i(Vector2i.ZERO, source.get_size()))
	var cropped := source.get_region(bounds)
	var scale := float(extent) / maxf(cropped.get_width(), cropped.get_height())
	cropped.resize(maxi(1, roundi(cropped.get_width() * scale)), maxi(1, roundi(cropped.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	var tile := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	tile.blit_rect(cropped, Rect2i(Vector2i.ZERO, cropped.get_size()), Vector2i((SIZE - cropped.get_width()) / 2, (SIZE - cropped.get_height()) / 2))
	_save(name, tile)

func _save(name: String, tile: Image) -> void:
	tile.save_png(ROOT + "textures/" + name + ".png")
	manifest[name] = {"size": [128, 128], "anchor": [64, 64], "file": "textures/" + name + ".png"}
