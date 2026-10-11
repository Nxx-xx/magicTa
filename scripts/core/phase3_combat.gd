extends RefCounted
## Pure snapshot simulation; no content reads, random numbers, saves or UI.
## hit/counter preserve legacy nominal damage; actual_hit records capped HP loss.
const MAX_VALUE := 1000000
const MAX_ENEMY_HP := 10000 # Also the strict upper bound on simulation turns.
const ABILITIES := ["", "rage", "stone_armor", "p3_shield", "p3_ember", "p3_ambush"]
const EFFECT_FIELDS := {
	"first_hit_bonus": ["amount"], "counter_guard": ["amount", "charges"],
	"rank_gold_bonus": ["elite", "boss"], "periodic_hit_bonus": ["amount", "interval"],
	"retaliation": ["amount", "charges"]
}

static func valid_integer(value: Variant, low: int = 0, high: int = MAX_VALUE) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and value >= low and value <= high and value == int(value)

static func validate_inputs(player: Dictionary, enemy: Dictionary, stats: Dictionary) -> Dictionary:
	if not valid_integer(player.get("hp"), 1):
		return _error("player.hp must be an integer in 1..1000000")
	for field in ["attack", "defense", "max_hp", "kill_heal", "gold_bonus"]:
		if not valid_integer(stats.get(field), 1 if field == "max_hp" else 0):
			return _error("stats.%s is missing or outside its finite integer range" % field)
	if player.hp > stats.max_hp:
		return _error("player.hp exceeds derived stats.max_hp")
	for field in ["hp", "attack", "defense"]:
		if not valid_integer(enemy.get(field), 1 if field == "hp" else 0, MAX_ENEMY_HP if field == "hp" else MAX_VALUE):
			return _error("enemy.%s is missing or outside its finite integer range" % field)
	if not valid_integer(enemy.get("gold_reward", 0)):
		return _error("enemy.gold_reward must be a non-negative finite integer")
	if not enemy.get("ability_id", "") is String or not enemy.get("ability_id", "") in ABILITIES:
		return _error("unknown enemy ability_id")
	if not enemy.get("rank", "normal") in ["normal", "elite", "boss"]:
		return _error("unknown enemy rank")
	if not stats.get("combat_effects", []) is Array:
		return _error("stats.combat_effects must be an array")
	var seen := {}
	for effect in stats.get("combat_effects", []):
		if not effect is Dictionary:
			return _error("combat effect must be a dictionary")
		var id: Variant = effect.get("id", "")
		if not id is String or not EFFECT_FIELDS.has(id):
			return _error("unknown combat effect id")
		if seen.has(id):
			return _error("duplicate combat effect: " + id)
		seen[id] = true
		if not effect.get("source_item_id") is String or effect.source_item_id.is_empty():
			return _error("effect.source_item_id must be a non-empty string")
		for key in EFFECT_FIELDS[id]:
			var lower := 1 if key == "interval" else 0
			if not valid_integer(effect.get(key), lower, MAX_ENEMY_HP if key in ["interval", "charges"] else MAX_VALUE):
				return _error("invalid %s.%s" % [id, key])
		for key in effect:
			if key not in ["id", "source_item_id"] and key not in EFFECT_FIELDS[id]:
				return _error("unknown effect parameter: " + str(key))
	return {"ok": true, "error": ""}

static func simulate(player: Dictionary, enemy: Dictionary, stats: Dictionary) -> Dictionary:
	var validation := validate_inputs(player, enemy, stats)
	if not validation.ok:
		return validation
	var hp := int(player.hp)
	var start_hp := hp
	var min_hp := hp
	var enemy_hp := int(enemy.hp)
	var enemy_max_hp := enemy_hp
	var enemy_attack := int(enemy.attack)
	var enemy_defense := int(enemy.defense)
	var ability := str(enemy.get("ability_id", ""))
	var effects := {}
	for effect in stats.get("combat_effects", []):
		effects[effect.id] = effect.duplicate(true)
	var turns := 0
	var counters := 0
	var incoming := 0
	var log: Array = []
	var all_events: Array = []
	while hp > 0 and enemy_hp > 0:
		turns += 1
		var events: Array = []
		var notes: Array[String] = []
		var before_hit := enemy_hp
		var raw_hit := maxi(1, int(stats.attack) - enemy_defense)
		var shield := 3 if ability == "p3_shield" and turns <= 2 else 0
		for id in ["first_hit_bonus", "periodic_hit_bonus"]:
			if not effects.has(id):
				continue
			var effect: Dictionary = effects[id]
			var trigger := turns == 1 if id == "first_hit_bonus" else turns % int(effect.interval) == 0
			if trigger:
				# Marginal actual HP loss after shield and overkill, in this stable order.
				var old_actual := mini(before_hit, maxi(1, raw_hit - shield))
				raw_hit += int(effect.amount)
				_item_event(events, effect, mini(before_hit, maxi(1, raw_hit - shield)) - old_actual)
		var hit := maxi(1, raw_hit - shield)
		if shield > 0:
			_enemy_event(events, enemy, "p3_shield", mini(before_hit, raw_hit) - mini(before_hit, hit))
		enemy_hp = maxi(0, enemy_hp - hit)
		var entry := {"turn": turns, "hit": hit, "actual_hit": before_hit - enemy_hp,
			"enemy_hp": enemy_hp, "enemy_hp_after_counter": enemy_hp,
			"counter": 0, "hp": hp, "note": "", "retaliation_damage": 0,
			"guard_reduction": 0, "effect_events": events}
		if enemy_hp > 0:
			if ability == "rage" and turns % 3 == 0:
				enemy_attack += 2
				notes.append("狂怒：敌人攻击 +2")
				_enemy_event(events, enemy, "rage", 2)
			if ability == "stone_armor":
				var new_defense := int(enemy.defense) + int((enemy_max_hp - enemy_hp) / 50) * 2
				if new_defense > enemy_defense:
					_enemy_event(events, enemy, "stone_armor", new_defense - enemy_defense)
				enemy_defense = new_defense
				notes.append("石甲：当前防御 %d" % enemy_defense)
			counters += 1
			var skill_bonus := 0
			if ability == "p3_ember" and counters % 3 == 0:
				skill_bonus = 5
			if ability == "p3_ambush" and counters == 1:
				skill_bonus = 4
			var raw_counter := maxi(0, enemy_attack + skill_bonus - int(stats.defense))
			var reduction := 0
			if effects.has("counter_guard") and int(effects.counter_guard.charges) > 0:
				reduction = mini(raw_counter, int(effects.counter_guard.amount))
				effects.counter_guard.charges -= 1
				_item_event(events, effects.counter_guard, reduction)
			var counter := raw_counter - reduction
			if skill_bonus > 0:
				# Compare final guarded counter against the same counter without the skill.
				var guard_amount := int(effects.counter_guard.amount) if effects.has("counter_guard") and _has_event(events, "counter_guard") else 0
				var without_skill := maxi(0, enemy_attack - int(stats.defense) - guard_amount)
				_enemy_event(events, enemy, ability, counter - without_skill)
			incoming += counter
			hp = maxi(0, hp - counter)
			min_hp = mini(min_hp, hp)
			entry.counter = counter
			entry.guard_reduction = reduction
			entry.hp = hp
			if hp > 0 and effects.has("retaliation") and int(effects.retaliation.charges) > 0:
				var damage := mini(enemy_hp, int(effects.retaliation.amount))
				effects.retaliation.charges -= 1
				enemy_hp -= damage
				entry.retaliation_damage = damage
				_item_event(events, effects.retaliation, damage)
				if enemy_hp > 0 and ability == "stone_armor":
					var new_defense := int(enemy.defense) + int((enemy_max_hp - enemy_hp) / 50) * 2
					if new_defense > enemy_defense:
						_enemy_event(events, enemy, "stone_armor", new_defense - enemy_defense)
						notes.append("反伤后石甲：当前防御 %d" % new_defense)
					enemy_defense = new_defense
		entry.enemy_hp_after_counter = enemy_hp
		entry.note = "；".join(notes)
		log.append(entry)
		for event in events:
			var flat: Dictionary = event.duplicate(true)
			flat.turn = turns
			all_events.append(flat)
	var won := enemy_hp == 0 and hp > 0
	var healing := 0
	var gold_reward := 0
	if won:
		healing = mini(int(stats.kill_heal), int(stats.max_hp) - hp)
		hp += healing
		gold_reward = int(enemy.get("gold_reward", 0)) + int(stats.gold_bonus)
		if effects.has("rank_gold_bonus"):
			var rank := str(enemy.get("rank", "normal"))
			var bonus := int(effects.rank_gold_bonus.get(rank, 0)) if rank in ["elite", "boss"] else 0
			gold_reward += bonus
			var reward_events: Array = []
			_item_event(reward_events, effects.rank_gold_bonus, bonus)
			log[-1].effect_events.append(reward_events[0].duplicate(true))
			reward_events[0].turn = turns
			all_events.append(reward_events[0])
	return {"ok": true, "error": "", "combat_rules_version": 2,
		"turns": turns, "counterattacks": counters, "incoming": incoming,
		"healing": healing, "loss": start_hp - hp, "hp_after": hp, "min_hp": min_hp,
		"lethal": not won, "won": won, "enemy_hp_after": enemy_hp,
		"gold_reward": gold_reward, "log": log, "effects_triggered": all_events}

static func _has_event(events: Array, id: String) -> bool:
	for event in events:
		if event.id == id:
			return true
	return false

static func _item_event(events: Array, effect: Dictionary, amount: int) -> void:
	events.append({"id": effect.id, "source_item_id": effect.source_item_id, "amount": amount})

static func _enemy_event(events: Array, enemy: Dictionary, id: String, amount: int) -> void:
	events.append({"id": id, "source_enemy_id": str(enemy.get("id", "")), "amount": amount})

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
