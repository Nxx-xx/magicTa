extends SceneTree
const DB = preload("res://scripts/core/content_db.gd")
const Rewards = preload("res://scripts/core/rewards.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Items = preload("res://scripts/core/phase3_items.gd")
const Combat2 = preload("res://scripts/core/phase3_combat.gd")
const ROOT := "res://build/verification/phase3/01-items/integration/"
var checks := 0
var failures := 0
var records: Array = []

func _initialize() -> void:
	_test_recorded_legacy()
	_test_dispatch()
	FileAccess.open(ROOT + "dispatch-results.json", FileAccess.WRITE).store_string(JSON.stringify({
		"checks": checks, "failures": failures, "cases": records, "user_data_dir": OS.get_user_data_dir()}, "  "))
	print("Phase3 explicit dispatch: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_recorded_legacy() -> void:
	var baseline: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "legacy-before-dispatch.json"))
	if not baseline is Dictionary:
		_check(false, "pre-change baseline must exist")
		return
	var db = DB.new()
	_check(db.rules_version == 1, "ContentDB defaults explicitly to rules version 1")
	for index in baseline.records.size():
		var row: Dictionary = baseline.records[index]
		_check(_equal(db.player_stats(row.player), row.stats), "legacy stats exact keys and values %d" % index)
		_check(_equal(Rewards.resolve(db, row.player, row.reward), row.reward_result), "legacy reward complete result %d" % index)
		for battle in row.battles:
			_check(_equal(Combat.simulate(row.player, battle.enemy, row.stats), battle.expected), "legacy default full report %d %s" % [index, battle.enemy.id])
			_check(_equal(Combat.simulate(row.player, battle.enemy, row.stats, 1), battle.expected), "legacy explicit v1 full report %d %s" % [index, battle.enemy.id])

func _test_dispatch() -> void:
	var db = DB.new()
	db.data = Items.merge_content(db.data)
	var player := {"hp": 100, "max_hp": 100, "attack": 15, "defense": 5, "gold": 100,
		"keys": 2, "silver_keys": 1, "gold_keys": 1, "equipment_ids": [], "relic_ids": ["p3_dawn_sigil", "p3_gilded_lantern"]}
	var enemy := {"id": "fixture", "rank": "normal", "hp": 30, "attack": 8, "defense": 2, "gold_reward": 10, "ability_id": ""}
	var original := player.duplicate(true)
	var content_before: Dictionary = db.data.duplicate(true)
	var legacy: Dictionary = db.player_stats(player)
	_check(legacy.defense == 5 and not legacy.has("combat_effects"), "p3 item presence never switches stats version")
	_check(not Rewards.resolve(db, player, {"cost": {"max_hp": 10}}).ok, "default reward keeps old cap-cost rejection")
	_check(Rewards.resolve(db, player, {"item_id": "p3_dawn_sigil"}).ok, "default reward keeps old duplicate semantics even with p3 IDs")
	db.rules_version = 2
	var stats: Dictionary = db.player_stats(player)
	_check(stats == Items.player_stats(player, db.data) and stats.defense == 7, "v2 stats delegate exactly to frozen item module")
	_check(stats.combat_effects.size() == 1, "v2 emits dawn effect but not a second lantern defense effect")
	var direct := Combat2.simulate(player, enemy, stats)
	_check(Combat.simulate(player, enemy, stats, 2) == direct and direct.turns == 2, "explicit combat v2 delegates exact report")
	var default_report := Combat.simulate(player, enemy, stats)
	_check(default_report.turns == 3 and not default_report.has("combat_rules_version"), "combat default ignores effect presence and keeps old report shape")
	var sacrifice := {"cost": {"max_hp": 10}, "effects": {"attack": 4}}
	var candidate := Rewards.resolve(db, player, sacrifice)
	_check(candidate == Items.resolve(db.data, player, sacrifice), "v2 reward delegates complete result")
	_check(candidate.player.max_hp == 90 and candidate.player.hp == 90 and candidate.healing == 0, "public reward entry supports cap cost and HP clamp")
	_check(not Rewards.resolve(db, player, {"cost": {"gold": 40}, "item_id": "p3_dawn_sigil"}).ok, "public v2 reward refuses unique duplicate")
	player.relic_ids = []
	stats = db.player_stats(player)
	_check(stats.has("combat_effects") and Combat.simulate(player, enemy, stats, 2).combat_rules_version == 2, "explicit v2 applies without any p3 item")
	player = original.duplicate(true)
	db.data.items.p3_dawn_sigil.combat_effects[0].amount = 9
	stats = db.player_stats(player)
	_check(stats.combat_effects[0].amount == 9, "stats entry uses caller snapshot instead of reloading JSON")
	_check(Combat.simulate(player, enemy, stats, 2).log[0].hit == 22, "combat entry consumes frozen effect amount")
	db.data = content_before.duplicate(true)
	for version in [-1, 0, 3, 99]:
		db.rules_version = version
		var bad_stats: Dictionary = db.player_stats(player)
		var bad_reward := Rewards.resolve(db, player, sacrifice)
		var bad_combat := Combat.simulate(player, enemy, stats, version)
		for rejected in [bad_stats, bad_reward, bad_combat]:
			_check(rejected.get("ok") == false and not str(rejected.get("error", "")).is_empty() and rejected.size() == 2, "unknown version %d returns explicit error without partial result" % version)
	_check(player == original and db.data == content_before, "all dispatch paths preserve inputs")
	db.rules_version = 1
	_check(db.player_stats(player) == legacy, "explicitly resetting to v1 restores old stats")
	_check(DB.new().rules_version == 1, "new database does not inherit previous version")

func _equal(left: Variant, right: Variant) -> bool:
	# JSON converts integer tokens to float; compare scalar numbers by value.
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size():
			return false
		for key in left:
			if not right.has(key) or not _equal(left[key], right[key]):
				return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size():
			return false
		for index in left.size():
			if not _equal(left[index], right[index]):
				return false
		return true
	if (left is int or left is float) and (right is int or right is float):
		return left == right
	return typeof(left) == typeof(right) and left == right

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
	records.append({"case": label, "pass": condition})
