extends RefCounted
## Frozen-content stats and pure reward2 transactions. No RNG, persistence or UI.
const LIMIT := 1000000
const FunctionCodes = preload("res://scripts/core/function_codes.gd")
const STAT_FIELDS := ["attack", "defense", "max_hp", "kill_heal", "gold_bonus"]
const ITEM_FIELDS := ["attack", "defense", "max_hp", "kill_heal", "gold_bonus", "gold_attack_step"]
const REWARD_FIELDS := ["attack", "defense", "max_hp", "gold", "keys", "silver_keys", "gold_keys", "heal"]
const COST_FIELDS := ["hp", "max_hp", "gold", "keys", "silver_keys", "gold_keys"]
const UNIQUE_IDS := ["p3_dawn_sigil", "p3_lantern_aegis", "p3_bounty_ledger", "p3_rhythm_blade", "p3_thorn_clasp", "p3_gilded_lantern"]
const COMBAT_FIELDS := {
	"first_hit_bonus": ["amount"], "counter_guard": ["amount", "charges"],
	"rank_gold_bonus": ["elite", "boss"], "periodic_hit_bonus": ["amount", "interval"],
	"retaliation": ["amount", "charges"]}

static func definitions() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/phase3_items.json"))
	if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("items") is Dictionary:
		return _error("无法读取第三阶段物品定义。")
	var checked := validate_definitions(parsed.items)
	return parsed.items.duplicate(true) if checked.ok else checked

static func merge_content(content: Dictionary, item_definitions: Dictionary = {}) -> Dictionary:
	var additions := definitions() if item_definitions.is_empty() else item_definitions.duplicate(true)
	var checked := validate_definitions(additions)
	if not checked.ok:
		return checked
	if not content.get("items", {}) is Dictionary:
		return _error("物品内容必须为字典。")
	var result := content.duplicate(true)
	result["items"] = result.get("items", {}).duplicate(true)
	result.items.merge(additions, true)
	checked = validate_definitions(result.items)
	return result if checked.ok else checked

static func validate_definitions(item_definitions: Dictionary) -> Dictionary:
	for id in item_definitions:
		var item: Variant = item_definitions[id]
		if not id is String or id.is_empty() or not item is Dictionary:
			return _error("物品 ID 或定义类型无效。")
		if item.get("id") != id or item.get("kind") not in ["equipment", "relic"]:
			return _error("物品身份无效：" + id)
		for field in ["name", "description"]:
			if not item.get(field) is String or item[field].is_empty():
				return _error("物品缺少名称/说明：" + id)
		if not _count(item.get("price")) or not _count(item.get("tier"), 1, 3):
			return _error("物品价格或阶级无效：" + id)
		if item.has("unique_per_run") and not item.unique_per_run is bool:
			return _error("唯一持有配置无效：" + id)
		if id in UNIQUE_IDS and (item.get("unique_per_run") != true or item.kind != "relic"):
			return _error("新机制遗物必须唯一持有：" + id)
		var effects: Variant = item.get("effects", {})
		if not effects is Dictionary:
			return _error("静态效果必须为字典：" + id)
		for field in effects:
			if field not in ITEM_FIELDS or not _count(effects[field], 1 if field == "gold_attack_step" else 0):
				return _error("未知或无效静态效果：" + id)
		var combat: Variant = item.get("combat_effects", [])
		var conditions: Variant = item.get("conditional_effects", [])
		if not combat is Array or not conditions is Array or combat.size() > 5 or conditions.size() > 1:
			return _error("效果列表无效：" + id)
		if (not combat.is_empty() or not conditions.is_empty()) and item.get("unique_per_run") != true:
			return _error("机制物品必须唯一持有：" + id)
		var seen := {}
		for effect in combat:
			if not effect is Dictionary or not COMBAT_FIELDS.has(effect.get("id")):
				return _error("未知战斗效果：" + id)
			if seen.has(effect.id):
				return _error("重复战斗效果：" + id)
			seen[effect.id] = true
			var fields: Array = COMBAT_FIELDS[effect.id]
			for field in effect:
				if field != "id" and field not in fields:
					return _error("战斗效果字段无效：" + id)
			for field in fields:
				var bounded: bool = field in ["charges", "interval"]
				if not _count(effect.get(field), 1 if bounded else 0, 100 if bounded else LIMIT):
					return _error("战斗效果数值无效：" + id)
		for effect in conditions:
			if not effect is Dictionary or effect.get("id") != "gold_defense_threshold" or effect.size() != 3:
				return _error("未知条件静态效果：" + id)
			if not _count(effect.get("threshold"), 1) or not _count(effect.get("amount")):
				return _error("条件静态效果数值无效：" + id)
		if item.has("build_tags"):
			if not item.build_tags is Array:
				return _error("构筑标签必须为数组：" + id)
			for tag in item.build_tags:
				if tag not in ["assault", "guard", "wealth"]:
					return _error("未知构筑标签：" + id)
	return {"ok": true, "error": ""}

static func validate_player(player: Dictionary, content: Dictionary) -> Dictionary:
	if not FunctionCodes.valid(player): return _error("功能码属性记录无效。")
	if not content.get("items") is Dictionary:
		return _error("内容缺少物品字典。")
	var checked := validate_definitions(content.items)
	if not checked.ok:
		return checked
	for field in ["hp", "max_hp", "attack", "defense", "gold"]:
		if not _count(player.get(field), 1 if field == "max_hp" else 0):
			return _error("玩家数值无效：" + field)
	for field in ["keys", "silver_keys", "gold_keys"]:
		if not _count(player.get(field, 0)):
			return _error("钥匙数量无效：" + field)
	var seen := {}
	for collection in ["equipment_ids", "relic_ids"]:
		if not player.get(collection) is Array or player[collection].size() > 4096:
			return _error("玩家物品列表无效。")
		for id in player[collection]:
			if not id is String or not content.items.has(id):
				return _error("玩家持有未知物品。")
			var item: Dictionary = content.items[id]
			if item.kind != ("equipment" if collection == "equipment_ids" else "relic"):
				return _error("物品所在栏位无效：" + id)
			if item.get("unique_per_run", false) and seen.has(id):
				return _error("新遗物重复持有：" + id)
			seen[id] = true
	return {"ok": true, "error": ""}

static func player_stats(player: Dictionary, content: Dictionary) -> Dictionary:
	var checked := validate_player(player, content)
	if not checked.ok:
		return checked
	var stats := {"ok": true, "error": "", "attack": int(player.attack), "defense": int(player.defense),
		"max_hp": int(player.max_hp), "kill_heal": 0, "gold_bonus": 0, "combat_effects": [], "effect_sources": []}
	for id in player.equipment_ids + player.relic_ids:
		var item: Dictionary = content.items[id]
		var effects: Dictionary = item.get("effects", {})
		for field in STAT_FIELDS:
			var amount := int(effects.get(field, 0))
			stats[field] += amount
			if amount != 0:
				stats.effect_sources.append({"id": field, "amount": amount, "source_item_id": id, "active": true})
		var ratio := int(effects.get("gold_attack_step", 0))
		if ratio > 0:
			var amount := int(int(player.gold) / ratio)
			stats.attack += amount
			stats.effect_sources.append({"id": "gold_attack_step", "amount": amount, "step": ratio, "source_item_id": id, "active": true})
		for effect in item.get("combat_effects", []):
			var entry: Dictionary = effect.duplicate(true)
			for field in COMBAT_FIELDS[entry.id]:
				entry[field] = int(entry[field])
			entry["source_item_id"] = id
			stats.combat_effects.append(entry)
		for effect in item.get("conditional_effects", []):
			var active := int(player.gold) >= int(effect.threshold)
			var amount := int(effect.amount) if active else 0
			stats.defense += amount
			stats.effect_sources.append({"id": effect.id, "amount": amount, "threshold": int(effect.threshold),
				"configured_amount": int(effect.amount), "source_item_id": id, "active": active})
	FunctionCodes.apply_stats(player, stats)
	for field in STAT_FIELDS:
		if not _count(stats[field], 1 if field == "max_hp" else 0):
			return _error("派生属性超出有效范围：" + field)
	stats.attack = maxi(1, stats.attack)
	stats.defense = maxi(0, stats.defense)
	return stats

static func resolve(content: Dictionary, player: Dictionary, reward: Dictionary) -> Dictionary:
	var before := player_stats(player, content)
	if not before.ok:
		return before
	var cost: Variant = reward.get("cost", {})
	var effects: Variant = reward.get("effects", {})
	if not cost is Dictionary or not effects is Dictionary:
		return _error("奖励成本和效果必须为字典。")
	for field in cost:
		if field not in COST_FIELDS or not _count(cost[field]):
			return _error("奖励成本配置无效。")
		var reserve := 1 if field in ["hp", "max_hp"] else 0
		if int(player.get(field, 0)) - int(cost[field]) < reserve:
			return _error("生命或基础上限不足，必须保留至少 1。" if reserve else "金币或对应钥匙不足。")
	for field in effects:
		if field not in REWARD_FIELDS or not _count(effects[field]):
			return _error("奖励效果配置无效。")
	var item: Dictionary = {}
	if reward.has("item_id"):
		if not reward.item_id is String or not content.items.has(reward.item_id):
			return _error("未知物品，奖励未领取。")
		item = content.items[reward.item_id]
		if item.get("unique_per_run", false) and (reward.item_id in player.equipment_ids or reward.item_id in player.relic_ids):
			return _error("已持有该唯一遗物，未扣除任何资源。")
	var next := player.duplicate(true)
	for field in cost:
		next[field] = int(next.get(field, 0)) - int(cost[field])
	# Pay the cap cost before benefits: a later cap reward cannot undo this HP loss.
	if int(cost.get("max_hp", 0)) > 0:
		var paid := player_stats(next, content)
		if not paid.ok:
			return paid
		next.hp = mini(int(next.hp), int(paid.max_hp))
	for field in effects:
		if field != "heal":
			next[field] = int(next.get(field, 0)) + int(effects[field])
	var heal := int(effects.get("heal", 0))
	if not item.is_empty():
		var collection := "equipment_ids" if item.kind == "equipment" else "relic_ids"
		next[collection].append(reward.item_id)
		heal += int(item.get("effects", {}).get("max_hp", 0))
	var after := player_stats(next, content)
	if not after.ok or not _count(heal):
		return after if not after.ok else _error("治疗总量超出有效范围。")
	var recovered := mini(heal, maxi(0, int(after.max_hp) - int(next.hp)))
	next.hp = mini(int(next.hp) + recovered, int(after.max_hp))
	return {"ok": true, "error": "", "player": next, "before": before, "after": after,
		"healing": recovered, "overflow": heal - recovered,
		"attack_delta": int(after.attack) - int(before.attack),
		"defense_delta": int(after.defense) - int(before.defense),
		"max_hp_delta": int(after.max_hp) - int(before.max_hp),
		"hp_delta": int(next.hp) - int(player.hp), "gold_delta": int(next.gold) - int(player.gold)}

static func _count(value: Variant, minimum: int = 0, maximum: int = LIMIT) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum and float(value) == floorf(float(value))

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
