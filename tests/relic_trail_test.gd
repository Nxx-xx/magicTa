extends SceneTree
const Trail = preload("res://scripts/core/relic_trail.gd")
const Ruins = preload("res://scripts/core/phase3_ruins.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
var checks := 0
var failures := 0

class RejectStore:
	extends RefCounted
	var last_error := "relic trail write rejected"
	func write(_state: Dictionary, _meta: Dictionary) -> bool: return false

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("verification/relic-trail/"):
		quit(2)
		return
	var defs := Ruins.definitions()
	_check(Ruins.validate_definitions(defs).ok, "new narrative definitions valid")
	var run := {"ruin_definitions_snapshot":defs, "floors":{}}
	_check(Trail.entries(run).is_empty() and Trail.journal(run).is_empty(), "no unearned clues or spoilers")
	for a in ["edge", "guard", "salvage"]:
		for b in ["temper", "sacrifice", "salvage"]:
			for c in ["restore", "ward", "reserve"]:
				var choices := [a,b,c]
				var sample := run.duplicate(true)
				# Intentionally discover in reverse order, then fill the gaps.
				for index in [2,0,1]:
					var id: String = Trail.IDS[index]
					var entity := {"ruin_id":id, "status":"resolved", "selected_option":choices[index]}
					sample.floors[str(int(defs[id].floor))] = {"entities":{"1,3":entity}}
					_check(Trail.has_evidence(sample,id), "any reward branch records clue")
				_check(Trail.complete(sample) and Trail.journal(sample).size() == 4, "all 27 combinations complete")
				_check(Trail.entries(sample)[0].id == Trail.IDS[0], "journal follows story order after backtracking")
				var frozen := sample.duplicate(true)
				var reread := JSON.parse_string(JSON.stringify(sample)) as Dictionary
				_check(Trail.journal(reread) == Trail.journal(sample), "JSON round trip retains evidence and chosen relic")
				_check(not Trail.knight_memory(sample).is_empty(), "knight recalls full trail")
				Trail.presentation(sample,defs[Trail.IDS[2]],sample.floors["9"].entities["1,3"])
				_check(sample == frozen, "reading all narrative views cannot mutate state")
	var only_last := run.duplicate(true)
	only_last.floors["9"] = {"entities":{"1,3":{"ruin_id":Trail.IDS[2],"status":"resolved","selected_option":"ward"}}}
	_check(not Trail.complete(only_last), "later clue alone cannot unlock conclusion")
	_check(not Trail.presentation(only_last,defs[Trail.IDS[1]],{}).description.contains(defs[Trail.IDS[1]].trail.link), "missing earlier clue uses independent introduction")
	var old := defs.duplicate(true)
	for definition in old.values(): definition.erase("trail")
	_check(Ruins.validate_definitions(old).ok, "prior frozen snapshots remain valid")
	only_last.ruin_definitions_snapshot = old
	_check(Trail.journal(only_last).is_empty(), "old runs do not invent evidence")
	var bad := defs.duplicate(true)
	bad[Trail.IDS[0]].trail.finds.erase("salvage")
	_check(not Ruins.validate_definitions(bad).ok, "reject incomplete trail reward metadata")
	bad = defs.duplicate(true)
	bad[Trail.IDS[2]].trail.previous = Trail.IDS[0]
	_check(not Ruins.validate_definitions(bad).ok, "reject contradictory chapter link")
	_test_transaction()
	print("RELIC_TRAIL checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)

func _test_transaction() -> void:
	var path := "user://trail_%d.json" % Time.get_ticks_usec()
	var core = Core.new(path)
	_check(core.start_phase3("42").is_empty(), "new run persists narrative snapshot")
	# Production generated floor; positioning is a transaction fixture, not a playthrough.
	var floor_map: Dictionary = core.campaign_generator.generate(core.state.campaign_plan,2,"battle")
	core._accept_generated_floor(2,floor_map)
	core.state.floor = 2
	core.state.position = floor_map.entry.duplicate()
	var ruin: Dictionary = {}
	for entity in floor_map.entities.values():
		if entity.has("ruin_id"): ruin = entity
	core.state.position = ruin.pos.duplicate()
	core.state.pending = {"kind":"entity", "pos":ruin.pos.duplicate()}
	_check(core.save_game(), "valid floor fixture persists before choice")
	var state_before: Dictionary = core.state.duplicate(true)
	var rng_before: int = core.rng.state
	var store = core.store
	core.store = RejectStore.new()
	_check(not core.choose_ruin("salvage").is_empty() and core.transaction_pending, "failed write blocks transaction")
	_check(core.state == state_before and Trail.journal(core.state).is_empty(), "failed write grants neither evidence nor reward")
	core.store = store
	_check(core.retry_save(), "retry commits original transaction")
	_check(Trail.entries(core.state).size() == 1, "committed choice grants exactly one clue")
	_check(core.rng.state == rng_before, "trail never advances RNG")
	var loaded = Core.new(path)
	loaded.load_game()
	_check(Trail.journal(loaded.state) == Trail.journal(core.state), "real disk reload keeps clue and relic outcome")
	loaded.state.pending = {"kind":"entity", "pos":ruin.pos.duplicate()}
	var gold: int = loaded.state.player.gold
	_check(not loaded.choose_ruin("salvage").is_empty() and loaded.state.player.gold == gold, "cannot claim twice after reload")
	var other = Core.new("user://trail_leave_%d.json" % Time.get_ticks_usec())
	_check(other.start_phase3("42").is_empty(), "new run starts with no prior trail")
	_check(Trail.entries(other.state).is_empty(), "no clues leak into next run")
	other._accept_generated_floor(2,other.campaign_generator.generate(other.state.campaign_plan,2,"battle"))
	other.state.floor = 2
	other.state.position = ruin.pos.duplicate()
	other.state.pending = {"kind":"entity", "pos":ruin.pos.duplicate()}
	_check(other.choose_ruin("leave").is_empty() and Trail.entries(other.state).is_empty(), "leave keeps investigation unclaimed")
