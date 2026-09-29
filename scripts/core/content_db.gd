class_name ContentDB
extends RefCounted
## Content is immutable; callers duplicate enemy/room dictionaries before modifying them.
const Enemies = preload("res://scripts/core/enemy_rules.gd")

var data: Dictionary = {}
var errors: Array[String] = []

func _init() -> void:
	var file := FileAccess.open("res://data/content.json", FileAccess.READ)
	if file == null:
		errors.append("无法读取 data/content.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		errors.append("内容 JSON 格式错误")
		return
	data = parsed
	for category in ["enemies", "items", "events", "shop", "floor_pools"]:
		if not data.has(category):
			errors.append("内容缺少：" + category)
	for id in data.get("enemies", {}):
		if not Enemies.valid_definition(data.enemies[id]):
			errors.append("怪物身份或档次配置无效：" + str(id))

func enemy(id: String) -> Dictionary:
	return data.get("enemies", {}).get(id, {}).duplicate(true)

func item(id: String) -> Dictionary:
	return data.get("items", {}).get(id, {}).duplicate(true)

func event(id: String) -> Dictionary:
	return data.get("events", {}).get(id, {}).duplicate(true)

func shop_item(id: String) -> Dictionary:
	return data.get("shop", {}).get(id, {}).duplicate(true)

func items_of_kind(kind: String, tier: int) -> Array:
	var result: Array = []
	for id in data.get("items", {}):
		var entry: Dictionary = data.items[id]
		if entry.kind == kind and int(entry.get("tier", 1)) <= tier:
			result.append(id)
	result.sort()
	return result

func player_stats(player: Dictionary) -> Dictionary:
	var stats := {
		"attack": int(player.attack), "defense": int(player.defense),
		"max_hp": int(player.max_hp), "kill_heal": 0, "gold_bonus": 0
	}
	for id in player.equipment_ids + player.relic_ids:
		var effects: Dictionary = item(str(id)).get("effects", {})
		for key in ["attack", "defense", "max_hp", "kill_heal", "gold_bonus"]:
			stats[key] += int(effects.get(key, 0))
		var ratio := int(effects.get("gold_attack_step", 0))
		if ratio > 0:
			stats.attack += int(int(player.gold) / ratio)
	stats.attack = maxi(1, stats.attack)
	stats.defense = maxi(0, stats.defense)
	return stats

