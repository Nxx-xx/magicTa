extends SceneTree
## Packaging only: preserve generated alpha, fit transparent bounds and downsample.
const Registry = preload("res://scripts/ui/item_icon_registry.gd")
const SOURCE := "res://assets/items/source/painted_v02/"

func _initialize() -> void:
	var records: Array = []
	var items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json")).items
	items.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/phase3_items.json")).items)
	var paths: Dictionary = Registry.PATHS.duplicate()
	for id in ["salvage", "temper", "sacrifice"]:
		paths[id] = "res://assets/items/interactions/icons/" + id + ".png"
	for id in paths:
		var source := SOURCE + str(id) + ".png"
		var master := Image.load_from_file(source)
		assert(master != null and master.detect_alpha() != Image.ALPHA_NONE, "Missing generated alpha: " + str(id))
		master.convert(Image.FORMAT_RGBA8)
		var bounds := master.get_used_rect()
		var cropped := master.get_region(bounds)
		var ratio := 100.0 / maxf(bounds.size.x, bounds.size.y)
		cropped.resize(maxi(1,roundi(bounds.size.x*ratio)),maxi(1,roundi(bounds.size.y*ratio)),Image.INTERPOLATE_LANCZOS)
		var icon := Image.create(128,128,false,Image.FORMAT_RGBA8)
		icon.fill(Color.TRANSPARENT)
		icon.blit_rect(cropped,Rect2i(Vector2i.ZERO,cropped.get_size()),(Vector2i(128,128)-cropped.get_size())/2)
		assert(icon.save_png(paths[id]) == OK)
		records.append({"id":id,"icon":paths[id],"source":source,"source_sha256":FileAccess.get_sha256(source),"icon_sha256":FileAccess.get_sha256(paths[id]),"source_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"runtime_size":128,"safe_edge":14})
	var file := FileAccess.open("res://assets/items/painted_v02_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":2,"method":"built-in image_gen; Godot alpha-preserving fit and Lanczos downsample","assets":records},"  "))
	var item_records: Array = []
	var phase3_records: Array = []
	for row in records:
		if not items.has(row.id): continue
		var record: Dictionary = row.duplicate(true)
		record.name = items[row.id].name
		record.kind = items[row.id].kind
		record.retained = false
		item_records.append(record)
		if str(row.id).begins_with("p3_"): phase3_records.append(record)
	for category in ["unique", "phase3"]:
		var subset: Array = item_records if category == "unique" else phase3_records
		var target := FileAccess.open("res://assets/items/" + category + "/manifest.json",FileAccess.WRITE)
		target.store_string(JSON.stringify({"version":2,"method":"built-in image_gen painted_v02; original v01 manifests archived in source/baseline_v01", "assets":subset},"  "))
	print("ITEM_ICONS_V02: %d generated RGBA assets packaged" % records.size())
	quit()
