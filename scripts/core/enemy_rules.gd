class_name EnemyRules
extends RefCounted
## Identity and progression belong to content; a guardian is a map role.
const RANK_NAMES := {"normal": "普通", "elite": "精英", "boss": "Boss"}
const TIER_NAMES := {1: "Ⅰ档 · 入门", 2: "Ⅱ档 · 进阶", 3: "Ⅲ档 · 高阶"}
const THEME_COUNTS := {"entrance": 2, "battle": 3, "treasure": 1, "shop": 2}
const ROLE_TIERS := {
	"small_fight_gate": [1], "gold_fight_gate": [1],
	"weapon_trial_gate": [1], "relic_fight_gate": [1, 2], "return_guard_gate": [3]
}

static func valid_definition(enemy: Dictionary) -> bool:
	var rank := str(enemy.get("rank", ""))
	if not RANK_NAMES.has(rank) or str(enemy.get("combat_hint", "")).is_empty():
		return false
	if rank == "boss":
		return _valid_integer(enemy.get("boss_floor", 0), [5, 10]) and not enemy.has("tier")
	return _valid_integer(enemy.get("tier", 0), [1, 2, 3]) and not enemy.has("boss_floor")

static func _valid_integer(value: Variant, allowed: Array) -> bool:
	# JSON numbers are floats; Array.has uses strict Variant types.
	return (value is int or value is float) and value == int(value) and int(value) in allowed

static func classification(enemy: Dictionary) -> String:
	var rank := str(enemy.get("rank", "normal"))
	if rank == "boss":
		return "Boss · 第 %d 层" % int(enemy.get("boss_floor", 0))
	return "%s · %s" % [RANK_NAMES.get(rank, "未知"), TIER_NAMES.get(int(enemy.get("tier", 1)), "未知档次")]

static func map_role(entity: Dictionary) -> String:
	if entity.get("campaign_boss", false):
		return "楼层首领"
	if entity.get("guardian", false):
		return "回溯守卫"
	match str(entity.get("role", "")):
		"weapon_trial_gate": return "成长守卫"
		"small_fight_gate", "gold_fight_gate": return "金币守卫"
		"relic_fight_gate": return "遗物守卫"
	return "支路守卫"

static func badge(enemy: Dictionary, entity: Dictionary) -> String:
	if str(enemy.get("rank", "")) == "boss":
		return "王"
	if str(enemy.get("rank", "")) == "elite":
		return "精"
	if entity.get("guardian", false):
		return "回"
	return str(int(enemy.get("tier", 1)))

static func valid_placement(enemy: Dictionary, entity: Dictionary) -> bool:
	# Current two-floor contract. Boss/elite floors will need their own rules.
	var role := str(entity.get("role", ""))
	if not valid_definition(enemy) or enemy.rank != "normal" or not ROLE_TIERS.has(role):
		return false
	if int(enemy.tier) not in ROLE_TIERS[role]:
		return false
	if bool(entity.get("guardian", false)) != (role == "return_guard_gate"):
		return false
	if role == "return_guard_gate":
		return enemy.id == "knight"
	if role == "weapon_trial_gate":
		return enemy.id == "slime"
	return true
