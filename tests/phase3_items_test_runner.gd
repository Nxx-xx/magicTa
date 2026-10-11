extends SceneTree
const Items = preload("res://scripts/core/phase3_items.gd")
const Summary = preload("res://scripts/ui/phase3_build_summary.gd")
const OldDB = preload("res://scripts/core/content_db.gd")
const OldRewards = preload("res://scripts/core/rewards.gd")
const OldCombat = preload("res://scripts/core/combat.gd")
var checks := 0
var failures := 0
var evidence: Array = []
var db = OldDB.new()
var content: Dictionary = {}

func _initialize() -> void:
	content = Items.merge_content(db.data)
	_check(content.items.size() == 28 and db.data.items.size() == 22, "merge does not mutate legacy content")
	_test_legacy()
	_test_thresholds()
	_test_transactions()
	_test_validation()
	_test_summary()
	var report := {"checks": checks, "failures": failures, "cases": evidence,
		"engine": Engine.get_version_info(), "user_data_dir": OS.get_user_data_dir()}
	var out := FileAccess.open("res://build/verification/phase3/01-items/results.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "  "))
	print("Phase3 items: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _player() -> Dictionary:
	return {"hp": 100, "max_hp": 100, "attack": 10, "defense": 5, "gold": 100,
		"keys": 2, "silver_keys": 2, "gold_keys": 2, "equipment_ids": [], "relic_ids": []}

func _test_legacy() -> void:
	for id in db.data.items:
		var p := _player()
		p.hp = 50
		for copy in 2:
			var before := p.duplicate(true)
			var original := OldRewards.resolve(db, p, {"item_id": id})
			var result := Items.resolve(content, p, {"item_id": id})
			_check(result.ok and p == before, "pure legacy reward %s copy%d" % [id, copy])
			_check(result.player == original.player, "legacy player exact match %s copy%d" % [id, copy])
			for field in ["healing", "overflow", "attack_delta", "defense_delta", "max_hp_delta", "hp_delta", "gold_delta"]:
				_check(result[field] == original[field], "legacy delta %s %s copy%d" % [id, field, copy])
			for field in Items.STAT_FIELDS:
				_check(result.after[field] == original.after[field], "legacy stats %s %s copy%d" % [id, field, copy])
			p = result.player
	for event in db.data.events.values():
		for reward in event.options:
			var p := _player()
			p.hp = 50
			var old := OldRewards.resolve(db, p, reward)
			var fresh := Items.resolve(content, p, reward)
			_check(fresh.ok and fresh.player == old.player and fresh.healing == old.healing, "legacy event " + reward.name)
	var mixed := _player()
	for id in db.data.items:
		var collection := "equipment_ids" if db.data.items[id].kind == "equipment" else "relic_ids"
		mixed[collection].append(id)
		mixed[collection].append(id)
	for gold in [0, 24, 25, 49, 50, 99, 100, 999]:
		mixed.gold = gold
		var stats := Items.player_stats(mixed, content)
		var old := db.player_stats(mixed)
		_check(stats.ok and stats.combat_effects.is_empty(), "mixed legacy has no combat effects")
		for field in Items.STAT_FIELDS:
			_check(stats[field] == old[field], "mixed 44 copies %d %s" % [gold, field])

func _test_thresholds() -> void:
	var p := _player()
	p.relic_ids = ["gold_sword", "merchant_seal", "p3_gilded_lantern"]
	var expected := {24: 0, 25: 1, 49: 1, 50: 3, 99: 4, 100: 6}
	for gold in expected:
		p.gold = gold
		var stats := Items.player_stats(p, content)
		_check(stats.attack == 10 + expected[gold], "gold attack threshold %d" % gold)
		_check(stats.defense == 5 + (2 if gold >= 100 else 0), "lantern defense threshold %d" % gold)
		_check(stats.combat_effects.is_empty(), "lantern never leaks into combat effects")
	p.gold = 100
	var buy := Items.resolve(content, p, {"cost": {"gold": 42}, "item_id": "steel_blade"})
	_check(buy.ok and buy.player.gold == 58 and buy.attack_delta == 4 and buy.defense_delta == -2, "wealth purchase includes both lost thresholds")
	var frozen := Items.player_stats(p, content)
	p.gold = 0
	_check(frozen.defense == 7, "already computed combat stats stay frozen")
	var all := _player()
	all.relic_ids = Items.UNIQUE_IDS.duplicate()
	var effects: Dictionary = Items.player_stats(all, content)
	_check(effects.combat_effects.size() == 5 and effects.defense == 7, "six relics produce five combat effects plus static defense")
	var expected_effects := [
		{"id": "first_hit_bonus", "amount": 4, "source_item_id": "p3_dawn_sigil"},
		{"id": "counter_guard", "amount": 2, "charges": 2, "source_item_id": "p3_lantern_aegis"},
		{"id": "rank_gold_bonus", "elite": 10, "boss": 20, "source_item_id": "p3_bounty_ledger"},
		{"id": "periodic_hit_bonus", "amount": 3, "interval": 3, "source_item_id": "p3_rhythm_blade"},
		{"id": "retaliation", "amount": 2, "charges": 3, "source_item_id": "p3_thorn_clasp"}]
	_check(effects.combat_effects == expected_effects, "exact five-effect public contract")

func _test_transactions() -> void:
	for id in Items.UNIQUE_IDS:
		var p := _player()
		var first := Items.resolve(content, p, {"cost": {"gold": 40}, "item_id": id})
		_check(first.ok and first.player.gold == 60, "first unique receipt " + id)
		var held: Dictionary = first.player.duplicate(true)
		var duplicate := Items.resolve(content, held, {"cost": {"gold": 40, "hp": 10, "max_hp": 10, "keys": 1}, "item_id": id, "effects": {"attack": 100}})
		_check(not duplicate.ok and held == first.player, "duplicate cannot debit or grant " + id)
	var p := _player()
	p.equipment_ids = ["heart_pendant"]
	p.hp = 125
	var before := p.duplicate(true)
	var cost := {"cost": {"max_hp": 10}, "effects": {"attack": 4}}
	var r2 := Items.resolve(content, p, cost)
	_check(r2.ok and r2.player.max_hp == 90 and r2.after.max_hp == 115, "R2 costs base cap, keeps equipment cap")
	_check(r2.player.hp == 115 and r2.hp_delta == -10 and r2.healing == 0 and r2.max_hp_delta == -10, "R2 HP clamps without healing")
	_check(p == before and Items.resolve(content, p, cost) == r2, "repeated previews are deterministic and pure")
	p.hp = 50
	_check(Items.resolve(content, p, cost).player.hp == 50, "R2 injured HP is not healed")
	p.max_hp = 10
	p.hp = 20
	_check(not Items.resolve(content, p, cost).ok, "R2 cannot spend equipment cap instead of base")
	p.max_hp = 11
	var last := Items.resolve(content, p, cost)
	_check(last.ok and last.player.max_hp == 1 and last.after.max_hp == 26, "R2 permits exactly one base cap")
	p = _player()
	var combined := Items.resolve(content, p, {"cost": {"max_hp": 10}, "effects": {"max_hp": 20}})
	_check(combined.player.hp == 90 and combined.after.max_hp == 110 and combined.healing == 0, "cap gain without heal cannot undo cap cost")
	var gift := Items.resolve(content, p, {"cost": {"max_hp": 10}, "item_id": "heart_pendant"})
	_check(gift.player.hp == 115 and gift.healing == 25, "item cap heals once after paying cap cost")
	p.hp = 99
	var heal := Items.resolve(content, p, {"effects": {"heal": 45}})
	_check(heal.healing == 1 and heal.overflow == 44 and heal.player.hp == 100, "healing reports actual and overflow")
	_check(not Items.resolve(content, p, {"cost": {"hp": 99}}).ok, "HP sacrifice must keep one")
	_check(Items.resolve(content, p, {"cost": {"hp": 98}}).player.hp == 1, "HP sacrifice permits one")
	for field in ["gold", "keys", "silver_keys", "gold_keys"]:
		_check(Items.resolve(content, p, {"cost": {field: p[field]}}).player[field] == 0, "exact resource cost " + field)
		_check(not Items.resolve(content, p, {"cost": {field: p[field] + 1}}).ok, "insufficient resource " + field)

func _test_validation() -> void:
	var original := content.duplicate(true)
	var p := _player()
	for invalid in [{"cost": []}, {"effects": []}, {"cost": {"gold": -1}}, {"cost": {"gold": true}},
		{"cost": {"gold": "1"}}, {"effects": {"heal": 1.5}}, {"effects": {"heal": NAN}},
		{"effects": {"heal": INF}}, {"effects": {"heal": Items.LIMIT + 1}}, {"effects": {"unknown": 1}},
		{"cost": {"unknown": 1}}, {"item_id": "missing"}, {"item_id": 2}, {"effects": {"gold": Items.LIMIT}}]:
		_check(not Items.resolve(content, p, invalid).ok and p == _player(), "reject invalid transaction " + str(invalid))
	for bad in ["unexpected", [], 1, null]:
		var defs := Items.definitions()
		defs.p3_dawn_sigil.effects = bad
		_check(not Items.validate_definitions(defs).ok, "malformed effects rejected")
	for effect in [{"id": "unknown", "amount": 1}, {"id": "counter_guard", "amount": 2, "charges": 0},
		{"id": "counter_guard", "amount": 2, "charges": 101}, {"id": "periodic_hit_bonus", "amount": 3, "interval": 0},
		{"id": "retaliation", "amount": -1, "charges": 3}, {"id": "first_hit_bonus", "amount": 4, "hidden": 1}]:
		var defs := Items.definitions()
		defs.p3_dawn_sigil.combat_effects = [effect]
		_check(not Items.validate_definitions(defs).ok, "invalid combat definition " + str(effect))
	var defs := Items.definitions()
	defs.p3_dawn_sigil.unique_per_run = false
	_check(not Items.validate_definitions(defs).ok, "cannot disable new uniqueness")
	defs = Items.definitions()
	defs.p3_gilded_lantern.conditional_effects[0].id = "unknown"
	_check(not Items.validate_definitions(defs).ok, "unknown condition rejected")
	p.relic_ids = ["p3_dawn_sigil", "p3_dawn_sigil"]
	_check(not Items.player_stats(p, content).ok, "invalid duplicate snapshot rejected")
	p.relic_ids = ["missing"]
	_check(not Items.player_stats(p, content).ok, "unknown owned item rejected")
	p.relic_ids = ["iron_sword"]
	_check(not Items.player_stats(p, content).ok, "wrong collection rejected")
	defs = Items.definitions()
	defs.p3_dawn_sigil.combat_effects[0].amount = 7
	var frozen := Items.merge_content(db.data, defs)
	defs.p3_dawn_sigil.combat_effects[0].amount = 99
	p = _player()
	p.relic_ids = ["p3_dawn_sigil"]
	_check(Items.player_stats(p, frozen).combat_effects[0].amount == 7, "explicit snapshot is isolated from later definitions")
	_check(content == original, "all validation and transactions preserve content")

func _test_summary() -> void:
	var p := _player()
	p.relic_ids = ["gold_sword", "merchant_seal", "p3_gilded_lantern"]
	var model := Summary.describe(p, content)
	_check(model.ok and model.tags.wealth == 3 and model.rows[2].notes[0].contains("+2"), "summary explains active lantern")
	var comparison := Summary.reward_comparison(content, p, {"cost": {"gold": 42}, "item_id": "steel_blade"})
	_check(comparison.ok and comparison.text.contains("+4") and comparison.text.contains("-2"), "UI shows net attack and defense")
	p.relic_ids = ["gold_sword", "gold_sword"]
	model = Summary.describe(p, content)
	_check(model.rows.size() == 2 and model.rows[0].notes.size() == 1, "old duplicate rows each explain their own bonus once")
	p = _player()
	var reward := {"item_id": "iron_sword"}
	var enemy: Dictionary = db.data.enemies.slime
	comparison = Summary.reward_comparison(content, p, reward, enemy, OldCombat.simulate)
	_check(comparison.ok and comparison.combat_before.counterattacks == 2 and comparison.combat_after.counterattacks == 2, "comparison uses supplied production simulator")
	_check(not Summary.reward_comparison(content, p, reward, enemy).ok, "marked enemy requires simulator")
	var panel := Summary.new()
	panel.present(p, content, comparison)
	_check(panel.get_child_count() > 3, "component can instantiate and present without host UI")
	panel.free()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
	evidence.append({"pass": condition, "case": description})
