extends RefCounted
## Protocol fixture, not simulated gameplay. Explicit values make replay assertions stable.
static func report(turns: int = 12, retaliation_finish: bool = true) -> Dictionary:
	var log: Array[Dictionary] = []
	var hp := 100
	for index in turns:
		var last := index == turns - 1
		var events: Array[Dictionary] = []
		if index == 1: events.append({"id": "first_hit_bonus", "source_item_id": "p3_dawn_sigil", "amount": 4})
		if index == 2: events.append({"id": "counter_guard", "source_item_id": "p3_lantern_aegis", "amount": 2})
		if index == 4: events.append({"id": "periodic_hit_bonus", "source_item_id": "p3_rhythm_blade", "amount": 3})
		if last and retaliation_finish: events.append({"id": "retaliation", "source_item_id": "p3_thorn_clasp", "amount": 2})
		var counter := 1 if not last or retaliation_finish else 0
		hp -= counter
		var enemy_hp := (turns - index - 1) * 8 + (2 if retaliation_finish else 0)
		log.append({"turn": index + 1, "hit": 8, "enemy_hp": enemy_hp, "counter": counter, "hp": hp,
			"enemy_hp_after_counter": 0 if last else enemy_hp, "retaliation_damage": 2 if last and retaliation_finish else 0,
			"guard_reduction": 2 if index == 2 else 0, "effect_events": events, "note": "狂怒：敌人攻击 +2" if index == 5 else ""})
	return {"ok": true, "error": "", "combat_rules_version": 2, "turns": turns, "log": log,
		"hp_after": hp + 3, "enemy_hp_after": 0, "gold_reward": 20, "healing": 3, "incoming": 100 - hp,
		"min_hp": hp, "won": true, "lethal": false, "loss": 100 - hp - 3, "effects_triggered": []}
