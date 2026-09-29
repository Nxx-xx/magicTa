class_name RewardRules
extends RefCounted
## Pure transaction: previews and commits use exactly the same resource rules.
const FIELDS := ["attack", "defense", "max_hp", "gold", "keys", "silver_keys", "gold_keys", "heal"]
const COSTS := ["hp", "gold", "keys", "silver_keys", "gold_keys"]

static func resolve(db, player: Dictionary, reward: Dictionary) -> Dictionary:
	var next: Dictionary = player.duplicate(true)
	var before: Dictionary = db.player_stats(player)
	var cost: Dictionary = reward.get("cost", {})
	var effects: Dictionary = reward.get("effects", {})
	for field in cost:
		if field not in COSTS or not _count(cost[field]):
			return _error("奖励成本配置无效。")
		if int(player.get(field, 0)) < int(cost[field]) or (field == "hp" and int(player.hp) <= int(cost[field])):
			return _error("生命不足，必须保留至少 1 HP。" if field == "hp" else "金币或对应钥匙不足。")
	for field in effects:
		if field not in FIELDS or not _count(effects[field]):
			return _error("奖励效果配置无效。")
	var item: Dictionary = {}
	if reward.has("item_id"):
		item = db.item(str(reward.item_id))
		if item.is_empty() or item.get("kind", "") not in ["equipment", "relic"]:
			return _error("未知物品，奖励未领取。")
	for field in cost:
		next[field] = int(next.get(field, 0)) - int(cost[field])
	for field in effects:
		if field != "heal":
			next[field] = int(next.get(field, 0)) + int(effects[field])
	var heal := int(effects.get("heal", 0))
	if not item.is_empty():
		var collection := "equipment_ids" if item.kind == "equipment" else "relic_ids"
		next[collection].append(str(reward.item_id))
		heal += int(item.effects.get("max_hp", 0))
	var after: Dictionary = db.player_stats(next)
	var recovered := mini(heal, maxi(0, int(after.max_hp) - int(next.hp)))
	next.hp = mini(int(next.hp) + recovered, int(after.max_hp))
	return {"ok": true, "error": "", "player": next, "before": before, "after": after,
		"healing": recovered, "overflow": heal - recovered,
		"attack_delta": int(after.attack) - int(before.attack),
		"defense_delta": int(after.defense) - int(before.defense),
		"max_hp_delta": int(after.max_hp) - int(before.max_hp),
		"hp_delta": int(next.hp) - int(player.hp), "gold_delta": int(next.gold) - int(player.gold)}

static func summary(result: Dictionary) -> String:
	if not result.get("ok", false):
		return str(result.get("error", "无法领取奖励。"))
	return "领取后：攻击 %d（%+d） · 防御 %d（%+d）\n生命 %d/%d · 金币 %d" % [
		result.after.attack, result.attack_delta, result.after.defense, result.defense_delta,
		result.player.hp, result.after.max_hp, result.player.gold]

static func _count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) == floorf(float(value))

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
