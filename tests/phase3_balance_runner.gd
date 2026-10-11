extends "res://tests/phase3_integration_runner.gd"
## Explicit unlocked-account fixture; player growth uses production APIs only.
const BALANCE_OUT := "res://build/verification/phase3/06-animation-balance/"
const Progress = preload("res://scripts/core/phase3_progress.gd")
var challenge := "p3_c1"
var start_config := "default"
var observations: Array = []
var supplies := false
var early_rests := {}
var prepared := false
var fight_variants := false

func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("phase3/06-animation-balance/"):
		quit(2)
		return
	suite_started = Time.get_ticks_msec()
	evidence_out = BALANCE_OUT
	DirAccess.make_dir_recursive_absolute(evidence_out)
	batch = "--batch" in OS.get_cmdline_user_args()
	supplies = "--supplies" in OS.get_cmdline_user_args()
	prepared = "--prepared" in OS.get_cmdline_user_args()
	fight_variants = "--variants" in OS.get_cmdline_user_args()
	if supplies:
		evidence_out += "variants/" if fight_variants else ("prepared/" if prepared else "supplied/")
		DirAccess.make_dir_recursive_absolute(evidence_out)
	run_folder = "user://balance_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(run_folder)
	Core = load("res://scripts/core/campaign_engine.gd")
	_suite.call_deferred()

func _suite() -> void:
	for level in ["p3_c1", "p3_c2"]:
		challenge = level
		for config in ["default", "p3_vanguard", "p3_keeper", "p3_trader"]:
			start_config = config
			for seed_value in (range(10) if batch else [42]):
				for build in ["attack", "defense", "wealth"]:
					_route(str(seed_value), build, not batch)
					_write_results()
					await process_frame
	_finish()

func _new_case(name: String, persist: bool = true) -> void:
	super._new_case(challenge + "_" + start_config + "_" + name, persist)
	context.challenge = challenge
	context.start_config = start_config
	context.account_provenance = "explicit unlock fixture; zero embers; not earned progression proof"
	context.supply_policy = "complementary equipment at floor3; safe potions; early rest if lethal" if prepared else ("safe potions, one shop purchase, early rest if lethal" if supplies else "original C0 minimal route")
	early_rests = {}
	# Account-only fixture, labelled in each route. Never touch state.player.
	core.meta = Progress.migrate_meta(core.meta)
	core.meta.unlocked_ids = ["p3_c0", "p3_c1", "p3_c2", "default", "p3_vanguard", "p3_keeper", "p3_trader"]

func _start_phase3(seed_text: String = "42", replay: Dictionary = {}) -> bool:
	var result: String = core.start_phase3(seed_text, challenge, start_config, replay)
	if not _check(result.is_empty() and not core.state.is_empty(), "challenge start accepted", {"error":result}): return false
	var expected: Dictionary = Progress.initial_player(core.meta, start_config).player
	_check(core.state.player == expected, "actual production starting configuration; no player overrides")
	expected_min_hp = int(expected.hp)
	return true

func _test_replay(snapshot: Dictionary) -> void:
	var result: String = core.start_phase3("42", challenge, start_config, snapshot)
	_check(result.is_empty(), "challenge snapshot retry accepted")
	for field in ["reward_content", "campaign_plan", "challenge_snapshot", "start_config_snapshot"]:
		_check(core.state.get(field) == snapshot.get(field), "challenge retry freezes " + field)

func _fight(cell: Vector2i, permit_lethal: bool = false) -> bool:
	if prepared and int(core.state.floor) == 3: _buy_complement()
	if supplies and not permit_lethal and core.preview(cell).get("lethal",false):
		_collect_safe_supplies()
		var rest := _entity_cell("rest")
		if core.preview(cell).get("lethal",false) and rest.x >= 0:
			if not super._rest(): return false
			early_rests[int(core.state.floor)] = true
	if not _walk(cell): return false
	var entity: Dictionary = core.entity_at(cell)
	if entity.get("type") == "enemy":
		var report: Dictionary = core.preview(cell)
		var enemy_id := str(entity.enemy_id)
		var sample := {"context":context.duplicate(true), "floor":core.state.floor, "enemy_id":enemy_id,
			"stats":core.stats(), "player":core.state.player.duplicate(true), "incoming":report.get("incoming",-1), "lethal":report.get("lethal",false)}
		var base_id: String = {"p3_shield_sentinel":"sentinel", "p3_ember_channeler":"warlock", "p3_vault_knight":"knight"}.get(enemy_id, "")
		if not base_id.is_empty():
			var baseline := P3Combat.simulate(core.state.player, core.db.enemy(base_id), core.stats())
			sample.extra_incoming = int(report.incoming) - int(baseline.incoming)
			sample.exceeds_20_percent = sample.extra_incoming > float(core.stats().max_hp) * 0.2
		observations.append(sample)
	return super._fight(cell, permit_lethal)

func _buy_complement() -> void:
	var shop := _entity_cell("shop")
	if shop.x < 0 or core.entity_at(shop).get("purchased",false) or int(core.state.player.gold)<30: return
	var offer := "buy_bow" if "tower_shield" in core.state.player.equipment_ids else "buy_shield"
	var entity: Dictionary = core.entity_at(shop).duplicate(true)
	if not _walk(shop): return
	var before: Dictionary = core.state.player.duplicate(true)
	var result: String = core.buy(entity.offers.find(offer))
	_check(result.is_empty(),"production complementary equipment purchase",{"error":result})
	trace.append({"kind":"shop_complement","floor":3,"offer":offer,"before":before,"after":core.state.player.duplicate(true)})

func _rest() -> bool:
	return true if early_rests.has(int(core.state.floor)) else super._rest()

func _travel_up(seed_text: String, number: int) -> bool:
	if supplies: _collect_safe_supplies()
	if fight_variants:
		for index in core.floor_data().branch_paths.size():
			var gate := _point(core.floor_data().branch_paths[index][0])
			var entity: Dictionary = core.entity_at(gate)
			if entity.get("type") != "enemy" or not str(entity.get("enemy_id", "")).begins_with("p3_"): continue
			if core.preview(gate).lethal:
				observations.append({"context":context.duplicate(true),"floor":number,"enemy_id":entity.enemy_id,"optional_variant_skipped_lethal":true})
				continue
			if not _branch(index): return false
	# Counterfactual preview at real route stats; do not call it an actual fight.
	for entity in core.floor_data().entities.values():
		if entity.get("type") != "enemy": continue
		var id := str(entity.enemy_id)
		var base_id: String = {"p3_shield_sentinel":"sentinel", "p3_ember_channeler":"warlock", "p3_vault_knight":"knight"}.get(id, "")
		if base_id.is_empty(): continue
		var report: Dictionary = core.preview(_point(entity.pos))
		var baseline := P3Combat.simulate(core.state.player,core.db.enemy(base_id),core.stats())
		observations.append({"context":context.duplicate(true),"floor":number,"enemy_id":id,"counterfactual_optional_preview":true,
			"stats":core.stats(),"incoming":report.incoming,"extra_incoming":int(report.incoming)-int(baseline.incoming),
			"exceeds_20_percent":int(report.incoming)-int(baseline.incoming)>float(core.stats().max_hp)*0.2})
	return super._travel_up(seed_text,number)

func _reachable(target: Vector2i) -> bool:
	var queue: Array[Vector2i] = [core.position()]
	var seen := {core.position():true}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == target: return true
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell+direction
			if core.is_wall(next) or seen.has(next): continue
			if core.entity_at(next).get("type", "") in ["enemy","door","up","down"]: continue
			seen[next] = true
			queue.append(next)
	return false

func _collect_safe_supplies() -> void:
	for raw in core.floor_data().entities.values().duplicate(true):
		var cell := _point(raw.pos)
		var kind := str(raw.get("type", ""))
		if kind not in ["potion","shop"] or not _reachable(cell): continue
		if int(core.stats().max_hp)-int(core.state.player.hp) < 30: continue
		if kind == "shop" and (raw.get("purchased",false) or int(core.state.player.gold)<16): continue
		if not _walk(cell): return
		var before: Dictionary = core.state.player.duplicate(true)
		var result: String = core.confirm_interaction() if kind == "potion" else core.buy(raw.offers.find("buy_potion"))
		_check(result.is_empty(),"production supply purchase/use",{"error":result})
		trace.append({"kind":"supply","floor":core.state.floor,"entity":raw,"before":before,"after":core.state.player.duplicate(true)})

func _write_results() -> void:
	var result := {"checks":checks, "failures":failures, "routes":routes, "observations":observations,
		"wins":routes.filter(func(r): return r.won).size(), "route_count":routes.size(),
		"account_provenance":"explicit unlock fixture; no player-stat mutation; not legal unlock preparation",
		"elapsed_ms":Time.get_ticks_msec()-suite_started}
	FileAccess.open(evidence_out + ("balance-batch.json" if batch else "balance-quick.json"), FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
