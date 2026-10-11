extends RefCounted
## Explicit draft opt-in. Never silently promotes generated art into production.
const ROOT := "res://assets/monsters/phase3/"
const FALLBACKS := {"p3_shield_sentinel": "sentinel", "p3_ember_channeler": "warlock", "p3_vault_knight": "knight"}
static var _manifest: Dictionary = {}

static func _read_manifest() -> Dictionary:
	# One metadata snapshot per run; never retain decoded animation frames here.
	if _manifest.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
		if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("actions") is Dictionary:
			return {}
		_manifest = parsed
	return _manifest

static func static_fallback(enemy_id: String) -> Dictionary:
	var base: String = FALLBACKS.get(enemy_id, enemy_id)
	if base not in ["slime", "skeleton", "bat", "sentinel", "warlock", "knight", "berserker", "warden", "minotaur", "golem"]:
		return _error("unknown enemy static fallback: " + enemy_id)
	var folder := "phase2" if base in ["berserker", "warden", "minotaur", "golem"] else "v01"
	return {"ok": true, "error": "", "path": "res://assets/monsters/%s/textures/%s.png" % [folder, base],
		"anchor": Vector2(128, 224), "status": "static_fallback", "requires_mechanic_badge": FALLBACKS.has(enemy_id)}

static func load_action(enemy_id: String, action_id: String, allow_drafts: bool = false) -> Dictionary:
	var metadata := describe_action(enemy_id, action_id, allow_drafts)
	if not metadata.ok: return metadata
	var action: Dictionary = metadata.action
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation(action_id)
	frames.set_animation_speed(action_id, float(action.fps))
	frames.set_animation_loop(action_id, bool(action.loop))
	for index in action.frames.size():
		var texture := load_frame(action, index)
		if texture == null: return _error("missing or wrong-size frame: " + str(action.frames[index]))
		frames.add_frame(action_id, texture)
	return {"ok": true, "error": "", "sprite_frames": frames, "animation": action_id,
		"anchor": Vector2(action.anchor[0], action.anchor[1]), "status": action.status,
		"events": action.get("events", {}).duplicate(true)}

static func describe_action(enemy_id: String, action_id: String, allow_drafts: bool = false) -> Dictionary:
	# Metadata only: gameplay must not decode an entire boss to select one frame.
	var manifest := _read_manifest()
	if manifest.is_empty():
		return _error("invalid enemy animation manifest")
	var key := enemy_id + "_" + action_id
	if not manifest.actions.has(key):
		return _error("action unavailable: " + key)
	var action: Dictionary = manifest.actions[key]
	if action.get("status") != "accepted" and not allow_drafts:
		return _error("action is DRAFT; explicit preview opt-in required: " + key)
	if not action.get("frames") is Array or action.frames.is_empty():
		return _error("empty action frames")
	if not action.get("size") is Array or action.size.size() != 2 or float(action.get("fps",0)) <= 0:
		return _error("invalid action dimensions or timing")
	if not action.get("anchor") is Array or action.anchor.size() != 2 or not action.get("loop") is bool or not action.get("events",{}) is Dictionary:
		return _error("invalid action registration")
	for dimension in action.size:
		if not (dimension is int or dimension is float) or float(dimension) <= 0 or float(dimension) > 2048:
			return _error("invalid frame dimensions")
	for channel in ["frames","effects_frames"]:
		if channel == "effects_frames" and not action.has(channel): continue
		if not action[channel] is Array or action[channel].size() != action.frames.size():
			return _error("mismatched effect timeline")
		for path in action[channel]:
			if not path is String or not path.begins_with(ROOT + "textures/") or ".." in path or not path.ends_with(".png"):
				return _error("invalid frame path")
	return {"ok":true, "action":action.duplicate(true)}

static func load_frame(action: Dictionary, index: int) -> Texture2D:
	if index < 0 or index >= action.frames.size(): return null
	var path: String = action.frames[index]
	var texture: Texture2D
	if ResourceLoader.exists(path):
		texture = ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if texture == null and FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty(): texture = ImageTexture.create_from_image(image)
	if texture == null or texture.get_width() != int(action.size[0]) or texture.get_height() != int(action.size[1]): return null
	return texture

static func stone_armor_design() -> Dictionary:
	# Lightweight metadata, never preloads the five full state atlases.
	var manifest := _read_manifest()
	if manifest.is_empty(): return {}
	var design: Variant = manifest.get("golem_stone_armor", {})
	if not design is Dictionary or design.get("includes_base") != true or design.get("reachable_enhancements") != 4:
		return {}
	return design.duplicate(true)

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
