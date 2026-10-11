extends RefCounted
## Observe committed map snapshots only. Animation never consumes or resolves a ruin.
const ROOT := "res://assets/environment/ruins/phase3/"
const LIMIT := 6*1024*1024
var manifest: Dictionary = {}
var states: Dictionary = {}
var playing: Dictionary = {}
var cache: Dictionary = {}
var order: Array = []
var cache_bytes := 0

func _init() -> void:
	var path := ROOT+"runtime_v02.json"
	if not FileAccess.file_exists(path): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.get("version") == 2 and parsed.get("status") == "accepted" and parsed.get("ruins") is Dictionary:
		manifest = parsed

func observe(floor_map: Dictionary, same_floor: bool, seconds: float) -> Array:
	var events := []
	if not same_floor:
		states.clear()
		playing.clear()
	var next_states := {}
	for entity in floor_map.get("entities",{}).values():
		if not entity.has("ruin_id"): continue
		var id: String = entity.id
		var status: String = entity.get("status", "available")
		if same_floor and states.get(id) == "available" and status == "resolved":
			playing[id] = {"start":seconds,"option":str(entity.get("selected_option",""))}
			events.append(str(entity.ruin_id))
		next_states[id] = status
	states = next_states
	return events

func texture(entity: Dictionary, seconds: float, reduced: bool = false) -> Texture2D:
	var ruin: Dictionary = manifest.get("ruins",{}).get(entity.get("ruin_id",""),{})
	var actions: Dictionary = ruin.get("actions",{})
	var action := "spent" if entity.get("status") == "resolved" else "idle"
	var elapsed := seconds
	var id: String = entity.get("id", "")
	if playing.has(id):
		var replay: Dictionary = playing[id]
		var resolve := "resolve_"+str(replay.option)
		elapsed = maxf(0,seconds-float(replay.start))
		var definition: Dictionary = actions.get(resolve,{})
		if not reduced and not definition.is_empty() and elapsed < float(definition.frames.size())/float(definition.fps):
			action = resolve
		else:
			playing.erase(id)
	var definition: Dictionary = actions.get(action,{})
	if definition.is_empty() or not definition.get("frames") is Array or definition.frames.is_empty() or float(definition.get("fps",0)) <= 0: return null
	var index := 0 if reduced else int(elapsed*float(definition.fps))
	index = index%definition.frames.size() if definition.get("loop",false) else mini(index,definition.frames.size()-1)
	var path: String = definition.frames[index]
	if not path.begins_with(ROOT+"textures/v02/") or ".." in path: return null
	if cache.has(path):
		order.erase(path)
		order.append(path)
		return cache[path]
	var result: Texture2D
	if ResourceLoader.exists(path): result = load(path) as Texture2D
	if result == null and FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null and image.get_size() == Vector2i(256,256): result = ImageTexture.create_from_image(image)
	if result == null or result.get_size() != Vector2(256,256): return null
	if manifest.get("storage", "") == "shared-base-overlay-v1":
		# Compose once per cached frame. The 15 timelines still select all 75 frame slots.
		var base_path: String = ruin.get("base", "")
		if not base_path.begins_with(ROOT+"textures/v02/") or ".." in base_path: return null
		var base_image: Image
		if ResourceLoader.exists(base_path):
			var base_texture := load(base_path) as Texture2D
			if base_texture != null: base_image = base_texture.get_image()
		elif FileAccess.file_exists(base_path):
			base_image = Image.load_from_file(base_path)
		if base_image == null or base_image.get_size() != Vector2i(256,256): return null
		base_image.convert(Image.FORMAT_RGBA8)
		if action == "spent":
			var tint: Array = ruin.get("spent_tint", [0.48,0.54,0.60])
			for y in 256:
				for x in 256:
					var pixel := base_image.get_pixel(x,y)
					base_image.set_pixel(x,y,Color(pixel.r*float(tint[0]),pixel.g*float(tint[1]),pixel.b*float(tint[2]),pixel.a))
		var overlay := result.get_image()
		overlay.convert(Image.FORMAT_RGBA8)
		base_image.blend_rect(overlay,Rect2i(0,0,256,256),Vector2i.ZERO)
		result = ImageTexture.create_from_image(base_image)
	while cache_bytes+256*256*4 > LIMIT and not order.is_empty():
		cache.erase(order.pop_front())
		cache_bytes -= 256*256*4
	cache[path] = result
	order.append(path)
	cache_bytes += 256*256*4
	return result
