extends RefCounted
const Combat = preload("res://scripts/core/phase3_combat.gd")
const DATA_PATH := "res://data/phase3_enemies.json"
const VARIANTS := {
	"p3_shield_sentinel": {"base": "sentinel", "ability": "p3_shield", "floors": [3, 4], "tier": 2},
	"p3_ember_channeler": {"base": "warlock", "ability": "p3_ember", "floors": [6, 7], "tier": 2},
	"p3_vault_knight": {"base": "knight", "ability": "p3_ambush", "floors": [8, 9], "tier": 3}
}

static func definitions() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("enemies") is Dictionary:
		return {"ok": false, "error": "invalid phase3_enemies.json envelope"}
	var validation := validate_definitions(parsed.enemies)
	return parsed.enemies.duplicate(true) if validation.ok else validation

static func validate_definitions(enemy_definitions: Dictionary) -> Dictionary:
	for id in enemy_definitions:
		if not VARIANTS.has(id) or not enemy_definitions[id] is Dictionary:
			return _error("unknown or malformed variant: " + str(id))
		var enemy: Dictionary = enemy_definitions[id]
		var spec: Dictionary = VARIANTS[id]
		if not Combat.valid_integer(enemy.get("gold_reward")):
			return _error(str(id) + ": missing or invalid gold_reward")
		var check := Combat.validate_inputs({"hp": 1}, enemy,
			{"attack": 1, "defense": 0, "max_hp": 1, "kill_heal": 0, "gold_bonus": 0})
		if not check.ok:
			return _error(str(id) + ": " + check.error)
		for field in ["name", "description", "combat_hint", "mechanic_badge"]:
			if not enemy.get(field) is String or enemy[field].is_empty():
				return _error(str(id) + ": missing " + field)
		if enemy.get("id") != id or enemy.get("rank") != "normal" or enemy.get("tier") != spec.tier or enemy.has("boss_floor"):
			return _error(str(id) + ": invalid identity/rank/tier")
		if enemy.get("ability_id") != spec.ability or enemy.get("base_enemy_id") != spec.base:
			return _error(str(id) + ": ability/base mismatch")
		if enemy.get("static_fallback_id") != spec.base or enemy.get("placement") != "optional_theme_branch" or enemy.get("max_per_run") != 1:
			return _error(str(id) + ": invalid placement/fallback/limit")
		var floors: Variant = enemy.get("variant_floors")
		if not floors is Array or floors.size() != 2:
			return _error(str(id) + ": variant_floors must contain the two allowed floors")
		for i in range(2):
			if not Combat.valid_integer(floors[i], 1, 10) or int(floors[i]) != spec.floors[i]:
				return _error(str(id) + ": wrong variant floor")
	return {"ok": true, "error": ""}

static func merge_content(content: Dictionary, enemy_definitions: Dictionary = {}) -> Dictionary:
	var defs := definitions() if enemy_definitions.is_empty() else enemy_definitions.duplicate(true)
	var validation := validate_definitions(defs)
	if not validation.ok:
		return validation
	if not content.get("enemies") is Dictionary:
		return _error("content.enemies must be a dictionary")
	var result := content.duplicate(true)
	for id in defs:
		if result.enemies.has(id) and result.enemies[id] != defs[id]:
			return _error("refusing to overwrite conflicting enemy snapshot: " + str(id))
		result.enemies[id] = defs[id].duplicate(true)
	return result

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
