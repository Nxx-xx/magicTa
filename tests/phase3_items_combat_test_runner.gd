extends SceneTree
## Cross-module checks: item-derived effects go into the production combat2 API.
const Items = preload("res://scripts/core/phase3_items.gd")
const Combat = preload("res://scripts/core/phase3_combat.gd")
const Summary = preload("res://scripts/ui/phase3_build_summary.gd")
const OldDB = preload("res://scripts/core/content_db.gd")
const OldCombat = preload("res://scripts/core/combat.gd")
var content: Dictionary
var checks := 0
var failures := 0
var cases: Array = []

func _initialize() -> void:
	var db = OldDB.new()
	content = Items.merge_content(db.data)
	var p := _player()
	var e := _enemy()
	var plain := _fight(p, e)
	p.relic_ids = ["p3_dawn_sigil"]
	var dawn := _fight(p, e)
	_check(plain.turns == 2 and dawn.turns == 2 and dawn.incoming == 3, "first hit bonus need not reduce counter count")
	e.hp = 30
	var crossed := _fight(p, e)
	p.relic_ids = []
	_check(_fight(p, e).turns == 3 and crossed.turns == 2, "dawn crosses exact 30 HP threshold")
	var compared := Summary.reward_comparison(content, p, {"item_id": "p3_dawn_sigil"}, e, Combat.simulate)
	_check(compared.ok and compared.combat_before.counterattacks == 2 and compared.combat_after.counterattacks == 1, "marked enemy UI exposes one fewer counter")
	e.hp = 100
	p.relic_ids = ["p3_lantern_aegis"]
	var guard := _fight(p, e)
	_check(guard.log[0].counter == 1 and guard.log[1].counter == 1 and guard.log[2].counter == 3, "guard expires after two counters")
	_check(_count_events(guard, "counter_guard") == 2, "exactly two guard events")
	e.attack = 5
	guard = _fight(p, e)
	_check(_count_events(guard, "counter_guard") == 2 and guard.log[0].guard_reduction == 0, "zero counters spend guard charges")
	p.relic_ids = ["p3_rhythm_blade"]
	var rhythm := _fight(p, e)
	_check(rhythm.log[1].hit == 13 and rhythm.log[2].hit == 16 and rhythm.log[5].hit == 16, "third and sixth attacks use periodic bonus")
	p.relic_ids = ["p3_thorn_clasp"]
	var thorns := _fight(p, e)
	_check(_count_events(thorns, "retaliation") == 3 and thorns.incoming == 0, "three thorns trigger even on zero damage")
	_check(thorns.log[2].retaliation_damage == 2 and thorns.log[3].retaliation_damage == 0, "fourth counter has no thorns")
	p.relic_ids = ["p3_thorn_clasp", "crimson_chalice", "lucky_coin", "p3_bounty_ledger"]
	p.hp = 50
	e.hp = 15
	e.attack = 8
	e.rank = "elite"
	var thorn_kill := _fight(p, e)
	_check(thorn_kill.won and thorn_kill.turns == 1 and thorn_kill.log.size() == 1, "retaliation kill creates no next attack")
	_check(thorn_kill.healing == 8 and thorn_kill.gold_reward == 32 and thorn_kill.hp_after == 55, "retaliation kill rewards exactly once")
	p.hp = 1
	var death := _fight(p, e)
	_check(not death.won and death.healing == 0 and death.gold_reward == 0, "death grants no gold or healing")
	_check(_count_events(death, "retaliation") == 0 and death.enemy_hp_after == 2, "fatal counter cannot be rescued by thorns")
	p = _player()
	p.relic_ids = ["p3_bounty_ledger"]
	e = _enemy()
	for rank in ["normal", "elite", "boss"]:
		e.rank = rank
		_check(_fight(p, e).gold_reward == 10 + {"normal": 0, "elite": 10, "boss": 20}[rank], "bounty rank " + rank)
	p.relic_ids = ["p3_gilded_lantern"]
	p.gold = 99
	e.rank = "normal"
	e.gold_reward = 1
	var before := _fight(p, e)
	p.gold = 100
	var after := _fight(p, e)
	_check(before.incoming == 3 and after.incoming == 1, "lantern activates at battle-start threshold only once")
	_check(before.gold_reward == 1, "gold crossing threshold is a post-battle reward")
	p.relic_ids = Items.UNIQUE_IDS.duplicate()
	e.hp = 180
	var snapshot := p.duplicate(true)
	var all := _fight(p, e)
	_check(all.ok and all == _fight(p, e) and p == snapshot, "all six production effects are deterministic and pure")
	for id in db.data.items:
		p = _player()
		p.hp = 50
		p.equipment_ids = [id] if db.data.items[id].kind == "equipment" else []
		p.relic_ids = [id] if db.data.items[id].kind == "relic" else []
		for enemy_id in ["slime", "minotaur", "golem"]:
			var old := OldCombat.simulate(p, db.data.enemies[enemy_id], db.player_stats(p))
			var fresh := _fight(p, db.data.enemies[enemy_id])
			for field in ["won", "turns", "counterattacks", "incoming", "healing", "hp_after", "gold_reward"]:
				_check(old[field] == fresh[field], "old combat match %s / %s / %s" % [id, enemy_id, field])
	var report := FileAccess.open("res://build/verification/phase3/01-items/combat-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "cases": cases,
		"combat_sha256": FileAccess.get_sha256("res://scripts/core/phase3_combat.gd")}, "  "))
	print("Phase3 item/combat integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _player() -> Dictionary:
	return {"hp": 100, "max_hp": 100, "attack": 15, "defense": 5, "gold": 100,
		"keys": 0, "silver_keys": 0, "gold_keys": 0, "equipment_ids": [], "relic_ids": []}

func _enemy() -> Dictionary:
	return {"id": "fixture", "hp": 24, "attack": 8, "defense": 2, "gold_reward": 10, "rank": "normal", "ability_id": ""}

func _fight(player: Dictionary, enemy: Dictionary) -> Dictionary:
	return Combat.simulate(player, enemy, Items.player_stats(player, content))

func _count_events(report: Dictionary, id: String) -> int:
	var result := 0
	for event in report.effects_triggered:
		if event.id == id:
			result += 1
	return result

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
	cases.append({"pass": condition, "case": label})
