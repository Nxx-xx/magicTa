extends RefCounted
## Single resource map. Missing art falls back to the original semantic drawings.
const Keys = preload("res://scripts/core/map_keys.gd")
static var cache: Dictionary = {}
const VARIANT_BASE := {"p3_shield_sentinel":"sentinel", "p3_ember_channeler":"warlock", "p3_vault_knight":"knight"}
const VARIANT_BADGE := {"p3_shield_sentinel":"盾", "p3_ember_channeler":"焰", "p3_vault_knight":"伏"}

static func texture(path: String) -> Texture2D:
	if not cache.has(path):
		cache[path] = load(path) if ResourceLoader.exists(path) else null
		if cache[path] == null and path.begins_with("res://assets/items/") and FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			if image != null and not image.is_empty(): cache[path] = ImageTexture.create_from_image(image)
	return cache[path] as Texture2D

static func enemy_static(id: String) -> Texture2D:
	var base: String = VARIANT_BASE.get(id, id)
	return texture("res://assets/monsters/" + ("phase2" if base in ["berserker", "warden", "minotaur", "golem"] else "v01") + "/textures/" + base + ".png")

static func environment(id: String) -> Texture2D:
	return texture("res://assets/environment/tower_v01/textures/" + id + ".png")

static func hero(direction: String) -> Texture2D:
	return texture("res://assets/characters/hero/textures/" + "idle_" + direction + ".png")

static func entity_texture(entity: Dictionary) -> Texture2D:
	match str(entity.get("type", "")):
		"enemy":
			var id := str(entity.enemy_id)
			# Variant badge is drawn by MonsterArt, without modifying the board/hero path.
			if VARIANT_BASE.has(id): return null
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
		"shop": return texture("res://assets/characters/candlelight_merchant/textures/idle.png")
		"event":
			if not entity.has("ruin_id"):
				return texture("res://assets/environment/encounters_v01/event_relic.png")
		"rest": return texture("res://assets/environment/encounters_v01/rest_ember.png")
		"up": return environment("stairs_up")
		"down": return environment("stairs_down")
	return null
