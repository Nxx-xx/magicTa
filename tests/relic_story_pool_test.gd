extends SceneTree
const Pool = preload("res://scripts/core/relic_story_pool.gd")
const Ruins = preload("res://scripts/core/phase3_ruins.gd")
const Trail = preload("res://scripts/core/relic_trail.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
const Store = preload("res://scripts/core/campaign_save.gd")
const Contract = preload("res://scripts/core/phase3_contract.gd")
var checks := 0
var failures := 0

class RejectStore:
	extends RefCounted
	var last_error := "pool settlement blocked"
	func write(_run: Dictionary, _meta: Dictionary) -> bool: return false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("verification/relic-pool/"):
		quit(2)
		return
	var stories := Pool.catalog()
	check(stories.size() == 6, "six complete histories")
	var base := Ruins.definitions()
	var base_budget := Ruins.direct_effect_budget(base)
	var source := Core.new("user://pool_source_%d.json" % Time.get_ticks_usec())
	check(source.start_phase3("42").is_empty(), "production start")
	var frozen: Dictionary = source.state.duplicate(true)
	var prose := {}
	for id in Pool.STORY_IDS:
		for chapter in stories[id].chapters:
			for variant in chapter.variants: prose[variant.description] = true
		for mask in 8:
			var definitions := Pool.materialize(base,id,[mask&1,(mask>>1)&1,(mask>>2)&1],stories)
			check(Ruins.validate_definitions(definitions).ok, "valid story/scene combination")
			var budget := Ruins.direct_effect_budget(definitions)
			for key in budget.upper_bounds:
				check(budget.upper_bounds[key] <= base_budget.upper_bounds[key], "no upper-bound reward inflation")
			var snapshot := frozen.duplicate(true)
			snapshot.ruin_definitions_snapshot = definitions
			snapshot.reward_content.events.merge(Ruins.event_definitions(definitions),true)
			var run := Core.new("user://pool_variant_%s_%d_%d.json" % [id,mask,Time.get_ticks_usec()])
			run.persistence_enabled = false
			check(run.start_phase3("ignored","p3_c0","default",snapshot).is_empty(), "replay accepts fully frozen variant")
			for index in 3:
				var number: int = [2,6,9][index]
				var floor_map: Dictionary = run.campaign_generator.generate(run.state.campaign_plan,number,"battle")
				check(not floor_map.is_empty(), "all three floors generate against selected rewards")
				run._accept_generated_floor(number,floor_map)
				run.state.floor = number
				var entity: Dictionary = {}
				for candidate in floor_map.entities.values():
					if candidate.has("ruin_id"): entity = candidate
				run.state.position = entity.pos.duplicate()
				run.state.pending = {"kind":"entity", "pos":entity.pos.duplicate()}
				check(run.choose_ruin("ward" if index == 2 else "salvage").is_empty(), "production reward resolution")
			check(Trail.complete(run.state), "all combinations connect")
			check(Trail.conclusion(run.state) == stories[id].conclusion, "correct conclusion without another hero's story")
			check(Trail.knight_memory(run.state) == stories[id].knight[2], "correct knight callback")
	check(prose.size() == 36, "36 separately written scenes")
	var sealed := Pool.materialize(base,"luoan",[0,0,0],stories)
	var disturbed := Pool.materialize(base,"luoan",[1,1,1],stories)
	check(sealed[Pool.IDS[0]].options != disturbed[Pool.IDS[0]].options, "scene changes actual items/costs/effects")
	var mixed := sealed.duplicate(true)
	mixed[Pool.IDS[1]] = Pool.materialize(base,"sefu",[0,0,0],stories)[Pool.IDS[1]]
	check(not Ruins.validate_definitions(mixed).ok, "mixed expedition snapshot rejected")
	var chosen := {}
	for seed_value in 120:
		var draw := Pool.for_run(base,seed_value,{"runs":0,"records":[]})
		check(draw == Pool.for_run(base,seed_value,{"runs":0,"records":[]}), "same inputs deterministic")
		chosen[draw[Pool.IDS[0]].trail.story_id] = true
	check(chosen.size() == 6, "all histories reachable from seed draw")
	_test_history_and_disk()
	_test_legacy(frozen)
	print("RELIC_STORY_POOL checks=%d failures=%d; 6 histories / 36 scenes / 48 combinations" % [checks,failures])
	quit(1 if failures else 0)

func _test_history_and_disk() -> void:
	var path := "user://pool_history_%d.json" % Time.get_ticks_usec()
	var core = Core.new(path)
	var history := []
	for index in 13:
		check(core.start_phase3("42").is_empty(), "same typed seed/new journey still advances story rotation")
		var id := Pool.story_id(core.state)
		check(id not in history.slice(maxi(0,history.size()-5)), "no repetition among six consecutive new journeys")
		history.append(id)
		var snapshot: Dictionary = core.state.duplicate(true)
		var rng_before: int = core.rng.state
		var resumed = Core.new(path)
		resumed.load_game()
		check(Contract.same_json(snapshot.ruin_definitions_snapshot,resumed.state.ruin_definitions_snapshot), "disk reload freezes all future scenes")
		check(core.rng.state == rng_before, "story inspection leaves gameplay RNG alone")
		if index == 0:
			var store = core.store
			core.store = RejectStore.new()
			check(not core.abandon_run().is_empty() and core.transaction_pending, "failed settlement holds history transaction")
			check(core.meta.records.is_empty(), "failed settlement cannot prematurely consume a story slot")
			core.store = store
			check(core.retry_save(), "retry atomically commits story history")
		else:
			check(core.abandon_run().is_empty(), "settle history")
		check(core.meta.records.back().get("relic_story_id") == id, "selected expedition recorded")
		if index == 0:
			var retry = Core.new("user://pool_retry_%d.json" % Time.get_ticks_usec())
			retry.meta = core.meta.duplicate(true)
			check(retry.start_phase3("ignored","p3_c0","default",snapshot).is_empty(), "explicit replay bypasses new draw")
			check(Contract.same_json(snapshot.ruin_definitions_snapshot,retry.state.ruin_definitions_snapshot), "same-journey retry retains story and every scene")
		var reloaded = Core.new(path)
		reloaded.load_game()
		check(reloaded.meta.records == JSON.parse_string(JSON.stringify(core.meta.records)), "anti-repeat history persists")
		core = reloaded

func _test_legacy(snapshot: Dictionary) -> void:
	for has_trail in [true,false]:
		var old := snapshot.duplicate(true)
		old.ruin_definitions_snapshot = Ruins.definitions()
		if not has_trail:
			for definition in old.ruin_definitions_snapshot.values(): definition.erase("trail")
		old.reward_content.events.merge(Ruins.event_definitions(old.ruin_definitions_snapshot),true)
		var core = Core.new("user://old_story_%d.json" % Time.get_ticks_usec())
		check(core.start_phase3("ignored","p3_c0","default",old).is_empty(), "old single-story and pre-story saves stay playable")
		check(core.state.ruin_definitions_snapshot == old.ruin_definitions_snapshot, "no retrofit into existing story snapshot")
		check(core.save_game(), "legacy story snapshot still saves")
