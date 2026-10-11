extends SceneTree
const Combat = preload("res://scripts/core/phase3_combat.gd")
const Legacy = preload("res://scripts/core/combat.gd")
const Enemies = preload("res://scripts/core/phase3_enemies.gd")
var checks := 0
var failures: Array[String] = []
var evidence := {}

func _initialize() -> void:
	_legacy()
	_boundaries()
	_combined_effects()
	_invalid()
	_definitions()
	var root := "res://build/verification/phase3/03-combat/"
	DirAccess.make_dir_recursive_absolute(root)
	var output := {"checks": checks, "failures": failures, "fixtures": evidence,
		"scope": "isolated deterministic module checks; not full tower integration"}
	FileAccess.open(root + "combat-results.json", FileAccess.WRITE).store_string(JSON.stringify(output, "\t"))
	print("Phase3 combat: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _stats(attack: int = 10, defense: int = 5, effects: Array = []) -> Dictionary:
	return {"attack": attack, "defense": defense, "max_hp": 100,
		"kill_heal": 0, "gold_bonus": 0, "combat_effects": effects}

func _enemy(hp: int = 30, attack: int = 10, defense: int = 0, ability: String = "") -> Dictionary:
	return {"id": "fixture", "hp": hp, "attack": attack, "defense": defense,
		"ability_id": ability, "gold_reward": 12, "rank": "normal"}

func _effect(id: String, amount: int, charges: int = 0) -> Dictionary:
	var e := {"id": id, "amount": amount, "source_item_id": "fixture_" + id}
	if id in ["counter_guard", "retaliation"]:
		e.charges = charges
	if id == "periodic_hit_bonus":
		e.interval = 3
	return e

func _events(report: Dictionary, id: String) -> Array:
	return report.effects_triggered.filter(func(e: Dictionary) -> bool: return e.id == id)

func _legacy() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	for enemy in content.enemies.values():
		for attack in [1, 10, 38, 114, 1000]:
			for defense in [0, 5, 18, 100]:
				for hp in [1, 17, 100]:
					var p := {"hp": hp}
					var stats := _stats(attack, defense)
					stats.kill_heal = 8
					stats.gold_bonus = 12
					var original := [p.duplicate(true), enemy.duplicate(true), stats.duplicate(true)]
					var old: Dictionary = Legacy.simulate(p, enemy, stats)
					var fresh: Dictionary = Combat.simulate(p, enemy, stats)
					_check(fresh.ok, "legacy input accepted")
					for key in old:
						if key != "log":
							_check(old[key] == fresh[key], "legacy %s %s/%s/%s field %s" % [enemy.id, attack, defense, hp, key])
					for i in range(old.log.size()):
						for key in old.log[i]:
							_check(old.log[i][key] == fresh.log[i][key], "legacy log %s %d %s" % [enemy.id, i, key])
					_check([p, enemy, stats] == original, "all inputs unchanged")
					_check(fresh == Combat.simulate(p, enemy, stats), "repeat deterministic")
	# Campaign override remains explicit; a base-22 run cannot represent floor ten.
	var golem: Dictionary = content.enemies.golem.duplicate(true)
	golem.attack = 28
	var r := Combat.simulate({"hp": 100}, golem, _stats(114, 22))
	_check(r.incoming == 12 and r.turns == 3, "floor-ten attack 28 override")
	evidence.floor10_golem = r

func _boundaries() -> void:
	var guard := _effect("counter_guard", 2, 2)
	var thorn := _effect("retaliation", 2, 3)
	var dawn := _effect("first_hit_bonus", 4)
	var rhythm := _effect("periodic_hit_bonus", 3)
	var p := {"hp": 100}
	var r := Combat.simulate(p, _enemy(10, 50, 0, "rage"), _stats(20, 0, [guard, thorn, dawn]))
	_check(r.won and r.counterattacks == 0 and r.log[0].hit == 24 and r.log[0].actual_hit == 10, "EN01 direct kill preserves nominal/actual hit")
	_check(_events(r, "counter_guard").is_empty() and _events(r, "retaliation").is_empty() and _events(r, "rage").is_empty(), "EN01 no counter effects on direct kill")
	_check(_events(r, "first_hit_bonus")[0].amount == 0, "overkill bonus has zero actual benefit")
	r = Combat.simulate(p, _enemy(80, 5, 0, "rage"), _stats(10, 5))
	_check(_events(r, "rage").size() == 2 and r.log[2].counter == 2 and r.log[5].counter == 4, "EN02 rage third and sixth counter")
	r = Combat.simulate(p, _enemy(30, 5, 0, "rage"), _stats(10, 5))
	_check(_events(r, "rage").is_empty(), "EN02 third hit lethal skips rage")
	for loss in [49, 50, 99, 100, 150]:
		r = Combat.simulate(p, _enemy(250, 0, 14, "stone_armor"), _stats(loss + 14, 0))
		_check(r.log[1].hit == maxi(1, loss - int(loss / 50) * 2), "EN03 exact armor threshold " + str(loss))
	r = Combat.simulate(p, _enemy(250, 0, 14, "stone_armor"), _stats(114, 0))
	_check(r.log[0].effect_events[0].amount == 4, "EN03 multiple armor thresholds one event")
	r = Combat.simulate(p, _enemy(250, 0, 14, "stone_armor"), _stats(63, 0, [thorn]))
	_check(r.log[0].enemy_hp == 201 and r.log[0].enemy_hp_after_counter == 199 and r.log[1].hit == 47, "EN03 retaliation crosses armor threshold immediately")
	evidence.retaliation_armor = r
	var stats := _stats(10, 0, [thorn])
	stats.kill_heal = 100
	r = Combat.simulate({"hp": 10}, _enemy(12, 10), stats)
	_check(r.lethal and r.hp_after == 0 and r.min_hp == 0 and r.healing == 0 and r.gold_reward == 0, "EN04 exact lethal cannot heal")
	_check(r.enemy_hp_after == 2 and _events(r, "retaliation").is_empty(), "EN04 no postmortem retaliation")
	evidence.lethal_no_thorns = r
	r = Combat.simulate(p, _enemy(5, 0, 100, "p3_shield"), _stats(0, 100))
	_check(r.turns == 5 and r.log[0].hit == 1 and _events(r, "p3_shield").size() == 2, "EN05 shield minimum and two charges")
	r = Combat.simulate(p, _enemy(100, 0, 8, "p3_shield"), _stats(10, 100, [dawn, rhythm]))
	_check(r.log[0].hit == 3 and r.log[1].hit == 1 and r.log[2].hit == 5, "EN05 damage bonuses precede shield, rhythm every third")
	r = Combat.simulate(p, _enemy(80, 0), _stats(10, 100, [guard, thorn]))
	_check(_events(r, "counter_guard").size() == 2 and _events(r, "counter_guard")[0].amount == 0, "zero counter consumes guard and records zero benefit")
	_check(_events(r, "retaliation").size() == 3 and r.counterattacks > 3, "zero counter triggers thorns but charges capped")
	stats = _stats(10, 0, [thorn])
	stats.kill_heal = 8
	stats.gold_bonus = 12
	r = Combat.simulate({"hp": 20}, _enemy(12, 5), stats)
	_check(r.won and r.turns == 1 and r.log.size() == r.turns and r.log[0].enemy_hp == 2 and r.log[0].enemy_hp_after_counter == 0, "EN06 thorns final blow no extra player turn")
	_check(r.min_hp == 15 and r.hp_after == 23 and r.healing == 8 and r.gold_reward == 24, "EN06 reward exactly once; minimum before healing")
	evidence.retaliation_kill = r
	r = Combat.simulate(p, _enemy(11, 0, 0, "stone_armor"), _stats(10, 0, [thorn]))
	_check(r.log[0].retaliation_damage == 1 and _events(r, "retaliation")[0].amount == 1 and _events(r, "stone_armor").is_empty(), "retaliation capped; no armor after lethal")
	var ledger := {"id": "rank_gold_bonus", "source_item_id": "p3_bounty_ledger", "elite": 10, "boss": 20}
	for rank in ["normal", "elite", "boss"]:
		var e := _enemy(1)
		e.rank = rank
		r = Combat.simulate(p, e, _stats(10, 5, [ledger]))
		_check(r.gold_reward == 12 + int(ledger.get(rank, 0)), "ledger rank " + rank)
	var variants := Enemies.definitions()
	r = Combat.simulate(p, variants.p3_ember_channeler, _stats(10, 17, [guard]))
	_check(r.log[2].counter == 5 and r.log[5].counter == 5 and r.log[0].counter == 0, "ember third and sixth counters")
	r = Combat.simulate(p, variants.p3_vault_knight, _stats(30, 20, [guard]))
	_check(r.log[0].counter == 2 and r.log[1].counter == 0 and _events(r, "p3_ambush").size() == 1, "ambush first actual counter plus guard")
	_check(Combat.simulate(p, variants.p3_vault_knight, _stats(100, 0, [guard])).counterattacks == 0, "ambush no counter on one shot")
	# Max accepted enemy HP terminates even at minimum damage and zero incoming.
	r = Combat.simulate(p, _enemy(10000, 0, 100), _stats(0, 100))
	_check(r.turns == 10000 and r.won, "bounded minimum damage termination")

func _invalid() -> void:
	for value in [-1, 0, 1.5, "10", true, NAN, INF, 1000001]:
		var r := Combat.simulate({"hp": value}, _enemy(), _stats())
		_check(not r.ok and not r.error.is_empty(), "invalid hp " + str(value))
	for field in ["attack", "defense", "max_hp", "kill_heal", "gold_bonus"]:
		for value in [-1, 0.5, "4", NAN, INF]:
			var s := _stats()
			s[field] = value
			_check(not Combat.simulate({"hp": 1}, _enemy(), s).ok, "invalid stats " + field)
	var e := _enemy()
	e.ability_id = "typo"
	_check(not Combat.simulate({"hp": 10}, e, _stats()).ok, "unknown enemy skill")
	e = _enemy(10001)
	_check(not Combat.simulate({"hp": 10}, e, _stats()).ok, "reject unbounded enemy hp")
	for effects in [[{"id": "typo"}], [_effect("counter_guard", -1, 2)],
		[_effect("retaliation", 2, -1)], [{"id": "periodic_hit_bonus", "amount": 3, "interval": 0, "source_item_id": "x"}],
		[_effect("first_hit_bonus", 4), _effect("first_hit_bonus", 4)], ["bad"],
		[{"id": "first_hit_bonus", "amount": 4}],
		[{"id": "first_hit_bonus", "amount": 4, "source_item_id": "x", "typo": 3}]]:
		var r := Combat.simulate({"hp": 10}, _enemy(), _stats(10, 5, effects))
		_check(not r.ok and not r.error.is_empty(), "invalid effects rejected")
	_check(not Combat.simulate({"hp": 101}, _enemy(), _stats()).ok, "hp above derived maximum rejected")

func _combined_effects() -> void:
	var effects := [_effect("first_hit_bonus", 4), _effect("counter_guard", 2, 2),
		_effect("periodic_hit_bonus", 3), _effect("retaliation", 2, 3),
		{"id": "rank_gold_bonus", "source_item_id": "p3_bounty_ledger", "elite": 10, "boss": 20}]
	var stats := _stats(18, 10, effects)
	stats.kill_heal = 8
	stats.gold_bonus = 12
	var enemy: Dictionary = Enemies.definitions().p3_shield_sentinel
	var p := {"hp": 30}
	var snapshot := [p.duplicate(true), enemy.duplicate(true), stats.duplicate(true)]
	var r := Combat.simulate(p, enemy, stats)
	_check(r.won and r.turns == 5 and r.incoming == 8 and r.min_hp == 22 and r.hp_after == 30 and r.gold_reward == 46, "all five effects compose in frozen order")
	var expected_hits := [11, 7, 13, 10, 10]
	var expected_enemy_hp := [37, 28, 13, 1, 0]
	var expected_after := [35, 26, 11, 1, 0]
	var flat: Array = []
	var damage := 0
	for i in range(r.log.size()):
		var entry: Dictionary = r.log[i]
		_check(entry.hit == expected_hits[i] and entry.enemy_hp == expected_enemy_hp[i] and entry.enemy_hp_after_counter == expected_after[i], "composed turn " + str(i + 1))
		damage += entry.actual_hit + entry.retaliation_damage
		for event in entry.effect_events:
			var copy: Dictionary = event.duplicate(true)
			copy.turn = i + 1
			flat.append(copy)
	_check(damage == enemy.hp and flat == r.effects_triggered, "actual HP conservation and flattened events agree")
	_check(snapshot == [p, enemy, stats] and r == Combat.simulate(p, enemy, stats), "effect charges reset every simulation without mutating snapshots")
	evidence.all_five_effects = r
	stats.defense = 100
	r = Combat.simulate({"hp": 30}, _enemy(40, 10, 0, "p3_ambush"), stats)
	_check(_events(r, "p3_ambush")[0].amount == 0 and _events(r, "counter_guard")[0].amount == 0, "fully defended ambush and guard report no false benefit")
	stats.defense = 0
	r = Combat.simulate({"hp": 1}, _enemy(100, 10), stats)
	_check(r.lethal and _events(r, "rank_gold_bonus").is_empty() and r.gold_reward == 0, "ledger cannot reward defeat")
	# Fixed representative preparation levels; this is not a whole-run balance claim.
	var old_content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	var comparisons: Array = []
	var prep := {"p3_shield_sentinel": [18, 9], "p3_ember_channeler": [24, 12], "p3_vault_knight": [30, 15]}
	for id in Enemies.definitions():
		var variant: Dictionary = Enemies.definitions()[id]
		var s := _stats(prep[id][0], prep[id][1])
		var old := Combat.simulate({"hp": 100}, old_content.enemies[variant.base_enemy_id], s)
		var fresh := Combat.simulate({"hp": 100}, variant, s)
		comparisons.append({"variant": id, "attack": s.attack, "defense": s.defense, "max_hp": 100,
			"base_incoming": old.incoming, "variant_incoming": fresh.incoming, "difference": fresh.incoming - old.incoming,
			"over_20_percent_review": fresh.incoming - old.incoming > 20})
	evidence.variant_preparation_comparisons = comparisons

func _definitions() -> void:
	var defs := Enemies.definitions()
	_check(defs.size() == 3 and Enemies.validate_definitions(defs).ok, "all three definitions valid")
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	var before := content.duplicate(true)
	var merged := Enemies.merge_content(content, defs)
	_check(content == before and merged.enemies.size() == 13, "merge copies input and adds three")
	_check(merged.enemies.golem.attack == 22 and merged.enemies.minotaur.attack == 18, "merge does not alter old boss snapshots")
	_check(Enemies.merge_content(merged, defs) == merged, "merge idempotent")
	defs.p3_shield_sentinel.hp = 49
	_check(not Enemies.merge_content(merged, defs).ok, "conflicting snapshots refused")
	defs = Enemies.definitions()
	defs.p3_shield_sentinel.variant_floors = [1, 3]
	_check(not Enemies.validate_definitions(defs).ok, "invalid variant placement refused")
	defs = Enemies.definitions()
	defs.p3_ember_channeler.ability_id = "unknown"
	_check(not Enemies.validate_definitions(defs).ok, "definition unknown skill refused")
	_check(not Enemies.merge_content({}).ok, "missing content enemies refused")
