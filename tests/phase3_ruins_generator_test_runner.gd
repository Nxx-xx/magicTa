extends SceneTree
const Generation = preload("res://scripts/core/phase3_campaign_generator.gd")
const Legacy = preload("res://scripts/core/campaign_generator.gd")
const Validator = preload("res://scripts/core/campaign_validator.gd")
const Ruins = preload("res://scripts/core/phase3_ruins.gd")
const Items = preload("res://scripts/core/phase3_items.gd")
const Enemies = preload("res://scripts/core/phase3_enemies.gd")
var checks := 0
var failures := 0
var generated := 0
var snapshot := {}
var definitions := {}
var challenges := {}
var coverage := {}

func _initialize() -> void:
	definitions = Ruins.definitions()
	challenges = JSON.parse_string(FileAccess.get_file_as_string("res://data/phase3_challenges.json")).challenges
	snapshot = Items.merge_content(JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json")))
	snapshot = Enemies.merge_content(snapshot)
	snapshot.events.merge(Ruins.event_definitions(definitions),true)
	_test_rejection()
	_test_healing()
	_test_snapshot_replay()
	_test_production()
	var result := {"checks":checks,"failures":failures,"generated_floors":generated,"coverage":coverage.keys(),
		"seeds":"0..99 all challenges; 100..199 C0 holdout", "scope":"v2 generator adapter, not full journey/save integration"}
	var file := FileAccess.open("res://build/verification/phase3/02-ruins/generator-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("PHASE3_GENERATOR " + JSON.stringify(result))
	quit(1 if failures else 0)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures <= 30: push_error("FAIL: " + label)

func _context(challenge_id: String = "p3_c0") -> Dictionary:
	var challenge: Dictionary = challenges[challenge_id].duplicate(true)
	challenge.version = 1
	return {"ruin_definitions":definitions.duplicate(true),"unlocked_ids":Items.UNIQUE_IDS.duplicate(),
		"used_unique_ids":[],"variant_plan":{"3":"p3_shield_sentinel","6":"p3_ember_channeler","8":"p3_vault_knight"},
		"challenge_snapshot":challenge,"challenge_id":challenge_id}

func _generator(challenge_id: String = "p3_c0"):
	var generator = Generation.new()
	generator.content_snapshot = snapshot.duplicate(true)
	generator.phase3_context = _context(challenge_id)
	return generator

func _test_rejection() -> void:
	var generator = Generation.new()
	_check(generator.config.version == 2 and generator.config.event_floors == Generation.EVENTS, "external config is v2 with new events")
	_check(generator.plan("0").is_empty() and not generator.last_error.is_empty(), "missing frozen context rejects plan")
	generator.phase3_context = _context()
	var plan: Dictionary = generator.plan("0")
	_check(not plan.is_empty() and plan.version == 2, "plan can precede content construction with frozen context: " + generator.last_error)
	if plan.is_empty(): return
	_check(generator.generate(plan,1,"entrance").is_empty(), "missing frozen content rejected")
	generator.content_snapshot = snapshot.duplicate(true)
	_check(not generator.generate(plan,1,"entrance").is_empty() and generator.last_error.is_empty(), "failure does not poison next valid generate")
	for field in ["ruin_definitions","unlocked_ids","used_unique_ids","variant_plan","challenge_snapshot"]:
		generator.phase3_context = _context()
		generator.phase3_context.erase(field)
		_check(generator.plan("0").is_empty() and generator.generate(plan,1,"entrance").is_empty(), "missing frozen " + field)
	generator.phase3_context = _context()
	generator.phase3_context.ruin_definitions = {}
	_check(generator.generate(plan,1,"entrance").is_empty(), "empty definitions cannot hot read")
	generator.phase3_context = _context()
	generator.phase3_context.variant_plan = {"3":"p3_shield_sentinel","4":"p3_shield_sentinel"}
	_check(generator.plan("0").is_empty(), "duplicate variants rejected before any floor")
	generator.phase3_context = _context()
	generator.phase3_context.geometry = "existing"
	_check(generator.generate(plan,1,"entrance").is_empty(), "context cannot override frozen geometry")
	generator.phase3_context = _context()
	for field in ["version","heal_percent"]:
		generator.phase3_context.challenge_snapshot.erase(field)
		_check(generator.generate(plan,1,"entrance").is_empty(), "challenge snapshot missing " + field)
		generator.phase3_context = _context()
	generator.phase3_context.challenge_id = "p3_c2"
	_check(generator.generate(plan,1,"entrance").is_empty(), "challenge id contradiction")
	generator.phase3_context = _context()
	var bad := plan.duplicate(true)
	bad.version = 1
	_check(not generator.validate_plan(bad).ok and generator.generate(bad,1,"entrance").is_empty(), "legacy plan never silently promoted")
	bad = plan.duplicate(true)
	bad.floors["1"].fixed_equipment = []
	_check(not generator.validate_plan(bad).ok, "fixed equipment plan mismatch")
	bad = plan.duplicate(true)
	bad.floors["1"].reward_budget = [99,99]
	_check(not generator.validate_plan(bad).ok, "budget mismatch")
	bad = plan.duplicate(true)
	bad.floors["1"].template_id = 7
	_check(not generator.validate_plan(bad).ok, "unknown template rejected")
	bad = plan.duplicate(true)
	bad.floors["1"].floor_seed = 10
	_check(not generator.validate_plan(bad).ok, "numeric rather than string seed rejected")
	generator.content_snapshot.events.p3_oath_ruin.options[0].effects.attack = 999
	_check(generator.generate(plan,2,"battle").is_empty(), "event content cannot contradict frozen ruin definition")
	generator.content_snapshot = snapshot.duplicate(true)
	generator.content_snapshot.events.erase("p3_oath_forge")
	_check(generator.generate(plan,1,"entrance").is_empty(), "missing frozen event rejected early")
	generator.content_snapshot = snapshot.duplicate(true)
	generator.content_snapshot.items.erase("p3_dawn_sigil")
	_check(generator.generate(plan,2,"battle").is_empty(), "missing mechanism item cannot silently substitute current definitions")
	generator.content_snapshot = snapshot.duplicate(true)
	_check(generator.generate(plan,5,"battle").is_empty() and generator.generate(plan,2,"entrance").is_empty() and generator.generate(plan,11,"shop").is_empty(), "invalid floor/theme combinations")
	_check(generator.generate(plan,6,"battle","unknown").is_empty(), "unknown Boss choice rejected")
	generator.config.fixed_equipment["1"] = ["steel_blade"]
	_check(generator.plan("0").is_empty(), "cannot alter mandatory fixed growth")

func _test_healing() -> void:
	var map := {"entities":{
		"p0":{"type":"potion","amount":0},"p1":{"type":"potion","amount":1},
		"p2":{"type":"potion","amount":2},"p35":{"type":"potion","amount":35},
		"p45":{"type":"potion","amount":45},
		"r":{"type":"rest","options":[{"effects":{"heal":70}},{"effects":{"max_hp":20,"heal":20}},{"effects":{"max_hp":20}}]},
		"s":{"type":"shop","effects":{"heal":50}},"e":{"type":"event","effects":{"heal":35}},
		"k":{"type":"kill","effects":{"heal":4}},"m":{"type":"max_hp","amount":30}}}
	var before := map.duplicate(true)
	var rule: Dictionary = _context("p3_c2").challenge_snapshot
	var output := Generation.apply_healing_snapshot(map,rule)
	_check(output.ok and map == before, "heal transform pure")
	var entities: Dictionary = output.floor_map.entities
	_check(entities.p0.amount == 0 and entities.p1.amount == 1 and entities.p2.amount == 1, "zero, floor and positive minimum")
	_check(entities.p35.amount == 28 and entities.p45.amount == 36, "C2 map potions")
	_check(entities.r.options[0].effects.heal == 56 and entities.r.options[1].effects == {"max_hp":20,"heal":16}, "C2 explicit rest healing only")
	_check(entities.r.options[1].description == "最大生命 +20，恢复 16 HP" and entities.p35.description == "恢复 28 HP。", "accurate scaled description")
	for id in ["s","e","k","m"]:
		_check(entities[id] == before.entities[id], "source unaffected: " + id)
	_check(not entities.r.options[2].has("phase3_heal_base"), "implicit max HP recovery not modified")
	_check(not Generation.apply_healing_snapshot(output.floor_map,rule).ok, "second heal application refused")
	var stripped: Dictionary = output.floor_map.duplicate(true)
	stripped.erase("phase3_healing")
	_check(not Generation.apply_healing_snapshot(stripped,rule).ok, "per-source baseline catches removed floor marker")
	rule.heal_percent = 50
	output = Generation.apply_healing_snapshot(map,rule)
	_check(output.floor_map.entities.p35.amount == 17 and output.floor_map.entities.r.options[0].effects.heal == 35, "frozen percentage used instead of hardcoded live C2 value")
	for id in ["p3_c0","p3_c1"]:
		output = Generation.apply_healing_snapshot(map,_context(id).challenge_snapshot)
		_check(output.floor_map.entities.p35.amount == 35 and output.floor_map.entities.r.options[1].effects.heal == 20, "C0/C1 healing unchanged")
	for bad_percent in [-1,0,101,0.8,"80",NAN,INF]:
		rule.heal_percent = bad_percent
		_check(not Generation.apply_healing_snapshot(map,rule).ok, "invalid frozen percentage rejected")

func _test_snapshot_replay() -> void:
	var generator = _generator("p3_c2")
	generator.config.floor_names[1] = "冻结快照中的第二层"
	generator.phase3_context.ruin_definitions.p3_oath_ruin.name = "冻结誓约"
	generator.content_snapshot.events.merge(Ruins.event_definitions(generator.phase3_context.ruin_definitions),true)
	for id in ["library","forge","hermit"]: generator.content_snapshot.events.erase(id)
	var plan: Dictionary = generator.plan("snapshot-only")
	if plan.is_empty():
		_check(false,"snapshot plan: " + generator.last_error)
		return
	var expected: Dictionary = generator.generate(plan,2,"battle")
	_check(not expected.is_empty() and expected.name == "冻结快照中的第二层", "frozen config and event definitions used without old event table")
	var restored = Generation.new(JSON.parse_string(JSON.stringify(generator.config)))
	restored.phase3_context = JSON.parse_string(JSON.stringify(generator.phase3_context))
	restored.content_snapshot = JSON.parse_string(JSON.stringify(generator.content_snapshot))
	var restored_plan: Dictionary = JSON.parse_string(JSON.stringify(plan))
	_check(restored.generate(restored_plan,2,"battle") == expected, "JSON freeze/replay reproduces decorated floor exactly")
	var old_config: Dictionary = generator.config.duplicate(true)
	old_config.erase("ruin_geometry")
	var old_v2 = Generation.new(old_config)
	old_v2.phase3_context = generator.phase3_context.duplicate(true)
	old_v2.content_snapshot = generator.content_snapshot.duplicate(true)
	var old_floor: Dictionary = old_v2.generate(plan,2,"battle")
	_check(not old_floor.is_empty() and old_floor.phase3_recipe.report.geometry == "existing", "pre-layout v2 snapshot keeps unvisited floors on old geometry")
	old_v2.config.ruin_geometry = "future_geometry"
	_check(old_v2.generate(plan,2,"battle").is_empty(), "unknown frozen geometry rejected")
	_check(restored.config.version == 2 and restored.config.event_floors == Generation.EVENTS and restored_plan.version == 2, "legacy conversion never changes caller config/plan")
	var frozen_context: Dictionary = generator.phase3_context.duplicate(true)
	var frozen_content: Dictionary = generator.content_snapshot.duplicate(true)
	seed(9821)
	var next_random := randi()
	seed(9821)
	generator.generate(plan,2,"battle")
	_check(randi() == next_random and generator.phase3_context == frozen_context and generator.content_snapshot == frozen_content, "no global RNG/content/context mutation")
	generator.phase3_context.used_unique_ids = ["p3_dawn_sigil","p3_bounty_ledger"]
	var fallback: Dictionary = generator.generate(plan,2,"battle")
	_check(fallback.phase3_new_unique_ids.is_empty() and fallback.phase3_recipe.report.theme_choices == ["sun_emblem","guardian_oath"], "external reservation table respected")

func _test_production() -> void:
	var legacy = Legacy.new()
	var legacy_config: Dictionary = legacy.config.duplicate(true)
	for seed_value in range(200):
		for challenge_id in (["p3_c0","p3_c1","p3_c2"] if seed_value < 100 else ["p3_c0"]):
			var generator = _generator(challenge_id)
			var plan: Dictionary = generator.plan(str(seed_value))
			_check(not plan.is_empty() and generator.validate_plan(plan).ok, "v2 plan valid: " + generator.last_error)
			if plan.is_empty(): return
			_check(plan == generator.plan(str(seed_value)), "repeat plan deterministic")
			var old_plan: Dictionary = legacy.plan(str(seed_value))
			_check(plan.floors == old_plan.floors and plan.budget == old_plan.budget, "underlying recipe and budgets retained")
			for theme in ["battle","treasure","shop"]:
				generator.phase3_context.used_unique_ids = []
				var totals := {"equipment":0,"relic":0,"merchants":0,"rests":0,"events":0}
				for number in range(1,11):
					var selected: String = "entrance" if number == 1 else ("boss" if number in [5,10] else theme)
					var choice: String = "dawn_spear" if seed_value % 2 == 0 else "obsidian_mail"
					var map: Dictionary = generator.generate(plan,number,selected,choice)
					_check(not map.is_empty(), "%s seed%d floor%d: %s" % [challenge_id,seed_value,number,generator.last_error])
					if map.is_empty(): continue
					generated += 1
					var original: Dictionary = legacy.generate(old_plan,number,selected,choice)
					var transformed: bool = number in [2,6,9]
					_check(map.generator_version == 2, "v2 marker")
					if transformed:
						_check(map.phase3_recipe.report.geometry == "ruin_spokes" and map.phase3_recipe.report.geometry_fallback.is_empty(), "new journey uses ruin geometry")
					else:
						_check(map.rows == original.rows and map.entry == original.entry and map.exit == original.exit and map.branch_paths == original.branch_paths, "other floors retain geometry")
					_check(Validator.validate(map).is_empty() and map.entities.size() == original.entities.size(), "production invariants and no deleted entity")
					for key in original.entities:
						var entity: Dictionary = original.entities[key]
						var updated: Dictionary = map.entities.get(key, {})
						if transformed:
							# Compare content through the retained branch/safe-slot role;
							# coordinates and entity IDs deliberately change on new maps.
							var destination: Array = []
							for slot in original.safe_slots:
								if original.safe_slots[slot] == entity.pos: destination = map.safe_slots[slot]
							for branch_index in range(4):
								for end in [0,-1]:
									if original.branch_paths[branch_index][end] == entity.pos: destination = map.branch_paths[branch_index][end]
							if entity.pos == original.entry: destination = map.entry
							if entity.pos == original.exit: destination = map.exit
							_check(not destination.is_empty(), "all original entity roles mapped")
							if destination.is_empty(): continue
							updated = map.entities["%d,%d" % [destination[0],destination[1]]].duplicate(true)
							updated.id = entity.id
							updated.pos = entity.pos
						if entity.get("fixed_growth",false) or entity.get("campaign_boss",false) or entity.get("campaign_boss_reward",false) or entity.get("role") in ["weapon_trial_gate","return_guard_gate"]:
							_check(updated == entity, "fixed growth and Boss gate content unchanged")
						if entity.type == "potion":
							var amount := maxi(1,int(int(entity.amount)*0.8)) if challenge_id == "p3_c2" else int(entity.amount)
							_check(updated.amount == amount and updated.phase3_heal_base == entity.amount, "potions scaled once from generator baseline")
						if entity.type == "rest":
							_check(updated.options[0].effects.heal == (56 if challenge_id == "p3_c2" else 70), "rest heal correct in every generated floor")
					if number in [2,6,9]:
						var id: String = Generation.EVENTS[str(number)]
						_check(map.phase3_recipe.report.event == id, "new event exactly replaces old safe slot")
					generator.phase3_context.used_unique_ids.append_array(map.phase3_new_unique_ids)
					var counts: Dictionary = generator.count_opportunities(map)
					_check(counts == map.phase3_recipe.opportunities, "compatible flat opportunity ledger")
					for field in totals: totals[field] += counts[field]
					coverage["%s/%s" % [challenge_id,str(map.template_id)]] = true
				_check(totals.equipment <= 14 and totals.relic <= 17 and totals.events == 3 and totals.rests == 2 and totals.merchants == 2, "global v2 budget and guaranteed facilities")
	_check(legacy.config == legacy_config and legacy.config.version == 1 and legacy.config.event_floors == Generation.OLD_EVENTS, "independent old generator semantics untouched")
