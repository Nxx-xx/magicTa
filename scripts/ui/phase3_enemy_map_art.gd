extends RefCounted
## Independent map-camera art. Metadata is cheap; decoded frames share one LRU.
const Catalog = preload("res://assets/monsters/phase3/phase3_enemy_animation_catalog.gd")
const FrameCache = preload("res://scripts/ui/phase3_enemy_player.gd")
var definitions := {}
var frames := FrameCache.new()

func _init() -> void:
	frames.max_cache_bytes = 4*1024*1024

func clear() -> void:
	definitions.clear()
	frames.release_frames()

func texture(enemy_id: String, seconds: float, reduced: bool = false) -> Texture2D:
	if not definitions.has(enemy_id):
		var described := Catalog.describe_action(enemy_id,"map_idle")
		definitions[enemy_id] = described.get("action",{})
	var action: Dictionary = definitions[enemy_id]
	if action.is_empty(): return null
	var index: int = 0 if reduced else int(maxf(0,seconds)*float(action.fps))%action.frames.size()
	return frames._texture(action,index)
