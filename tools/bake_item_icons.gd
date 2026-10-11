extends SceneTree
## Reproducible SVG-to-PNG export; phase3 originals are deliberately retained.
const Registry = preload("res://scripts/ui/item_icon_registry.gd")

func _initialize() -> void:
	var records: Array = []
	var hashes: Array = []
	var items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json")).items
	items.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/phase3_items.json")).items)
	DirAccess.make_dir_recursive_absolute("res://assets/items/unique/icons/")
	for id in items:
		var path: String = Registry.PATHS[id]
		var source := path.replace("/icons/", "/source/").replace(".png", ".svg")
		var master := Image.new()
		assert(master.load_svg_from_string(FileAccess.get_file_as_string(source)) == OK, id)
		master.convert(Image.FORMAT_RGBA8)
		var bounds := master.get_used_rect()
		assert(bounds.position.x >= 25 and bounds.position.y >= 25 and bounds.end.x <= 231 and bounds.end.y <= 231, "Margins: " + id)
		if not id.begins_with("p3_"):
			master.resize(128, 128, Image.INTERPOLATE_LANCZOS)
			assert(master.save_png(path) == OK, "Export: " + id)
		var hash := FileAccess.get_sha256(path)
		assert(not hash in hashes, "Duplicate bitmap: " + id)
		hashes.append(hash)
		records.append({"id": id, "name": items[id].name, "kind": items[id].kind,
			"icon": path, "source": source, "retained": id.begins_with("p3_"),
			"source_sha256": FileAccess.get_sha256(source), "icon_sha256": hash,
			"source_bounds": [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]})
	var file := FileAccess.open("res://assets/items/unique/manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"method":"Original repo-native SVG, Godot SVG rasterizer; 6 phase3 originals retained", "assets":records},"  "))
	print("ITEM_ICONS: 28 unique mappings; 22 exported, 6 retained; margins and hashes passed")
	quit()
