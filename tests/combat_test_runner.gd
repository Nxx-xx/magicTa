extends SceneTree
## Shared combat/content regression for the current map game.
const DB = preload("res://scripts/core/content_db.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Enemies = preload("res://scripts/core/enemy_rules.gd")
var failures := 0
var checks := 0
var db = DB.new()

func _initialize() -> void:
	_test_combat()
	_test_monster_progression()
	_test_content()
	print("Combat tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _player(hp: int = 100, attack: int = 15, defense: int = 5) -> Dictionary:
	return {"hp": hp, "max_hp": 100, "attack": attack, "defense": defense,
		"gold": 0, "keys": 0, "equipment_ids": [], "relic_ids": []}

func _test_combat() -> void:
	var p := _player()
	var enemy := {"hp": 30, "attack": 10, "defense": 5, "gold_reward": 12, "ability_id": ""}
	var report: Dictionary = Combat.simulate(p, enemy, db.player_stats(p))
	_check(report.loss == 10 and report.hp_after == 90 and report.turns == 3, "document example = 10 HP loss")
	_check(report.counterattacks == 2 and report.gold_reward == 12, "last hit has no counterattack")
	_check(p.hp == 100 and enemy.hp == 30, "simulation does not mutate inputs")
	p.hp = 10
	report = Combat.simulate(p, enemy, db.player_stats(p))
	_check(report.lethal and report.hp_after == 0 and report.gold_reward == 0, "exact HP loss is lethal; no rewards")
	p = _player(100, 50, 0)
	report = Combat.simulate(p, enemy, db.player_stats(p))
	_check(report.loss == 0 and report.turns == 1, "one-hit kill has no retaliation")
	p = _player(100, 1, 100)
	report = Combat.simulate(p, enemy, db.player_stats(p))
	_check(report.turns == 30 and report.loss == 0, "minimum player damage 1; enemy damage may be zero")
	p = _player(80)
	p.relic_ids = ["blood_sword"]
	report = Combat.simulate(p, enemy, db.player_stats(p))
	_check(report.loss == 7 and report.healing == 3 and report.hp_after == 73, "kill-heal included in net loss")
	p.hp = 10
	report = Combat.simulate(p, enemy, db.player_stats(p))
	_check(report.lethal and report.healing == 0, "kill-heal cannot resurrect")
	p = _player(99, 50)
	p.relic_ids = ["crimson_chalice"]
	report = Combat.simulate(p, enemy, db.player_stats(p))
	_check(report.hp_after == 100 and report.healing == 1, "healing capped at maximum")
	p = _player(100, 38, 18)
	report = Combat.simulate(p, db.enemy("minotaur"), db.player_stats(p))
	_check(report.turns == 4 and report.loss == 2, "rage applies to third counterattack")
	p = _player(100, 114, 22)
	report = Combat.simulate(p, db.enemy("golem"), db.player_stats(p))
	_check(report.log[0].hit == 100 and report.log[1].hit == 96 and report.log[2].hit == 94, "golem crosses armor thresholds after each hit")
	p = _player()
	p.gold = 100
	p.relic_ids = ["gold_sword"]
	_check(db.player_stats(p).attack == 17, "gold sword uses held gold")
	p.gold = 49
	_check(db.player_stats(p).attack == 15, "spending removes gold-derived attack")

func _test_content() -> void:
	_check(db.errors.is_empty(), "content loads")
	_check(db.data.enemies.size() == 10, "6 normal + 2 elite + 2 bosses")
	_check(db.items_of_kind("equipment", 3).size() == 12, "12 equipment")
	_check(db.items_of_kind("relic", 3).size() == 10, "10 relics")
	_check(db.data.events.size() == 10 and db.data.shop.size() == 10, "10 events and shop products")
	for event in db.data.events.values():
		_check(event.options.size() == 2, "event has two options: " + str(event.name))
	var counts := {"normal": 0, "elite": 0, "boss": 0}
	for enemy in db.data.enemies.values():
		_check(Enemies.valid_definition(enemy), "monster metadata valid: " + str(enemy.id))
		counts[enemy.rank] += 1
	_check(counts == {"normal": 6, "elite": 2, "boss": 2}, "monster identities match the design")
	_check(Enemies.classification(db.enemy("knight")) == "普通 · Ⅲ档 · 高阶", "return knight remains a normal high-tier monster")
	_check(Enemies.badge(db.enemy("knight"), {"guardian": true}) == "回", "return guardian has a text badge")
	_check(Enemies.classification(db.enemy("minotaur")) == "Boss · 第 5 层", "boss uses its stage instead of a normal tier")

func _test_monster_progression() -> void:
	var early_losses := {"slime": 6, "skeleton": 25, "bat": 24}
	var late_losses := {"slime": 0, "skeleton": 2, "bat": 4, "sentinel": 12, "warlock": 30, "knight": 77}
	for id in late_losses:
		var initial := _player(100, 10, 5)
		var report: Dictionary = Combat.simulate(initial, db.enemy(id), db.player_stats(initial))
		if early_losses.has(id):
			_check(report.won and report.loss == early_losses[id], "entry combat cost: " + id)
		else:
			_check(report.lethal and report.gold_reward == 0, "strong monster starts lethal: " + id)
		initial.equipment_ids = ["dawn_spear", "knight_plate"]
		report = Combat.simulate(initial, db.enemy(id), db.player_stats(initial))
		_check(report.won and report.loss == late_losses[id], "equipment lowers combat cost: " + id)
	var player := _player(100, 10, 5)
	var trial: Dictionary = Combat.simulate(player, db.enemy("slime"), db.player_stats(player))
	player.hp = trial.hp_after
	player.equipment_ids = ["dawn_spear", "knight_plate"]
	var returning: Dictionary = Combat.simulate(player, db.enemy("knight"), db.player_stats(player))
	_check(returning.won and returning.hp_after == 17, "100 HP growth route survives without additional supplies")

