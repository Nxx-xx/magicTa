extends SceneTree
## Run after importing once: godot --headless --path . --script tests/test_runner.gd
## Calls production GDScript directly. No independent copy of combat rules.

const DB = preload("res://scripts/core/content_db.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Core = preload("res://scripts/core/run_engine.gd")
const Store = preload("res://scripts/core/save_store.gd")
const Enemies = preload("res://scripts/core/enemy_rules.gd")
const SavedData = preload("res://tests/saved_data.gd")
var failures := 0
var checks := 0
var db = DB.new()
var test_path := "user://tower_test_%d.json" % OS.get_process_id()

func _initialize() -> void:
	_test_combat()
	_test_monster_progression()
	_test_content()
	_test_economy_and_rooms()
	_test_determinism()
	_test_save()
	_test_full_run()
	_test_zero_upgrade_route()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
	print("Tower tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _player(hp: int = 100, attack: int = 15, defense: int = 5) -> Dictionary:
	return {"hp": hp, "max_hp": 100, "attack": attack, "defense": defense,
		"gold": 0, "keys": 0, "equipment_ids": [], "relic_ids": []}

func _core():
	var core = Core.new(test_path)
	core.persistence_enabled = false
	core.start("42")
	return core

func _room(kind: String, enemy_id: String = "slime") -> Dictionary:
	return {"id": "test_room", "floor": 1, "type": kind, "name": "测试房间",
		"enemy_id": enemy_id, "event_id": "altar", "lock_cost": 0,
		"rewards": ["blood_sword", "gold_sword"], "offers": ["buy_sword", "buy_potion", "buy_key"]}

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

func _test_economy_and_rooms() -> void:
	var core = _core()
	core.run.room_options = [_room("normal")]
	var predicted: Dictionary = core.preview(core.run.room_options[0])
	core.enter_room(0)
	_check(core.run.player.hp == predicted.hp_after and core.run.player.gold == predicted.gold_reward, "preview equals actual outcome")
	_check(core.run.floor == 2 and core.run.history.size() == 1, "room completion advances exactly one floor")
	core = _core()
	core.run.player.hp = 1
	core.run.room_options = [_room("normal", "knight")]
	_check(core.enter_room(0) == "confirm_lethal" and core.run.player.hp == 1, "lethal fight requires explicit confirmation")
	core.enter_room(0, true)
	_check(core.run.result == "death" and core.run.completed, "confirmed lethal fight ends run")
	var souls := int(core.meta.souls)
	core.enter_room(0, true)
	core._finish("death")
	_check(core.meta.souls == souls, "ended run cannot award souls twice")
	core = _core()
	core.run.room_options = [_room("shop")]
	core.enter_room(0)
	_check(core.run.phase == "shop" and core.run.room_options.is_empty(), "entering shop locks room selection")
	_check(core.buy(0) == "金币不足。" and core.run.floor == 1, "insufficient funds do not advance")
	core.run.player.gold = 50
	core.buy(0)
	_check(core.run.floor == 2 and core.run.player.gold == 30 and core.stats().attack == 13, "purchase charged once and equipment takes effect")
	core.buy(0)
	_check(core.run.player.gold == 30, "second purchase is impossible")
	core = _core()
	var chest := _room("chest")
	chest.lock_cost = 1
	chest.item_id = "heart_pendant"
	chest.gold = 20
	chest.reward_text = "生命吊坠"
	core.run.room_options = [chest]
	_check(core.enter_room(0) == "钥匙不足。" and core.run.floor == 1, "locked chest rejects missing key")
	core.run.player.keys = 1
	core.enter_room(0)
	_check(core.run.player.keys == 0 and core.stats().max_hp == 125 and core.run.player.hp == 125, "key consumed and max HP item heals increment")
	core = _core()
	core.run.room_options = [_room("event")]
	core.run.player.hp = 20
	core.enter_room(0)
	_check(not core.choose_option(0).is_empty() and core.run.player.hp == 20, "sacrifice must leave one HP")
	core.choose_option(1)
	_check(core.run.floor == 2 and core.run.player.hp == 25, "safe event option progresses")
	core = _core()
	core.run.room_options = [_room("rest")]
	core.enter_room(0)
	core.choose_option(1)
	_check(core.stats().attack == 13 and core.stats().defense == 6, "rest training is a choice")
	core = _core()
	core.run.player.attack = 500
	core.run.room_options = [_room("elite", "berserker")]
	core.enter_room(0)
	_check(core.run.phase == "reward" and core.run.floor == 1, "elite pauses for two-choice reward")
	core.choose_reward(0)
	_check(core.run.floor == 2 and core.run.player.relic_ids.has("blood_sword"), "reward grants and advances")
	core = _core()
	core.meta.souls = 100
	_check(not core.upgrade("attack").is_empty(), "meta upgrades blocked during run")
	core.abandon()
	_check(core.run.soul_reward == 0, "abandoning gives no souls")
	for i in 3:
		core.upgrade("attack")
	_check(core.meta.upgrades.attack == 3 and core.meta.souls == 52, "upgrade cost and cap")
	_check(not core.upgrade("attack").is_empty(), "fourth upgrade rejected")
	core.start("42")
	_check(core.run.player.attack == 13, "meta upgrade applies on next run")

func _test_determinism() -> void:
	var left = _core()
	var right = _core()
	_check(left.run.room_options == right.run.room_options, "same seed same first floor")
	for floor_number in range(1, 11):
		left.run.floor = floor_number
		right.run.floor = floor_number
		left._generate_floor()
		right._generate_floor()
		_check(left.run.room_options == right.run.room_options, "same RNG progression floor %d" % floor_number)
		_check(left.run.room_options.size() == (1 if floor_number in [5, 10] else 3), "correct candidate count floor %d" % floor_number)
		if floor_number in [5, 10]:
			_check(left.run.room_options[0].type == "boss", "boss floor is mandatory")

func _test_save() -> void:
	var original = _core()
	original.persistence_enabled = true
	original.run.room_options = [_room("shop")]
	original.enter_room(0)
	var restored = Core.new(test_path)
	restored.load_game()
	_check(restored.run.phase == "shop" and SavedData.equal(restored.run.selected_room, original.run.selected_room), "resume inside pending shop")
	_check(restored.rng.state == original.rng.state, "64-bit RNG state survives JSON")
	original.leave_shop()
	restored.leave_shop()
	_check(restored.run.room_options == original.run.room_options, "resumed run generates identical next floor")
	original.run.phase = "reward"
	original.run.pending_choices = ["blood_sword", "gold_sword"]
	original.run.selected_room = _room("elite")
	original.save_game()
	restored.load_game()
	_check(restored.run.pending_choices == original.run.pending_choices and restored.run.phase == "reward", "pending reward survives reload")
	var stored = Store.new(test_path)
	_check(stored.read().version == 1, "versioned envelope is readable")
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string("{broken-json")
	file.close()
	_check(not stored.read().is_empty() and not stored.last_error.is_empty(), "invalid primary recovers backup")
	original.persistence_enabled = false
	original._finish("death")
	original.persistence_enabled = true
	original.save_game()
	restored.load_game()
	var souls := int(restored.meta.souls)
	restored._finish("death")
	_check(restored.meta.souls == souls, "reload does not duplicate soul reward")

func _test_full_run() -> void:
	# Deliberately boosted fixture tests transitions, NOT natural game balance.
	var core = _core()
	core.run.player.attack = 1000
	core.run.player.defense = 1000
	while core.active():
		if core.run.phase == "reward":
			core.choose_reward(0)
			continue
		var found := false
		for index in core.run.room_options.size():
			if core.run.room_options[index].type in ["normal", "elite", "boss"]:
				core.enter_room(index)
				found = true
				break
		if not found:
			_check(false, "each floor has a combat route")
			break
	_check(core.run.result == "victory" and core.run.history.size() == 10, "10-floor run reaches victory")
	_check(core.meta.wins == 1 and core.run.soul_reward >= 20, "victory awards soul bonus exactly once")

func _test_zero_upgrade_route() -> void:
	# A legal, hand-selected route proves baseline stats can win. It is NOT a
	# measured seed win rate: random rooms still need real balance/seed testing.
	var core = _core()
	core.run.room_options = [_room("rest")]
	core.enter_room(0)
	core.choose_option(1)
	_scripted_chest(core, "hunter_bow")
	var event := _room("event")
	event.event_id = "armory"
	core.run.room_options = [event]
	core.enter_room(0)
	core.choose_option(0)
	_scripted_chest(core, "steel_blade")
	_check(core.run.floor == 5 and core.stats().attack == 28, "baseline route arrives at first boss")
	core.enter_room(0)
	_check(core.run.phase == "reward" and core.run.player.hp == 79, "baseline survives minotaur and heals")
	core.choose_reward(1)
	_scripted_chest(core, "knight_plate")
	core.run.room_options = [_room("rest")]
	core.enter_room(0)
	core.choose_option(1)
	var shop := _room("shop")
	shop.offers = ["buy_plate", "buy_steel", "buy_potion"]
	core.run.room_options = [shop]
	core.enter_room(0)
	core.buy(0)
	core.run.room_options = [_room("rest")]
	core.enter_room(0)
	core.choose_option(1)
	_check(core.run.floor == 10 and core.stats().defense == 22, "baseline defense route reaches golem")
	core.enter_room(0)
	_check(core.run.result == "victory" and core.meta.upgrades.attack == 0, "a legal route wins without meta upgrades")

func _scripted_chest(core, id: String) -> void:
	var room := _room("chest")
	room.item_id = id
	room.gold = 0
	room.reward_text = id
	core.run.room_options = [room]
	core.enter_room(0)
