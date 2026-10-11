extends SceneTree
const Ruins = preload("res://scripts/core/phase3_ruins.gd")
const Recipe = preload("res://scripts/core/phase3_map_recipe.gd")
const Generator = preload("res://scripts/core/campaign_generator.gd")
const Validator = preload("res://scripts/core/campaign_validator.gd")
const RuinPanel = preload("res://scripts/ui/phase3_ruin_panel.gd")
var checks := 0
var failures := 0
var maps := 0
var coverage := {}
var variants := {}
var items: GDScript
var content := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	content = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	items = load("res://scripts/core/phase3_items.gd")
	if items == null:
		_check(false, "Authoritative phase3_items required for transaction boundary tests")
		quit(1)
		return
	content = items.merge_content(content)
	content.events.merge(Ruins.event_definitions(), true)
	# Variant identities are protocol fixtures; enemy arithmetic is not owned here.
	for id in Recipe.VARIANTS:
		content.enemies[id] = {"name":id}
	_test_ruins()
	_test_maps()
	await _test_panel()
	var report := {"checks":checks,"failures":failures,"maps":maps,"coverage":coverage.keys(),
		"variants":variants,"transactions":"production phase3_items.resolve","seeds":"0..199",
		"scope":"generation and isolated previews; no route, persistence or full-stage claim"}
	var output := FileAccess.open("res://build/verification/phase3/02-ruins/results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	print("PHASE3_RUINS " + JSON.stringify(report))
	quit(1 if failures else 0)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures <= 30: push_error("FAIL: " + label)

func _player(hp: int = 100, max_hp: int = 100, gold: int = 100) -> Dictionary:
	return {"hp":hp,"max_hp":max_hp,"attack":10,"defense":5,"gold":gold,
		"keys":0,"silver_keys":0,"gold_keys":0,"equipment_ids":[],"relic_ids":[]}

func _preview(id: String, player: Dictionary) -> Dictionary:
	return Ruins.preview_options(id, player, content, Callable(items,"resolve"))

func _test_ruins() -> void:
	var defs := Ruins.definitions()
	_check(Ruins.validate_definitions(defs).ok, "all three definitions valid")
	for id in defs:
		var leave := Ruins.reward_for_option(id, "leave", defs)
		_check(leave.ok and not leave.consumes and leave.reward.is_empty(), "free nonconsuming leave")
		_check(_preview(id,_player()).options.leave.ok, "three ruins independent without R1 state")
	_check(not Ruins.reward_for_option("unknown", "leave").ok, "unknown ruin rejected")
	_check(not Ruins.reward_for_option("p3_oath_ruin", "unknown").ok, "unknown option rejected")
	var bad := defs.duplicate(true)
	bad.p3_oath_ruin.options[0].cost.hp = -1
	_check(not Ruins.validate_definitions(bad).ok, "negative cost rejected")
	bad = defs.duplicate(true)
	bad.p3_oath_ruin.options[0].effects.mystery = 1
	_check(not Ruins.validate_definitions(bad).ok, "unknown effects rejected")
	bad = defs.duplicate(true)
	bad.p3_oath_ruin.options[3].cost = {"gold":1}
	_check(not Ruins.validate_definitions(bad).ok, "paid leave rejected")
	for hp in [12,13]:
		for gold in [14,15]:
			var player := _player(hp,100,gold)
			var frozen := player.duplicate(true)
			var snapshot := content.duplicate(true)
			var preview := _preview("p3_oath_ruin",player)
			_check(preview.ok and preview.options.edge.ok == (hp == 13), "HP 12/13 boundary")
			_check(preview.options.guard.ok == (gold == 15), "gold 14/15 boundary")
			_check(player == frozen and content == snapshot, "preview keeps player and content immutable")
			if hp == 13: _check(preview.options.edge.player.hp == 1 and preview.options.edge.attack_delta == 2, "edge actual deltas")
	for base in [10,11,100]:
		for hp in [1,base]:
			var result: Dictionary = _preview("p3_oath_forge",_player(hp,base)).options.sacrifice
			_check(result.ok == (base >= 11), "max HP 10/11 boundary")
			if result.ok:
				_check(result.player.hp == mini(hp,base-10) and result.healing == 0 and result.max_hp_delta == -10 and result.attack_delta == 4, "sacrifice truncates only; never heals")
	var equipped := _player(131,101)
	equipped.relic_ids = ["spring_seed"]
	var result: Dictionary = _preview("p3_oath_forge",equipped).options.sacrifice
	_check(result.ok and result.player.max_hp == 91 and result.after.max_hp == 121 and result.player.hp == 121, "equipment max HP retained")
	equipped.max_hp = 10
	equipped.hp = 40
	_check(not _preview("p3_oath_forge",equipped).options.sacrifice.ok, "equipment cannot pay base max HP debt")
	_check(not _preview("p3_lantern_sanctuary",_player()).options.restore.ok, "full HP restore disabled")
	result = _preview("p3_lantern_sanctuary",_player(90)).options.restore
	_check(result.ok and result.healing == 10 and result.overflow == 25, "actual healing and overflow")
	_check(not _preview("p3_lantern_sanctuary",_player(12)).options.reserve.ok, "reserve HP bound")
	var bounds := Ruins.direct_effect_budget()
	_check(bounds.upper_bounds == {"hp_cost":24,"max_hp_cost":10,"gold_cost":40,"attack":6,"defense":3,"gold_gain":53,"heal":35}, "direct effects independent maxima")
	seed(314159)
	var expected := randi()
	seed(314159)
	_preview("p3_oath_ruin",_player())
	_check(randi() == expected, "preview does not consume global RNG")
	var mark := {"discovered":true,"entity_id":"f1:1,4","floor":1,"previous_report":{"won":false,"incoming":100}}
	var frozen_mark := mark.duplicate(true)
	_check(Ruins.marked_target_hint(mark,{"won":true,"incoming":20}).show_hint, "marked target becomes survivable")
	_check(mark == frozen_mark and Ruins.marked_target_hint(mark,{"won":true}).show_hint, "reopening never mutates comparison baseline")
	mark.discovered = false
	var hidden := Ruins.marked_target_hint(mark,{"won":true})
	_check(not hidden.show_hint and not hidden.has("entity_id") and not hidden.has("current"), "undiscovered enemy data not exposed")
	var state := {"entity_id":"f2:5,7","ruin_id":"p3_oath_ruin","rules_version":1,"status":"available","selected_option":"","transaction_id":""}
	var state_before := state.duplicate(true)
	var player := _player(13)
	var candidate := Ruins.prepare_resolution("p3_oath_ruin","edge",state,content,player,Callable(items,"resolve"),"fixture-run")
	_check(candidate.ok and candidate.player.hp == 1 and candidate.ruin_state.status == "resolved", "atomic candidate uses real transaction")
	_check(state == state_before and player.hp == 13, "uncommitted/discarded candidate never charges original")
	var retry := Ruins.prepare_resolution("p3_oath_ruin","edge",state,content,player,Callable(items,"resolve"),"fixture-run")
	_check(retry == candidate and candidate.ruin_state.transaction_id == "fixture-run:f2:5,7:resolve", "retry candidate deterministic with stable transaction key")
	_check(not Ruins.prepare_resolution("p3_oath_ruin","guard",candidate.ruin_state,content,candidate.player,Callable(items,"resolve"),"fixture-run").ok, "resolved state rejects second benefit")
	var leave := Ruins.prepare_resolution("p3_oath_ruin","leave",state,content,player,Callable(),"")
	_check(leave.ok and not leave.consumes and leave.ruin_state == state_before, "leave does not require transaction or consume state")
	var corrupt: Dictionary = candidate.ruin_state.duplicate(true)
	corrupt.selected_option = "unknown"
	_check(not Ruins.prepare_resolution("p3_oath_ruin","leave",corrupt,content,player,Callable(),"").ok, "corrupt resolved choice rejected")

func _context(number: int, theme: String, used: Array = []) -> Dictionary:
	return {"freshly_generated":true,"floor":number,"theme":theme,"unlocked_ids":items.UNIQUE_IDS.duplicate(),
		"used_unique_ids":used,"variant_plan":{"3":"p3_shield_sentinel","6":"p3_ember_channeler","8":"p3_vault_knight"}}

func _test_maps() -> void:
	var generator := Generator.new()
	for seed_value in range(200):
		var plan: Dictionary = generator.plan(str(seed_value))
		for theme in ["battle","treasure","shop"]:
			for geometry in ["existing","ruin_spokes"]:
				var used := []
				var totals := {"equipment":0,"relic":0,"merchants":0,"rests":0,"events":0}
				for number in range(1,11):
					var actual_theme: String = "boss" if number in [5,10] else theme
					var original: Dictionary = generator.generate(plan,number,actual_theme,"dawn_spear")
					var frozen := original.duplicate(true)
					var context := _context(number,actual_theme,used)
					context.geometry = geometry
					context.orientation = seed_value % 8
					var output := Recipe.decorate_floor(original,content,context)
					_check(output.ok, "seed %d floor %d %s %s: %s" % [seed_value,number,theme,geometry,output.error])
					if not output.ok: continue
					maps += 1
					var map: Dictionary = output.floor_map
					_check(original == frozen, "map input is immutable")
					_check(Validator.validate(map).is_empty(), "production validator accepts decorated floor")
					_check(_fixed(original) == _fixed(map), "fixed growth and Boss entities unchanged")
					_check(original.entities.size() == map.entities.size(), "no entity deletion or budget repair")
					_check(map.phase3_recipe.opportunities == Recipe.opportunity_counts(map,content).counts, "opportunity ledger recomputes")
					used.append_array(output.new_unique_ids)
					for field in totals: totals[field] += map.phase3_recipe.opportunities[field]
					coverage["%s/%s/%s" % [str(original.template_id),geometry,str(context.orientation)]] = true
					if not output.report.variant.is_empty(): variants[output.report.variant] = int(variants.get(output.report.variant,0)) + 1
				_check(totals.equipment <= 14 and totals.relic <= 17 and totals.merchants == 2 and totals.rests == 2 and totals.events == 3, "whole tower opportunity/facility budget")
	_test_edge_maps(generator)

func _fixed(map: Dictionary) -> Array:
	var result := []
	for entity in map.entities.values():
		if entity.get("fixed_growth",false) or entity.get("campaign_boss",false) or entity.get("campaign_boss_reward",false) or entity.get("role") in ["weapon_trial_gate","return_guard_gate"]:
			var copy: Dictionary = entity.duplicate(true)
			copy.erase("id")
			copy.erase("pos")
			result.append(JSON.stringify(copy))
	result.sort()
	return result

func _test_edge_maps(generator) -> void:
	var plan: Dictionary = generator.plan("0")
	plan.floors["2"].template_id = 0
	var map: Dictionary = generator.generate(plan,2,"battle","dawn_spear")
	var context := _context(2,"battle")
	var output := Recipe.decorate_floor(map,content,context)
	_check(output == Recipe.decorate_floor(map,content,context), "same frozen inputs reproduce")
	var invalid_content := content.duplicate(true)
	invalid_content.items.p3_dawn_sigil = 5
	_check(not Recipe.decorate_floor(map,invalid_content,context).ok, "malformed content returns error rather than indexing scalar")
	_check(output.floor_map.rows == map.rows and output.floor_map.branch_paths == map.branch_paths, "safe-slot path keeps original geometry")
	_check(not Recipe.decorate_floor(output.floor_map,content,context).ok, "cannot redecorate")
	context.freshly_generated = false
	_check(not Recipe.decorate_floor(map,content,context).ok, "visited input rejected")
	context.freshly_generated = true
	context.variant_plan = {"3":"p3_shield_sentinel","4":"p3_shield_sentinel"}
	_check(not Recipe.decorate_floor(map,content,context).ok, "duplicate whole-tower variants rejected")
	context.variant_plan = {}
	context.used_unique_ids = ["p3_dawn_sigil","p3_bounty_ledger"]
	output = Recipe.decorate_floor(map,content,context)
	_check(output.ok and output.report.theme_choices == ["sun_emblem","guardian_oath"], "unique reservations use deterministic fallback")
	var locked_context := _context(6,"treasure")
	locked_context.unlocked_ids = []
	var locked_map: Dictionary = generator.generate(plan,6,"treasure","dawn_spear")
	output = Recipe.decorate_floor(locked_map,content,locked_context)
	_check(output.ok and output.report.theme_choices == ["sun_emblem","guardian_oath"], "locked tier II uses legal fallback")
	context.geometry = "ruin_spokes"
	map.entities["3,8"] = {"id":"f2:3,8","type":"gold","name":"future interior fixture","pos":[3,8],"amount":1}
	output = Recipe.decorate_floor(map,content,context)
	_check(output.ok and output.report.geometry == "existing" and not output.report.geometry_fallback.is_empty() and output.floor_map.entities.size() == map.entities.size(), "unsupported geometry deterministically retains every entity")
	seed(271828)
	var expected := randi()
	seed(271828)
	Recipe.decorate_floor(map,content,context)
	_check(randi() == expected, "map transform does not consume global RNG")

func _test_panel() -> void:
	var panel := RuinPanel.new()
	root.add_child(panel)
	panel.size = Vector2(320,600)
	var ruin: Dictionary = Ruins.definitions().p3_oath_ruin
	var previews := _preview("p3_oath_ruin",_player(12,100,14))
	var frozen := previews.duplicate(true)
	panel.present(ruin,previews.options)
	await process_frame
	panel.option_button("edge").pressed.emit()
	_check(panel._action.disabled, "insufficient choice details readable but commit disabled")
	panel.show_overview()
	_check(not panel.leave_button().disabled, "leave always enabled")
	var emitted := []
	panel.option_selected.connect(func(id): emitted.append(id))
	panel.leave_requested.connect(func(): emitted.append("leave"))
	panel.option_button("salvage").pressed.emit()
	_check(emitted.is_empty(), "inspection never commits")
	panel._action.pressed.emit()
	panel.leave_button().pressed.emit()
	_check(emitted == ["salvage","leave"] and previews == frozen, "panel emits IDs without mutating transaction")
	panel.present(ruin,previews.options,{"status":"resolved","selected_option":"salvage"})
	panel.option_button("salvage").pressed.emit()
	_check(panel._action.disabled and not panel.leave_button().disabled, "spent detail read-only with free exit")
	await process_frame
	await process_frame
	_check(panel.size.x == 320 and panel.leave_button().get_global_rect().end.y <= 600, "320-width layout fits and exit stays outside scroll")
	panel.queue_free()
