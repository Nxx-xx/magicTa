extends RefCounted
## Single resource map. Missing art falls back to the original semantic drawings.
const Keys = preload("res://scripts/core/map_keys.gd")
static var cache: Dictionary = {}

static func texture(path: String) -> Texture2D:
	if not cache.has(path):
		cache[path] = load(path) if ResourceLoader.exists(path) else null
	return cache[path] as Texture2D

static func environment(id: String) -> Texture2D:
	return texture("res://assets/environment/tower_v01/textures/" + id + ".png")

static func hero(direction: String) -> Texture2D:
	return texture("res://assets/characters/hero/textures/" + "idle_" + direction + ".png")

static func entity_texture(entity: Dictionary) -> Texture2D:
	match str(entity.get("type", "")):
		"enemy":
			var id := str(entity.enemy_id)
			if id in ["berserker", "warden", "minotaur", "golem"]:
				var campaign_art := texture("res://assets/monsters/phase2/textures/" + id + ".png")
				if campaign_art != null:
					return campaign_art
			return texture("res://assets/monsters/v01/textures/" + id + ".png")
		"door": return environment("door_" + Keys.kind(entity) + "_closed")
		"key": return environment("key_" + Keys.kind(entity))
		"chest", "choice": return environment("chest")
		"potion": return environment("potion")
		"gold": return environment("coins")
		"up": return environment("stairs_up")
		"down": return environment("stairs_down")
	return null
