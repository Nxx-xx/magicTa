extends RefCounted
## Pure candidate transactions. The campaign engine commits run and account together.
const Story = preload("res://scripts/core/story_state.gd")
const KINDS := ["hp", "attack", "gold"]
const COSTS := [8, 16, 24]
const RULES := {"version": 1, "normal": 2, "elite": 2, "boss": 5, "victory": 20}

static func default_meta() -> Dictionary:
	return {"souls": 0, "souls_earned_total": 0,
		"upgrades": {"hp": 0, "attack": 0, "gold": 0},
		"upgrade_spend": {"hp": 0, "attack": 0, "gold": 0},
		"failure_count": 0, "runs": 0, "wins": 0, "best_floor": 0,
		"milestones": [], "records": [], "last_settled_run_id": ""}

static func initial_player(meta: Dictionary) -> Dictionary:
	var levels: Dictionary = meta.get("upgrades", default_meta().upgrades)
	return {"hp": 100 + 5 * int(levels.hp), "max_hp": 100 + 5 * int(levels.hp),
		"attack": 10 + int(levels.attack), "defense": 5, "gold": 5 * int(levels.gold),
		"keys": 0, "silver_keys": 0, "gold_keys": 0, "equipment_ids": [], "relic_ids": []}

static func settle(state: Dictionary, meta: Dictionary, result: String) -> Dictionary:
	var next := state.duplicate(true)
	var account := meta.duplicate(true)
	if state.get("mode", "") != "tower_campaign_v1" or state.get("campaign_kind", "") != "tower_10f":
		return _error("两层试炼不参与灵魂结算。")
	if result not in ["death", "victory", "abandoned"] or str(state.get("run_id", "")).is_empty():
		return _error("旅程结算信息无效。")
	if state.get("settlement", {}).get("committed", false):
		if state.get("result", "") != result:
			return _error("已结束的旅程不能变更结果。")
		return {"ok": true, "error": "", "state": next, "meta": account}
	if account.get("last_settled_run_id", "") == state.run_id:
		return _error("这次旅程已经结算，不能重复发奖。")
	for record in account.get("records", []):
		if record.get("run_id", "") == state.run_id:
			return _error("这次旅程已经结算，不能重复发奖。")
	var counts := {"normal": 0, "elite": 0, "boss": 0}
	var seen := {}
	for enemy in state.get("defeated_entities", []):
		if not enemy is Dictionary or enemy.get("rank", "") not in counts or str(enemy.get("id", "")).is_empty():
			return _error("击杀记录无效。")
		if not seen.has(enemy.id):
			counts[enemy.rank] += 1
			seen[enemy.id] = true
	var rules: Dictionary = state.get("meta_rules_snapshot", RULES)
	var bonus := int(rules.get("victory", 20)) if result == "victory" else 0
	var souls := 0
	if result != "abandoned":
		for rank in counts:
			souls += int(counts[rank]) * int(rules.get(rank, RULES[rank]))
		souls += bonus
	var before := int(account.souls)
	account.souls = before + souls
	account.souls_earned_total = int(account.get("souls_earned_total", 0)) + souls
	account.runs = int(account.runs) + 1
	var highest_floor := int(state.floor)
	for floor_id in state.get("floors", {}):
		highest_floor = maxi(highest_floor, int(floor_id))
	account.best_floor = maxi(int(account.best_floor), highest_floor)
	account.last_settled_run_id = state.run_id
	if result == "death":
		account.failure_count = int(account.failure_count) + 1
		Story.on_failure(next, int(account.failure_count))
	if result == "victory":
		account.wins = int(account.wins) + 1
		_add_milestone(account, "first_victory")
		var snapshot: Dictionary = state.get("meta_snapshot", {})
		var levels: Dictionary = snapshot.get("upgrades", snapshot)
		if int(levels.get("hp", 0)) + int(levels.get("attack", 0)) + int(levels.get("gold", 0)) == 0:
			_add_milestone(account, "zero_upgrade_victory")
		Story.on_victory(next)
	next.result = result
	next.completed = true
	next.pending = {}
	next.settlement = {"committed": true, "run_id": state.run_id, "result": result,
		"souls": souls, "regular": counts.normal, "elite": counts.elite, "boss": counts.boss,
		"victory_bonus": bonus, "balance_before": before, "balance_after": account.souls}
	account.records.append({"run_id": state.run_id, "result": result, "floor": int(state.floor),
		"highest_floor":highest_floor, "seed": str(state.seed), "souls": souls, "kills": seen.size(), "failure_count": account.failure_count})
	while account.records.size() > 30:
		account.records.pop_front()
	return {"ok": true, "error": "", "state": next, "meta": account}

static func purchase(meta: Dictionary, kind: String) -> Dictionary:
	if kind not in KINDS:
		return _error("未知火种。")
	var next := meta.duplicate(true)
	var level := int(next.upgrades[kind])
	if level >= 3:
		return _error("这枚火种已满级。")
	var cost: int = COSTS[level]
	if int(next.souls) < cost:
		return _error("灵魂不足，还差 %d。" % (cost - int(next.souls)))
	next.souls = int(next.souls) - cost
	next.upgrades[kind] = level + 1
	next.upgrade_spend[kind] = int(next.upgrade_spend[kind]) + cost
	if int(next.upgrades.hp) + int(next.upgrades.attack) + int(next.upgrades.gold) == 9:
		_add_milestone(next, "all_upgrades")
	return {"ok": true, "error": "", "meta": next}

static func reset(meta: Dictionary) -> Dictionary:
	var next := meta.duplicate(true)
	var refund := 0
	for kind in KINDS:
		refund += int(next.upgrade_spend[kind])
		next.upgrades[kind] = 0
		next.upgrade_spend[kind] = 0
	if refund == 0:
		return _error("还没有需要重置的火种。")
	next.souls = int(next.souls) + refund
	return {"ok": true, "error": "", "meta": next, "refund": refund}

static func _add_milestone(meta: Dictionary, milestone: String) -> void:
	if milestone not in meta.milestones:
		meta.milestones.append(milestone)

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
