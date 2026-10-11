extends RefCounted
## Imported resources in exports; direct PNG decoding also supports isolated art review.
const ROOT := "res://assets/characters/hero/phase3/"
const DEFAULT_MANIFEST := ROOT + "manifest.json"
const DIRECTIONS := ["down", "left", "up", "right"]
const MAP_SPECS := {"idle": [4, 6, true], "walk": [6, 12, true], "interact": [4, 10, false]}
const COMBAT_SPECS := {"idle": [6, 6, true], "attack": [8, 16, false], "guard": [4, 12, false], "hit": [3, 12, false], "victory": [8, 12, false], "defeat": [6, 10, false]}
static var _runtime_manifest: Dictionary = {}
var manifest: Dictionary = {}
var _cache: Dictionary = {}
var _order: Array[String] = []
var cache_bytes := 0
var max_cache_bytes := 24 * 1024 * 1024
var effects_enabled := true:
	set(value):
		if effects_enabled != value:
			effects_enabled = value
			clear_cache()

static func read_manifest(path: String = DEFAULT_MANIFEST, check_files: bool = true) -> Dictionary:
	if not FileAccess.file_exists(path): return _error("Manifest missing: " + path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return _error("Manifest must be an object")
	var result := validate(parsed, false, check_files)
	if result.ok: result.manifest = parsed.duplicate(true)
	return result

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func specifications() -> Dictionary:
	var expected := {}
	for action in MAP_SPECS:
		for direction in DIRECTIONS:
			expected["map_" + action + "_" + direction] = {"count": MAP_SPECS[action][0], "fps": MAP_SPECS[action][1], "loop": MAP_SPECS[action][2], "size": [128, 128], "anchor": [64, 116]}
	for action in COMBAT_SPECS:
		expected["combat_" + action] = {"count": COMBAT_SPECS[action][0], "fps": COMBAT_SPECS[action][1], "loop": COMBAT_SPECS[action][2], "size": [384, 384], "anchor": [192, 348]}
	return expected

static func validate(data: Dictionary, require_complete: bool = false, check_files: bool = true) -> Dictionary:
	if data.get("version", 0) != 1 or not data.get("actions") is Dictionary:
		return _error("Invalid manifest version/actions")
	if data.get("handedness", "") != "right_sword_left_lantern" or data.get("mirrored", true) != false:
		return _error("Independent views and right sword / left lantern required")
	var expected := specifications()
	var missing: Array[String] = []
	var total_bytes := 0
	for key in expected:
		if not data.actions.has(key): missing.append(key)
	for key in data.actions:
		if not expected.has(key): return _error("Unknown action: " + str(key))
		var action: Variant = data.actions[key]
		var spec: Dictionary = expected[key]
		if not action is Dictionary or action.get("status", "") != "accepted": return _error("Unreviewed action: " + key)
		if action.get("fps") != spec.fps or action.get("loop") != spec.loop or not action.get("loop") is bool:
			return _error("FPS/loop mismatch: " + key)
		# JSON decodes numeric arrays as floats; compare validated coordinates.
		for field in ["size", "anchor"]:
			if not action.get(field) is Array or action[field].size() != 2: return _error("Size/anchor mismatch: " + key)
			for axis in 2:
				if not _integer(action[field][axis]) or int(action[field][axis]) != spec[field][axis]: return _error("Size/anchor mismatch: " + key)
		if not action.get("frames") is Array or action.frames.size() != spec.count: return _error("Frame count mismatch: " + key)
		if str(action.get("source", "")).is_empty() or str(action.get("review", "")).is_empty(): return _error("Source/review required: " + key)
		if not action.get("events", {}) is Dictionary: return _error("Invalid events: " + key)
		for event in action.get("events", {}):
			var at: Variant = action.events[event]
			if not _integer(at) or at < 0 or at >= spec.count: return _error("Event frame outside action: " + key)
		if key == "combat_attack" and action.get("events", {}).get("hit", -1) != 3: return _error("Attack hit must be frame 3")
		var holds: Variant = action.get("pose_holds", {})
		if not holds is Dictionary or holds.size() > 2 or (not holds.is_empty() and action.loop): return _error("Invalid authored pose holds: " + key)
		for held in holds:
			if not held is String or not held.is_valid_int() or str(int(held)) != held or not _integer(holds[held]) or int(held) <= int(holds[held]) or int(holds[held]) < 0 or int(held) >= action.frames.size(): return _error("Invalid pose hold index: " + key)
		var seen := {}
		var seen_pixels := {}
		for frame_index in action.frames.size():
			var frame: Variant = action.frames[frame_index]
			if not frame is String or not frame.begins_with(ROOT + "textures/") or ".." in frame or not frame.ends_with(".png"):
				return _error("Unsafe frame path: " + str(frame))
			if seen.has(frame): return _error("Duplicated frame reference: " + key)
			seen[frame] = true
			if check_files and not FileAccess.file_exists(frame) and not ResourceLoader.exists(frame): return _error("Missing frame: " + frame)
			if check_files:
				var image: Image
				if ResourceLoader.exists(frame):
					var texture := load(frame) as Texture2D
					if texture != null: image = texture.get_image()
				elif FileAccess.file_exists(frame): image = Image.load_from_file(frame)
				if image == null or image.is_empty(): return _error("Undecodable frame: " + frame)
				if image.get_size() != Vector2i(spec.size[0], spec.size[1]): return _error("Wrong frame dimensions: " + frame)
				if image.detect_alpha() == Image.ALPHA_NONE: return _error("Frame requires transparent background: " + frame)
				var hash_context := HashingContext.new()
				hash_context.start(HashingContext.HASH_SHA256)
				hash_context.update(image.get_data())
				var digest := hash_context.finish().hex_encode()
				if seen_pixels.has(digest):
					if int(holds.get(str(frame_index),-1)) != int(seen_pixels[digest]): return _error("Undeclared identical frame pixels: " + key)
				else:
					if holds.has(str(frame_index)): return _error("Pose hold differs from reference: " + key)
					seen_pixels[digest] = frame_index
			total_bytes += int(spec.size[0]) * int(spec.size[1]) * 4
		# v06 body and optional effects remain separate production assets.
		if action.has("effects_frames"):
			if not action.effects_frames is Array or action.effects_frames.size() != spec.count: return _error("Effect count mismatch: " + key)
			for path in action.effects_frames:
				if not path is String or not path.begins_with(ROOT + "textures/") or ".." in path or not path.ends_with(".png"): return _error("Unsafe effect path")
				if check_files:
					var texture := _read_texture(path)
					if texture == null or Vector2i(texture.get_size()) != Vector2i(spec.size[0],spec.size[1]): return _error("Missing/wrong effect: " + path)
	if require_complete and not missing.is_empty(): return _error("Incomplete actions: " + ", ".join(missing))
	return {"ok": true, "error": "", "missing_actions": missing, "decoded_bytes": total_bytes, "complete": missing.is_empty()}

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

func configure(data: Dictionary) -> Dictionary:
	var checked := validate(data)
	if not checked.ok: return checked
	clear_cache()
	manifest = data.duplicate(true)
	return checked

func configure_runtime() -> Dictionary:
	# Full pixel/alpha/hash validation belongs to the art checks, not encounter
	# creation. Keep only metadata shared; frames still load lazily into the LRU.
	if _runtime_manifest.is_empty():
		var loaded := read_manifest(DEFAULT_MANIFEST, false)
		if not loaded.ok: return loaded
		_runtime_manifest = loaded.manifest
	clear_cache()
	manifest = _runtime_manifest.duplicate(true)
	return {"ok": true, "error": ""}

func clear_cache() -> void:
	_cache.clear()
	_order.clear()
	cache_bytes = 0

func sprite_frames(action_id: String) -> Dictionary:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation(action_id)
	var action: Dictionary = manifest.get("actions", {}).get(action_id, {})
	if action.is_empty():
		var fallback := _fallback(action_id, "Action unavailable")
		if not fallback.ok: return fallback
		frames.add_frame(action_id, fallback.texture)
		frames.set_animation_speed(action_id, 1)
		frames.set_animation_loop(action_id, true)
		return {"ok": true, "error": "", "frames": frames, "fallback": true, "anchor": fallback.anchor}
	frames.set_animation_speed(action_id, action.fps)
	frames.set_animation_loop(action_id, action.loop)
	for index in action.frames.size():
		var frame := frame_at(action_id, float(index) / float(action.fps) + 0.000001)
		if frame.fallback: return _error("Cannot bake incomplete action: " + action_id)
		frames.add_frame(action_id, frame.texture)
	return {"ok": true, "error": "", "frames": frames, "fallback": false, "anchor": Vector2(action.anchor[0], action.anchor[1])}

func frame_at(action_id: String, seconds: float, reduced: bool = false) -> Dictionary:
	var actions: Dictionary = manifest.get("actions", {})
	if not actions.has(action_id): return _fallback(action_id, "Action unavailable")
	var action: Dictionary = actions[action_id]
	var index := 0
	if not reduced and is_finite(seconds):
		index = int(maxf(0.0, seconds) * float(action.fps))
		index = index % action.frames.size() if action.loop else mini(index, action.frames.size() - 1)
	var effect_path: String = action.get("effects_frames", [])[index] if effects_enabled and not reduced and action.has("effects_frames") else ""
	var loaded := _texture(action.frames[index], Vector2i(int(action.size[0]), int(action.size[1])), effect_path)
	if not loaded.ok: return _fallback(action_id, loaded.error)
	return {"ok": true, "error": "", "texture": loaded.texture, "frame": index, "anchor": Vector2(action.anchor[0], action.anchor[1]), "fallback": false, "label": ""}

func _fallback(action_id: String, reason: String) -> Dictionary:
	var direction := action_id.get_slice("_", 2)
	if not direction in DIRECTIONS: direction = "right"
	var path := "res://assets/characters/hero/textures/idle_" + direction + ".png"
	var loaded := _texture(path, Vector2i(128, 128))
	return {"ok": loaded.ok, "error": reason, "texture": loaded.get("texture"), "frame": 0, "anchor": Vector2(64, 116), "fallback": true, "label": "静态回退 · " + action_id}

static func _read_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null: return imported
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty(): return ImageTexture.create_from_image(image)
	return null

func _texture(path: String, expected_size: Vector2i, effect_path: String = "") -> Dictionary:
	var cache_key := path + ("|"+effect_path if not effect_path.is_empty() else "")
	if _cache.has(cache_key):
		_order.erase(cache_key)
		_order.append(cache_key)
		return {"ok": true, "texture": _cache[cache_key].texture}
	var texture := _read_texture(path)
	if texture == null: return _error("Texture unavailable: " + path)
	if Vector2i(texture.get_size()) != expected_size: return _error("Texture size mismatch: " + path)
	if not effect_path.is_empty():
		var effect := _read_texture(effect_path)
		# An absent optional effect must retain the reviewed body.
		if effect != null and Vector2i(effect.get_size()) == expected_size:
			var image := texture.get_image()
			image.convert(Image.FORMAT_RGBA8)
			var overlay := effect.get_image()
			overlay.convert(Image.FORMAT_RGBA8)
			image.blend_rect(overlay,Rect2i(Vector2i.ZERO,expected_size),Vector2i.ZERO)
			texture = ImageTexture.create_from_image(image)
	var cost := texture.get_image().get_data_size()
	while cache_bytes + cost > max_cache_bytes and not _order.is_empty():
		var oldest: String = _order.pop_front()
		cache_bytes -= int(_cache[oldest].bytes)
		_cache.erase(oldest)
	if cost <= max_cache_bytes:
		_cache[cache_key] = {"texture": texture, "bytes": cost}
		_order.append(cache_key)
		cache_bytes += cost
	return {"ok": true, "texture": texture}
